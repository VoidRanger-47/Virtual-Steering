import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/customization_config.dart';

void main() {
  group('CustomizationConfig Tests', () {
    test('Defaults and boundaries for sensitivity 1-900', () {
      final cfg = CustomizationConfig();
      expect(cfg.steeringSensitivity, equals(540.0));

      // Test steering sensitivity set to 1 degree
      cfg.steeringSensitivity = 1.0;
      expect(cfg.computeSteeringInt16(1.0), equals(32767));
      expect(cfg.computeSteeringInt16(-1.0), equals(-32768));
      expect(cfg.computeSteeringInt16(0.0), equals(0));

      // Test steering sensitivity set to 900 degrees with linear 1.0
      cfg.steeringSensitivity = 900.0;
      cfg.steeringLinearity = 1.0;
      expect(cfg.computeSteeringInt16(900.0), equals(32767));
      expect(cfg.computeSteeringInt16(-900.0), equals(-32768));
      expect(cfg.computeSteeringInt16(450.0), closeTo(16000, 1000));

      // With default progressive curve (1.35x), half lock is gentler (~12500) for enhanced control
      cfg.steeringLinearity = 1.35;
      expect(cfg.computeSteeringInt16(450.0), closeTo(12500, 500));
    });

    test('Pedal response curves calculate correctly', () {
      final cfg = CustomizationConfig(pedalDeadzone: 0.0);

      // Linear (1:1)
      expect(cfg.computePedalOutput(0.5, PedalCurve.linear), equals(0.5));
      expect(cfg.computePedalOutput(1.0, PedalCurve.linear), equals(1.0));
      expect(cfg.computePedalOutput(0.0, PedalCurve.linear), equals(0.0));

      // Smooth (x^1.2) - more responsive than 1.6
      final smoothVal = cfg.computePedalOutput(0.5, PedalCurve.smooth);
      expect(smoothVal, greaterThan(0.40));

      // Progressive exponential (x^1.6)
      final progVal = cfg.computePedalOutput(0.5, PedalCurve.exponential);
      expect(progVal, closeTo(0.33, 0.02));

      // Aggressive (x^2.2)
      final aggVal = cfg.computePedalOutput(0.5, PedalCurve.aggressive);
      expect(aggVal, lessThan(0.25));
    });

    test('Pedal deadzone prevents accidental touches', () {
      final cfg = CustomizationConfig(pedalDeadzone: 0.05);
      expect(cfg.computePedalOutput(0.02, PedalCurve.linear), equals(0.0));
      expect(cfg.computePedalOutput(0.05, PedalCurve.linear), equals(0.0));
      expect(cfg.computePedalOutput(0.10, PedalCurve.linear), greaterThan(0.0));
    });

    test('JSON serialization round-trip', () {
      final original = CustomizationConfig(
        wheelStyle: WheelStyle.f1Yoke,
        spokeStyle: SpokeStyle.twoSpokeYoke,
        hubStyle: HubStyle.shiftLightBar,
        steeringSensitivity: 720.0,
        pedalStyle: PedalStyle.carbonTrack,
        throttleCurve: PedalCurve.linear,
        brakeCurve: PedalCurve.aggressive,
        showClutch: true,
        wheelAccentColor: const Color(0xFFFF2A4B),
      );

      final json = original.toJson();
      final restored = CustomizationConfig.fromJson(json);

      expect(restored.wheelStyle, equals(WheelStyle.f1Yoke));
      expect(restored.spokeStyle, equals(SpokeStyle.twoSpokeYoke));
      expect(restored.hubStyle, equals(HubStyle.shiftLightBar));
      expect(restored.steeringSensitivity, equals(720.0));
      expect(restored.pedalStyle, equals(PedalStyle.carbonTrack));
      expect(restored.throttleCurve, equals(PedalCurve.linear));
      expect(restored.brakeCurve, equals(PedalCurve.aggressive));
      expect(restored.showClutch, isTrue);
      expect(restored.wheelAccentColor.value, equals(const Color(0xFFFF2A4B).value));
      expect(restored.steeringSmoothing, equals(0.20));
      expect(restored.steeringLinearity, equals(1.35));
    });

    test('Progressive steering curve provides gentle micro-control around center', () {
      final linearCfg = CustomizationConfig(
        steeringDeadzone: 0.0,
        steeringLinearity: 1.0,
        steeringSensitivity: 540.0,
      );

      final progCfg = CustomizationConfig(
        steeringDeadzone: 0.0,
        steeringLinearity: 1.35, // Default progressive
        steeringSensitivity: 540.0,
      );

      final formulaCfg = CustomizationConfig(
        steeringDeadzone: 0.0,
        steeringLinearity: 1.6, // Ultra-fine
        steeringSensitivity: 540.0,
      );

      // At 10% steering angle (54 degrees):
      final linearCenter = linearCfg.computeSteeringInt16(54.0);
      final progCenter = progCfg.computeSteeringInt16(54.0);
      final formulaCenter = formulaCfg.computeSteeringInt16(54.0);

      // Progressive curve provides gentler output than linear for fine highway/straight control
      expect(progCenter, lessThan(linearCenter));
      expect(formulaCenter, lessThan(progCenter));

      // At 100% full lock (540 degrees), all reach full 32767
      expect(linearCfg.computeSteeringInt16(540.0), equals(32767));
      expect(progCfg.computeSteeringInt16(540.0), equals(32767));
      expect(formulaCfg.computeSteeringInt16(540.0), equals(32767));
    });

    test('Steering smoothing and linearity defaults', () {
      final cfg = CustomizationConfig();
      expect(cfg.steeringSmoothing, equals(0.20));
      expect(cfg.steeringLinearity, equals(1.35));
    });

    test('Brake sensitivity multiplier delivers amplified braking', () {
      final cfg = CustomizationConfig(
        pedalDeadzone: 0.0,
        brakeSensitivityMultiplier: 2.0,
      );

      // At 50% physical slide with 2.0x sensitivity multiplier, effective brake is 100%
      final brakeOut = cfg.computePedalOutput(0.5, PedalCurve.linear, isBrake: true);
      expect(brakeOut, equals(1.0));

      // At 25% physical slide with 2.0x, output is 50%
      final halfOut = cfg.computePedalOutput(0.25, PedalCurve.linear, isBrake: true);
      expect(halfOut, equals(0.5));
    });

    test('ExtraButtonConfig and layout positions serialization round-trip', () {
      final btn = ExtraButtonConfig(
        id: 'btn_handbrake',
        label: 'HBRAKE',
        buttonMask: 1,
        isBtn2: false,
        color: const Color(0xFFFF2A4B),
        size: 60.0,
        x: 0.85,
        y: 0.35,
      );

      final original = CustomizationConfig(
        useCustomLayout: true,
        extraButtons: [btn],
        steeringSmoothing: 0.40,
        steeringLinearity: 1.6,
      );

      final json = original.toJson();
      final restored = CustomizationConfig.fromJson(json);

      expect(restored.useCustomLayout, isTrue);
      expect(restored.extraButtons.length, equals(1));
      expect(restored.extraButtons.first.id, equals('btn_handbrake'));
      expect(restored.extraButtons.first.label, equals('HBRAKE'));
      expect(restored.extraButtons.first.size, equals(60.0));
      expect(restored.extraButtons.first.x, equals(0.85));
      expect(restored.extraButtons.first.y, equals(0.35));
      expect(restored.steeringSmoothing, equals(0.40));
      expect(restored.steeringLinearity, equals(1.6));
    });
  });
}
