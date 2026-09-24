import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/customization_config.dart';
import '../services/udp_transmitter.dart';
import '../widgets/hud_overlay.dart';
import '../widgets/pedal_slider.dart';
import '../widgets/steering_wheel.dart';

/// Main landscape driving controller screen
class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  late final UdpTransmitter _transmitter;

  // Preferences keys
  static const _prefKeyHost = 'server_host';
  static const _prefKeyPort = 'server_port';
  static const _prefKeyMaxAngle = 'max_steer_angle';

  String _host = '192.168.1.100';
  int _port = 5005;
  double _maxSteerAngle = 540.0;
  bool _isUsbMode = false;
  String _wifiFallbackHost = '192.168.1.100';

  // Live telemetry
  int _rawSteer = 0;
  int _rawThrottle = 0;
  int _rawBrake = 0;
  double _steerAngleDegrees = 0.0;
  double _throttlePercentage = 0.0;
  double _brakePercentage = 0.0;

  double _currentHz = 0.0;
  int _totalPackets = 0;

  @override
  void initState() {
    super.initState();
    // Enable immersive fullscreen sticky mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _transmitter = UdpTransmitter(
      targetHost: _host,
      targetPort: _port,
    );

    _transmitter.onStatsUpdated = (hz, pkts) {
      if (mounted) {
        setState(() {
          _currentHz = hz;
          _totalPackets = pkts;
        });
      }
    };

    _loadPreferences().then((_) {
      _transmitter.start();
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _host = prefs.getString(_prefKeyHost) ?? '192.168.1.100';
      _port = prefs.getInt(_prefKeyPort) ?? 5005;
      _maxSteerAngle = prefs.getDouble(_prefKeyMaxAngle) ?? 540.0;
      _wifiFallbackHost = _host;
    });
    await _transmitter.updateTarget(_host, _port);
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyHost, _host);
    await prefs.setInt(_prefKeyPort, _port);
    await prefs.setDouble(_prefKeyMaxAngle, _maxSteerAngle);
  }

  @override
  void dispose() {
    _transmitter.dispose();
    super.dispose();
  }

  void _onSteerChanged(int steer) {
    _rawSteer = steer;
    _transmitCurrentInputs();
  }

  void _onThrottleChanged(int throttle) {
    _rawThrottle = throttle;
    _transmitCurrentInputs();
  }

  void _onBrakeChanged(int brake) {
    _rawBrake = brake;
    _transmitCurrentInputs();
  }

  void _transmitCurrentInputs() {
    _transmitter.updateInputs(
      steer: _rawSteer,
      throttle: _rawThrottle,
      brake: _rawBrake,
    );
  }

  void _toggleUsbMode() {
    setState(() {
      if (!_isUsbMode) {
        _wifiFallbackHost = _host;
        _host = '127.0.0.1';
        _isUsbMode = true;
      } else {
        _host = _wifiFallbackHost;
        _isUsbMode = false;
      }
    });
    _transmitter.updateTarget(_host, _port);
  }

  void _showSettingsDialog() {
    final hostController = TextEditingController(text: _host);
    final portController = TextEditingController(text: _port.toString());
    double selectedAngle = _maxSteerAngle;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161A24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF2E374A)),
              ),
              title: const Row(
                children: [
                  Icon(Icons.settings, color: Color(0xFF00E5FF)),
                  SizedBox(width: 8),
                  Text(
                    'Connection & Physics Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HOST IP ADDRESS (Windows PC):',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: hostController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. 192.168.1.100 or 127.0.0.1',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: const Color(0xFF0E1017),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF333D52)),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.usb, color: Color(0xFF00E5FF)),
                            tooltip: 'Set to 127.0.0.1 for USB tether',
                            onPressed: () {
                              hostController.text = '127.0.0.1';
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        'UDP PORT:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: portController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0E1017),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF333D52)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        'STEERING WHEEL ROTATION LOCK:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [360.0, 540.0, 900.0].map((angle) {
                          final isSelected = (selectedAngle == angle);
                          return ChoiceChip(
                            label: Text(
                              '±${angle.toInt()}°',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.black : Colors.white70,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF00E5FF),
                            backgroundColor: const Color(0xFF1E2433),
                            onSelected: (val) {
                              if (val) {
                                setDialogState(() {
                                  selectedAngle = angle;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final newHost = hostController.text.trim();
                    final newPort = int.tryParse(portController.text.trim()) ?? 5005;

                    setState(() {
                      _host = newHost;
                      _port = newPort;
                      _maxSteerAngle = selectedAngle;
                      _isUsbMode = (_host == '127.0.0.1');
                    });

                    _savePreferences();
                    _transmitter.updateTarget(_host, _port);
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('APPLY & CONNECT', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D13),
      body: SafeArea(
        child: Column(
          children: [
            // Top Telemetry and Settings Bar
            HudTopBar(
              serverHost: _host,
              serverPort: _port,
              currentHz: _currentHz,
              totalPackets: _totalPackets,
              isConnected: _transmitter.isConnected,
              isUsbMode: _isUsbMode,
              onOpenSettings: _showSettingsDialog,
              onQuickUsbToggle: _toggleUsbMode,
            ),

            // Main Interactive Cockpit Area
            Expanded(
              child: Row(
                children: [
                  // Left Screen: Steering Wheel (Circular touch-drag area)
                  Expanded(
                    flex: 6,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SteeringWheelWidget(
                          config: CustomizationConfig(steeringSensitivity: _maxSteerAngle),
                          onSteerChanged: _onSteerChanged,
                          onAngleChanged: (deg) {
                            setState(() {
                              _steerAngleDegrees = deg;
                            });
                          },
                        ),
                      ),
                    ),
                  ),

                  // Center Telemetry Gutter
                  Container(
                    width: 60,
                    margin: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121620),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E2536)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Steer Indicator
                        Column(
                          children: [
                            const Text(
                              'STEER',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white54,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_steerAngleDegrees.round()}°',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00E5FF),
                              ),
                            ),
                          ],
                        ),
                        Container(height: 1, width: 30, color: Colors.white12),

                        // Brake Indicator
                        Column(
                          children: [
                            const Text(
                              'BRK',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white54,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_brakePercentage.round()}%',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF2A4B),
                              ),
                            ),
                          ],
                        ),
                        Container(height: 1, width: 30, color: Colors.white12),

                        // Throttle Indicator
                        Column(
                          children: [
                            const Text(
                              'THR',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white54,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_throttlePercentage.round()}%',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00E676),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Right Screen: Dual Analog Pedals (Brake & Accelerator)
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 16.0,
                      ),
                      child: Row(
                        children: [
                          // Left strip: Analog Brake
                          Expanded(
                            child: PedalSliderWidget(
                              pedalType: PedalType.brake,
                              config: CustomizationConfig(steeringSensitivity: _maxSteerAngle),
                              onValueChanged: _onBrakeChanged,
                              onPercentageChanged: (pct) {
                                setState(() {
                                  _brakePercentage = pct;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Right strip: Analog Accelerator
                          Expanded(
                            child: PedalSliderWidget(
                              pedalType: PedalType.throttle,
                              config: CustomizationConfig(steeringSensitivity: _maxSteerAngle),
                              onValueChanged: _onThrottleChanged,
                              onPercentageChanged: (pct) {
                                setState(() {
                                  _throttlePercentage = pct;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
