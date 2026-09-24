import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable on-screen analog joystick with neon glow aesthetic.
/// Returns normalized (dx, dy) in range -1.0 to 1.0.
class VirtualJoystick extends StatefulWidget {
  final double size;
  final Color color;
  final void Function(double dx, double dy) onChanged;
  final String? label;

  const VirtualJoystick({
    super.key,
    this.size = 140,
    this.color = AppTheme.neonCyan,
    required this.onChanged,
    this.label,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick>
    with SingleTickerProviderStateMixin {
  Offset _knob = Offset.zero;    // -1..1 normalized
  Offset _rawKnob = Offset.zero; // pixel offset
  bool _active = false;
  late AnimationController _returnAnim;
  late Animation<Offset> _returnOffset;

  @override
  void initState() {
    super.initState();
    _returnAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _returnOffset = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
      CurvedAnimation(parent: _returnAnim, curve: Curves.easeOut),
    );
    _returnAnim.addListener(() {
      setState(() => _rawKnob = _returnOffset.value);
      final r = widget.size * 0.5 * 0.55;
      widget.onChanged(
        (_rawKnob.dx / r).clamp(-1, 1),
        (-_rawKnob.dy / r).clamp(-1, 1),
      );
    });
  }

  @override
  void dispose() {
    _returnAnim.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails d) {
    _returnAnim.stop();
    setState(() => _active = true);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final r = widget.size * 0.5 * 0.55; // max travel radius
    var raw = _rawKnob + d.delta;
    final dist = raw.distance;
    if (dist > r) raw = raw / dist * r;
    setState(() => _rawKnob = raw);
    _knob = Offset(raw.dx / r, -raw.dy / r);
    widget.onChanged(_knob.dx.clamp(-1, 1), _knob.dy.clamp(-1, 1));
  }

  void _onPanEnd(DragEndDetails _) {
    _active = false;
    _returnOffset = Tween<Offset>(begin: _rawKnob, end: Offset.zero).animate(
      CurvedAnimation(parent: _returnAnim..reset(), curve: Curves.easeOut),
    );
    _returnAnim.forward();
    widget.onChanged(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final size   = widget.size;
    final color  = widget.color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: AppTheme.label(size: 11, color: AppTheme.textDim)),
          const SizedBox(height: 4),
        ],
        GestureDetector(
          onPanStart:  _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd:    _onPanEnd,
          child: CustomPaint(
            size: Size(size, size),
            painter: _JoystickPainter(
              knobOffset: _rawKnob,
              color:      color,
              active:     _active,
            ),
          ),
        ),
      ],
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final Offset knobOffset;
  final Color color;
  final bool active;

  _JoystickPainter({required this.knobOffset, required this.color, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final baseR = size.width / 2;
    final knobR = baseR * 0.32;

    // Outer ring track
    final trackPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), baseR, trackPaint);

    // Track border
    final borderPaint = Paint()
      ..color = color.withOpacity(active ? 0.5 : 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), baseR - 1, borderPaint);

    // Cross-hair guides
    final guidePaint = Paint()
      ..color = color.withOpacity(0.12)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(cx - baseR + 8, cy), Offset(cx + baseR - 8, cy), guidePaint);
    canvas.drawLine(Offset(cx, cy - baseR + 8), Offset(cx, cy + baseR - 8), guidePaint);

    // Knob glow
    final knobCenter = Offset(cx + knobOffset.dx, cy + knobOffset.dy);
    if (active) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(knobCenter, knobR + 6, glowPaint);
    }

    // Knob body
    final knobPaint = Paint()
      ..shader = RadialGradient(colors: [
        color.withOpacity(active ? 1.0 : 0.7),
        color.withOpacity(active ? 0.5 : 0.2),
      ]).createShader(Rect.fromCircle(center: knobCenter, radius: knobR));
    canvas.drawCircle(knobCenter, knobR, knobPaint);

    // Knob highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      knobCenter - Offset(knobR * 0.25, knobR * 0.3),
      knobR * 0.22,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(_JoystickPainter old) =>
      old.knobOffset != knobOffset || old.active != active;
}
