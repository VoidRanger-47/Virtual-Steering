import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/customization_config.dart';

/// Customizable Motorsport Steering Wheel with:
/// - Angular drag tracking via atan2(dy, dx)
/// - Sensitivity range 1° to 900° (or beyond)
/// - Multi-style visuals: GT Racing, F1 Yoke, Drift Deep Dish, Cyberpunk, Classic Sport
/// - Multiple spoke styles and hub displays (Digital HUD, Shift-Light LEDs, Minimal Badge)
/// - Configurable spring-back physics, deadzone, linearity, and custom colors
class SteeringWheelWidget extends StatefulWidget {
  final CustomizationConfig config;
  final ValueChanged<int> onSteerChanged; // -32768 to 32767
  final ValueChanged<double>? onAngleChanged; // raw degrees

  const SteeringWheelWidget({
    super.key,
    required this.config,
    required this.onSteerChanged,
    this.onAngleChanged,
  });

  @override
  State<SteeringWheelWidget> createState() => _SteeringWheelWidgetState();
}

class _SteeringWheelWidgetState extends State<SteeringWheelWidget>
    with SingleTickerProviderStateMixin {
  double _currentAngle = 0.0;
  double _previousTouchAngle = 0.0;
  bool _isDragging = false;

  late AnimationController _springController;
  late Animation<double> _springAnimation;
  double _springStartAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _initSpringController();
  }

  void _initSpringController() {
    final durationMs = widget.config.springReturnMs.clamp(50.0, 1000.0).toInt();
    _springController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    _springAnimation = CurvedAnimation(
      parent: _springController,
      curve: Curves.easeOutCubic,
    );

    _springController.addListener(() {
      if (!_isDragging && widget.config.springReturnMs > 0) {
        final newAngle = _springStartAngle * (1.0 - _springAnimation.value);
        _updateAngle(newAngle);
      }
    });
  }

  @override
  void didUpdateWidget(covariant SteeringWheelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.springReturnMs != widget.config.springReturnMs) {
      _springController.duration = Duration(
        milliseconds: widget.config.springReturnMs.clamp(50.0, 1000.0).toInt(),
      );
    }
    // Clamp current angle if sensitivity changed
    if (_currentAngle.abs() > widget.config.steeringSensitivity) {
      _updateAngle(_currentAngle.clamp(
        -widget.config.steeringSensitivity,
        widget.config.steeringSensitivity,
      ));
    }
  }

  double _lastSign = 0.0;

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _updateAngle(double angle, {bool smooth = false}) {
    final maxAngle = widget.config.steeringSensitivity;
    double target = angle.clamp(-maxAngle, maxAngle);

    // Soft magnetic center detent (±0.75° soft pull for effortless straight-line stability)
    if (target.abs() < 0.75) {
      target = 0.0;
    }

    // Zero-crossing haptic detent tick
    if (widget.config.hapticFeedback && _isDragging) {
      final currentSign = target > 0.8 ? 1.0 : (target < -0.8 ? -1.0 : 0.0);
      if (_lastSign != 0.0 && currentSign != 0.0 && _lastSign != currentSign) {
        HapticFeedback.selectionClick();
      }
      if (currentSign != 0.0) {
        _lastSign = currentSign;
      }
    }

    double finalAngle = target;
    if (smooth && widget.config.steeringSmoothing > 0.0) {
      final alpha = (1.0 - widget.config.steeringSmoothing).clamp(0.15, 1.0);
      finalAngle = _currentAngle + (target - _currentAngle) * alpha;
    }

    setState(() {
      _currentAngle = finalAngle;
    });

    final int16Value = widget.config.computeSteeringInt16(finalAngle);
    widget.onSteerChanged(int16Value);
    widget.onAngleChanged?.call(finalAngle);
  }

  void _onPanStart(DragStartDetails details, Size size) {
    _springController.stop();
    _isDragging = true;

    final center = Offset(size.width / 2, size.height / 2);
    final touchPos = details.localPosition;
    _previousTouchAngle = math.atan2(touchPos.dy - center.dy, touchPos.dx - center.dx);
    _lastSign = _currentAngle > 0.8 ? 1.0 : (_currentAngle < -0.8 ? -1.0 : 0.0);

    if (widget.config.hapticFeedback) {
      HapticFeedback.selectionClick();
    }
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (!_isDragging) return;

    final center = Offset(size.width / 2, size.height / 2);
    final touchPos = details.localPosition;
    final dx = touchPos.dx - center.dx;
    final dy = touchPos.dy - center.dy;
    final touchDist = math.sqrt(dx * dx + dy * dy);
    final hubRadius = (size.width * 0.32) / 2.0;

    // Guard against touches deep inside the center hub causing chaotic 180° spins
    if (touchDist < hubRadius * 0.4) {
      return;
    }

    final touchAngle = math.atan2(dy, dx);

    var delta = touchAngle - _previousTouchAngle;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;

    var deltaDegrees = delta * (180.0 / math.pi);

    // Attenuate delta if touch is near the inner hub boundary
    if (touchDist < hubRadius) {
      final factor = (touchDist - hubRadius * 0.4) / (hubRadius * 0.6);
      deltaDegrees *= factor.clamp(0.0, 1.0);
    }

    // Clamp radical single-frame jumps (>60° per frame) to prevent erratic glitching
    if (deltaDegrees.abs() > 60.0) {
      deltaDegrees = deltaDegrees.clamp(-60.0, 60.0);
    }

    _previousTouchAngle = touchAngle;

    _updateAngle(_currentAngle + deltaDegrees, smooth: true);
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
    if (widget.config.springReturnMs > 0) {
      _springStartAngle = _currentAngle;
      _springController.forward(from: 0.0);
    }
    if (widget.config.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
  }

  void _onPanCancel() {
    _isDragging = false;
    if (widget.config.springReturnMs > 0) {
      _springStartAngle = _currentAngle;
      _springController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxAngle = widget.config.steeringSensitivity;
    final accent = widget.config.wheelAccentColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dimension = math.min(constraints.maxWidth, constraints.maxHeight);
        final size = Size(dimension, dimension);

        return GestureDetector(
          onPanStart: (d) => _onPanStart(d, size),
          onPanUpdate: (d) => _onPanUpdate(d, size),
          onPanEnd: _onPanEnd,
          onPanCancel: _onPanCancel,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: dimension,
            height: dimension,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Rotating Wheel Painter
                CustomPaint(
                  size: size,
                  painter: _WheelPainter(
                    angleDegrees: _currentAngle,
                    maxAngleDegrees: maxAngle,
                    isDragging: _isDragging,
                    config: widget.config,
                  ),
                ),

                // 2. Center Hub Display
                _buildCenterHub(dimension, accent),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCenterHub(double dimension, Color accent) {
    final hubSize = dimension * 0.32;
    final maxAngle = widget.config.steeringSensitivity;
    final anglePct = (_currentAngle.abs() / maxAngle).clamp(0.0, 1.0);

    return Container(
      width: hubSize,
      height: hubSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            widget.config.wheelRimColor.withOpacity(0.95),
            const Color(0xFF0A0C12),
          ],
        ),
        border: Border.all(
          color: _isDragging ? accent.withOpacity(0.8) : const Color(0xFF2C3549),
          width: _isDragging ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.7),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          if (_isDragging)
            BoxShadow(
              color: accent.withOpacity(0.3),
              blurRadius: 16,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildHubContent(accent, anglePct),
          ),
        ),
      ),
    );
  }

  Widget _buildHubContent(Color accent, double anglePct) {
    switch (widget.config.hubStyle) {
      case HubStyle.digitalTelemetry:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_currentAngle.abs().round()}°',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: anglePct >= 0.95 ? const Color(0xFFFF3D57) : accent,
                shadows: [
                  Shadow(color: accent.withOpacity(0.5), blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _currentAngle > 1.0
                  ? '▶ RIGHT'
                  : (_currentAngle < -1.0 ? '◀ LEFT' : '● CENTER'),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: _currentAngle.abs() > 1.0 ? Colors.white : Colors.white54,
              ),
            ),
          ],
        );

      case HubStyle.shiftLightBar:
        // Progressive Formula LED shift lights
        const totalLeds = 7;
        final litLeds = (anglePct * totalLeds).round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(totalLeds, (i) {
                final isLit = i < litLeds;
                final ledColor = i < 3
                    ? const Color(0xFF00E676)
                    : (i < 5 ? const Color(0xFFFFEA00) : const Color(0xFFFF1744));
                return Container(
                  width: 5,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: isLit ? ledColor : Colors.white12,
                    boxShadow: isLit
                        ? [BoxShadow(color: ledColor.withOpacity(0.8), blurRadius: 6)]
                        : [],
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Text(
              '${_currentAngle.abs().round()}°',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ],
        );

      case HubStyle.minimalBadge:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, size: 24, color: accent),
            const SizedBox(height: 2),
            Text(
              'V-RACE',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: accent,
              ),
            ),
          ],
        );
    }
  }
}

/// Dynamic steering wheel painter adapting to wheel style, spokes, colors, and markers
class _WheelPainter extends CustomPainter {
  final double angleDegrees;
  final double maxAngleDegrees;
  final bool isDragging;
  final CustomizationConfig config;

  _WheelPainter({
    required this.angleDegrees,
    required this.maxAngleDegrees,
    required this.isDragging,
    required this.config,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final angleRad = angleDegrees * (math.pi / 180.0);

    // 1. Static Outer Progress Arc (Rotation Range Indicator)
    _paintOuterTravelArc(canvas, center, radius);

    // 2. Rotate Canvas for Wheel Body
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angleRad);

    // 3. Draw Rim according to WheelStyle
    _paintWheelRim(canvas, radius);

    // 4. Draw Spokes according to SpokeStyle
    _paintSpokes(canvas, radius);

    // 5. Draw 12 O'Clock Marker Stripe
    if (config.showMarkerStripe && config.wheelStyle != WheelStyle.f1Yoke) {
      _paintMarkerStripe(canvas, radius);
    }

    // 6. Draw Grips & Textures
    _paintGrips(canvas, radius);

    canvas.restore();
  }

  void _paintOuterTravelArc(Canvas canvas, Offset center, double radius) {
    final trackPaint = Paint()
      ..color = const Color(0xFF141822)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(center, radius + 5, trackPaint);

    final progress = (angleDegrees / maxAngleDegrees).clamp(-1.0, 1.0);
    if (progress.abs() > 0.005) {
      final sweepPaint = Paint()
        ..color = config.wheelAccentColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.0);

      const startAngle = -math.pi / 2;
      final sweepAngle = progress * math.pi * 0.95;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + 5),
        startAngle,
        sweepAngle,
        false,
        sweepPaint,
      );
    }
  }

  void _paintWheelRim(Canvas canvas, double radius) {
    final rimColor = config.wheelRimColor;

    switch (config.wheelStyle) {
      case WheelStyle.f1Yoke:
        // Formula butterfly yoke: open top & bottom cutouts
        final yokePaint = Paint()
          ..shader = RadialGradient(
            colors: [rimColor.withOpacity(0.9), const Color(0xFF0F1218)],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius))
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.28
          ..strokeCap = StrokeCap.round;

        // Left grip arc
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: radius * 0.85),
          math.pi * 0.65,
          math.pi * 0.70,
          false,
          yokePaint,
        );
        // Right grip arc
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: radius * 0.85),
          -math.pi * 0.35,
          math.pi * 0.70,
          false,
          yokePaint,
        );
        break;

      case WheelStyle.cyberpunk:
        // Angular sci-fi polygon halo
        final haloPaint = Paint()
          ..color = config.wheelAccentColor.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0;
        canvas.drawCircle(Offset.zero, radius, haloPaint);

        final rimPaint = Paint()
          ..color = rimColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.20;
        canvas.drawCircle(Offset.zero, radius * 0.88, rimPaint);
        break;

      case WheelStyle.driftDeepDish:
        // Deep dish rally wheel with recessed center
        final rimPaint = Paint()
          ..shader = RadialGradient(
            colors: [rimColor, const Color(0xFF0B0D13)],
            stops: const [0.7, 1.0],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius))
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.24;
        canvas.drawCircle(Offset.zero, radius * 0.87, rimPaint);
        break;

      case WheelStyle.classicSport:
        // Dual-line classic sports steering wheel
        final outerRim = Paint()
          ..color = const Color(0xFF3B2A1D) // Classic mahogany / sport leather
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.18;
        canvas.drawCircle(Offset.zero, radius * 0.89, outerRim);

        final alloyRing = Paint()
          ..color = Colors.white.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(Offset.zero, radius * 0.80, alloyRing);
        break;

      case WheelStyle.gtRacing:
      default:
        // Heavy contour GT motorsport rim
        final shadowPaint = Paint()
          ..color = Colors.black.withOpacity(0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
        canvas.drawCircle(Offset.zero, radius, shadowPaint);

        final rimPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              rimColor.withOpacity(0.95),
              const Color(0xFF131722),
              const Color(0xFF090B0F),
            ],
            stops: const [0.75, 0.90, 1.0],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius))
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.22;
        canvas.drawCircle(Offset.zero, radius * 0.88, rimPaint);

        final innerLine = Paint()
          ..color = Colors.white.withOpacity(0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(Offset.zero, radius * 0.77, innerLine);
        break;
    }
  }

  void _paintSpokes(Canvas canvas, double radius) {
    final spokePaint = Paint()
      ..shader = LinearGradient(
        colors: [config.wheelSpokeColor, const Color(0xFF151922)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius))
      ..style = PaintingStyle.fill;

    final spokeH = radius * 0.16;

    switch (config.spokeStyle) {
      case SpokeStyle.twoSpokeYoke:
        // Left & Right Horizontal Spokes
        final leftPath = Path()
          ..moveTo(-radius * 0.22, -spokeH * 0.6)
          ..lineTo(-radius * 0.78, -spokeH * 0.8)
          ..lineTo(-radius * 0.78, spokeH * 0.8)
          ..lineTo(-radius * 0.22, spokeH * 0.6)
          ..close();
        final rightPath = Path()
          ..moveTo(radius * 0.22, -spokeH * 0.6)
          ..lineTo(radius * 0.78, -spokeH * 0.8)
          ..lineTo(radius * 0.78, spokeH * 0.8)
          ..lineTo(radius * 0.22, spokeH * 0.6)
          ..close();
        canvas.drawPath(leftPath, spokePaint);
        canvas.drawPath(rightPath, spokePaint);
        break;

      case SpokeStyle.fourSpokeRally:
        // X-pattern 4-spoke
        for (final angle in [0.75, 2.35, -0.75, -2.35]) {
          canvas.save();
          canvas.rotate(angle);
          final path = Path()
            ..moveTo(-spokeH * 0.4, radius * 0.2)
            ..lineTo(-spokeH * 0.5, radius * 0.76)
            ..lineTo(spokeH * 0.5, radius * 0.76)
            ..lineTo(spokeH * 0.4, radius * 0.2)
            ..close();
          canvas.drawPath(path, spokePaint);
          canvas.restore();
        }
        break;

      case SpokeStyle.minimalAero:
        // Sleek aerodynamic 3-blade design
        for (final angle in [math.pi * 0.5, math.pi * 1.15, -math.pi * 0.15]) {
          canvas.save();
          canvas.rotate(angle);
          final path = Path()
            ..moveTo(-spokeH * 0.3, radius * 0.2)
            ..lineTo(-spokeH * 0.2, radius * 0.77)
            ..lineTo(spokeH * 0.2, radius * 0.77)
            ..lineTo(spokeH * 0.3, radius * 0.2)
            ..close();
          canvas.drawPath(path, spokePaint);
          canvas.restore();
        }
        break;

      case SpokeStyle.threeSpoke:
      default:
        // 3-Spoke GT (Left, Right, Bottom)
        final leftPath = Path()
          ..moveTo(-radius * 0.22, -spokeH * 0.5)
          ..lineTo(-radius * 0.77, -spokeH * 0.7)
          ..lineTo(-radius * 0.77, spokeH * 0.7)
          ..lineTo(-radius * 0.22, spokeH * 0.5)
          ..close();
        final rightPath = Path()
          ..moveTo(radius * 0.22, -spokeH * 0.5)
          ..lineTo(radius * 0.77, -spokeH * 0.7)
          ..lineTo(radius * 0.77, spokeH * 0.7)
          ..lineTo(radius * 0.22, spokeH * 0.5)
          ..close();
        final botPath = Path()
          ..moveTo(-spokeH * 0.5, radius * 0.22)
          ..lineTo(-spokeH * 0.7, radius * 0.77)
          ..lineTo(spokeH * 0.7, radius * 0.77)
          ..lineTo(spokeH * 0.5, radius * 0.22)
          ..close();

        canvas.drawPath(leftPath, spokePaint);
        canvas.drawPath(rightPath, spokePaint);
        canvas.drawPath(botPath, spokePaint);

        // Lightweight drill holes in spokes
        final holePaint = Paint()
          ..color = const Color(0xFF0A0C12)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(-radius * 0.52, 0), spokeH * 0.22, holePaint);
        canvas.drawCircle(Offset(radius * 0.52, 0), spokeH * 0.22, holePaint);
        canvas.drawCircle(Offset(0, radius * 0.52), spokeH * 0.22, holePaint);
        break;
    }
  }

  void _paintMarkerStripe(Canvas canvas, double radius) {
    final stripePaint = Paint()
      ..shader = LinearGradient(
        colors: [config.markerColor, config.markerColor.withOpacity(0.75)],
      ).createShader(
        Rect.fromCenter(
          center: Offset(0, -radius * 0.88),
          width: radius * 0.08,
          height: radius * 0.22,
        ),
      )
      ..style = PaintingStyle.fill;

    final stripeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -radius * 0.88),
        width: radius * 0.07,
        height: radius * 0.20,
      ),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(stripeRect, stripePaint);
  }

  void _paintGrips(Canvas canvas, double radius) {
    // Thumb grip ribs at 9:15 and 2:45
    final gripPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (var i = -2; i <= 2; i++) {
      canvas.drawLine(
        Offset(-radius * 0.96, i * 7.5),
        Offset(-radius * 0.80, i * 7.5),
        gripPaint,
      );
      canvas.drawLine(
        Offset(radius * 0.80, i * 7.5),
        Offset(radius * 0.96, i * 7.5),
        gripPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) {
    return old.angleDegrees != angleDegrees ||
        old.isDragging != isDragging ||
        old.maxAngleDegrees != maxAngleDegrees ||
        old.config != config;
  }
}
