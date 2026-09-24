import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/customization_config.dart';
import '../services/udp_transmitter.dart';
import 'hud_layout_editor.dart';

/// Interactive modal studio to customize:
/// - Steering wheel visuals & physics
/// - Sensitivity range 1° - 900°
/// - Pedals, Brake Mode (Instant Stomp vs Modulated), Sensitivity Multiplier
/// - Extra Buttons & Screen Layout customization
class CustomizationStudioModal extends StatefulWidget {
  final CustomizationConfig config;
  final ValueChanged<CustomizationConfig> onConfigChanged;

  final int initialTab;

  const CustomizationStudioModal({
    super.key,
    required this.config,
    required this.onConfigChanged,
    this.initialTab = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required CustomizationConfig config,
    required ValueChanged<CustomizationConfig> onConfigChanged,
    int initialTab = 0,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => CustomizationStudioModal(
        config: config,
        onConfigChanged: onConfigChanged,
        initialTab: initialTab,
      ),
    );
  }

  @override
  State<CustomizationStudioModal> createState() => _CustomizationStudioModalState();
}

class _CustomizationStudioModalState extends State<CustomizationStudioModal>
    with SingleTickerProviderStateMixin {
  late CustomizationConfig _cfg;
  late TabController _tabController;

  static const List<Color> _presetColors = [
    Color(0xFF00E5FF), // Neon Cyan
    Color(0xFF00E676), // Neon Green
    Color(0xFFFF2A4B), // Neon Red
    Color(0xFFFFEA00), // Racing Yellow
    Color(0xFF7C4DFF), // Deep Purple
    Color(0xFFFF9100), // Vibrant Orange
    Color(0xFF3D5AFE), // Electric Blue
    Color(0xFFFFFFFF), // Pure White
  ];

  static const List<Map<String, dynamic>> _buttonPresets = [
    {'label': 'HANDBRAKE', 'mask': UdpTransmitter.btnA,     'isBtn2': false, 'color': Color(0xFFFF2A4B), 'icon': Icons.car_crash_rounded},
    {'label': 'BOOST',      'mask': UdpTransmitter.btnB,     'isBtn2': false, 'color': Color(0xFFFF9100), 'icon': Icons.bolt_rounded},
    {'label': 'HORN',       'mask': UdpTransmitter.btnLStick,'isBtn2': true,  'color': Color(0xFFFFEA00), 'icon': Icons.volume_up_rounded},
    {'label': 'LOOK BACK',  'mask': UdpTransmitter.btnRStick,'isBtn2': true,  'color': Color(0xFF00E5FF), 'icon': Icons.replay_rounded},
    {'label': 'CAMERA',     'mask': UdpTransmitter.btnY,     'isBtn2': false, 'color': Color(0xFF7C4DFF), 'icon': Icons.videocam_rounded},
    {'label': 'GEAR UP',    'mask': UdpTransmitter.btnRB,    'isBtn2': false, 'color': Color(0xFF00E676), 'icon': Icons.arrow_upward_rounded},
    {'label': 'GEAR DOWN',  'mask': UdpTransmitter.btnLB,    'isBtn2': false, 'color': Color(0xFF00E676), 'icon': Icons.arrow_downward_rounded},
    {'label': 'RESET CAR',  'mask': UdpTransmitter.btnBack,  'isBtn2': false, 'color': Color(0xFF90A4AE), 'icon': Icons.restart_alt_rounded},
    {'label': 'PAUSE',      'mask': UdpTransmitter.btnStart, 'isBtn2': false, 'color': Color(0xFFFFFFFF), 'icon': Icons.pause_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _cfg = widget.config.copyWith();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _update(CustomizationConfig newCfg) {
    setState(() {
      _cfg = newCfg;
    });
    widget.onConfigChanged(_cfg);
    _cfg.saveToPrefs();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = math.min(screenSize.width * 0.94, 720.0);
    final dialogHeight = math.min(screenSize.height * 0.92, 430.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: const Color(0xFF10131B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cfg.wheelAccentColor.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.85),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: _cfg.wheelAccentColor.withOpacity(0.12),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Studio Header Bar ─────────────────────────────────────────
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF161A26),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.palette_rounded, size: 20, color: _cfg.wheelAccentColor),
                  const SizedBox(width: 8),
                  Text(
                    'CUSTOMIZATION STUDIO',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                      color: Colors.white.withOpacity(0.95),
                    ),
                  ),
                  const Spacer(),
                  // 4 Tabs
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0E14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: _cfg.wheelAccentColor.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: _cfg.wheelAccentColor, width: 1.2),
                      ),
                      labelColor: _cfg.wheelAccentColor,
                      unselectedLabelColor: Colors.white54,
                      labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      tabs: const [
                        Tab(text: '🎮 GAMEPAD'),
                        Tab(text: '🏎️ STEERING'),
                        Tab(text: '🎯 SENSITIVITY'),
                        Tab(text: '⚡ PEDALS & BRAKE'),
                        Tab(text: '📐 HUD & BUTTONS'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white60),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Tab Views ─────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGamepadTab(),
                  _buildSteeringTab(),
                  _buildSensitivityTab(),
                  _buildPedalsTab(),
                  _buildLayoutAndButtonsTab(),
                ],
              ),
            ),

            // ── Bottom Action Footer ──────────────────────────────────────
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF141824),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
              ),
              child: Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('RESET ALL', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      _update(CustomizationConfig());
                    },
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _cfg.wheelAccentColor,
                      foregroundColor: const Color(0xFF090B0F),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 0: GAMEPAD CUSTOMIZATION
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildGamepadTab() {
    final accent = _cfg.gamepadAccentColor;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ACCENT COLOR & GLOW ─────────────────────────────────────────
          _sectionTitle('GAMEPAD ACCENT & GLOW THEME'),
          const SizedBox(height: 8),
          _colorRow(_cfg.gamepadAccentColor, (c) {
            _update(_cfg.copyWith(gamepadAccentColor: c));
          }),
          const SizedBox(height: 18),

          // ── BUTTON STYLE & LABELS ────────────────────────────────────────
          _sectionTitle('BUTTON GLYPHS & ICON STYLING'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _choiceChip('🟢 XBOX CLASSIC (A/B/X/Y)', GamepadButtonStyle.xboxColors, _cfg.gamepadButtonStyle, (v) {
                _update(_cfg.copyWith(gamepadButtonStyle: v));
              }),
              _choiceChip('🔮 NEON THEME GLOW', GamepadButtonStyle.neonTheme, _cfg.gamepadButtonStyle, (v) {
                _update(_cfg.copyWith(gamepadButtonStyle: v));
              }),
              _choiceChip('🔺 PLAYSTATION (△ ○ ✕ □)', GamepadButtonStyle.playstationSymbols, _cfg.gamepadButtonStyle, (v) {
                _update(_cfg.copyWith(gamepadButtonStyle: v));
              }),
              _choiceChip('⚪ STEALTH DARK', GamepadButtonStyle.stealthDark, _cfg.gamepadButtonStyle, (v) {
                _update(_cfg.copyWith(gamepadButtonStyle: v));
              }),
            ],
          ),
          const SizedBox(height: 18),

          // ── HARDWARE LAYOUT & TRIGGERS ──────────────────────────────────
          _sectionTitle('HARDWARE LAYOUT (STICK & D-PAD PLACEMENT)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _choiceChip('🎮 XBOX ASYMMETRICAL (Stick Top, D-Pad Bottom)', GamepadLayout.xbox, _cfg.gamepadLayout, (v) {
                _update(_cfg.copyWith(gamepadLayout: v));
              }),
              _choiceChip('🕹️ PLAYSTATION SYMMETRICAL (D-Pad Top, Stick Bottom)', GamepadLayout.playstation, _cfg.gamepadLayout, (v) {
                _update(_cfg.copyWith(gamepadLayout: v));
              }),
            ],
          ),
          const SizedBox(height: 16),

          _sectionTitle('TRIGGER BEHAVIOR (LT / RT)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _choiceChip('🔘 INSTANT DIGITAL TAP', TriggerStyle.instantDigital, _cfg.triggerStyle, (v) {
                _update(_cfg.copyWith(triggerStyle: v));
              }),
              _choiceChip('🎚️ ANALOG MODULATION SLIDER', TriggerStyle.analogSlider, _cfg.triggerStyle, (v) {
                _update(_cfg.copyWith(triggerStyle: v));
              }),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141824),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SWAP BUMPERS & TRIGGERS',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text(
                      _cfg.swapBumpersAndTriggers ? 'Triggers (LT/RT) on top, Bumpers (LB/RB) below' : 'Bumpers (LB/RB) on top, Triggers (LT/RT) below',
                      style: const TextStyle(color: Colors.white54, fontSize: 9),
                    ),
                  ],
                ),
                Switch(
                  value: _cfg.swapBumpersAndTriggers,
                  activeColor: accent,
                  onChanged: (v) => _update(_cfg.copyWith(swapBumpersAndTriggers: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── THUMBSTICKS CALIBRATION ─────────────────────────────────────
          _sectionTitle('THUMBSTICKS CALIBRATION & SENSITIVITY'),
          const SizedBox(height: 10),

          // Stick Size
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('JOYSTICK DIAMETER / SCALE:',
                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
              Text('${_cfg.joystickSize.round()} px',
                  style: TextStyle(fontFamily: 'monospace', color: accent, fontSize: 11)),
            ],
          ),
          Slider(
            value: _cfg.joystickSize.clamp(90.0, 140.0),
            min: 90.0,
            max: 140.0,
            divisions: 10,
            activeColor: accent,
            inactiveColor: Colors.white12,
            onChanged: (v) => _update(_cfg.copyWith(joystickSize: v.roundToDouble())),
          ),
          const SizedBox(height: 10),

          // Left Stick Controls
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141824),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sports_esports_rounded, size: 14, color: accent),
                    const SizedBox(width: 6),
                    const Text('LEFT STICK (MOVE / STEER)',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('DEADZONE:', style: TextStyle(color: Colors.white70, fontSize: 9)),
                              Text('${(_cfg.leftStickDeadzone * 100).toInt()}%',
                                  style: TextStyle(fontFamily: 'monospace', color: accent, fontSize: 10)),
                            ],
                          ),
                          Slider(
                            value: _cfg.leftStickDeadzone,
                            min: 0.0,
                            max: 0.20,
                            divisions: 20,
                            activeColor: accent,
                            inactiveColor: Colors.white12,
                            onChanged: (v) => _update(_cfg.copyWith(leftStickDeadzone: v)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('SENSITIVITY:', style: TextStyle(color: Colors.white70, fontSize: 9)),
                              Text('${_cfg.leftStickSensitivity.toStringAsFixed(2)}x',
                                  style: TextStyle(fontFamily: 'monospace', color: accent, fontSize: 10)),
                            ],
                          ),
                          Slider(
                            value: _cfg.leftStickSensitivity,
                            min: 0.5,
                            max: 2.0,
                            divisions: 15,
                            activeColor: accent,
                            inactiveColor: Colors.white12,
                            onChanged: (v) => _update(_cfg.copyWith(leftStickSensitivity: v)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Right Stick Controls
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141824),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.visibility_rounded, size: 14, color: accent),
                        const SizedBox(width: 6),
                        const Text('RIGHT STICK (LOOK / AIM)',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('INVERT Y', style: TextStyle(color: Colors.white70, fontSize: 9)),
                        const SizedBox(width: 4),
                        Switch(
                          value: _cfg.invertRightStickY,
                          activeColor: accent,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (v) => _update(_cfg.copyWith(invertRightStickY: v)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('DEADZONE:', style: TextStyle(color: Colors.white70, fontSize: 9)),
                              Text('${(_cfg.rightStickDeadzone * 100).toInt()}%',
                                  style: TextStyle(fontFamily: 'monospace', color: accent, fontSize: 10)),
                            ],
                          ),
                          Slider(
                            value: _cfg.rightStickDeadzone,
                            min: 0.0,
                            max: 0.20,
                            divisions: 20,
                            activeColor: accent,
                            inactiveColor: Colors.white12,
                            onChanged: (v) => _update(_cfg.copyWith(rightStickDeadzone: v)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('SENSITIVITY:', style: TextStyle(color: Colors.white70, fontSize: 9)),
                              Text('${_cfg.rightStickSensitivity.toStringAsFixed(2)}x',
                                  style: TextStyle(fontFamily: 'monospace', color: accent, fontSize: 10)),
                            ],
                          ),
                          Slider(
                            value: _cfg.rightStickSensitivity,
                            min: 0.5,
                            max: 2.0,
                            divisions: 15,
                            activeColor: accent,
                            inactiveColor: Colors.white12,
                            onChanged: (v) => _update(_cfg.copyWith(rightStickSensitivity: v)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── TACTILE & PRO CONTROLS ──────────────────────────────────────
          _sectionTitle('TACTILE & PRO CONTROLS'),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141824),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('DEDICATED L3 & R3 BUTTONS (STICK CLICKS)',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    Switch(
                      value: _cfg.showL3R3,
                      activeColor: accent,
                      onChanged: (v) => _update(_cfg.copyWith(showL3R3: v)),
                    ),
                  ],
                ),
                Divider(color: Colors.white.withOpacity(0.06), height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('HAPTIC VIBRATION FEEDBACK',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    Switch(
                      value: _cfg.gamepadHaptics,
                      activeColor: accent,
                      onChanged: (v) => _update(_cfg.copyWith(gamepadHaptics: v)),
                    ),
                  ],
                ),
                Divider(color: Colors.white.withOpacity(0.06), height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('REAR QUICK-ACTION PADDLES (M1 & M2)',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    Switch(
                      value: _cfg.showPaddles,
                      activeColor: accent,
                      onChanged: (v) => _update(_cfg.copyWith(showPaddles: v)),
                    ),
                  ],
                ),
                if (_cfg.showPaddles) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('M1 PADDLE (LEFT):', style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              children: ['LB', 'A', 'X', 'L3'].map((act) => _choiceChip(act, act, _cfg.paddle1Action, (v) {
                                _update(_cfg.copyWith(paddle1Action: v));
                              })).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('M2 PADDLE (RIGHT):', style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              children: ['RB', 'B', 'Y', 'R3'].map((act) => _choiceChip(act, act, _cfg.paddle2Action, (v) {
                                _update(_cfg.copyWith(paddle2Action: v));
                              })).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: STEERING WHEEL
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSteeringTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('WHEEL MODEL & AESTHETIC'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _choiceChip('GT RACING', WheelStyle.gtRacing, _cfg.wheelStyle, (v) {
                _update(_cfg.copyWith(wheelStyle: v));
              }),
              _choiceChip('F1 YOKE', WheelStyle.f1Yoke, _cfg.wheelStyle, (v) {
                _update(_cfg.copyWith(wheelStyle: v));
              }),
              _choiceChip('DRIFT DEEP DISH', WheelStyle.driftDeepDish, _cfg.wheelStyle, (v) {
                _update(_cfg.copyWith(wheelStyle: v));
              }),
              _choiceChip('CYBERPUNK NEON', WheelStyle.cyberpunk, _cfg.wheelStyle, (v) {
                _update(_cfg.copyWith(wheelStyle: v));
              }),
              _choiceChip('CLASSIC SPORT', WheelStyle.classicSport, _cfg.wheelStyle, (v) {
                _update(_cfg.copyWith(wheelStyle: v));
              }),
            ],
          ),
          const SizedBox(height: 18),

          _sectionTitle('SPOKE ARCHITECTURE'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _choiceChip('3-SPOKE GT', SpokeStyle.threeSpoke, _cfg.spokeStyle, (v) {
                _update(_cfg.copyWith(spokeStyle: v));
              }),
              _choiceChip('2-SPOKE YOKE', SpokeStyle.twoSpokeYoke, _cfg.spokeStyle, (v) {
                _update(_cfg.copyWith(spokeStyle: v));
              }),
              _choiceChip('4-SPOKE RALLY', SpokeStyle.fourSpokeRally, _cfg.spokeStyle, (v) {
                _update(_cfg.copyWith(spokeStyle: v));
              }),
              _choiceChip('MINIMAL AERO', SpokeStyle.minimalAero, _cfg.spokeStyle, (v) {
                _update(_cfg.copyWith(spokeStyle: v));
              }),
            ],
          ),
          const SizedBox(height: 18),

          _sectionTitle('CENTER HUB DISPLAY'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _choiceChip('DIGITAL TELEMETRY', HubStyle.digitalTelemetry, _cfg.hubStyle, (v) {
                _update(_cfg.copyWith(hubStyle: v));
              }),
              _choiceChip('FORMULA SHIFT LEDS', HubStyle.shiftLightBar, _cfg.hubStyle, (v) {
                _update(_cfg.copyWith(hubStyle: v));
              }),
              _choiceChip('MINIMAL BADGE', HubStyle.minimalBadge, _cfg.hubStyle, (v) {
                _update(_cfg.copyWith(hubStyle: v));
              }),
            ],
          ),
          const SizedBox(height: 18),

          _sectionTitle('ACCENT / NEON COLOR'),
          const SizedBox(height: 8),
          _colorRow(_cfg.wheelAccentColor, (c) => _update(_cfg.copyWith(wheelAccentColor: c))),
          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('12 O\'Clock Racing Stripe',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  value: _cfg.showMarkerStripe,
                  activeColor: _cfg.wheelAccentColor,
                  checkColor: Colors.black,
                  onChanged: (val) {
                    if (val != null) _update(_cfg.copyWith(showMarkerStripe: val));
                  },
                ),
              ),
              if (_cfg.showMarkerStripe) ...[
                const SizedBox(width: 8),
                _colorBubble(_cfg.markerColor, () {
                  final nextIndex = (_presetColors.indexOf(_cfg.markerColor) + 1) % _presetColors.length;
                  _update(_cfg.copyWith(markerColor: _presetColors[nextIndex]));
                }),
              ],
            ],
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('AUTO-CENTERING SPRING:',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              Text(
                _cfg.springReturnMs <= 0 ? 'OFF (FREE ROTATION)' : '${_cfg.springReturnMs.toInt()} ms',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: _cfg.wheelAccentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: _cfg.springReturnMs,
            min: 0.0,
            max: 600.0,
            divisions: 12,
            activeColor: _cfg.wheelAccentColor,
            inactiveColor: Colors.white12,
            onChanged: (val) => _update(_cfg.copyWith(springReturnMs: val)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: SENSITIVITY (1 - 900°)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSensitivityTab() {
    final sens = _cfg.steeringSensitivity;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF151924),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cfg.wheelAccentColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('STEERING ROTATION LOCK / SENSITIVITY:',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '±${sens.round()}° (Total ${sens.round() * 2}°)',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _cfg.wheelAccentColor,
                        shadows: [
                          Shadow(color: _cfg.wheelAccentColor.withOpacity(0.5), blurRadius: 10),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _stepBtn('-10', () => _changeSensitivity(-10)),
                    const SizedBox(width: 4),
                    _stepBtn('-1', () => _changeSensitivity(-1)),
                    const SizedBox(width: 4),
                    _stepBtn('+1', () => _changeSensitivity(1)),
                    const SizedBox(width: 4),
                    _stepBtn('+10', () => _changeSensitivity(10)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Slider(
            value: sens.clamp(1.0, 900.0),
            min: 1.0,
            max: 900.0,
            activeColor: _cfg.wheelAccentColor,
            inactiveColor: Colors.white12,
            onChanged: (val) {
              _update(_cfg.copyWith(steeringSensitivity: val.roundToDouble()));
            },
          ),
          const SizedBox(height: 8),

          _sectionTitle('QUICK DEGREE PRESETS'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [90.0, 180.0, 270.0, 360.0, 540.0, 720.0, 900.0].map((deg) {
              final sel = sens.round() == deg.round();
              return ChoiceChip(
                label: Text(
                  '±${deg.toInt()}°',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: sel ? const Color(0xFF090B0F) : Colors.white70,
                  ),
                ),
                selected: sel,
                selectedColor: _cfg.wheelAccentColor,
                backgroundColor: const Color(0xFF161B27),
                onSelected: (v) {
                  if (v) _update(_cfg.copyWith(steeringSensitivity: deg));
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          _sectionTitle('PROGRESSIVE RESPONSE CURVE'),
          const SizedBox(height: 4),
          const Text(
            'Higher curvature softens center micro-adjustments for stable straightaway control without losing full lock.',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              {'name': 'Linear (1.0x)', 'val': 1.0},
              {'name': 'Sport/GT (1.35x)', 'val': 1.35},
              {'name': 'Formula (1.6x)', 'val': 1.6},
              {'name': 'Highway (2.0x)', 'val': 2.0},
            ].map((preset) {
              final val = preset['val'] as double;
              final sel = (_cfg.steeringLinearity - val).abs() < 0.05;
              return ChoiceChip(
                label: Text(
                  preset['name'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: sel ? const Color(0xFF090B0F) : Colors.white70,
                  ),
                ),
                selected: sel,
                selectedColor: _cfg.wheelAccentColor,
                backgroundColor: const Color(0xFF161B27),
                onSelected: (v) {
                  if (v) _update(_cfg.copyWith(steeringLinearity: val));
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('CENTER DEADZONE:',
                            style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text('${(_cfg.steeringDeadzone * 100).toStringAsFixed(1)}%',
                            style: TextStyle(fontFamily: 'monospace', color: _cfg.wheelAccentColor, fontSize: 11)),
                      ],
                    ),
                    Slider(
                      value: _cfg.steeringDeadzone,
                      min: 0.0,
                      max: 0.15,
                      divisions: 15,
                      activeColor: _cfg.wheelAccentColor,
                      inactiveColor: Colors.white12,
                      onChanged: (v) => _update(_cfg.copyWith(steeringDeadzone: v)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('CURVE LINEARITY:',
                            style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text('${_cfg.steeringLinearity.toStringAsFixed(2)}x',
                            style: TextStyle(fontFamily: 'monospace', color: _cfg.wheelAccentColor, fontSize: 11)),
                      ],
                    ),
                    Slider(
                      value: _cfg.steeringLinearity.clamp(0.5, 2.0),
                      min: 0.5,
                      max: 2.0,
                      divisions: 30,
                      activeColor: _cfg.wheelAccentColor,
                      inactiveColor: Colors.white12,
                      onChanged: (v) => _update(_cfg.copyWith(steeringLinearity: v)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── STEERING SMOOTHING (ANTI-JITTER FILTER) ───────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF141824),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 14, color: _cfg.wheelAccentColor),
                        const SizedBox(width: 6),
                        const Text(
                          'ANTI-TWITCH SMOOTHING FILTER:',
                          style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      _cfg.steeringSmoothing <= 0.01
                          ? 'OFF (RAW)'
                          : '${(_cfg.steeringSmoothing * 100).round()}% ${(_cfg.steeringSmoothing - 0.20).abs() < 0.03 ? '(OPTIMAL)' : '(DAMPED)'}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: _cfg.wheelAccentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _cfg.steeringSmoothing.clamp(0.0, 0.8),
                  min: 0.0,
                  max: 0.8,
                  divisions: 16,
                  activeColor: _cfg.wheelAccentColor,
                  inactiveColor: Colors.white12,
                  onChanged: (v) => _update(_cfg.copyWith(steeringSmoothing: v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _changeSensitivity(double delta) {
    final next = (_cfg.steeringSensitivity + delta).clamp(1.0, 900.0);
    _update(_cfg.copyWith(steeringSensitivity: next));
  }

  Widget _stepBtn(String text, VoidCallback onPressed) {
    return SizedBox(
      height: 30,
      width: 42,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          backgroundColor: const Color(0xFF10141E),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3: PEDALS & BRAKE FIX
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPedalsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── BRAKE INPUT BEHAVIOR (FIX) ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF161B28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF2A4B).withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.flash_on_rounded, size: 16, color: Color(0xFFFF2A4B)),
                    SizedBox(width: 6),
                    Text(
                      'BRAKE RESPONSE MODE & SENSITIVITY FIX',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFFF2A4B)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _choiceChip('MODULATED SLIDER', BrakeMode.progressiveSlider, _cfg.brakeMode, (v) {
                      _update(_cfg.copyWith(brakeMode: v));
                    }),
                    _choiceChip('TAP & HOLD (STOMP BRAKE)', BrakeMode.tapAndHoldStomp, _cfg.brakeMode, (v) {
                      _update(_cfg.copyWith(brakeMode: v));
                    }),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('BRAKE GAIN / SENSITIVITY MULTIPLIER:',
                        style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text('${_cfg.brakeSensitivityMultiplier.toStringAsFixed(1)}x',
                        style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFFF2A4B), fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _cfg.brakeSensitivityMultiplier,
                  min: 1.0,
                  max: 3.0,
                  divisions: 20,
                  activeColor: const Color(0xFFFF2A4B),
                  inactiveColor: Colors.white12,
                  onChanged: (v) => _update(_cfg.copyWith(brakeSensitivityMultiplier: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pedal Style Model
          _sectionTitle('PEDAL ARCHITECTURE & FACEPLATE'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _choiceChip('BILLET RALLY', PedalStyle.billetRally, _cfg.pedalStyle, (v) {
                _update(_cfg.copyWith(pedalStyle: v));
              }),
              _choiceChip('CARBON TRACK', PedalStyle.carbonTrack, _cfg.pedalStyle, (v) {
                _update(_cfg.copyWith(pedalStyle: v));
              }),
              _choiceChip('PERFORATED SPORT', PedalStyle.perforatedSport, _cfg.pedalStyle, (v) {
                _update(_cfg.copyWith(pedalStyle: v));
              }),
              _choiceChip('MINIMAL GLOW', PedalStyle.minimalGlow, _cfg.pedalStyle, (v) {
                _update(_cfg.copyWith(pedalStyle: v));
              }),
            ],
          ),
          const SizedBox(height: 18),

          // Throttle Response Curve
          _sectionTitle('THROTTLE RESPONSE CURVE (POWER DELIVERY)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _choiceChip('LINEAR (1:1 DIRECT)', PedalCurve.linear, _cfg.throttleCurve, (v) {
                _update(_cfg.copyWith(throttleCurve: v));
              }),
              _choiceChip('SMOOTH (x^1.2)', PedalCurve.smooth, _cfg.throttleCurve, (v) {
                _update(_cfg.copyWith(throttleCurve: v));
              }),
              _choiceChip('PROGRESSIVE (x^1.6)', PedalCurve.exponential, _cfg.throttleCurve, (v) {
                _update(_cfg.copyWith(throttleCurve: v));
              }),
              _choiceChip('AGGRESSIVE (x^2.2)', PedalCurve.aggressive, _cfg.throttleCurve, (v) {
                _update(_cfg.copyWith(throttleCurve: v));
              }),
            ],
          ),
          const SizedBox(height: 18),

          // Throttle & Brake Colors
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('THROTTLE COLOR'),
                    const SizedBox(height: 6),
                    _colorRow(_cfg.throttleColor, (c) => _update(_cfg.copyWith(throttleColor: c))),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('BRAKE COLOR'),
                    const SizedBox(height: 6),
                    _colorRow(_cfg.brakeColor, (c) => _update(_cfg.copyWith(brakeColor: c))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3-Pedal Clutch & Direction Toggles
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Enable Clutch Pedal (3-Pedals)',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  value: _cfg.showClutch,
                  activeColor: _cfg.clutchColor,
                  onChanged: (val) => _update(_cfg.copyWith(showClutch: val)),
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Haptic Vibration Feedback',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  value: _cfg.hapticFeedback,
                  activeColor: _cfg.wheelAccentColor,
                  onChanged: (val) => _update(_cfg.copyWith(hapticFeedback: val)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 4: HUD & BUTTONS LAYOUT
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildLayoutAndButtonsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner to open interactive visual drag-and-drop editor
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _cfg.wheelAccentColor.withOpacity(0.2),
                  const Color(0xFF141824),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cfg.wheelAccentColor.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.dashboard_customize_rounded, size: 28, color: _cfg.wheelAccentColor),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INTERACTIVE HUD DRAG & DROP EDITOR',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Freely move, resize, and position the steering wheel, pedals, shifters, and extra buttons anywhere on screen.',
                        style: TextStyle(color: Colors.white60, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cfg.wheelAccentColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('EDIT LAYOUT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  onPressed: () {
                    Navigator.of(context).pop();
                    HudLayoutEditor.show(
                      context,
                      config: _cfg,
                      onSave: (newCfg) {
                        widget.onConfigChanged(newCfg);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Custom Layout Active Toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Use Custom Screen Placement',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: const Text('When enabled, elements appear at your saved positions.',
                style: TextStyle(color: Colors.white54, fontSize: 10)),
            value: _cfg.useCustomLayout,
            activeColor: _cfg.wheelAccentColor,
            onChanged: (val) => _update(_cfg.copyWith(useCustomLayout: val)),
          ),
          const SizedBox(height: 14),

          // Extra Buttons List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('EXTRA ON-SCREEN BUTTONS (${_cfg.extraButtons.length})'),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2436),
                  foregroundColor: const Color(0xFF00E5FF),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('ADD BUTTON', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                onPressed: () => _showAddButtonPresetDialog(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_cfg.extraButtons.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF131722),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: const Text(
                'No extra buttons added yet.\nTap "+ ADD BUTTON" to add Handbrake, Nitrous, Horn, or Camera!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _cfg.extraButtons.map((btn) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: btn.color,
                    radius: 6,
                  ),
                  label: Text(btn.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                  backgroundColor: const Color(0xFF1A202E),
                  side: BorderSide(color: btn.color.withOpacity(0.5)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Colors.white60),
                  onDeleted: () {
                    final next = List<ExtraButtonConfig>.from(_cfg.extraButtons)..removeWhere((b) => b.id == btn.id);
                    _update(_cfg.copyWith(extraButtons: next));
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _showAddButtonPresetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141824),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2C3549)),
        ),
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline_rounded, color: Color(0xFF00E5FF)),
            SizedBox(width: 8),
            Text('Select Button Action', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buttonPresets.map((preset) {
                final color = preset['color'] as Color;
                return ActionChip(
                  avatar: Icon(preset['icon'] as IconData, size: 16, color: color),
                  label: Text(preset['label'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                  backgroundColor: const Color(0xFF1B2130),
                  side: BorderSide(color: color.withOpacity(0.5)),
                  onPressed: () {
                    final newId = 'btn_${DateTime.now().millisecondsSinceEpoch}';
                    final next = List<ExtraButtonConfig>.from(_cfg.extraButtons)
                      ..add(
                        ExtraButtonConfig(
                          id: newId,
                          label: preset['label'] as String,
                          buttonMask: preset['mask'] as int,
                          isBtn2: preset['isBtn2'] as bool,
                          color: color,
                          size: 52.0,
                          x: 0.50,
                          y: 0.50,
                        ),
                      );
                    _update(_cfg.copyWith(extraButtons: next, useCustomLayout: true));
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: Colors.white54,
      ),
    );
  }

  Widget _choiceChip<T>(String label, T value, T current, ValueChanged<T> onSelected) {
    final sel = value == current;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: sel ? const Color(0xFF090B0F) : Colors.white70,
        ),
      ),
      selected: sel,
      selectedColor: _cfg.wheelAccentColor,
      backgroundColor: const Color(0xFF161B27),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onSelected: (v) {
        if (v) onSelected(value);
      },
    );
  }

  Widget _colorRow(Color selected, ValueChanged<Color> onSelected) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _presetColors.map((c) {
          final isSel = c.value == selected.value;
          return GestureDetector(
            onTap: () => onSelected(c),
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSel ? Colors.white : Colors.white24,
                  width: isSel ? 2.5 : 1.0,
                ),
                boxShadow: isSel ? [BoxShadow(color: c.withOpacity(0.7), blurRadius: 8)] : [],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _colorBubble(Color c, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}
