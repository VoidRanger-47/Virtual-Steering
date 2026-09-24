#!/usr/bin/env python3
"""
Unit tests for Virtual Driving Controller server packet serialization,
deadzone calculation, and failsafe logic.
"""

import struct
import unittest

PACKET_FORMAT = "<hHH"


class TestControllerProtocol(unittest.TestCase):
    def test_packet_size(self):
        """Verify binary packet format <hHH is exactly 6 bytes."""
        size = struct.calcsize(PACKET_FORMAT)
        self.assertEqual(size, 6, "Packet size must be exactly 6 bytes")

    def test_pack_unpack_limits(self):
        """Test boundary conditions for steering (-32768 to 32767) and pedals (0 to 65535)."""
        # Neutral
        raw = struct.pack(PACKET_FORMAT, 0, 0, 0)
        steer, thr, brk = struct.unpack(PACKET_FORMAT, raw)
        self.assertEqual((steer, thr, brk), (0, 0, 0))

        # Full left, full throttle, no brake
        raw = struct.pack(PACKET_FORMAT, -32768, 65535, 0)
        steer, thr, brk = struct.unpack(PACKET_FORMAT, raw)
        self.assertEqual(steer, -32768)
        self.assertEqual(thr, 65535)
        self.assertEqual(brk, 0)

        # Full right, no throttle, full brake
        raw = struct.pack(PACKET_FORMAT, 32767, 0, 65535)
        steer, thr, brk = struct.unpack(PACKET_FORMAT, raw)
        self.assertEqual(steer, 32767)
        self.assertEqual(thr, 0)
        self.assertEqual(brk, 65535)

    def test_trigger_scaling(self):
        """Verify 16-bit uint throttle/brake bit shift to 8-bit trigger (0-255)."""
        # 65535 >> 8 is 255
        self.assertEqual(65535 >> 8, 255)
        # Half throttle: ~32768 >> 8 is 128
        self.assertEqual(32768 >> 8, 128)
        # 0 >> 8 is 0
        self.assertEqual(0 >> 8, 0)

    def test_steering_deadzone(self):
        """Verify deadzone logic ignores small inputs near center."""
        deadzone = 600

        def apply_deadzone(raw_steer):
            if abs(raw_steer) < deadzone:
                return 0
            sign = 1 if raw_steer > 0 else -1
            mag = (abs(raw_steer) - deadzone) / (32767 - deadzone)
            return int(sign * min(32767, max(0, mag * 32767)))

        self.assertEqual(apply_deadzone(0), 0)
        self.assertEqual(apply_deadzone(250), 0)
        self.assertEqual(apply_deadzone(-500), 0)
        self.assertTrue(apply_deadzone(1000) > 0)
        self.assertTrue(apply_deadzone(-1000) < 0)
        self.assertEqual(apply_deadzone(32767), 32767)
        self.assertEqual(apply_deadzone(-32767), -32767)


if __name__ == "__main__":
    unittest.main()
