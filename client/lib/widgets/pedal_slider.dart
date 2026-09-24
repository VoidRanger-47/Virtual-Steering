import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/customization_config.dart';

enum PedalType { brake, throttle, clutch }

/// Interactive motorsport pedal with:
/// - Isolated multi-touch tracking (prevents multi-finger interference)
/// - Configurable response curves (Linear, Smooth, Progressive, Aggressive)
/// - Customizable styles (Billet Rally, Carbon Track, Perforated Sport, Minimal Glow)
/// - Customizable colors, deadzone, and responsive layout that never overflows
class PedalSliderWidget extends StatefulWidget {
  final PedalType pedalType;
  final CustomizationConfig config;
  final ValueChanged<int> onValueChanged; // 0 to 65535
  final ValueChanged<double>? onPercentageChanged; // 0.0 to 100.0

  const PedalSliderWidget({
    super.key,
    required this.pedalType,
    required this.config,
    required this.onValueChanged,
    this.onPercentageChanged,
  });

  @override
  State<PedalSliderWidget> createState() => _PedalSliderWidgetState();
}

class _PedalSliderWidgetState extends State<PedalSliderWidget>
    with SingleTickerProviderStateMixin {
  double _rawInput = 0.0; // Linear 0.0 to 1.0
  double _curvedOutput = 0.0; // After curve & deadzone
  bool _isPressed = false;
  int? _activePointerId;

  late AnimationController _resetController;
  late Animation<double> _resetAnimation;
  double _releaseStartValue = 0.0;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );

    _resetAnimation = CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeOutQuad,
    );

    _resetController.addListener(() {
      if (!_isPressed) {
        final currentLinear = _releaseStartValue * (1.0 - _resetAnimation.value);
        _applyDisplacement(currentLinear);
      }
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  PedalCurve get _activeCurve {
    switch (widget.pedalType) {
      case PedalType.throttle:
        return widget.config.throttleCurve;
      case PedalType.brake:
        return widget.config.brakeCurve;
      case PedalType.clutch:
        return widget.config.clutchCurve;
    }
  }

  Color get _primaryColor {
    switch (widget.pedalType) {
      case PedalType.throttle:
        return widget.config.throttleColor;
      case PedalType.brake:
        return widget.config.brakeColor;
      case PedalType.clutch:
        return widget.config.clutchColor;
    }
  }

  String get _pedalTitle {
    switch (widget.pedalType) {
      case PedalType.throttle:
        return 'THROTTLE';
      case PedalType.brake:
        return 'BRAKE';
      case PedalType.clutch:
        return 'CLUTCH';
    }
  }

  IconData get _pedalIcon {
    switch (widget.pedalType) {
      case PedalType.throttle:
        return Icons.speed_rounded;
      case PedalType.brake:
        return Icons.pause_circle_filled_rounded;
      case PedalType.clutch:
        return Icons.alt_route_rounded;
    }
  }

  void _applyDisplacement(double linearValue) {
    final clampedLinear = linearValue.clamp(0.0, 1.0);
    final isBrake = widget.pedalType == PedalType.brake;
    final output = widget.config.computePedalOutput(clampedLinear, _activeCurve, isBrake: isBrake);

    setState(() {
      _rawInput = clampedLinear;
      _curvedOutput = output;
    });

    final uint16Value = (output * 65535.0).round().clamp(0, 65535);
    widget.onValueChanged(uint16Value);
    widget.onPercentageChanged?.call(output * 100.0);
  }

  void _handleTouch(Offset localPosition, double totalHeight) {
    if (totalHeight <= 0) return;
    if (widget.pedalType == PedalType.brake &&
        widget.config.brakeMode == BrakeMode.tapAndHoldStomp) {
      _applyDisplacement(1.0);
      return;
    }
    double raw;
    if (widget.config.invertPedalDirection) {
      raw = (localPosition.dy / totalHeight);
    } else {
      raw = 1.0 - (localPosition.dy / totalHeight);
    }
    _applyDisplacement(raw);
  }

  void _onPointerDown(PointerDownEvent event, double totalHeight) {
    // Isolate active pointer so other touches don't disrupt
    if (_activePointerId == null) {
      _activePointerId = event.pointer;
      _resetController.stop();
      _isPressed = true;
      _handleTouch(event.localPosition, totalHeight);
      if (widget.config.hapticFeedback) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event, double totalHeight) {
    if (_isPressed && event.pointer == _activePointerId) {
      _handleTouch(event.localPosition, totalHeight);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer == _activePointerId) {
      _activePointerId = null;
      _isPressed = false;
      _releaseStartValue = _rawInput;
      _resetController.forward(from: 0.0);
      if (widget.config.hapticFeedback) {
        HapticFeedback.lightImpact();
      }
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _activePointerId) {
      _activePointerId = null;
      _isPressed = false;
      _releaseStartValue = _rawInput;
      _resetController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = _primaryColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final width = constraints.maxWidth;

        return Listener(
          onPointerDown: (e) => _onPointerDown(e, height),
          onPointerMove: (e) => _onPointerMove(e, height),
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF0F1219),
              border: Border.all(
                color: _isPressed
                    ? primaryColor.withOpacity(0.9)
                    : const Color(0xFF222938),
                width: _isPressed ? 2.0 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                if (_isPressed)
                  BoxShadow(
                    color: primaryColor.withOpacity(0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // 1. Dynamic progressive gauge fill
                  FractionallySizedBox(
                    heightFactor: _curvedOutput.clamp(0.0, 1.0),
                    widthFactor: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            primaryColor.withOpacity(0.25),
                            primaryColor.withOpacity(0.85),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.6),
                            blurRadius: 14,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Custom Style Texture Painter
                  CustomPaint(
                    size: Size(width, height),
                    painter: _PedalCustomPainter(
                      style: widget.config.pedalStyle,
                      primaryColor: primaryColor,
                      isPressed: _isPressed,
                      fillPercent: _curvedOutput,
                    ),
                  ),

                  // 3. Responsive Telemetry & HUD Info (FittedBox to prevent any overflow)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top: Percentage pill badge
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _isPressed
                                      ? primaryColor.withOpacity(0.8)
                                      : Colors.white12,
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                '${(_curvedOutput * 100.0).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _isPressed ? primaryColor : Colors.white70,
                                ),
                              ),
                            ),
                          ),

                          // Center: Subtle Icon (Auto scales down)
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Icon(
                                _pedalIcon,
                                color: _isPressed
                                    ? Colors.white.withOpacity(0.9)
                                    : Colors.white24,
                                size: math.min(width * 0.35, 32.0),
                              ),
                            ),
                          ),

                          // Bottom: Label and curve name
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _pedalTitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0,
                                    color: _isPressed ? Colors.white : Colors.white60,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _activeCurve.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                    color: primaryColor.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Dynamic custom painter rendering the selected pedal faceplate style
class _PedalCustomPainter extends CustomPainter {
  final PedalStyle style;
  final Color primaryColor;
  final bool isPressed;
  final double fillPercent;

  _PedalCustomPainter({
    required this.style,
    required this.primaryColor,
    required this.isPressed,
    required this.fillPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case PedalStyle.billetRally:
        _paintBilletRally(canvas, size);
        break;
      case PedalStyle.carbonTrack:
        _paintCarbonTrack(canvas, size);
        break;
      case PedalStyle.perforatedSport:
        _paintPerforatedSport(canvas, size);
        break;
      case PedalStyle.minimalGlow:
        _paintMinimalGlow(canvas, size);
        break;
    }
  }

  void _paintBilletRally(Canvas canvas, Size size) {
    final slotPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final ribHighlight = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const slotCount = 7;
    final slotHeight = size.height * 0.022;
    final slotWidth = size.width * 0.6;
    final spacing = size.height / (slotCount + 1);

    for (int i = 1; i <= slotCount; i++) {
      final y = spacing * i;
      final slotRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, y),
          width: slotWidth,
          height: slotHeight,
        ),
        const Radius.circular(3.0),
      );
      canvas.drawRRect(slotRect, slotPaint);
      canvas.drawRRect(slotRect, ribHighlight);
    }
  }

  void _paintCarbonTrack(Canvas canvas, Size size) {
    // Carbon fiber diagonal weave simulation
    final weavePaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 2.0;

    for (double i = -size.height; i < size.width + size.height; i += 12.0) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        weavePaint,
      );
    }

    // Outer alloy border accent
    final borderPaint = Paint()
      ..color = isPressed ? primaryColor.withOpacity(0.4) : Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
        const Radius.circular(10),
      ),
      borderPaint,
    );
  }

  void _paintPerforatedSport(Canvas canvas, Size size) {
    // Rubber anti-slip traction studs
    final studBackPaint = Paint()
      ..color = const Color(0xFF080A0E)
      ..style = PaintingStyle.fill;

    final studHighlight = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const rows = 6;
    const cols = 3;
    final rowSpacing = size.height / (rows + 1);
    final colSpacing = size.width / (cols + 1);
    final radius = math.min(size.width * 0.07, 7.0);

    for (int r = 1; r <= rows; r++) {
      for (int c = 1; c <= cols; c++) {
        final pos = Offset(colSpacing * c, rowSpacing * r);
        canvas.drawCircle(pos, radius, studBackPaint);
        canvas.drawCircle(pos, radius, studHighlight);
      }
    }
  }

  void _paintMinimalGlow(Canvas canvas, Size size) {
    // Vertical laser guideline in center
    final linePaint = Paint()
      ..color = isPressed ? primaryColor.withOpacity(0.3) : Colors.white.withOpacity(0.05)
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(size.width / 2, 20),
      Offset(size.width / 2, size.height - 20),
      linePaint,
    );

    // Lateral hash markers at 25%, 50%, 75%
    for (final pct in [0.25, 0.50, 0.75]) {
      final y = size.height * (1.0 - pct);
      canvas.drawLine(
        Offset(size.width * 0.35, y),
        Offset(size.width * 0.65, y),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PedalCustomPainter old) {
    return old.style != style ||
        old.primaryColor != primaryColor ||
        old.isPressed != isPressed ||
        old.fillPercent != fillPercent;
  }
}
