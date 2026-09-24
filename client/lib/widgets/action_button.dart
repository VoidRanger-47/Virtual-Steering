import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Premium glowing action button for RPG / Gamepad screens.
class ActionButton extends StatefulWidget {
  final String label;
  final Color color;
  final double size;
  final VoidCallback? onPressed;
  final VoidCallback? onReleased;
  final IconData? icon;

  const ActionButton({
    super.key,
    required this.label,
    this.color = AppTheme.neonCyan,
    this.size = 56,
    this.onPressed,
    this.onReleased,
    this.icon,
  });

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _handleDown(PointerEvent _) {
    HapticFeedback.lightImpact();
    _pulseCtrl.forward();
    setState(() => _pressed = true);
    widget.onPressed?.call();
  }

  void _handleUp(PointerEvent _) {
    _pulseCtrl.reverse();
    setState(() => _pressed = false);
    widget.onReleased?.call();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return Listener(
      onPointerDown: _handleDown,
      onPointerUp:   _handleUp,
      onPointerCancel: _handleUp,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width:  widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _pressed ? color.withOpacity(0.35) : AppTheme.bgCard,
            border: Border.all(
              color: color.withOpacity(_pressed ? 1.0 : 0.5),
              width: 1.5,
            ),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 4,
                    )
                  ]
                : [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
          ),
          child: Center(
            child: widget.icon != null
                ? Icon(widget.icon, color: _pressed ? Colors.white : color, size: widget.size * 0.4)
                : Text(
                    widget.label,
                    style: AppTheme.label(
                      size: widget.size * 0.28,
                      color: _pressed ? Colors.white : color,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
        ),
      ),
    );
  }
}

/// A larger rectangular trigger / bumper button.
class TriggerButton extends StatefulWidget {
  final String label;
  final Color color;
  final double width;
  final double height;
  final VoidCallback? onPressed;
  final VoidCallback? onReleased;

  const TriggerButton({
    super.key,
    required this.label,
    this.color = AppTheme.neonCyan,
    this.width  = 80,
    this.height = 36,
    this.onPressed,
    this.onReleased,
  });

  @override
  State<TriggerButton> createState() => _TriggerButtonState();
}

class _TriggerButtonState extends State<TriggerButton> {
  bool _pressed = false;

  void _down(PointerEvent _) {
    HapticFeedback.lightImpact();
    setState(() => _pressed = true);
    widget.onPressed?.call();
  }

  void _up(PointerEvent _) {
    setState(() => _pressed = false);
    widget.onReleased?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return Listener(
      onPointerDown: _down,
      onPointerUp:   _up,
      onPointerCancel: _up,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width:  widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: _pressed ? c.withOpacity(0.4) : AppTheme.bgCard,
          border: Border.all(color: c.withOpacity(_pressed ? 1.0 : 0.4), width: 1.5),
          boxShadow: _pressed
              ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 16, spreadRadius: 2)]
              : [BoxShadow(color: c.withOpacity(0.1), blurRadius: 6)],
        ),
        child: Center(
          child: Text(
            widget.label,
            style: AppTheme.label(size: 11, color: _pressed ? Colors.white : c),
          ),
        ),
      ),
    );
  }
}
