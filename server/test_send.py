#!/usr/bin/env python3
"""
Quick UDP test sender to verify if the VCTRL server is receiving packets.
Sends 10 simulated 12-byte packets to 127.0.0.1:5005.
"""
import socket
import struct
import time

PACKET_FORMAT = "<hHHhhBB"

def main():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    target = ("127.0.0.1", 5005)
    print(f"Sending test packets to {target[0]}:{target[1]}...")

    for i in range(1, 11):
        steer = int((i / 10.0) * 16000)
        throttle = int((i / 10.0) * 32000)
        brake = 0
        rx = 0
        ry = 0
        btn1 = 1 if (i % 2 == 0) else 0  # Alternate Button A
        btn2 = 0
        
        packet = struct.pack(PACKET_FORMAT, steer, throttle, brake, rx, ry, btn1, btn2)
        sock.sendto(packet, target)
        print(f"  Sent packet #{i}: steer={steer}, thr={throttle}, btnA={'ON' if btn1 else 'OFF'}")
        time.sleep(0.1)

    print("Done! Check your PC server terminal to see if Hz and inputs responded.")

if __name__ == "__main__":
    main()
