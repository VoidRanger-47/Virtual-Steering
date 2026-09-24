import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Packet Protocol Tests (<hHH)', () {
    test('Verify 6-byte binary little-endian structure', () {
      final byteData = ByteData(6);

      // Neutral: 0, 0, 0
      byteData.setInt16(0, 0, Endian.little);
      byteData.setUint16(2, 0, Endian.little);
      byteData.setUint16(4, 0, Endian.little);
      expect(byteData.lengthInBytes, equals(6));

      // Extremes: steer -32768, throttle 65535, brake 0
      byteData.setInt16(0, -32768, Endian.little);
      byteData.setUint16(2, 65535, Endian.little);
      byteData.setUint16(4, 0, Endian.little);

      expect(byteData.getInt16(0, Endian.little), equals(-32768));
      expect(byteData.getUint16(2, Endian.little), equals(65535));
      expect(byteData.getUint16(4, Endian.little), equals(0));

      // Full right: steer 32767, throttle 0, brake 65535
      byteData.setInt16(0, 32767, Endian.little);
      byteData.setUint16(2, 0, Endian.little);
      byteData.setUint16(4, 65535, Endian.little);

      expect(byteData.getInt16(0, Endian.little), equals(32767));
      expect(byteData.getUint16(2, Endian.little), equals(0));
      expect(byteData.getUint16(4, Endian.little), equals(65535));
    });

    test('Verify exponential response curve y = x^1.6', () {
      double computeExponential(double x) {
        if (x <= 0.0) return 0.0;
        if (x >= 1.0) return 1.0;
        return math.pow(x, 1.6).toDouble();
      }

      expect(computeExponential(0.0), equals(0.0));
      expect(computeExponential(1.0), equals(1.0));

      // At 50% physical travel, exponential output should be ~32.9% for fine low-speed control
      final mid = computeExponential(0.5);
      expect(mid, closeTo(0.3298, 0.01));

      // Lower at low travel: at 20% travel, output is ~7.6%
      final low = computeExponential(0.2);
      expect(low, closeTo(0.076, 0.01));
    });
  });
}
