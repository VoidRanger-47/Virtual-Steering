import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/udp_transmitter.dart';
import '../widgets/virtual_joystick.dart';
import '../widgets/action_button.dart';

/// RPG mode: Left joystick = move, Right swipe = camera,
/// Right panel = Attack, Heavy, Dodge, Block, Skill1, Skill2, Interact, Menu
class RpgScreen extends StatefulWidget {
  final UdpTransmitter tx;
  const RpgScreen({super.key, required this.tx});

  @override
  State<RpgScreen> createState() => _RpgScreenState();
}

class _RpgScreenState extends State<RpgScreen> {
  static const Color _accent = AppTheme.neonAmber;

  Offset _lastCam = Offset.zero;
  bool _camActive = false;
  double _camSens = 1.0;

  void _onMove(double dx, double dy) {
    final lx = (dx * 32767).toInt();
    widget.tx.updateDriveInputs(steer: lx, throttle: 0, brake: 0);
    if (!_camActive) {
      widget.tx.updateRightStick(rx: 0, ry: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Left: Move joystick ───────────────────────────────────────────
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('MOVE', style: AppTheme.label(size: 10, color: _accent.withOpacity(0.5))),
                  const SizedBox(height: 6),
                  VirtualJoystick(
                    size:  130,
                    color: _accent,
                    onChanged: _onMove,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Center: Camera look swipe ─────────────────────────────────────
        Expanded(
          flex: 3,
          child: Listener(
            onPointerDown: (e) {
              setState(() { _camActive = true; _lastCam = e.localPosition; });
            },
            onPointerMove: (e) {
              final d = e.localPosition - _lastCam;
              _lastCam = e.localPosition;
              final sens = _camSens * 180;
              widget.tx.updateRightStick(
                rx: (d.dx * sens).clamp(-32767, 32767).toInt(),
                ry: (-d.dy * sens).clamp(-32767, 32767).toInt(),
              );
            },
            onPointerUp: (_) {
              setState(() => _camActive = false);
              widget.tx.updateRightStick(rx: 0, ry: 0);
            },
            onPointerCancel: (_) {
              setState(() => _camActive = false);
              widget.tx.updateRightStick(rx: 0, ry: 0);
            },
            child: Container(
              decoration: BoxDecoration(
                color: _camActive ? _accent.withOpacity(0.03) : Colors.transparent,
                border: Border.all(
                  color: _accent.withOpacity(_camActive ? 0.2 : 0.06),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe_rounded,
                        size: 32, color: _accent.withOpacity(_camActive ? 0.6 : 0.18)),
                    const SizedBox(height: 6),
                    Text('CAMERA', style: AppTheme.label(
                        size: 10, color: _accent.withOpacity(_camActive ? 0.6 : 0.18))),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Right: Action buttons ──────────────────────────────────────────
        SizedBox(
          width: 200,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 190,
                height: 275,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                // Skill / Block row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TriggerButton(
                      label: 'LB\nSKILL 1',
                      color: _accent,
                      width: 80,
                      height: 34,
                      onPressed:  () => widget.tx.setButton(UdpTransmitter.btnLB, pressed: true),
                      onReleased: () => widget.tx.setButton(UdpTransmitter.btnLB, pressed: false),
                    ),
                    TriggerButton(
                      label: 'RB\nSKILL 2',
                      color: _accent,
                      width: 80,
                      height: 34,
                      onPressed:  () => widget.tx.setButton(UdpTransmitter.btnRB, pressed: true),
                      onReleased: () => widget.tx.setButton(UdpTransmitter.btnRB, pressed: false),
                    ),
                  ],
                ),
                // Block / Parry (LT) + Heavy (RT)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TriggerButton(
                      label: 'LT\nBLOCK',
                      color: AppTheme.neonCyan,
                      width: 80,
                      height: 38,
                      onPressed:  () => widget.tx.updateDriveInputs(steer: 0, throttle: 0, brake: 65535),
                      onReleased: () => widget.tx.updateDriveInputs(steer: 0, throttle: 0, brake: 0),
                    ),
                    TriggerButton(
                      label: 'RT\nHEAVY',
                      color: AppTheme.neonRed,
                      width: 80,
                      height: 38,
                      onPressed:  () => widget.tx.updateDriveInputs(steer: 0, throttle: 65535, brake: 0),
                      onReleased: () => widget.tx.updateDriveInputs(steer: 0, throttle: 0, brake: 0),
                    ),
                  ],
                ),
                // Face buttons
                Column(
                  children: [
                    ActionButton(
                      label: 'Y\nULT',
                      color: AppTheme.neonAmber,
                      size: 52,
                      onPressed:  () => widget.tx.setButton(UdpTransmitter.btnY, pressed: true),
                      onReleased: () => widget.tx.setButton(UdpTransmitter.btnY, pressed: false),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ActionButton(
                          label: 'X\nATK',
                          color: AppTheme.neonCyan,
                          size: 52,
                          onPressed:  () => widget.tx.setButton(UdpTransmitter.btnX, pressed: true),
                          onReleased: () => widget.tx.setButton(UdpTransmitter.btnX, pressed: false),
                        ),
                        ActionButton(
                          label: 'B\nDGE',
                          color: AppTheme.neonRed,
                          size: 52,
                          onPressed:  () => widget.tx.setButton(UdpTransmitter.btnB, pressed: true),
                          onReleased: () => widget.tx.setButton(UdpTransmitter.btnB, pressed: false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ActionButton(
                      label: 'A\nINT',
                      color: AppTheme.neonGreen,
                      size: 52,
                      onPressed:  () => widget.tx.setButton(UdpTransmitter.btnA, pressed: true),
                      onReleased: () => widget.tx.setButton(UdpTransmitter.btnA, pressed: false),
                    ),
                  ],
                ),
                // Menu buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TriggerButton(
                      label: 'MAP',
                      color: AppTheme.textDim,
                      width: 60,
                      height: 28,
                      onPressed:  () => widget.tx.setButton(UdpTransmitter.btnBack, pressed: true),
                      onReleased: () => widget.tx.setButton(UdpTransmitter.btnBack, pressed: false),
                    ),
                    TriggerButton(
                      label: 'MENU',
                      color: AppTheme.textDim,
                      width: 60,
                      height: 28,
                      onPressed:  () => widget.tx.setButton(UdpTransmitter.btnStart, pressed: true),
                      onReleased: () => widget.tx.setButton(UdpTransmitter.btnStart, pressed: false),
                    ),
                  ],
                ),
                // Camera sensitivity
                Column(
                  children: [
                    Text('CAM SENS', style: AppTheme.label(size: 9, color: AppTheme.textDim)),
                    Slider(
                      value: _camSens,
                      min: 0.3,
                      max: 3.0,
                      divisions: 27,
                      activeColor: _accent,
                      inactiveColor: _accent.withOpacity(0.2),
                      onChanged: (v) => setState(() => _camSens = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
      ],
    );
  }
}
