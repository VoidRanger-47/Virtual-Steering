#!/usr/bin/env python3
"""
Mock client for Virtual Driving Controller server.
Sends synthetic 60 Hz steering, throttle, and brake datagrams
to verify packet unpacking and gamepad driver operation.
"""

import argparse
import math
import socket
import struct
import time

PACKET_FORMAT = "<hHH"


def run_mock_client(host: str = "127.0.0.1", port: int = 5005, duration: float = 10.0):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    interval = 1.0 / 60.0  # 60 Hz

    print(f"[*] Sending 60 Hz test packets to {host}:{port} for {duration:.1f}s...")
    start_time = time.perf_counter()
    next_tick = start_time
    packet_count = 0

    try:
        while True:
            now = time.perf_counter()
            elapsed = now - start_time
            if elapsed >= duration:
                break

            # Synthesize inputs:
            # 1. Sine wave steering: -32767 to 32767 (frequency 0.5 Hz)
            steer = int(32767 * math.sin(elapsed * 2 * math.pi * 0.5))

            # 2. Throttle ramps up and down (triangle wave 0 to 65535)
            thr_cycle = (elapsed * 0.4) % 2.0
            if thr_cycle < 1.0:
                throttle = int(65535 * thr_cycle)
                brake = 0
            else:
                throttle = 0
                brake = int(65535 * (thr_cycle - 1.0))

            packet = struct.pack(PACKET_FORMAT, steer, throttle, brake)
            sock.sendto(packet, (host, port))
            packet_count += 1

            next_tick += interval
            sleep_time = next_tick - time.perf_counter()
            if sleep_time > 0:
                time.sleep(sleep_time)

    except KeyboardInterrupt:
        pass
    finally:
        sock.close()
        actual_time = time.perf_counter() - start_time
        avg_hz = packet_count / actual_time if actual_time > 0 else 0
        print(f"[*] Finished. Sent {packet_count} packets in {actual_time:.2f}s ({avg_hz:.1f} Hz).")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Virtual Driving Controller Mock Client")
    parser.add_argument("--host", default="127.0.0.1", help="Target server IP")
    parser.add_argument("--port", type=int, default=5005, help="Target server UDP port")
    parser.add_argument("--duration", type=float, default=10.0, help="Test run duration in seconds")
    args = parser.parse_args()

    run_mock_client(host=args.host, port=args.port, duration=args.duration)
