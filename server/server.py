#!/usr/bin/env python3
"""
Virtual Controller - PC Host Receiver (VCTRL)
Supports two UDP packet formats:
  - Legacy 6-byte  racing protocol : <hHH   (steer, throttle, brake)
  - Extended 12-byte full protocol : <hHHhhBB (+ rx, ry, btn1, btn2)

Button bitmasks (btn1):
  bit0=A  bit1=B  bit2=X  bit3=Y  bit4=LB  bit5=RB  bit6=Start  bit7=Back
Button bitmasks (btn2):
  bit0=LStick  bit1=RStick  bit2=DUp  bit3=DDown  bit4=DLeft  bit5=DRight
"""

import argparse
import os
import select
import socket
import struct
import sys
import time
from typing import Optional

# Optional colorama for colored terminal output
try:
    import colorama
    colorama.init(autoreset=True)
    GREEN = colorama.Fore.GREEN
    CYAN = colorama.Fore.CYAN
    YELLOW = colorama.Fore.YELLOW
    RED = colorama.Fore.RED
    RESET = colorama.Style.RESET_ALL
    BRIGHT = colorama.Style.BRIGHT
    DIM = colorama.Style.DIM
except ImportError:
    GREEN = CYAN = YELLOW = RED = RESET = BRIGHT = DIM = ""

# Gamepad driver
VGAMEPAD_AVAILABLE = False
try:
    import vgamepad as vg
    VGAMEPAD_AVAILABLE = True
except Exception:
    VGAMEPAD_AVAILABLE = False

# Protocol specifications
PACKET_FORMAT_LEGACY  = "<hHH"      # 6-byte backward-compat
PACKET_FORMAT_FULL    = "<hHHhhBB"  # 12-byte full protocol
PACKET_SIZE_LEGACY    = struct.calcsize(PACKET_FORMAT_LEGACY)   # 6
PACKET_SIZE_FULL      = struct.calcsize(PACKET_FORMAT_FULL)     # 12

# Button bitmasks (btn1)
BTN_A     = 1 << 0
BTN_B     = 1 << 1
BTN_X     = 1 << 2
BTN_Y     = 1 << 3
BTN_LB    = 1 << 4
BTN_RB    = 1 << 5
BTN_START = 1 << 6
BTN_BACK  = 1 << 7

# Button bitmasks (btn2)
BTN_LSTICK = 1 << 0
BTN_RSTICK = 1 << 1
BTN_DUP    = 1 << 2
BTN_DDOWN  = 1 << 3
BTN_DLEFT  = 1 << 4
BTN_DRIGHT = 1 << 5
DEFAULT_PORT = 5005
DEFAULT_HOST = "0.0.0.0"
FAILSAFE_TIMEOUT_SEC = 0.5  # Auto-neutral reset after 500ms without packets
STEERING_DEADZONE = 600     # ~1.8% deadzone on 32767 scale


class DrivingControllerServer:
    def __init__(
        self,
        host: str = DEFAULT_HOST,
        port: int = DEFAULT_PORT,
        deadzone: int = STEERING_DEADZONE,
        emulate: bool = True,
    ):
        self.host = host
        self.port = port
        self.deadzone = deadzone
        self.emulate = emulate and VGAMEPAD_AVAILABLE
        self.gamepad: Optional["vg.VX360Gamepad"] = None
        self.sock: Optional[socket.socket] = None
        self.running = False

        # State tracking
        self.last_steer: int = 0
        self.last_throttle: int = 0
        self.last_brake: int = 0
        self.last_rx: int = 0
        self.last_ry: int = 0
        self.last_btn1: int = 0
        self.last_btn2: int = 0
        self.is_full_protocol: bool = False
        self.last_packet_time: float = 0.0
        self.packet_count: int = 0
        self.packets_in_window: int = 0
        self.window_start_time: float = 0.0
        self.current_hz: float = 0.0
        self.client_addr: Optional[tuple] = None
        self.in_neutral_failsafe: bool = True

    def init_gamepad(self) -> bool:
        if not self.emulate:
            print(f"{YELLOW}[WARN] Gamepad emulation disabled or vgamepad not installed.{RESET}")
            print(f"{YELLOW}       Running in telemetry/logging mode only.{RESET}")
            return False

        try:
            print(f"{CYAN}[INIT] Initializing ViGEm Virtual Xbox 360 Controller...{RESET}")
            self.gamepad = vg.VX360Gamepad()
            # Set to initial neutral state
            self.reset_controller_neutral()
            print(f"{GREEN}[OK] Virtual Xbox 360 controller connected successfully!{RESET}")
            return True
        except Exception as e:
            print(f"{RED}[ERROR] Failed to initialize virtual gamepad: {e}{RESET}")
            print(f"{YELLOW}[HELP] The ViGEmBus driver is required on Windows.{RESET}")
            print(f"{GREEN}[FIX]  We have bundled the installer directly in this project!{RESET}")
            print(f"{GREEN}       Run 'install_driver.bat' or double-click 'drivers/ViGEmBus_Setup.exe'.{RESET}")
            print(f"{YELLOW}       (You can also test packet reception using --no-gamepad flag){RESET}")
            self.gamepad = None
            return False

    def init_socket(self):
        print(f"{CYAN}[INIT] Binding non-blocking UDP socket on {self.host}:{self.port}...{RESET}")
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        # Allow address reuse
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        # Increase socket receive buffer to avoid dropping packets under load
        try:
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 65536)
        except OSError:
            pass
        self.sock.bind((self.host, self.port))
        self.sock.setblocking(False)
        print(f"{GREEN}[OK] Listening for UDP datagrams on port {self.port}.{RESET}")

    def reset_controller_neutral(self):
        """Resets all axes and buttons to neutral."""
        self.last_steer = 0
        self.last_throttle = 0
        self.last_brake = 0
        self.last_rx = 0
        self.last_ry = 0
        self.last_btn1 = 0
        self.last_btn2 = 0
        if self.gamepad:
            self.gamepad.left_joystick(x_value=0, y_value=0)
            self.gamepad.right_joystick(x_value=0, y_value=0)
            self.gamepad.right_trigger(value=0)
            self.gamepad.left_trigger(value=0)
            # Release all buttons
            try:
                import vgamepad as vg
                self.gamepad.reset_buttons()
            except Exception:
                pass
            self.gamepad.update()
        self.in_neutral_failsafe = True

    def apply_inputs(
        self,
        raw_steer: int,
        raw_throttle: int,
        raw_brake: int,
        raw_rx: int = 0,
        raw_ry: int = 0,
        btn1: int = 0,
        btn2: int = 0,
    ):
        """Processes input deadzones and dispatches to the virtual gamepad."""
        # Deadzone processing for left stick X (steering)
        if abs(raw_steer) < self.deadzone:
            steer = 0
        else:
            sign = 1 if raw_steer > 0 else -1
            magnitude = (abs(raw_steer) - self.deadzone) / (32767 - self.deadzone)
            steer = int(sign * min(32767, max(0, magnitude * 32767)))

        # Scale 16-bit uint throttle & brake (0..65535) → 8-bit trigger (0..255)
        throttle_trigger = min(255, max(0, raw_throttle >> 8))
        brake_trigger    = min(255, max(0, raw_brake    >> 8))

        self.last_steer    = steer
        self.last_throttle = raw_throttle
        self.last_brake    = raw_brake
        self.last_rx       = raw_rx
        self.last_ry       = raw_ry
        self.last_btn1     = btn1
        self.last_btn2     = btn2
        self.in_neutral_failsafe = False

        if self.gamepad:
            import vgamepad as vg
            self.gamepad.left_joystick(x_value=steer, y_value=0)
            self.gamepad.right_joystick(x_value=raw_rx, y_value=raw_ry)
            self.gamepad.right_trigger(value=throttle_trigger)
            self.gamepad.left_trigger(value=brake_trigger)

            # Face buttons + bumpers
            def _btn(mask, button):
                if btn1 & mask:
                    self.gamepad.press_button(button=button)
                else:
                    self.gamepad.release_button(button=button)

            _btn(BTN_A,     vg.XUSB_BUTTON.XUSB_GAMEPAD_A)
            _btn(BTN_B,     vg.XUSB_BUTTON.XUSB_GAMEPAD_B)
            _btn(BTN_X,     vg.XUSB_BUTTON.XUSB_GAMEPAD_X)
            _btn(BTN_Y,     vg.XUSB_BUTTON.XUSB_GAMEPAD_Y)
            _btn(BTN_LB,    vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_SHOULDER)
            _btn(BTN_RB,    vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_SHOULDER)
            _btn(BTN_START, vg.XUSB_BUTTON.XUSB_GAMEPAD_START)
            _btn(BTN_BACK,  vg.XUSB_BUTTON.XUSB_GAMEPAD_BACK)

            # Stick clicks + D-pad (btn2)
            def _btn2(mask, button):
                if btn2 & mask:
                    self.gamepad.press_button(button=button)
                else:
                    self.gamepad.release_button(button=button)

            _btn2(BTN_LSTICK, vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_THUMB)
            _btn2(BTN_RSTICK, vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_THUMB)
            _btn2(BTN_DUP,    vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_UP)
            _btn2(BTN_DDOWN,  vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_DOWN)
            _btn2(BTN_DLEFT,  vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_LEFT)
            _btn2(BTN_DRIGHT, vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_RIGHT)

            self.gamepad.update()

    def print_hud(self):
        """Renders an in-place telemetry HUD line."""
        steer_pct = (self.last_steer / 32767.0) * 100.0
        throttle_pct = (self.last_throttle / 65535.0) * 100.0
        brake_pct = (self.last_brake / 65535.0) * 100.0

        # Bar visualization
        steer_bar_len = 10
        steer_norm = int(round(steer_pct / 10.0))  # -10 to +10
        if steer_norm < 0:
            steer_bar = "[" + " " * (10 + steer_norm) + "<" * abs(steer_norm) + "|" + " " * 10 + "]"
        else:
            steer_bar = "[" + " " * 10 + "|" + ">" * steer_norm + " " * (10 - steer_norm) + "]"

        throttle_bars = int(throttle_pct / 10.0)
        throttle_bar = "[" + "=" * throttle_bars + " " * (10 - throttle_bars) + "]"

        brake_bars = int(brake_pct / 10.0)
        brake_bar = "[" + "#" * brake_bars + " " * (10 - brake_bars) + "]"

        status = f"{RED}[FAILSAFE]{RESET}" if self.in_neutral_failsafe else f"{GREEN}[ACTIVE]{RESET}"
        client_str = f"{self.client_addr[0]}:{self.client_addr[1]}" if self.client_addr else "Waiting..."
        lat_str = f"{(1000.0 / self.current_hz):.1f}ms" if self.current_hz > 0 else "--ms"

        line = (
            f"\r{status} "
            f"Client: {CYAN}{client_str:<21}{RESET} "
            f"Hz: {BRIGHT}{self.current_hz:5.1f}{RESET} ({GREEN}{lat_str:<6}{RESET}) | "
            f"Steer: {steer_bar} {steer_pct:+6.1f}% | "
            f"Thr: {GREEN}{throttle_bar} {throttle_pct:5.1f}%{RESET} | "
            f"Brk: {RED}{brake_bar} {brake_pct:5.1f}%{RESET}"
        )
        sys.stdout.write(line)
        sys.stdout.flush()

    def get_primary_ip(self) -> str:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
        except Exception:
            ip = "127.0.0.1"
        finally:
            s.close()
        return ip

    def run(self):
        # Enable 1ms Windows OS scheduler resolution for ultra-low latency
        if sys.platform == "win32":
            try:
                import ctypes
                ctypes.windll.winmm.timeBeginPeriod(1)
            except Exception:
                pass

        self.init_gamepad()
        self.init_socket()
        self.running = True
        self.window_start_time = time.perf_counter()
        last_hud_update = time.perf_counter()
        primary_ip = self.get_primary_ip()

        print(f"\n{BRIGHT}========================================================================{RESET}")
        print(f"{BRIGHT}           VCTRL PC HOST RECEIVER - UDP PORT {self.port}              {RESET}")
        print(f"{BRIGHT}========================================================================{RESET}")
        print(f"  {YELLOW}{BRIGHT}[STEP 1]{RESET} Ensure phone is on the SAME Wi-Fi network as this PC.")
        print(f"  {YELLOW}{BRIGHT}[STEP 2]{RESET} In the mobile app, tap the {CYAN}gear / tune icon{RESET} (top right).")
        print(f"  {YELLOW}{BRIGHT}[STEP 3]{RESET} Enter Host IP:")
        print(f"           {GREEN}{BRIGHT}>>>  {primary_ip}  <<<{RESET}  (Your Wi-Fi IP)")
        print(f"           {DIM}If using Android Emulator, enter: 10.0.2.2{RESET}")
        print(f"  {YELLOW}{BRIGHT}[STEP 4]{RESET} Target Latency: Choose {GREEN}5ms (200 Hz){RESET} or {GREEN}10ms (100 Hz){RESET}.")
        print(f"  {YELLOW}{BRIGHT}[STEP 5]{RESET} Tap {GREEN}APPLY{RESET} and move the controls.")
        print(f"{BRIGHT}========================================================================{RESET}")
        print(f"{CYAN}Waiting for controller packets from phone...{RESET}\n")

        try:
            while self.running:
                now = time.perf_counter()

                # High-precision socket wait (1ms timeout)
                # When a packet arrives, select returns instantly (< 0.1ms)
                r, _, _ = select.select([self.sock], [], [], 0.001)

                latest_packet = None
                latest_addr = None

                if r:
                    # Drain all pending datagrams in kernel socket buffer, keeping only the freshest
                    while True:
                        try:
                            data, addr = self.sock.recvfrom(64)
                            plen = len(data)
                            if plen in (PACKET_SIZE_LEGACY, PACKET_SIZE_FULL):
                                latest_packet = data
                                latest_addr   = addr
                                self.packet_count      += 1
                                self.packets_in_window += 1
                                if self.packet_count == 1:
                                    sys.stdout.write(
                                        f"\n{GREEN}{BRIGHT}[>>> CONNECTED! <<<] Received first signal from phone at {addr[0]}:{addr[1]}!{RESET}\n\n"
                                    )
                                    sys.stdout.flush()
                        except (BlockingIOError, socket.error):
                            break
                        except ConnectionResetError:
                            # On Windows UDP, ICMP Port Unreachable raises ConnectionResetError
                            break

                if latest_packet is not None:
                    self.client_addr = latest_addr
                    self.last_packet_time = now
                    try:
                        plen = len(latest_packet)
                        if plen == PACKET_SIZE_FULL:
                            self.is_full_protocol = True
                            rs, rt, rb, rx, ry, b1, b2 = struct.unpack(
                                PACKET_FORMAT_FULL, latest_packet
                            )
                            self.apply_inputs(rs, rt, rb, rx, ry, b1, b2)
                        else:
                            self.is_full_protocol = False
                            rs, rt, rb = struct.unpack(PACKET_FORMAT_LEGACY, latest_packet)
                            self.apply_inputs(rs, rt, rb)
                    except struct.error as e:
                        sys.stderr.write(f"\n[WARN] Malformed packet: {e}\n")

                # Failsafe check: If no packet received for FAILSAFE_TIMEOUT_SEC, reset to neutral
                if (
                    not self.in_neutral_failsafe
                    and (now - self.last_packet_time) > FAILSAFE_TIMEOUT_SEC
                ):
                    self.reset_controller_neutral()

                # Calculate Hz rate every 0.5s
                if now - self.window_start_time >= 0.5:
                    elapsed = now - self.window_start_time
                    self.current_hz = self.packets_in_window / elapsed
                    self.packets_in_window = 0
                    self.window_start_time = now

                # Update HUD line at ~20 Hz to reduce terminal overhead
                if now - last_hud_update >= 0.05:
                    self.print_hud()
                    last_hud_update = now

        except KeyboardInterrupt:
            print(f"\n{YELLOW}[SHUTDOWN] Interrupted by user (Ctrl+C).{RESET}")
        finally:
            self.teardown()

    def teardown(self):
        print(f"\n{CYAN}[CLEANUP] Resetting inputs and closing handles...{RESET}")
        self.reset_controller_neutral()
        if self.sock:
            try:
                self.sock.close()
            except Exception:
                pass
            print(f"{GREEN}[OK] UDP socket closed.{RESET}")

        if self.gamepad:
            try:
                del self.gamepad
            except Exception:
                pass
            print(f"{GREEN}[OK] Virtual gamepad released.{RESET}")

        if sys.platform == "win32":
            try:
                import ctypes
                ctypes.windll.winmm.timeEndPeriod(1)
            except Exception:
                pass

        print(f"{BRIGHT}Shutdown complete. Goodbye!{RESET}")


def main():
    parser = argparse.ArgumentParser(
        description="Virtual Driving Controller PC Host Receiver (Xbox 360 emulation via UDP)"
    )
    parser.add_argument(
        "--host",
        default=DEFAULT_HOST,
        help=f"IP address to bind UDP receiver (default: {DEFAULT_HOST})",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=DEFAULT_PORT,
        help=f"UDP port to listen on (default: {DEFAULT_PORT})",
    )
    parser.add_argument(
        "--deadzone",
        type=int,
        default=STEERING_DEADZONE,
        help=f"Center steering deadzone [-32768, 32767] (default: {STEERING_DEADZONE})",
    )
    parser.add_argument(
        "--no-gamepad",
        action="store_true",
        help="Run without vgamepad virtual controller (telemetry inspection mode)",
    )

    args = parser.parse_args()

    server = DrivingControllerServer(
        host=args.host,
        port=args.port,
        deadzone=args.deadzone,
        emulate=not args.no_gamepad,
    )
    server.run()


if __name__ == "__main__":
    main()
