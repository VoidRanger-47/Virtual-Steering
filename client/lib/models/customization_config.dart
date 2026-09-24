import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WheelStyle {
  gtRacing,      // Classic GT racing with leather grips and 3 spokes
  f1Yoke,        // Formula open-top butterfly yoke with carbon texture
  driftDeepDish, // Deep-dish rally wheel with drilled slotted spokes
  cyberpunk,     // Angular futuristic neon halo design
  classicSport,  // Retro twin-spoke polished metal
}

enum SpokeStyle {
  threeSpoke,     // Classic 3-spoke (9, 3, 6 o'clock)
  twoSpokeYoke,   // Horizontal 2-spoke formula style
  fourSpokeRally, // 4-spoke X/cross rally layout
  minimalAero,    // Minimalist aerodynamic cutout spokes
}

enum HubStyle {
  digitalTelemetry, // Digital degree readout + direction indicator
  shiftLightBar,    // Formula-style progressive RPM/Angle LED bar
  minimalBadge,     // Clean racing emblem logo
}

enum PedalStyle {
  billetRally,     // CNC milled slotted aluminum pedal
  carbonTrack,     // Carbon fiber weave with alloy bevels
  perforatedSport, // Brushed alloy with anti-slip rubber studs
  minimalGlow,     // Frosted glass with progressive neon glow
}

enum PedalCurve {
  linear,      // y = x (1:1 instant direct response)
  smooth,      // y = x^1.2 (gentle low-rev modulation)
  exponential, // y = x^1.6 (progressive street car curve)
  aggressive,  // y = x^2.2 (high-torque race curve)
}

enum BrakeMode {
  progressiveSlider, // standard touch/drag modulation
  tapAndHoldStomp,   // instant 100% full brake on touch/hold, spring release on lift
}

enum GamepadLayout {
  xbox,        // Asymmetrical: Left stick top, D-Pad bottom
  playstation, // Symmetrical: D-Pad top, Left stick bottom
}

enum GamepadButtonStyle {
  xboxColors,         // Classic ABXY: A-Green, B-Red, X-Blue, Y-Yellow
  neonTheme,          // Monochrome glowing icons matching gamepad accent color
  playstationSymbols, // Iconic shapes: Triangle △, Circle ○, Cross ✕, Square □
  stealthDark,        // Sleek matte graphite with high-contrast white glyphs
}

enum TriggerStyle {
  instantDigital, // Crisp tap/release full button triggers
  analogSlider,   // Interactive touch slide modulation (0% - 100%)
}

class LayoutItemConfig {
  String id; // 'steering', 'brake', 'throttle', 'clutch', 'shifters'
  double x;  // 0.0 to 1.0 relative center
  double y;  // 0.0 to 1.0 relative center
  double scale; // 0.6 to 1.5

  LayoutItemConfig({
    required this.id,
    required this.x,
    required this.y,
    this.scale = 1.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'scale': scale,
  };

  static LayoutItemConfig fromJson(Map<String, dynamic> json) => LayoutItemConfig(
    id: json['id'] ?? '',
    x: (json['x'] as num?)?.toDouble() ?? 0.5,
    y: (json['y'] as num?)?.toDouble() ?? 0.5,
    scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
  );
}

class ExtraButtonConfig {
  String id;
  String label;
  int buttonMask; // e.g. UdpTransmitter.btnA, btnB, etc.
  bool isBtn2;    // true if on btn2 bitmask
  Color color;
  double size;    // diameter in dp (40.0 - 80.0)
  double x;       // 0.0 to 1.0
  double y;       // 0.0 to 1.0

  ExtraButtonConfig({
    required this.id,
    required this.label,
    required this.buttonMask,
    this.isBtn2 = false,
    this.color = const Color(0xFF00E5FF),
    this.size = 52.0,
    required this.x,
    required this.y,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'buttonMask': buttonMask,
    'isBtn2': isBtn2,
    'color': color.value,
    'size': size,
    'x': x,
    'y': y,
  };

  static ExtraButtonConfig fromJson(Map<String, dynamic> json) => ExtraButtonConfig(
    id: json['id'] ?? '',
    label: json['label'] ?? 'BTN',
    buttonMask: json['buttonMask'] ?? 1,
    isBtn2: json['isBtn2'] ?? false,
    color: Color(json['color'] ?? 0xFF00E5FF),
    size: (json['size'] as num?)?.toDouble() ?? 52.0,
    x: (json['x'] as num?)?.toDouble() ?? 0.5,
    y: (json['y'] as num?)?.toDouble() ?? 0.5,
  );
}

class CustomizationConfig {
  // ── Steering Wheel ──────────────────────────────────────────────────────────
  WheelStyle wheelStyle;
  SpokeStyle spokeStyle;
  HubStyle hubStyle;
  Color wheelRimColor;
  Color wheelAccentColor;
  Color wheelSpokeColor;
  Color markerColor;
  bool showMarkerStripe;
  double springReturnMs;      // 0 = no spring-back, 100-600ms
  double steeringSensitivity; // 1.0 to 900.0 degrees (default 540.0)
  double steeringDeadzone;    // 0.0 to 0.15 (fraction of max angle)
  double steeringLinearity;   // 0.5 (sensitive center) to 2.0 (fine progressive center)
  double steeringSmoothing;   // 0.0 (raw) to 0.8 (ultra smooth), default 0.20

  // ── Pedals ──────────────────────────────────────────────────────────────────
  PedalStyle pedalStyle;
  Color throttleColor;
  Color brakeColor;
  Color clutchColor;
  PedalCurve throttleCurve;
  PedalCurve brakeCurve;
  PedalCurve clutchCurve;
  BrakeMode brakeMode;                // progressiveSlider or tapAndHoldStomp
  double brakeSensitivityMultiplier;  // 1.0 to 3.0 (reaches full brake faster)
  double pedalDeadzone;               // 0.0 to 0.15 (bottom deadzone)
  bool showClutch;                    // 3-pedal manual mode
  bool hapticFeedback;
  bool invertPedalDirection;          // true = press down at bottom, false = drag up

  // ── Freeform Custom Layout & Extra Buttons ──────────────────────────────────
  bool useCustomLayout;
  Map<String, LayoutItemConfig> layoutPositions;
  List<ExtraButtonConfig> extraButtons;

  // ── Gamepad Customization ───────────────────────────────────────────────────
  Color gamepadAccentColor;
  GamepadLayout gamepadLayout;
  GamepadButtonStyle gamepadButtonStyle;
  TriggerStyle triggerStyle;
  double leftStickDeadzone;     // 0.0 to 0.25 (default 0.04)
  double leftStickSensitivity;  // 0.5 to 2.0 (default 1.0)
  double rightStickDeadzone;    // 0.0 to 0.25 (default 0.04)
  double rightStickSensitivity; // 0.5 to 2.0 (default 1.0)
  bool invertRightStickY;       // false by default
  double joystickSize;          // 90.0 to 140.0 (default 115.0)
  bool showL3R3;                // true by default (LStick / RStick clicks)
  bool showPaddles;             // false by default (M1/M2)
  String paddle1Action;         // 'LB' default
  String paddle2Action;         // 'RB' default
  bool gamepadHaptics;          // true by default
  bool swapBumpersAndTriggers;  // false by default

  CustomizationConfig({
    this.wheelStyle = WheelStyle.gtRacing,
    this.spokeStyle = SpokeStyle.threeSpoke,
    this.hubStyle = HubStyle.digitalTelemetry,
    this.wheelRimColor = const Color(0xFF1E2433),
    this.wheelAccentColor = const Color(0xFF00E5FF),
    this.wheelSpokeColor = const Color(0xFF2C3549),
    this.markerColor = const Color(0xFFFFEA00),
    this.showMarkerStripe = true,
    this.springReturnMs = 300.0,
    this.steeringSensitivity = 540.0,
    this.steeringDeadzone = 0.02,
    this.steeringLinearity = 1.35, // Default 1.35 progressive curve for straight-line micro-control
    this.steeringSmoothing = 0.20, // Default 20% anti-jitter smoothing filter
    this.pedalStyle = PedalStyle.billetRally,
    this.throttleColor = const Color(0xFF00E676),
    this.brakeColor = const Color(0xFFFF2A4B),
    this.clutchColor = const Color(0xFFFFB300),
    this.throttleCurve = PedalCurve.linear,
    this.brakeCurve = PedalCurve.linear, // Linear by default for instant strong response
    this.clutchCurve = PedalCurve.linear,
    this.brakeMode = BrakeMode.progressiveSlider,
    this.brakeSensitivityMultiplier = 1.5,
    this.pedalDeadzone = 0.02,
    this.showClutch = false,
    this.hapticFeedback = true,
    this.invertPedalDirection = false,
    this.useCustomLayout = false,
    Map<String, LayoutItemConfig>? layoutPositions,
    List<ExtraButtonConfig>? extraButtons,
    this.gamepadAccentColor = const Color(0xFFD500F9),
    this.gamepadLayout = GamepadLayout.xbox,
    this.gamepadButtonStyle = GamepadButtonStyle.xboxColors,
    this.triggerStyle = TriggerStyle.instantDigital,
    this.leftStickDeadzone = 0.04,
    this.leftStickSensitivity = 1.0,
    this.rightStickDeadzone = 0.04,
    this.rightStickSensitivity = 1.0,
    this.invertRightStickY = false,
    this.joystickSize = 115.0,
    this.showL3R3 = true,
    this.showPaddles = false,
    this.paddle1Action = 'LB',
    this.paddle2Action = 'RB',
    this.gamepadHaptics = true,
    this.swapBumpersAndTriggers = false,
  }) : layoutPositions = layoutPositions ?? _defaultLayout(),
       extraButtons = extraButtons ?? [];

  static Map<String, LayoutItemConfig> _defaultLayout() => {
    'steering': LayoutItemConfig(id: 'steering', x: 0.28, y: 0.52, scale: 1.0),
    'shifters': LayoutItemConfig(id: 'shifters', x: 0.55, y: 0.52, scale: 1.0),
    'brake':    LayoutItemConfig(id: 'brake',    x: 0.72, y: 0.54, scale: 1.0),
    'throttle': LayoutItemConfig(id: 'throttle', x: 0.88, y: 0.54, scale: 1.0),
    'clutch':   LayoutItemConfig(id: 'clutch',   x: 0.63, y: 0.54, scale: 1.0),
  };

  /// Calculates curved pedal response from raw 0.0-1.0 displacement
  double computePedalOutput(double rawDisplacement, PedalCurve curve, {bool isBrake = false}) {
    if (rawDisplacement <= pedalDeadzone) return 0.0;

    // Apply sensitivity multiplier if brake
    double effective = rawDisplacement;
    if (isBrake && brakeSensitivityMultiplier > 1.0) {
      effective = (rawDisplacement * brakeSensitivityMultiplier).clamp(0.0, 1.0);
    }

    // Normalize after deadzone
    final normalized = ((effective - pedalDeadzone) / (1.0 - pedalDeadzone)).clamp(0.0, 1.0);

    switch (curve) {
      case PedalCurve.linear:
        return normalized;
      case PedalCurve.smooth:
        return math.pow(normalized, 1.2).toDouble();
      case PedalCurve.exponential:
        return math.pow(normalized, 1.6).toDouble();
      case PedalCurve.aggressive:
        return math.pow(normalized, 2.2).toDouble();
    }
  }

  /// Calculates steering output from angle degrees (-sensitivity .. +sensitivity)
  int computeSteeringInt16(double rawDegrees) {
    if (steeringSensitivity <= 0) return 0;
    final normalized = (rawDegrees / steeringSensitivity).clamp(-1.0, 1.0);
    final absNorm = normalized.abs();

    if (absNorm <= steeringDeadzone) return 0;

    final adjusted = (absNorm - steeringDeadzone) / (1.0 - steeringDeadzone);
    final curved = math.pow(adjusted.clamp(0.0, 1.0), steeringLinearity).toDouble();

    final isPositive = normalized >= 0;
    final scale = isPositive ? 32767.0 : 32768.0;
    final rawVal = (curved * scale * (isPositive ? 1.0 : -1.0)).round();
    return rawVal.clamp(-32768, 32767);
  }

  CustomizationConfig copyWith({
    WheelStyle? wheelStyle,
    SpokeStyle? spokeStyle,
    HubStyle? hubStyle,
    Color? wheelRimColor,
    Color? wheelAccentColor,
    Color? wheelSpokeColor,
    Color? markerColor,
    bool? showMarkerStripe,
    double? springReturnMs,
    double? steeringSensitivity,
    double? steeringDeadzone,
    double? steeringLinearity,
    double? steeringSmoothing,
    PedalStyle? pedalStyle,
    Color? throttleColor,
    Color? brakeColor,
    Color? clutchColor,
    PedalCurve? throttleCurve,
    PedalCurve? brakeCurve,
    PedalCurve? clutchCurve,
    BrakeMode? brakeMode,
    double? brakeSensitivityMultiplier,
    double? pedalDeadzone,
    bool? showClutch,
    bool? hapticFeedback,
    bool? invertPedalDirection,
    bool? useCustomLayout,
    Map<String, LayoutItemConfig>? layoutPositions,
    List<ExtraButtonConfig>? extraButtons,
    Color? gamepadAccentColor,
    GamepadLayout? gamepadLayout,
    GamepadButtonStyle? gamepadButtonStyle,
    TriggerStyle? triggerStyle,
    double? leftStickDeadzone,
    double? leftStickSensitivity,
    double? rightStickDeadzone,
    double? rightStickSensitivity,
    bool? invertRightStickY,
    double? joystickSize,
    bool? showL3R3,
    bool? showPaddles,
    String? paddle1Action,
    String? paddle2Action,
    bool? gamepadHaptics,
    bool? swapBumpersAndTriggers,
  }) {
    return CustomizationConfig(
      wheelStyle: wheelStyle ?? this.wheelStyle,
      spokeStyle: spokeStyle ?? this.spokeStyle,
      hubStyle: hubStyle ?? this.hubStyle,
      wheelRimColor: wheelRimColor ?? this.wheelRimColor,
      wheelAccentColor: wheelAccentColor ?? this.wheelAccentColor,
      wheelSpokeColor: wheelSpokeColor ?? this.wheelSpokeColor,
      markerColor: markerColor ?? this.markerColor,
      showMarkerStripe: showMarkerStripe ?? this.showMarkerStripe,
      springReturnMs: springReturnMs ?? this.springReturnMs,
      steeringSensitivity: steeringSensitivity ?? this.steeringSensitivity,
      steeringDeadzone: steeringDeadzone ?? this.steeringDeadzone,
      steeringLinearity: steeringLinearity ?? this.steeringLinearity,
      steeringSmoothing: steeringSmoothing ?? this.steeringSmoothing,
      pedalStyle: pedalStyle ?? this.pedalStyle,
      throttleColor: throttleColor ?? this.throttleColor,
      brakeColor: brakeColor ?? this.brakeColor,
      clutchColor: clutchColor ?? this.clutchColor,
      throttleCurve: throttleCurve ?? this.throttleCurve,
      brakeCurve: brakeCurve ?? this.brakeCurve,
      clutchCurve: clutchCurve ?? this.clutchCurve,
      brakeMode: brakeMode ?? this.brakeMode,
      brakeSensitivityMultiplier: brakeSensitivityMultiplier ?? this.brakeSensitivityMultiplier,
      pedalDeadzone: pedalDeadzone ?? this.pedalDeadzone,
      showClutch: showClutch ?? this.showClutch,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      invertPedalDirection: invertPedalDirection ?? this.invertPedalDirection,
      useCustomLayout: useCustomLayout ?? this.useCustomLayout,
      layoutPositions: layoutPositions ?? Map.from(this.layoutPositions),
      extraButtons: extraButtons ?? List.from(this.extraButtons),
      gamepadAccentColor: gamepadAccentColor ?? this.gamepadAccentColor,
      gamepadLayout: gamepadLayout ?? this.gamepadLayout,
      gamepadButtonStyle: gamepadButtonStyle ?? this.gamepadButtonStyle,
      triggerStyle: triggerStyle ?? this.triggerStyle,
      leftStickDeadzone: leftStickDeadzone ?? this.leftStickDeadzone,
      leftStickSensitivity: leftStickSensitivity ?? this.leftStickSensitivity,
      rightStickDeadzone: rightStickDeadzone ?? this.rightStickDeadzone,
      rightStickSensitivity: rightStickSensitivity ?? this.rightStickSensitivity,
      invertRightStickY: invertRightStickY ?? this.invertRightStickY,
      joystickSize: joystickSize ?? this.joystickSize,
      showL3R3: showL3R3 ?? this.showL3R3,
      showPaddles: showPaddles ?? this.showPaddles,
      paddle1Action: paddle1Action ?? this.paddle1Action,
      paddle2Action: paddle2Action ?? this.paddle2Action,
      gamepadHaptics: gamepadHaptics ?? this.gamepadHaptics,
      swapBumpersAndTriggers: swapBumpersAndTriggers ?? this.swapBumpersAndTriggers,
    );
  }

  Map<String, dynamic> toJson() => {
    'wheelStyle': wheelStyle.index,
    'spokeStyle': spokeStyle.index,
    'hubStyle': hubStyle.index,
    'wheelRimColor': wheelRimColor.value,
    'wheelAccentColor': wheelAccentColor.value,
    'wheelSpokeColor': wheelSpokeColor.value,
    'markerColor': markerColor.value,
    'showMarkerStripe': showMarkerStripe,
    'springReturnMs': springReturnMs,
    'steeringSensitivity': steeringSensitivity,
    'steeringDeadzone': steeringDeadzone,
    'steeringLinearity': steeringLinearity,
    'steeringSmoothing': steeringSmoothing,
    'pedalStyle': pedalStyle.index,
    'throttleColor': throttleColor.value,
    'brakeColor': brakeColor.value,
    'clutchColor': clutchColor.value,
    'throttleCurve': throttleCurve.index,
    'brakeCurve': brakeCurve.index,
    'clutchCurve': clutchCurve.index,
    'brakeMode': brakeMode.index,
    'brakeSensitivityMultiplier': brakeSensitivityMultiplier,
    'pedalDeadzone': pedalDeadzone,
    'showClutch': showClutch,
    'hapticFeedback': hapticFeedback,
    'invertPedalDirection': invertPedalDirection,
    'useCustomLayout': useCustomLayout,
    'layoutPositions': layoutPositions.map((k, v) => MapEntry(k, v.toJson())),
    'extraButtons': extraButtons.map((b) => b.toJson()).toList(),
    'gamepadAccentColor': gamepadAccentColor.value,
    'gamepadLayout': gamepadLayout.index,
    'gamepadButtonStyle': gamepadButtonStyle.index,
    'triggerStyle': triggerStyle.index,
    'leftStickDeadzone': leftStickDeadzone,
    'leftStickSensitivity': leftStickSensitivity,
    'rightStickDeadzone': rightStickDeadzone,
    'rightStickSensitivity': rightStickSensitivity,
    'invertRightStickY': invertRightStickY,
    'joystickSize': joystickSize,
    'showL3R3': showL3R3,
    'showPaddles': showPaddles,
    'paddle1Action': paddle1Action,
    'paddle2Action': paddle2Action,
    'gamepadHaptics': gamepadHaptics,
    'swapBumpersAndTriggers': swapBumpersAndTriggers,
  };

  static CustomizationConfig fromJson(Map<String, dynamic> json) {
    Map<String, LayoutItemConfig> layout = _defaultLayout();
    if (json['layoutPositions'] is Map) {
      final raw = json['layoutPositions'] as Map;
      layout = raw.map((k, v) => MapEntry(k.toString(), LayoutItemConfig.fromJson(Map<String, dynamic>.from(v))));
    }

    List<ExtraButtonConfig> buttons = [];
    if (json['extraButtons'] is List) {
      final raw = json['extraButtons'] as List;
      buttons = raw.map((b) => ExtraButtonConfig.fromJson(Map<String, dynamic>.from(b))).toList();
    }

    return CustomizationConfig(
      wheelStyle: WheelStyle.values[(json['wheelStyle'] ?? 0).clamp(0, WheelStyle.values.length - 1)],
      spokeStyle: SpokeStyle.values[(json['spokeStyle'] ?? 0).clamp(0, SpokeStyle.values.length - 1)],
      hubStyle: HubStyle.values[(json['hubStyle'] ?? 0).clamp(0, HubStyle.values.length - 1)],
      wheelRimColor: Color(json['wheelRimColor'] ?? 0xFF1E2433),
      wheelAccentColor: Color(json['wheelAccentColor'] ?? 0xFF00E5FF),
      wheelSpokeColor: Color(json['wheelSpokeColor'] ?? 0xFF2C3549),
      markerColor: Color(json['markerColor'] ?? 0xFFFFEA00),
      showMarkerStripe: json['showMarkerStripe'] ?? true,
      springReturnMs: (json['springReturnMs'] as num?)?.toDouble() ?? 300.0,
      steeringSensitivity: (json['steeringSensitivity'] as num?)?.toDouble() ?? 540.0,
      steeringDeadzone: (json['steeringDeadzone'] as num?)?.toDouble() ?? 0.02,
      steeringLinearity: (json['steeringLinearity'] as num?)?.toDouble() ?? 1.35,
      steeringSmoothing: (json['steeringSmoothing'] as num?)?.toDouble() ?? 0.20,
      pedalStyle: PedalStyle.values[(json['pedalStyle'] ?? 0).clamp(0, PedalStyle.values.length - 1)],
      throttleColor: Color(json['throttleColor'] ?? 0xFF00E676),
      brakeColor: Color(json['brakeColor'] ?? 0xFFFF2A4B),
      clutchColor: Color(json['clutchColor'] ?? 0xFFFFB300),
      throttleCurve: PedalCurve.values[(json['throttleCurve'] ?? 0).clamp(0, PedalCurve.values.length - 1)],
      brakeCurve: PedalCurve.values[(json['brakeCurve'] ?? 0).clamp(0, PedalCurve.values.length - 1)], // Default linear
      clutchCurve: PedalCurve.values[(json['clutchCurve'] ?? 0).clamp(0, PedalCurve.values.length - 1)],
      brakeMode: BrakeMode.values[(json['brakeMode'] ?? 0).clamp(0, BrakeMode.values.length - 1)],
      brakeSensitivityMultiplier: (json['brakeSensitivityMultiplier'] as num?)?.toDouble() ?? 1.5,
      pedalDeadzone: (json['pedalDeadzone'] as num?)?.toDouble() ?? 0.02,
      showClutch: json['showClutch'] ?? false,
      hapticFeedback: json['hapticFeedback'] ?? true,
      invertPedalDirection: json['invertPedalDirection'] ?? false,
      useCustomLayout: json['useCustomLayout'] ?? false,
      layoutPositions: layout,
      extraButtons: buttons,
      gamepadAccentColor: Color(json['gamepadAccentColor'] ?? 0xFFD500F9),
      gamepadLayout: GamepadLayout.values[(json['gamepadLayout'] ?? 0).clamp(0, GamepadLayout.values.length - 1)],
      gamepadButtonStyle: GamepadButtonStyle.values[(json['gamepadButtonStyle'] ?? 0).clamp(0, GamepadButtonStyle.values.length - 1)],
      triggerStyle: TriggerStyle.values[(json['triggerStyle'] ?? 0).clamp(0, TriggerStyle.values.length - 1)],
      leftStickDeadzone: (json['leftStickDeadzone'] as num?)?.toDouble() ?? 0.04,
      leftStickSensitivity: (json['leftStickSensitivity'] as num?)?.toDouble() ?? 1.0,
      rightStickDeadzone: (json['rightStickDeadzone'] as num?)?.toDouble() ?? 0.04,
      rightStickSensitivity: (json['rightStickSensitivity'] as num?)?.toDouble() ?? 1.0,
      invertRightStickY: json['invertRightStickY'] ?? false,
      joystickSize: (json['joystickSize'] as num?)?.toDouble() ?? 115.0,
      showL3R3: json['showL3R3'] ?? true,
      showPaddles: json['showPaddles'] ?? false,
      paddle1Action: json['paddle1Action'] ?? 'LB',
      paddle2Action: json['paddle2Action'] ?? 'RB',
      gamepadHaptics: json['gamepadHaptics'] ?? true,
      swapBumpersAndTriggers: json['swapBumpersAndTriggers'] ?? false,
    );
  }

  static const String _prefKey = 'vctrl_customization_config';

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(toJson()));
  }

  static Future<CustomizationConfig> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_prefKey);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is Map<String, dynamic>) {
          return CustomizationConfig.fromJson(decoded);
        }
      }
    } catch (_) {}
    return CustomizationConfig();
  }
}
