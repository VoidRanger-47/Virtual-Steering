import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customization_config.dart';
import '../services/udp_transmitter.dart';
import '../theme/app_theme.dart';
import '../widgets/customization_studio.dart';
import '../widgets/hud_layout_editor.dart';
import '../widgets/steering_wheel.dart';
import '../widgets/pedal_slider.dart';
import 'rpg_screen.dart';
import 'gamepad_screen.dart';

/// Root shell: holds the transmitter, HUD, customization, settings, and bottom mode dock.
/// Switches content area between Racing / RPG / Gamepad modes.
class ControllerShell extends StatefulWidget {
  const ControllerShell({super.key});

  @override
  State<ControllerShell> createState() => _ControllerShellState();
}

class _ControllerShellState extends State<ControllerShell>
    with SingleTickerProviderStateMixin {
  late final UdpTransmitter _tx;
  late AnimationController _tabGlowCtrl;

  // Preferences
  static const _keyHost      = 'server_host';
  static const _keyPort      = 'server_port';
  static const _keyLatencyMs = 'server_latency_ms';

  String _host         = '192.168.1.100';
  int    _port         = 5005;
  int    _latencyMs    = 5; // Default 5ms (200 Hz) for ultra-low latency
  bool   _isUsbMode    = false;
  String _wifiFallback = '192.168.1.100';

  // Customization Configuration
  CustomizationConfig _customization = CustomizationConfig();

  // Telemetry stats
  double _hz        = 0.0;
  int    _totalPkts = 0;

  // Isolated ValueNotifiers for High-Frequency Telemetry (Prevents root rebuild jank)
  final ValueNotifier<double> _steerDegNotifier    = ValueNotifier<double>(0.0);
  final ValueNotifier<double> _throttlePctNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> _brakePctNotifier    = ValueNotifier<double>(0.0);
  final ValueNotifier<double> _clutchPctNotifier   = ValueNotifier<double>(0.0);

  // Raw drive inputs
  int _rawSteer    = 0;
  int _rawThrottle = 0;
  int _rawBrake    = 0;

  // Mode
  GameMode _mode = GameMode.racing;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _tx = UdpTransmitter(targetHost: _host, targetPort: _port, targetIntervalMs: _latencyMs);
    _tx.onStatsUpdated = (hz, pkts) {
      if (mounted) setState(() { _hz = hz; _totalPkts = pkts; });
    };

    _tabGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _loadPrefs().then((_) {
      _tx.start();
    });
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    final customCfg = await CustomizationConfig.loadFromPrefs();
    setState(() {
      _host          = p.getString(_keyHost) ?? '192.168.1.100';
      _port          = p.getInt(_keyPort)    ?? 5005;
      _latencyMs     = p.getInt(_keyLatencyMs) ?? 5;
      _wifiFallback  = _host;
      _customization = customCfg;
    });
    _tx.setTargetIntervalMs(_latencyMs);
    await _tx.updateTarget(_host, _port);
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyHost,      _host);
    await p.setInt   (_keyPort,       _port);
    await p.setInt   (_keyLatencyMs,  _latencyMs);
    await _customization.saveToPrefs();
  }

  @override
  void dispose() {
    _tx.dispose();
    _tabGlowCtrl.dispose();
    _steerDegNotifier.dispose();
    _throttlePctNotifier.dispose();
    _brakePctNotifier.dispose();
    _clutchPctNotifier.dispose();
    super.dispose();
  }

  void _toggleUsb() {
    setState(() {
      if (!_isUsbMode) {
        _wifiFallback = _host;
        _host         = '127.0.0.1';
        _isUsbMode    = true;
      } else {
        _host      = _wifiFallback;
        _isUsbMode = false;
      }
    });
    _tx.updateTarget(_host, _port);
  }

  void _showSettings() {
    final hostCtrl = TextEditingController(text: _host);
    final portCtrl = TextEditingController(text: _port.toString());
    double currentSens = _customization.steeringSensitivity;
    int selectedLatency = _latencyMs;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          backgroundColor: AppTheme.bgPanel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _mode.color.withOpacity(0.4)),
          ),
          title: Row(
            children: [
              Icon(Icons.tune_rounded, color: _mode.color),
              const SizedBox(width: 8),
              Text('Connection & Settings', style: AppTheme.title(size: 16, color: AppTheme.textPrimary)),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogCtx).size.height * 0.75,
              maxWidth: 380,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HOST IP ADDRESS (Windows PC)', style: AppTheme.label(size: 10, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: hostCtrl,
                    style: AppTheme.hud(size: 12, color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: '192.168.1.100',
                      hintStyle: AppTheme.hud(color: AppTheme.textDim),
                      filled: true,
                      fillColor: AppTheme.bgBase,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _mode.color.withOpacity(0.3)),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.usb_rounded, size: 18, color: _mode.color),
                        tooltip: 'USB: 127.0.0.1',
                        onPressed: () => hostCtrl.text = '127.0.0.1',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('UDP PORT', style: AppTheme.label(size: 10, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: portCtrl,
                    keyboardType: TextInputType.number,
                    style: AppTheme.hud(size: 12, color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.bgBase,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _mode.color.withOpacity(0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TARGET LATENCY / RATE:', style: AppTheme.label(size: 10, color: AppTheme.textSecondary)),
                      Text('${selectedLatency}ms (${(1000 / selectedLatency).round()} Hz)',
                          style: TextStyle(fontFamily: 'monospace', color: _mode.color, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      [5,  '5ms (200 Hz)',  'Ultra'],
                      [10, '10ms (100 Hz)', 'Fast'],
                      [16, '16ms (60 Hz)',  'Standard'],
                    ].map((entry) {
                      final ms = entry[0] as int;
                      final label = entry[1] as String;
                      final tag = entry[2] as String;
                      final sel = selectedLatency == ms;
                      return ChoiceChip(
                        label: Text('$label • $tag',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sel ? AppTheme.bgBase : AppTheme.textSecondary)),
                        selected: sel,
                        selectedColor: _mode.color,
                        backgroundColor: AppTheme.bgCard,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        onSelected: (v) { if (v) setDS(() => selectedLatency = ms); },
                      );
                    }).toList(),
                  ),
                  if (_mode == GameMode.racing) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('STEERING LOCK / SENSITIVITY:', style: AppTheme.label(size: 10, color: AppTheme.textSecondary)),
                        Text('±${currentSens.round()}°',
                            style: TextStyle(fontFamily: 'monospace', color: _mode.color, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Slider(
                      value: currentSens.clamp(1.0, 900.0),
                      min: 1.0,
                      max: 900.0,
                      activeColor: _mode.color,
                      inactiveColor: Colors.white12,
                      onChanged: (v) {
                        setDS(() => currentSens = v.roundToDouble());
                      },
                    ),
                    Wrap(
                      spacing: 6,
                      children: [180.0, 360.0, 540.0, 900.0].map((angle) {
                        final sel = currentSens.round() == angle.round();
                        return ChoiceChip(
                          label: Text('±${angle.toInt()}°',
                              style: TextStyle(fontSize: 10, color: sel ? AppTheme.bgBase : AppTheme.textSecondary)),
                          selected: sel,
                          selectedColor: _mode.color,
                          backgroundColor: AppTheme.bgCard,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          onSelected: (v) { if (v) setDS(() => currentSens = angle); },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('CANCEL', style: AppTheme.label(color: AppTheme.textDim)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _mode.color,
                foregroundColor: AppTheme.bgBase,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final h = hostCtrl.text.trim();
                final p = int.tryParse(portCtrl.text.trim()) ?? 5005;
                setState(() {
                  _host          = h;
                  _port          = p;
                  _latencyMs     = selectedLatency;
                  _isUsbMode     = h == '127.0.0.1';
                  _customization = _customization.copyWith(steeringSensitivity: currentSens);
                });
                _tx.setTargetIntervalMs(selectedLatency);
                _savePrefs();
                _tx.updateTarget(h, p);
                Navigator.pop(dialogCtx);
              },
              child: Text('APPLY', style: AppTheme.label(size: 12, color: AppTheme.bgBase)),
            ),
          ],
        ),
      ),
    );
  }

  void _openCustomizationStudio({int initialTab = 0}) {
    CustomizationStudioModal.show(
      context,
      config: _customization,
      initialTab: initialTab,
      onConfigChanged: (newCfg) {
        setState(() {
          _customization = newCfg;
        });
        _savePrefs();
      },
    );
  }

  void _openHudLayoutEditor() {
    HudLayoutEditor.show(
      context,
      config: _customization,
      onSave: (newCfg) {
        setState(() {
          _customization = newCfg;
        });
        _savePrefs();
      },
    );
  }

  void _txDrive() {
    _tx.updateDriveInputs(
      steer: _rawSteer,
      throttle: _rawThrottle,
      brake: _rawBrake,
    );
  }

  Widget _buildContent() {
    switch (_mode) {
      case GameMode.racing:
        return _RacingContent(
          tx: _tx,
          config: _customization,
          steerNotifier: _steerDegNotifier,
          throttleNotifier: _throttlePctNotifier,
          brakeNotifier: _brakePctNotifier,
          clutchNotifier: _clutchPctNotifier,
          onSteer: (v) { _rawSteer = v; _txDrive(); },
          onThrottle: (v) { _rawThrottle = v; _txDrive(); },
          onBrake: (v) { _rawBrake = v; _txDrive(); },
          onClutch: (v) {
            // Map clutch to LB shoulder button on press
            _tx.setButton(UdpTransmitter.btnLB, pressed: v > 10000);
          },
        );
      case GameMode.rpg:
        return RpgScreen(tx: _tx);
      case GameMode.pad:
        return GamepadScreen(
          tx: _tx,
          config: _customization,
          onOpenCustomization: () => _openCustomizationStudio(initialTab: 0),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _mode.color;

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // ── Responsive HUD bar (Never overflows) ──────────────────────
            _HudBar(
              host:             _host,
              port:             _port,
              hz:               _hz,
              pkts:             _totalPkts,
              latencyMs:        _latencyMs,
              connected:        _tx.isConnected,
              usbMode:          _isUsbMode,
              accent:           accentColor,
              mode:             _mode,
              steerNotifier:    _steerDegNotifier,
              throttleNotifier: _throttlePctNotifier,
              brakeNotifier:    _brakePctNotifier,
              onSettings:       _showSettings,
              onCustomize:      () => _openCustomizationStudio(initialTab: _mode == GameMode.pad ? 0 : 1),
              onEditHud:        _openHudLayoutEditor,
              onUsbToggle:      _toggleUsb,
            ),

            // ── Interactive Content Area ──────────────────────────────────
            Expanded(child: _buildContent()),

            // ── Mode Dock ─────────────────────────────────────────────────
            _ModeDock(
              currentMode: _mode,
              glowCtrl:    _tabGlowCtrl,
              onSelect:    (m) => setState(() => _mode = m),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Responsive Overflow-Free HUD Bar ─────────────────────────────────────────
class _HudBar extends StatelessWidget {
  final String host;
  final int    port;
  final double hz;
  final int    pkts;
  final int    latencyMs;
  final bool   connected;
  final bool   usbMode;
  final Color  accent;
  final GameMode mode;
  final ValueNotifier<double> steerNotifier;
  final ValueNotifier<double> throttleNotifier;
  final ValueNotifier<double> brakeNotifier;
  final VoidCallback onSettings;
  final VoidCallback onCustomize;
  final VoidCallback? onEditHud;
  final VoidCallback onUsbToggle;

  const _HudBar({
    required this.host,
    required this.port,
    required this.hz,
    required this.pkts,
    required this.latencyMs,
    required this.connected,
    required this.usbMode,
    required this.accent,
    required this.mode,
    required this.steerNotifier,
    required this.throttleNotifier,
    required this.brakeNotifier,
    required this.onSettings,
    required this.onCustomize,
    this.onEditHud,
    required this.onUsbToggle,
  });

  @override
  Widget build(BuildContext context) {
    final connColor = connected ? AppTheme.neonGreen : AppTheme.neonRed;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgPanel,
        border: Border(bottom: BorderSide(color: accent.withOpacity(0.18), width: 1)),
      ),
      child: Row(
        children: [
          // Left: Mode badge & Host connection
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: accent.withOpacity(0.35), width: 1),
                ),
                child: Text('${mode.emoji} ${mode.label.toUpperCase()}',
                    style: AppTheme.label(size: 9, color: accent)),
              ),
              const SizedBox(width: 8),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connColor,
                  boxShadow: [BoxShadow(color: connColor.withOpacity(0.7), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 5),
              Text(
                usbMode ? 'USB' : host,
                style: AppTheme.hud(size: 10, color: AppTheme.textSecondary),
              ),
            ],
          ),

          const SizedBox(width: 8),

          // Center & Right: Flexible & Scrollable telemetry items so it never overflows
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Live isolated telemetry values (Zero root rebuild)
                  if (mode == GameMode.racing) ...[
                    ValueListenableBuilder<double>(
                      valueListenable: steerNotifier,
                      builder: (_, deg, __) => _Chip('STR', '${deg.round()}°', AppTheme.neonCyan),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<double>(
                      valueListenable: throttleNotifier,
                      builder: (_, pct, __) => _Chip('THR', '${pct.round()}%', AppTheme.neonGreen),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<double>(
                      valueListenable: brakeNotifier,
                      builder: (_, pct, __) => _Chip('BRK', '${pct.round()}%', AppTheme.neonRed),
                    ),
                    const SizedBox(width: 8),
                  ],

                  _Chip('LAT', hz > 0 ? '${(1000 / hz).round()}ms' : '${latencyMs}ms', AppTheme.neonGreen),
                  const SizedBox(width: 8),
                  _Chip('Hz', hz.toStringAsFixed(0), accent),
                  const SizedBox(width: 8),

                  // USB quick toggle
                  GestureDetector(
                    onTap: onUsbToggle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: usbMode ? accent.withOpacity(0.25) : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: accent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.usb_rounded, size: 12, color: accent),
                          const SizedBox(width: 2),
                          Text('USB', style: AppTheme.label(size: 8, color: accent)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Racing: HUD Layout Editor Button
                  if (mode == GameMode.racing && onEditHud != null) ...[
                    GestureDetector(
                      onTap: onEditHud,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.dashboard_customize_rounded, size: 12, color: Color(0xFF00E5FF)),
                            const SizedBox(width: 4),
                            Text('EDIT HUD', style: AppTheme.label(size: 8, color: const Color(0xFF00E5FF))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Customize / Studio Button
                  GestureDetector(
                    onTap: onCustomize,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: accent.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.palette_rounded, size: 12, color: accent),
                          const SizedBox(width: 4),
                          Text('TUNE', style: AppTheme.label(size: 8, color: accent)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Settings Icon
                  GestureDetector(
                    onTap: onSettings,
                    child: const Icon(Icons.tune_rounded, size: 18, color: AppTheme.textDim),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Chip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: AppTheme.hud(size: 8, color: AppTheme.textDim)),
        Text(value, style: AppTheme.hud(size: 10, color: color, weight: FontWeight.bold)),
      ],
    );
  }
}

// ── Mode Dock ────────────────────────────────────────────────────────────────
class _ModeDock extends StatelessWidget {
  final GameMode currentMode;
  final AnimationController glowCtrl;
  final void Function(GameMode) onSelect;

  const _ModeDock({
    required this.currentMode,
    required this.glowCtrl,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowCtrl,
      builder: (_, __) {
        final pulse = 0.6 + 0.4 * glowCtrl.value;
        return Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.bgPanel,
            border: Border(top: BorderSide(color: currentMode.color.withOpacity(0.18))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: GameMode.values.map((m) {
              final sel = m == currentMode;
              return GestureDetector(
                onTap: () => onSelect(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: sel ? m.color.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: sel ? m.color.withOpacity(0.7 * pulse) : Colors.transparent,
                      width: 1.2,
                    ),
                    boxShadow: sel
                        ? [BoxShadow(color: m.color.withOpacity(0.25 * pulse), blurRadius: 10)]
                        : [],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(m.emoji, style: const TextStyle(fontSize: 14)),
                      Text(
                        m.label.toUpperCase(),
                        style: AppTheme.label(
                          size: 7,
                          color: sel ? m.color : AppTheme.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ── Racing Content (With Customization & Multi-pedal Layout) ──────────────────
class _RacingContent extends StatelessWidget {
  final UdpTransmitter tx;
  final CustomizationConfig config;
  final ValueNotifier<double> steerNotifier;
  final ValueNotifier<double> throttleNotifier;
  final ValueNotifier<double> brakeNotifier;
  final ValueNotifier<double> clutchNotifier;
  final void Function(int) onSteer, onThrottle, onBrake, onClutch;

  const _RacingContent({
    required this.tx,
    required this.config,
    required this.steerNotifier,
    required this.throttleNotifier,
    required this.brakeNotifier,
    required this.clutchNotifier,
    required this.onSteer,
    required this.onThrottle,
    required this.onBrake,
    required this.onClutch,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final baseLayout = config.useCustomLayout
            ? _buildCustomLayout(constraints)
            : _buildDefaultLayout(constraints);

        if (config.extraButtons.isEmpty) {
          return baseLayout;
        }

        // Overlay interactive custom extra buttons
        return Stack(
          children: [
            baseLayout,
            ...config.extraButtons.map((btn) {
              final left = (btn.x * constraints.maxWidth) - (btn.size / 2);
              final top = (btn.y * constraints.maxHeight) - (btn.size / 2);
              return Positioned(
                left: left,
                top: top,
                width: btn.size,
                height: btn.size,
                child: _ExtraButtonWidget(
                  btn: btn,
                  tx: tx,
                  haptic: config.hapticFeedback,
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildDefaultLayout(BoxConstraints constraints) {
    return Row(
      children: [
        // Left Area: Customizable Steering Wheel
        Expanded(
          flex: 6,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: SteeringWheelWidget(
                config: config,
                onSteerChanged: onSteer,
                onAngleChanged: (deg) => steerNotifier.value = deg,
              ),
            ),
          ),
        ),

        // Center Gutter (Shifter paddles & quick info)
        Container(
          width: 44,
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.bgPanel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PaddleButton('LB', 'DOWN', () => tx.setButton(UdpTransmitter.btnLB, pressed: true), () => tx.setButton(UdpTransmitter.btnLB, pressed: false)),
              Container(height: 1, width: 22, color: AppTheme.divider),
              _PaddleButton('RB', 'UP',   () => tx.setButton(UdpTransmitter.btnRB, pressed: true), () => tx.setButton(UdpTransmitter.btnRB, pressed: false)),
            ],
          ),
        ),

        // Right Area: Pedals (Adaptive 2 or 3 pedal box)
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                // Optional Clutch Pedal
                if (config.showClutch) ...[
                  Expanded(
                    child: PedalSliderWidget(
                      pedalType: PedalType.clutch,
                      config: config,
                      onValueChanged: onClutch,
                      onPercentageChanged: (p) => clutchNotifier.value = p,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Brake Pedal
                Expanded(
                  child: PedalSliderWidget(
                    pedalType: PedalType.brake,
                    config: config,
                    onValueChanged: onBrake,
                    onPercentageChanged: (p) => brakeNotifier.value = p,
                  ),
                ),
                const SizedBox(width: 8),

                // Throttle Pedal
                Expanded(
                  child: PedalSliderWidget(
                    pedalType: PedalType.throttle,
                    config: config,
                    onValueChanged: onThrottle,
                    onPercentageChanged: (p) => throttleNotifier.value = p,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomLayout(BoxConstraints constraints) {
    final widgets = <Widget>[];

    // 1. Steering Wheel
    final steerCfg = config.layoutPositions['steering'] ??
        LayoutItemConfig(id: 'steering', x: 0.28, y: 0.52, scale: 1.0);
    final steerSize = (constraints.maxHeight * 0.90 * steerCfg.scale).clamp(120.0, 360.0);
    final steerLeft = (steerCfg.x * constraints.maxWidth) - (steerSize / 2);
    final steerTop = (steerCfg.y * constraints.maxHeight) - (steerSize / 2);
    widgets.add(Positioned(
      left: steerLeft,
      top: steerTop,
      width: steerSize,
      height: steerSize,
      child: SteeringWheelWidget(
        config: config,
        onSteerChanged: onSteer,
        onAngleChanged: (deg) => steerNotifier.value = deg,
      ),
    ));

    // 2. Shifter Paddles
    final shiftersCfg = config.layoutPositions['shifters'] ??
        LayoutItemConfig(id: 'shifters', x: 0.55, y: 0.52, scale: 1.0);
    final shiftersWidth = (44.0 * shiftersCfg.scale).clamp(32.0, 80.0);
    final shiftersHeight = (120.0 * shiftersCfg.scale).clamp(80.0, 200.0);
    final shiftersLeft = (shiftersCfg.x * constraints.maxWidth) - (shiftersWidth / 2);
    final shiftersTop = (shiftersCfg.y * constraints.maxHeight) - (shiftersHeight / 2);
    widgets.add(Positioned(
      left: shiftersLeft,
      top: shiftersTop,
      width: shiftersWidth,
      height: shiftersHeight,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgPanel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _PaddleButton('LB', 'DOWN', () => tx.setButton(UdpTransmitter.btnLB, pressed: true), () => tx.setButton(UdpTransmitter.btnLB, pressed: false)),
            Container(height: 1, width: 22, color: AppTheme.divider),
            _PaddleButton('RB', 'UP',   () => tx.setButton(UdpTransmitter.btnRB, pressed: true), () => tx.setButton(UdpTransmitter.btnRB, pressed: false)),
          ],
        ),
      ),
    ));

    // 3. Brake Pedal
    final brakeCfg = config.layoutPositions['brake'] ??
        LayoutItemConfig(id: 'brake', x: 0.72, y: 0.54, scale: 1.0);
    final brakeWidth = (84.0 * brakeCfg.scale).clamp(50.0, 160.0);
    final brakeHeight = (constraints.maxHeight * 0.88 * brakeCfg.scale).clamp(130.0, constraints.maxHeight);
    final brakeLeft = (brakeCfg.x * constraints.maxWidth) - (brakeWidth / 2);
    final brakeTop = (brakeCfg.y * constraints.maxHeight) - (brakeHeight / 2);
    widgets.add(Positioned(
      left: brakeLeft,
      top: brakeTop,
      width: brakeWidth,
      height: brakeHeight,
      child: PedalSliderWidget(
        pedalType: PedalType.brake,
        config: config,
        onValueChanged: onBrake,
        onPercentageChanged: (p) => brakeNotifier.value = p,
      ),
    ));

    // 4. Throttle Pedal
    final throttleCfg = config.layoutPositions['throttle'] ??
        LayoutItemConfig(id: 'throttle', x: 0.88, y: 0.54, scale: 1.0);
    final throttleWidth = (84.0 * throttleCfg.scale).clamp(50.0, 160.0);
    final throttleHeight = (constraints.maxHeight * 0.88 * throttleCfg.scale).clamp(130.0, constraints.maxHeight);
    final throttleLeft = (throttleCfg.x * constraints.maxWidth) - (throttleWidth / 2);
    final throttleTop = (throttleCfg.y * constraints.maxHeight) - (throttleHeight / 2);
    widgets.add(Positioned(
      left: throttleLeft,
      top: throttleTop,
      width: throttleWidth,
      height: throttleHeight,
      child: PedalSliderWidget(
        pedalType: PedalType.throttle,
        config: config,
        onValueChanged: onThrottle,
        onPercentageChanged: (p) => throttleNotifier.value = p,
      ),
    ));

    // 5. Optional Clutch Pedal
    if (config.showClutch) {
      final clutchCfg = config.layoutPositions['clutch'] ??
          LayoutItemConfig(id: 'clutch', x: 0.63, y: 0.54, scale: 1.0);
      final clutchWidth = (74.0 * clutchCfg.scale).clamp(46.0, 140.0);
      final clutchHeight = (constraints.maxHeight * 0.84 * clutchCfg.scale).clamp(130.0, constraints.maxHeight);
      final clutchLeft = (clutchCfg.x * constraints.maxWidth) - (clutchWidth / 2);
      final clutchTop = (clutchCfg.y * constraints.maxHeight) - (clutchHeight / 2);
      widgets.add(Positioned(
        left: clutchLeft,
        top: clutchTop,
        width: clutchWidth,
        height: clutchHeight,
        child: PedalSliderWidget(
          pedalType: PedalType.clutch,
          config: config,
          onValueChanged: onClutch,
          onPercentageChanged: (p) => clutchNotifier.value = p,
        ),
      ));
    }

    return Stack(children: widgets);
  }
}

class _PaddleButton extends StatefulWidget {
  final String label;
  final String sublabel;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _PaddleButton(this.label, this.sublabel, this.onDown, this.onUp);

  @override
  State<_PaddleButton> createState() => _PaddleButtonState();
}

class _PaddleButtonState extends State<_PaddleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        setState(() => _pressed = true);
        widget.onDown();
        HapticFeedback.selectionClick();
      },
      onPointerUp: (_) {
        setState(() => _pressed = false);
        widget.onUp();
      },
      onPointerCancel: (_) {
        setState(() => _pressed = false);
        widget.onUp();
      },
      child: Container(
        width: 38,
        height: 48,
        decoration: BoxDecoration(
          color: _pressed ? AppTheme.neonCyan.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _pressed ? AppTheme.neonCyan : Colors.white70)),
            Text(widget.sublabel, style: TextStyle(fontSize: 7, color: _pressed ? AppTheme.neonCyan : Colors.white38)),
          ],
        ),
      ),
    );
  }
}

class _ExtraButtonWidget extends StatefulWidget {
  final ExtraButtonConfig btn;
  final UdpTransmitter tx;
  final bool haptic;

  const _ExtraButtonWidget({
    required this.btn,
    required this.tx,
    required this.haptic,
  });

  @override
  State<_ExtraButtonWidget> createState() => _ExtraButtonWidgetState();
}

class _ExtraButtonWidgetState extends State<_ExtraButtonWidget> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.btn;
    return Listener(
      onPointerDown: (_) {
        setState(() => _pressed = true);
        widget.tx.setButton(b.buttonMask, btn2: b.isBtn2, pressed: true);
        if (widget.haptic) HapticFeedback.mediumImpact();
      },
      onPointerUp: (_) {
        setState(() => _pressed = false);
        widget.tx.setButton(b.buttonMask, btn2: b.isBtn2, pressed: false);
      },
      onPointerCancel: (_) {
        setState(() => _pressed = false);
        widget.tx.setButton(b.buttonMask, btn2: b.isBtn2, pressed: false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: b.size,
        height: b.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _pressed ? b.color.withOpacity(0.55) : const Color(0xFF141824).withOpacity(0.85),
          border: Border.all(
            color: _pressed ? Colors.white : b.color,
            width: _pressed ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: b.color.withOpacity(_pressed ? 0.7 : 0.3),
              blurRadius: _pressed ? 14 : 6,
              spreadRadius: _pressed ? 2 : 0,
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              b.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: (b.size * 0.20).clamp(8.0, 14.0),
                fontWeight: FontWeight.w900,
                color: _pressed ? Colors.white : b.color,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
