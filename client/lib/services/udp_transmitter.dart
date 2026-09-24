import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Expanded 12-byte protocol: <hHHhhBB
/// [0..1]  steer   : int16   Left Stick X       (-32768..32767)
/// [2..3]  throttle: uint16  Right Trigger axis  (0..65535)
/// [4..5]  brake   : uint16  Left Trigger axis   (0..65535)
/// [6..7]  rx      : int16   Right Stick X       (-32768..32767)
/// [8..9]  ry      : int16   Right Stick Y       (-32768..32767, up=positive)
/// [10]    btn1    : uint8   Bitmask A|B|X|Y|LB|RB|Start|Back
/// [11]    btn2    : uint8   Bitmask LStick|RStick|DUp|DDown|DLeft|DRight|--|--
class UdpTransmitter {
  String _targetHost;
  int _targetPort;
  int _targetIntervalMs;

  RawDatagramSocket? _socket;
  Timer? _ticker;

  // Pre-allocated 12-byte packet buffer (zero-GC path)
  final ByteData _byteData = ByteData(12);
  late final Uint8List _packetBuffer;

  InternetAddress? _cachedTargetAddress;

  // Axes
  int _steer    = 0; // int16
  int _throttle = 0; // uint16
  int _brake    = 0; // uint16
  int _rx       = 0; // int16  Right Stick X
  int _ry       = 0; // int16  Right Stick Y

  // Button bitmasks
  int _btn1 = 0; // uint8
  int _btn2 = 0; // uint8

  // Telemetry
  int _packetsSent     = 0;
  int _packetsInWindow = 0;
  double _currentHz    = 0.0;
  DateTime _lastHzCheck = DateTime.now();
  bool _isConnected = false;
  String? _lastError;

  // High-precision immediate dispatch tracking
  final Stopwatch _stopwatch = Stopwatch()..start();
  int _lastSendUs = 0;
  // Minimum interval between immediate packets to prevent flooding (2.5ms = max 400 Hz burst cap)
  static const int _minImmediateIntervalUs = 2500;

  void Function(double hz, int totalPackets)? onStatsUpdated;

  UdpTransmitter({
    String targetHost = '192.168.1.100',
    int targetPort = 5005,
    int targetIntervalMs = 5, // Default 5ms (200 Hz) for ultra-low latency
  })  : _targetHost = targetHost,
        _targetPort = targetPort,
        _targetIntervalMs = targetIntervalMs {
    _packetBuffer = _byteData.buffer.asUint8List();
  }

  String  get targetHost       => _targetHost;
  int     get targetPort       => _targetPort;
  int     get targetIntervalMs => _targetIntervalMs;
  double  get currentHz        => _currentHz;
  int     get packetsSent      => _packetsSent;
  bool    get isConnected      => _isConnected;
  String? get lastError        => _lastError;

  /// Update transmission interval (e.g. 5ms = 200 Hz, 10ms = 100 Hz).
  void setTargetIntervalMs(int ms) {
    _targetIntervalMs = ms.clamp(2, 50);
    if (_isConnected) {
      _ticker?.cancel();
      _ticker = Timer.periodic(
        Duration(milliseconds: _targetIntervalMs),
        (_) => _sendTick(),
      );
    }
  }

  // ── Button bit positions (btn1) ───────────────────────────────────────────
  static const int btnA     = 1 << 0;
  static const int btnB     = 1 << 1;
  static const int btnX     = 1 << 2;
  static const int btnY     = 1 << 3;
  static const int btnLB    = 1 << 4;
  static const int btnRB    = 1 << 5;
  static const int btnStart = 1 << 6;
  static const int btnBack  = 1 << 7;

  // Button bit positions (btn2)
  static const int btnLStick = 1 << 0;
  static const int btnRStick = 1 << 1;
  static const int btnDUp    = 1 << 2;
  static const int btnDDown  = 1 << 3;
  static const int btnDLeft  = 1 << 4;
  static const int btnDRight = 1 << 5;

  Future<void> start() async {
    await stop();
    try {
      _cachedTargetAddress = InternetAddress(_targetHost);
    } catch (_) {
      try {
        final addresses = await InternetAddress.lookup(_targetHost);
        if (addresses.isNotEmpty) _cachedTargetAddress = addresses.first;
      } catch (e) {
        _lastError = 'Address resolution failed: $e';
      }
    }

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _isConnected = true;
      _lastError = null;
      _ticker = Timer.periodic(
        Duration(milliseconds: _targetIntervalMs),
        (_) => _sendTick(),
      );
      _lastHzCheck = DateTime.now();
    } catch (e) {
      _isConnected = false;
      _lastError = 'Socket bind error: $e';
    }
  }

  Future<void> updateTarget(String host, int port) async {
    _targetHost = host.trim();
    _targetPort = port;
    _cachedTargetAddress = null;
    await start();
  }

  /// Update driving / left stick axes with immediate dispatch on change.
  void updateDriveInputs({
    required int steer,
    required int throttle,
    required int brake,
  }) {
    final s = steer.clamp(-32768, 32767);
    final t = throttle.clamp(0, 65535);
    final b = brake.clamp(0, 65535);

    if (s != _steer || t != _throttle || b != _brake) {
      _steer    = s;
      _throttle = t;
      _brake    = b;
      _sendImmediate();
    }
  }

  /// Update right stick (camera / look) with immediate dispatch on change.
  void updateRightStick({required int rx, required int ry}) {
    final x = rx.clamp(-32768, 32767);
    final y = ry.clamp(-32768, 32767);

    if (x != _rx || y != _ry) {
      _rx = x;
      _ry = y;
      _sendImmediate();
    }
  }

  /// Set / clear individual buttons with instant dispatch.
  void setButton(int mask, {bool btn2 = false, required bool pressed}) {
    final oldVal = btn2 ? _btn2 : _btn1;
    final newVal = pressed ? (oldVal | mask) : (oldVal & ~mask);

    if (newVal != oldVal) {
      if (btn2) {
        _btn2 = newVal;
      } else {
        _btn1 = newVal;
      }
      _sendImmediate();
    }
  }

  int get steer => _steer;
  int get throttle => _throttle;
  int get brake => _brake;
  int get rx => _rx;
  int get ry => _ry;
  int get btn1 => _btn1;
  int get btn2 => _btn2;

  /// Set left stick X axis independently
  void setSteer(int steer) => updateDriveInputs(steer: steer, throttle: _throttle, brake: _brake);

  /// Set right trigger (throttle) independently
  void setThrottle(int throttle) => updateDriveInputs(steer: _steer, throttle: throttle, brake: _brake);

  /// Set left trigger (brake) independently
  void setBrake(int brake) => updateDriveInputs(steer: _steer, throttle: _throttle, brake: brake);

  /// Full axis + button update in one call (used by driving mode).
  void updateInputs({
    required int steer,
    required int throttle,
    required int brake,
  }) => updateDriveInputs(steer: steer, throttle: throttle, brake: brake);

  /// Immediate dispatch on user input change with burst protection.
  void _sendImmediate() {
    final nowUs = _stopwatch.elapsedMicroseconds;
    if (nowUs - _lastSendUs >= _minImmediateIntervalUs) {
      _sendPacket();
      _lastSendUs = nowUs;
    }
  }

  /// Periodic tick ensures continuous telemetry and keeps failsafe alive.
  void _sendTick() {
    final nowUs = _stopwatch.elapsedMicroseconds;
    if (nowUs - _lastSendUs >= (_targetIntervalMs * 1000 - 1000)) {
      _sendPacket();
      _lastSendUs = nowUs;
    }
  }

  void _sendPacket() {
    if (_socket == null || _cachedTargetAddress == null) return;

    _byteData.setInt16 (0,  _steer,    Endian.little);
    _byteData.setUint16(2,  _throttle, Endian.little);
    _byteData.setUint16(4,  _brake,    Endian.little);
    _byteData.setInt16 (6,  _rx,       Endian.little);
    _byteData.setInt16 (8,  _ry,       Endian.little);
    _byteData.setUint8 (10, _btn1);
    _byteData.setUint8 (11, _btn2);

    try {
      final sent = _socket!.send(_packetBuffer, _cachedTargetAddress!, _targetPort);
      if (sent > 0) {
        _packetsSent++;
        _packetsInWindow++;
      }
    } catch (e) {
      _lastError = 'Send error: $e';
    }

    final now = DateTime.now();
    final elapsedMs = now.difference(_lastHzCheck).inMilliseconds;
    if (elapsedMs >= 500) {
      _currentHz       = _packetsInWindow / (elapsedMs / 1000.0);
      _packetsInWindow = 0;
      _lastHzCheck     = now;
      onStatsUpdated?.call(_currentHz, _packetsSent);
    }
  }

  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
    _socket?.close();
    _socket = null;
    _isConnected = false;
  }

  void dispose() => stop();
}
