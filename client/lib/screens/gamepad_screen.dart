import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/customization_config.dart';
import '../services/udp_transmitter.dart';
import '../theme/app_theme.dart';
import '../widgets/action_button.dart';
import '../widgets/virtual_joystick.dart';

/// Fully customizable, responsive on-screen gamepad.
/// Supports Xbox & PlayStation layouts, customizable deadzones & sensitivity,
/// instant or analog triggers, ABXY / PlayStation symbols, L3/R3 stick clicks,
/// and remappable pro rear paddles (M1/M2).
class GamepadScreen extends StatefulWidget {
  final UdpTransmitter tx;
  final CustomizationConfig config;
  final VoidCallback? onOpenCustomization;

  const GamepadScreen({
    super.key,
    required this.tx,
    required this.config,
    this.onOpenCustomization,
  });

  @override
  State<GamepadScreen> createState() => _GamepadScreenState();
}

class _GamepadScreenState extends State<GamepadScreen> {
  Color get _accent => widget.config.gamepadAccentColor;

  void _vibrate() {
    if (widget.config.gamepadHaptics) {
      HapticFeedback.lightImpact();
    }
  }

  void _onLeftStick(double dx, double dy) {
    final deadzone = widget.config.leftStickDeadzone;
    final sens = widget.config.leftStickSensitivity;

    double processAxis(double val) {
      final abs = val.abs();
      if (abs <= deadzone) return 0.0;
      final normalized = ((abs - deadzone) / (1.0 - deadzone)).clamp(0.0, 1.0);
      final curved = normalized * (val >= 0 ? 1.0 : -1.0) * sens;
      return curved.clamp(-1.0, 1.0);
    }

    final pDx = processAxis(dx);
    final pDy = processAxis(dy);

    widget.tx.setSteer((pDx * 32767).toInt());
    // Encode LY into partial ry if right stick is neutral
    if (widget.tx.rx == 0 && widget.tx.ry == 0 && pDy.abs() > 0.05) {
      widget.tx.updateRightStick(rx: 0, ry: (pDy * 16383).toInt());
    }
  }

  void _onRightStick(double dx, double dy) {
    final deadzone = widget.config.rightStickDeadzone;
    final sens = widget.config.rightStickSensitivity;
    final invertY = widget.config.invertRightStickY;

    double processAxis(double val) {
      final abs = val.abs();
      if (abs <= deadzone) return 0.0;
      final normalized = ((abs - deadzone) / (1.0 - deadzone)).clamp(0.0, 1.0);
      final curved = normalized * (val >= 0 ? 1.0 : -1.0) * sens;
      return curved.clamp(-1.0, 1.0);
    }

    final pDx = processAxis(dx);
    final pDy = processAxis(invertY ? -dy : dy);

    widget.tx.updateRightStick(
      rx: (pDx * 32767).toInt(),
      ry: (pDy * 32767).toInt(),
    );
  }

  void _setPaddleAction(String action, bool pressed) {
    if (pressed) _vibrate();
    switch (action.toUpperCase()) {
      case 'LB':
        widget.tx.setButton(UdpTransmitter.btnLB, pressed: pressed);
        break;
      case 'RB':
        widget.tx.setButton(UdpTransmitter.btnRB, pressed: pressed);
        break;
      case 'A':
        widget.tx.setButton(UdpTransmitter.btnA, pressed: pressed);
        break;
      case 'B':
        widget.tx.setButton(UdpTransmitter.btnB, pressed: pressed);
        break;
      case 'X':
        widget.tx.setButton(UdpTransmitter.btnX, pressed: pressed);
        break;
      case 'Y':
        widget.tx.setButton(UdpTransmitter.btnY, pressed: pressed);
        break;
      case 'L3':
        widget.tx.setButton(UdpTransmitter.btnLStick, btn2: true, pressed: pressed);
        break;
      case 'R3':
        widget.tx.setButton(UdpTransmitter.btnRStick, btn2: true, pressed: pressed);
        break;
      case 'BACK':
        widget.tx.setButton(UdpTransmitter.btnBack, pressed: pressed);
        break;
      case 'START':
        widget.tx.setButton(UdpTransmitter.btnStart, pressed: pressed);
        break;
    }
  }

  Widget _buildLeftShoulders() {
    final swapped = widget.config.swapBumpersAndTriggers;
    final isAnalog = widget.config.triggerStyle == TriggerStyle.analogSlider;

    Widget btnLB = TriggerButton(
      label: 'LB',
      color: _accent,
      width: 68,
      height: 34,
      onPressed: () {
        _vibrate();
        widget.tx.setButton(UdpTransmitter.btnLB, pressed: true);
      },
      onReleased: () => widget.tx.setButton(UdpTransmitter.btnLB, pressed: false),
    );

    Widget btnLT = isAnalog
        ? _AnalogTriggerSlider(
            label: 'LT',
            color: _accent,
            width: 68,
            height: 48,
            onChanged: (val) => widget.tx.setBrake(val),
          )
        : TriggerButton(
            label: 'LT',
            color: _accent,
            width: 68,
            height: 34,
            onPressed: () {
              _vibrate();
              widget.tx.setBrake(65535);
            },
            onReleased: () => widget.tx.setBrake(0),
          );

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: swapped
          ? [btnLT, const SizedBox(width: 6), btnLB]
          : [btnLB, const SizedBox(width: 6), btnLT],
    );
  }

  Widget _buildRightShoulders() {
    final swapped = widget.config.swapBumpersAndTriggers;
    final isAnalog = widget.config.triggerStyle == TriggerStyle.analogSlider;

    Widget btnRB = TriggerButton(
      label: 'RB',
      color: _accent,
      width: 68,
      height: 34,
      onPressed: () {
        _vibrate();
        widget.tx.setButton(UdpTransmitter.btnRB, pressed: true);
      },
      onReleased: () => widget.tx.setButton(UdpTransmitter.btnRB, pressed: false),
    );

    Widget btnRT = isAnalog
        ? _AnalogTriggerSlider(
            label: 'RT',
            color: _accent,
            width: 68,
            height: 48,
            onChanged: (val) => widget.tx.setThrottle(val),
          )
        : TriggerButton(
            label: 'RT',
            color: _accent,
            width: 68,
            height: 34,
            onPressed: () {
              _vibrate();
              widget.tx.setThrottle(65535);
            },
            onReleased: () => widget.tx.setThrottle(0),
          );

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: swapped
          ? [btnRB, const SizedBox(width: 6), btnRT]
          : [btnRT, const SizedBox(width: 6), btnRB],
    );
  }

  Widget _buildLeftStickWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('L STICK', style: AppTheme.label(size: 9, color: _accent.withOpacity(0.6))),
            if (widget.config.showL3R3) ...[
              const SizedBox(width: 8),
              _SmallClickButton(
                label: 'L3',
                color: _accent,
                onPressed: () {
                  _vibrate();
                  widget.tx.setButton(UdpTransmitter.btnLStick, btn2: true, pressed: true);
                },
                onReleased: () => widget.tx.setButton(UdpTransmitter.btnLStick, btn2: true, pressed: false),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        VirtualJoystick(
          size: widget.config.joystickSize,
          color: _accent,
          onChanged: _onLeftStick,
        ),
      ],
    );
  }

  Widget _buildRightStickWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('R STICK', style: AppTheme.label(size: 9, color: _accent.withOpacity(0.6))),
            if (widget.config.showL3R3) ...[
              const SizedBox(width: 8),
              _SmallClickButton(
                label: 'R3',
                color: _accent,
                onPressed: () {
                  _vibrate();
                  widget.tx.setButton(UdpTransmitter.btnRStick, btn2: true, pressed: true);
                },
                onReleased: () => widget.tx.setButton(UdpTransmitter.btnRStick, btn2: true, pressed: false),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        VirtualJoystick(
          size: widget.config.joystickSize,
          color: _accent,
          onChanged: _onRightStick,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPlaystation = widget.config.gamepadLayout == GamepadLayout.playstation;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Stack(
        children: [
          Row(
            children: [
              // ── Left Column: Shoulders, D-Pad / Left Stick ─────────────
              Expanded(
                flex: 3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: 175,
                    height: 275,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLeftShoulders(),
                        if (isPlaystation) ...[
                          _DPad(tx: widget.tx, color: _accent, onHaptic: _vibrate),
                          _buildLeftStickWidget(),
                        ] else ...[
                          _buildLeftStickWidget(),
                          _DPad(tx: widget.tx, color: _accent, onHaptic: _vibrate),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // ── Center Console: Back / Tune / Logo / Start ──────────────
              Expanded(
                flex: 1,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Quick Customize Button
                      if (widget.onOpenCustomization != null) ...[
                        GestureDetector(
                          onTap: widget.onOpenCustomization,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: _accent.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _accent.withOpacity(0.5)),
                              boxShadow: [
                                BoxShadow(
                                  color: _accent.withOpacity(0.2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tune_rounded, size: 11, color: _accent),
                                const SizedBox(width: 3),
                                Text(
                                  'TUNE',
                                  style: AppTheme.label(size: 8, color: _accent),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      TriggerButton(
                        label: 'BACK',
                        color: AppTheme.textSecondary,
                        width: 52,
                        height: 26,
                        onPressed: () {
                          _vibrate();
                          widget.tx.setButton(UdpTransmitter.btnBack, pressed: true);
                        },
                        onReleased: () => widget.tx.setButton(UdpTransmitter.btnBack, pressed: false),
                      ),
                      const SizedBox(height: 10),

                      // Center V Badge with glowing ring
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.bgCard,
                          border: Border.all(color: _accent.withOpacity(0.6), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withOpacity(0.35),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text('V', style: AppTheme.digit(size: 14, color: _accent)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      TriggerButton(
                        label: 'START',
                        color: AppTheme.textSecondary,
                        width: 52,
                        height: 26,
                        onPressed: () {
                          _vibrate();
                          widget.tx.setButton(UdpTransmitter.btnStart, pressed: true);
                        },
                        onReleased: () => widget.tx.setButton(UdpTransmitter.btnStart, pressed: false),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Right Column: Shoulders, Face Buttons, Right Stick ──────
              Expanded(
                flex: 3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: 175,
                    height: 275,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildRightShoulders(),
                        _FaceButtons(
                          tx: widget.tx,
                          style: widget.config.gamepadButtonStyle,
                          accentColor: _accent,
                          onHaptic: _vibrate,
                        ),
                        _buildRightStickWidget(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Optional Pro Rear Paddles (M1 / M2) ─────────────────────────
          if (widget.config.showPaddles) ...[
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: _PaddleButton(
                  label: 'M1 (${widget.config.paddle1Action})',
                  color: _accent,
                  onPressed: () => _setPaddleAction(widget.config.paddle1Action, true),
                  onReleased: () => _setPaddleAction(widget.config.paddle1Action, false),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 4, bottom: 2),
                child: _PaddleButton(
                  label: 'M2 (${widget.config.paddle2Action})',
                  color: _accent,
                  onPressed: () => _setPaddleAction(widget.config.paddle2Action, true),
                  onReleased: () => _setPaddleAction(widget.config.paddle2Action, false),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── D-Pad ─────────────────────────────────────────────────────────────────
class _DPad extends StatelessWidget {
  final UdpTransmitter tx;
  final Color color;
  final VoidCallback onHaptic;

  const _DPad({
    required this.tx,
    required this.color,
    required this.onHaptic,
  });

  @override
  Widget build(BuildContext context) {
    const btnSize = 38.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DBtn(
          label: '▲',
          onP: () {
            onHaptic();
            tx.setButton(UdpTransmitter.btnDUp, btn2: true, pressed: true);
          },
          onR: () => tx.setButton(UdpTransmitter.btnDUp, btn2: true, pressed: false),
          size: btnSize,
          color: color,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DBtn(
              label: '◀',
              onP: () {
                onHaptic();
                tx.setButton(UdpTransmitter.btnDLeft, btn2: true, pressed: true);
              },
              onR: () => tx.setButton(UdpTransmitter.btnDLeft, btn2: true, pressed: false),
              size: btnSize,
              color: color,
            ),
            SizedBox(
              width: btnSize * 0.8,
              height: btnSize * 0.8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.bgPanel,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            _DBtn(
              label: '▶',
              onP: () {
                onHaptic();
                tx.setButton(UdpTransmitter.btnDRight, btn2: true, pressed: true);
              },
              onR: () => tx.setButton(UdpTransmitter.btnDRight, btn2: true, pressed: false),
              size: btnSize,
              color: color,
            ),
          ],
        ),
        _DBtn(
          label: '▼',
          onP: () {
            onHaptic();
            tx.setButton(UdpTransmitter.btnDDown, btn2: true, pressed: true);
          },
          onR: () => tx.setButton(UdpTransmitter.btnDDown, btn2: true, pressed: false),
          size: btnSize,
          color: color,
        ),
      ],
    );
  }
}

class _DBtn extends StatefulWidget {
  final String label;
  final VoidCallback onP, onR;
  final double size;
  final Color color;

  const _DBtn({
    required this.label,
    required this.onP,
    required this.onR,
    required this.size,
    required this.color,
  });

  @override
  State<_DBtn> createState() => _DBtnState();
}

class _DBtnState extends State<_DBtn> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        setState(() => _p = true);
        widget.onP();
      },
      onPointerUp: (_) {
        setState(() => _p = false);
        widget.onR();
      },
      onPointerCancel: (_) {
        setState(() => _p = false);
        widget.onR();
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: _p ? widget.color.withOpacity(0.35) : AppTheme.bgPanel,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: widget.color.withOpacity(_p ? 0.9 : 0.3)),
          boxShadow: _p
              ? [BoxShadow(color: widget.color.withOpacity(0.4), blurRadius: 10, spreadRadius: 1)]
              : [],
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(color: widget.color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// ── Face Buttons (ABXY or PlayStation Symbols) ────────────────────────────
class _FaceButtons extends StatelessWidget {
  final UdpTransmitter tx;
  final GamepadButtonStyle style;
  final Color accentColor;
  final VoidCallback onHaptic;

  const _FaceButtons({
    required this.tx,
    required this.style,
    required this.accentColor,
    required this.onHaptic,
  });

  @override
  Widget build(BuildContext context) {
    String labelY = 'Y';
    String labelX = 'X';
    String labelB = 'B';
    String labelA = 'A';

    Color colorY = const Color(0xFFE2B714);
    Color colorX = const Color(0xFF0078D4);
    Color colorB = const Color(0xFFE81123);
    Color colorA = const Color(0xFF107C10);

    switch (style) {
      case GamepadButtonStyle.xboxColors:
        // defaults above
        break;
      case GamepadButtonStyle.neonTheme:
        colorY = accentColor;
        colorX = accentColor;
        colorB = accentColor;
        colorA = accentColor;
        break;
      case GamepadButtonStyle.playstationSymbols:
        labelY = '△';
        labelX = '□';
        labelB = '○';
        labelA = '✕';
        colorY = const Color(0xFF00E5FF);
        colorX = const Color(0xFFFF4081);
        colorB = const Color(0xFFFF1744);
        colorA = const Color(0xFF2979FF);
        break;
      case GamepadButtonStyle.stealthDark:
        colorY = const Color(0xFFCCCCCC);
        colorX = const Color(0xFFCCCCCC);
        colorB = const Color(0xFFCCCCCC);
        colorA = const Color(0xFFCCCCCC);
        break;
    }

    const double btnSize = 46.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ActionButton(
          label: labelY,
          color: colorY,
          size: btnSize,
          onPressed: () {
            onHaptic();
            tx.setButton(UdpTransmitter.btnY, pressed: true);
          },
          onReleased: () => tx.setButton(UdpTransmitter.btnY, pressed: false),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ActionButton(
              label: labelX,
              color: colorX,
              size: btnSize,
              onPressed: () {
                onHaptic();
                tx.setButton(UdpTransmitter.btnX, pressed: true);
              },
              onReleased: () => tx.setButton(UdpTransmitter.btnX, pressed: false),
            ),
            const SizedBox(width: 4),
            ActionButton(
              label: labelB,
              color: colorB,
              size: btnSize,
              onPressed: () {
                onHaptic();
                tx.setButton(UdpTransmitter.btnB, pressed: true);
              },
              onReleased: () => tx.setButton(UdpTransmitter.btnB, pressed: false),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ActionButton(
          label: labelA,
          color: colorA,
          size: btnSize,
          onPressed: () {
            onHaptic();
            tx.setButton(UdpTransmitter.btnA, pressed: true);
          },
          onReleased: () => tx.setButton(UdpTransmitter.btnA, pressed: false),
        ),
      ],
    );
  }
}

// ── Small L3 / R3 Click Button ────────────────────────────────────────────
class _SmallClickButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final VoidCallback onReleased;

  const _SmallClickButton({
    required this.label,
    required this.color,
    required this.onPressed,
    required this.onReleased,
  });

  @override
  State<_SmallClickButton> createState() => _SmallClickButtonState();
}

class _SmallClickButtonState extends State<_SmallClickButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        setState(() => _pressed = true);
        widget.onPressed();
      },
      onPointerUp: (_) {
        setState(() => _pressed = false);
        widget.onReleased();
      },
      onPointerCancel: (_) {
        setState(() => _pressed = false);
        widget.onReleased();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _pressed ? widget.color.withOpacity(0.35) : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: widget.color.withOpacity(_pressed ? 0.9 : 0.4)),
        ),
        child: Text(
          widget.label,
          style: AppTheme.label(size: 8, color: _pressed ? Colors.white : widget.color),
        ),
      ),
    );
  }
}

// ── Analog Modulated Trigger Slider ───────────────────────────────────────
class _AnalogTriggerSlider extends StatefulWidget {
  final String label;
  final Color color;
  final double width;
  final double height;
  final ValueChanged<int> onChanged;

  const _AnalogTriggerSlider({
    required this.label,
    required this.color,
    required this.width,
    required this.height,
    required this.onChanged,
  });

  @override
  State<_AnalogTriggerSlider> createState() => _AnalogTriggerSliderState();
}

class _AnalogTriggerSliderState extends State<_AnalogTriggerSlider> {
  double _fraction = 0.0; // 0.0 to 1.0

  void _handleTouch(Offset localPosition) {
    final frac = (localPosition.dy / widget.height).clamp(0.0, 1.0);
    setState(() => _fraction = frac);
    widget.onChanged((frac * 65535).round());
  }

  void _release() {
    setState(() => _fraction = 0.0);
    widget.onChanged(0);
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_fraction * 100).round();
    final c = widget.color;

    return Listener(
      onPointerDown: (e) => _handleTouch(e.localPosition),
      onPointerMove: (e) => _handleTouch(e.localPosition),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withOpacity(0.4), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6.5),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Fill level indicator
              FractionallySizedBox(
                heightFactor: _fraction,
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.withOpacity(0.3), c.withOpacity(0.75)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
              // Label & live percentage
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: AppTheme.label(size: 11, color: Colors.white),
                    ),
                    Text(
                      '$pct%',
                      style: AppTheme.digit(size: 10, color: c),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Rear Pro Paddle Button ────────────────────────────────────────────────
class _PaddleButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final VoidCallback onReleased;

  const _PaddleButton({
    required this.label,
    required this.color,
    required this.onPressed,
    required this.onReleased,
  });

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
        widget.onPressed();
      },
      onPointerUp: (_) {
        setState(() => _pressed = false);
        widget.onReleased();
      },
      onPointerCancel: (_) {
        setState(() => _pressed = false);
        widget.onReleased();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _pressed ? widget.color.withOpacity(0.35) : AppTheme.bgPanel,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: widget.color.withOpacity(_pressed ? 0.9 : 0.4)),
          boxShadow: _pressed
              ? [BoxShadow(color: widget.color.withOpacity(0.35), blurRadius: 10, spreadRadius: 1)]
              : [],
        ),
        child: Text(
          widget.label,
          style: AppTheme.label(size: 9, color: _pressed ? Colors.white : widget.color),
        ),
      ),
    );
  }
}
