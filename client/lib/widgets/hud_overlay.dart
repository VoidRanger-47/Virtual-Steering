import 'package:flutter/material.dart';

/// Top bar and settings modal for IP configuration, rate indicator, and steering range
class HudTopBar extends StatelessWidget {
  final String serverHost;
  final int serverPort;
  final double currentHz;
  final int totalPackets;
  final bool isConnected;
  final VoidCallback onOpenSettings;
  final VoidCallback onQuickUsbToggle;
  final bool isUsbMode;

  const HudTopBar({
    super.key,
    required this.serverHost,
    required this.serverPort,
    required this.currentHz,
    required this.totalPackets,
    required this.isConnected,
    required this.onOpenSettings,
    required this.onQuickUsbToggle,
    required this.isUsbMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1117).withOpacity(0.85),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF222836), width: 1.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: App brand & status
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected
                          ? const Color(0xFF00E676)
                          : const Color(0xFFFF5252),
                      boxShadow: [
                        BoxShadow(
                          color: (isConnected
                                  ? const Color(0xFF00E676)
                                  : const Color(0xFFFF5252))
                              .withOpacity(0.7),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'V-WHEEL',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2330),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'XBOX 360',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00E5FF),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center: Rate and Packets Telemetry
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF181D27),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF2D3547)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed, size: 13, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 4),
                    Text(
                      '${currentHz.toStringAsFixed(0)} Hz',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '($totalPackets pkts)',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right: Target Host button & Settings
          Flexible(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // USB Quick toggle
                  InkWell(
                    onTap: onQuickUsbToggle,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUsbMode
                            ? const Color(0xFF00E5FF).withOpacity(0.2)
                            : const Color(0xFF181D27),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isUsbMode
                              ? const Color(0xFF00E5FF)
                              : const Color(0xFF2D3547),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.usb_rounded,
                            size: 13,
                            color: isUsbMode
                                ? const Color(0xFF00E5FF)
                                : Colors.white60,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'USB',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isUsbMode
                                  ? const Color(0xFF00E5FF)
                                  : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Server target button
                  InkWell(
                    onTap: onOpenSettings,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181D27),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF2D3547)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi, size: 13, color: Colors.white70),
                          const SizedBox(width: 5),
                          Text(
                            '$serverHost:$serverPort',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.settings, size: 13, color: Colors.white54),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
