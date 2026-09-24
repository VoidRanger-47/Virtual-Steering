import 'package:flutter/material.dart';
import '../models/customization_config.dart';
import '../services/udp_transmitter.dart';
import '../theme/app_theme.dart';
import 'steering_wheel.dart';
import 'pedal_slider.dart';

/// Interactive full-screen Drag-and-Drop HUD Layout Editor
/// Allows users to customize the exact placement and scale of:
/// - Steering Wheel
/// - Throttle Pedal
/// - Brake Pedal
/// - Clutch Pedal
/// - Shifter Paddles
/// - Custom Extra Buttons (Handbrake, Nitrous, Horn, Camera, etc.)
class HudLayoutEditor extends StatefulWidget {
  final CustomizationConfig config;
  final ValueChanged<CustomizationConfig> onSave;

  const HudLayoutEditor({
    super.key,
    required this.config,
    required this.onSave,
  });

  static void show(
    BuildContext context, {
    required CustomizationConfig config,
    required ValueChanged<CustomizationConfig> onSave,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => HudLayoutEditor(
          config: config,
          onSave: onSave,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<HudLayoutEditor> createState() => _HudLayoutEditorState();
}

class _HudLayoutEditorState extends State<HudLayoutEditor> {
  late CustomizationConfig _cfg;
  String? _selectedElementId;

  static const List<Map<String, dynamic>> _buttonPresets = [
    {'label': 'HANDBRAKE', 'mask': UdpTransmitter.btnA,     'isBtn2': false, 'color': Color(0xFFFF2A4B), 'icon': Icons.car_crash_rounded},
    {'label': 'BOOST',      'mask': UdpTransmitter.btnB,     'isBtn2': false, 'color': Color(0xFFFF9100), 'icon': Icons.bolt_rounded},
    {'label': 'HORN',       'mask': UdpTransmitter.btnLStick,'isBtn2': true,  'color': Color(0xFFFFEA00), 'icon': Icons.volume_up_rounded},
    {'label': 'LOOK BACK',  'mask': UdpTransmitter.btnRStick,'isBtn2': true,  'color': Color(0xFF00E5FF), 'icon': Icons.replay_rounded},
    {'label': 'CAMERA',     'mask': UdpTransmitter.btnY,     'isBtn2': false, 'color': Color(0xFF7C4DFF), 'icon': Icons.videocam_rounded},
    {'label': 'GEAR UP',    'mask': UdpTransmitter.btnRB,    'isBtn2': false, 'color': Color(0xFF00E676), 'icon': Icons.arrow_upward_rounded},
    {'label': 'GEAR DOWN',  'mask': UdpTransmitter.btnLB,    'isBtn2': false, 'color': Color(0xFF00E676), 'icon': Icons.arrow_downward_rounded},
    {'label': 'RESET CAR',  'mask': UdpTransmitter.btnBack,  'isBtn2': false, 'color': Color(0xFF90A4AE), 'icon': Icons.restart_alt_rounded},
    {'label': 'PAUSE',      'mask': UdpTransmitter.btnStart, 'isBtn2': false, 'color': Color(0xFFFFFFFF), 'icon': Icons.pause_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _cfg = widget.config.copyWith();
  }

  void _onPanItem(String id, DragUpdateDetails details, Size canvasSize) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;

    final dx = details.delta.dx / canvasSize.width;
    final dy = details.delta.dy / canvasSize.height;

    setState(() {
      _selectedElementId = id;
      // Check if standard layout element
      if (_cfg.layoutPositions.containsKey(id)) {
        final current = _cfg.layoutPositions[id]!;
        final newX = (current.x + dx).clamp(0.08, 0.92);
        final newY = (current.y + dy).clamp(0.12, 0.88);
        _cfg.layoutPositions[id] = LayoutItemConfig(
          id: id,
          x: newX,
          y: newY,
          scale: current.scale,
        );
      } else {
        // Check if extra button
        final idx = _cfg.extraButtons.indexWhere((b) => b.id == id);
        if (idx != -1) {
          final b = _cfg.extraButtons[idx];
          final newX = (b.x + dx).clamp(0.05, 0.95);
          final newY = (b.y + dy).clamp(0.10, 0.90);
          _cfg.extraButtons[idx] = ExtraButtonConfig(
            id: b.id,
            label: b.label,
            buttonMask: b.buttonMask,
            isBtn2: b.isBtn2,
            color: b.color,
            size: b.size,
            x: newX,
            y: newY,
          );
        }
      }
    });
  }

  void _setScale(double newScale) {
    if (_selectedElementId == null) return;
    setState(() {
      if (_cfg.layoutPositions.containsKey(_selectedElementId)) {
        final current = _cfg.layoutPositions[_selectedElementId]!;
        _cfg.layoutPositions[_selectedElementId!] = LayoutItemConfig(
          id: current.id,
          x: current.x,
          y: current.y,
          scale: newScale,
        );
      } else {
        final idx = _cfg.extraButtons.indexWhere((b) => b.id == _selectedElementId);
        if (idx != -1) {
          final b = _cfg.extraButtons[idx];
          _cfg.extraButtons[idx] = ExtraButtonConfig(
            id: b.id,
            label: b.label,
            buttonMask: b.buttonMask,
            isBtn2: b.isBtn2,
            color: b.color,
            size: (52.0 * newScale).clamp(36.0, 80.0),
            x: b.x,
            y: b.y,
          );
        }
      }
    });
  }

  void _deleteSelectedExtraButton() {
    if (_selectedElementId == null) return;
    setState(() {
      _cfg.extraButtons.removeWhere((b) => b.id == _selectedElementId);
      _selectedElementId = null;
    });
  }

  void _showAddButtonDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141824),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2C3549)),
        ),
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline_rounded, color: Color(0xFF00E5FF)),
            SizedBox(width: 8),
            Text('Add Extra Control Button', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buttonPresets.map((preset) {
                final color = preset['color'] as Color;
                return ActionChip(
                  avatar: Icon(preset['icon'] as IconData, size: 16, color: color),
                  label: Text(preset['label'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                  backgroundColor: const Color(0xFF1B2130),
                  side: BorderSide(color: color.withOpacity(0.5)),
                  onPressed: () {
                    final newId = 'btn_${DateTime.now().millisecondsSinceEpoch}';
                    setState(() {
                      _cfg.extraButtons.add(
                        ExtraButtonConfig(
                          id: newId,
                          label: preset['label'] as String,
                          buttonMask: preset['mask'] as int,
                          isBtn2: preset['isBtn2'] as bool,
                          color: color,
                          size: 52.0,
                          x: 0.50,
                          y: 0.50,
                        ),
                      );
                      _selectedElementId = newId;
                    });
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _saveAndExit() {
    _cfg.useCustomLayout = true;
    _cfg.saveToPrefs();
    widget.onSave(_cfg);
    Navigator.of(context).pop();
  }

  void _resetLayout() {
    setState(() {
      _cfg.layoutPositions = {
        'steering': LayoutItemConfig(id: 'steering', x: 0.28, y: 0.52, scale: 1.0),
        'shifters': LayoutItemConfig(id: 'shifters', x: 0.55, y: 0.52, scale: 1.0),
        'brake':    LayoutItemConfig(id: 'brake',    x: 0.72, y: 0.54, scale: 1.0),
        'throttle': LayoutItemConfig(id: 'throttle', x: 0.88, y: 0.54, scale: 1.0),
        'clutch':   LayoutItemConfig(id: 'clutch',   x: 0.63, y: 0.54, scale: 1.0),
      };
      _cfg.extraButtons.clear();
      _selectedElementId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090B10),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

            return Stack(
              children: [
                // 1. Grid Background
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GridBackgroundPainter(),
                  ),
                ),

                // 2. Positionable Elements
                ..._buildCanvasElements(canvasSize),

                // 3. Top Action Toolbar
                Positioned(
                  top: 8,
                  left: 12,
                  right: 12,
                  child: _buildTopToolbar(),
                ),

                // 4. Bottom Selection Inspector
                if (_selectedElementId != null)
                  Positioned(
                    bottom: 8,
                    left: 20,
                    right: 20,
                    child: _buildBottomInspector(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopToolbar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141824).withOpacity(0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2E384D)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white70),
            tooltip: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          const Text(
            'HUD LAYOUT EDITOR (DRAG TO MOVE)',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          // Add Extra Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E2638),
              foregroundColor: const Color(0xFF00E5FF),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('ADD BUTTON', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            onPressed: _showAddButtonDialog,
          ),
          const SizedBox(width: 8),
          // Reset
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white54),
            onPressed: _resetLayout,
            child: const Text('RESET', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 8),
          // Save
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: _saveAndExit,
            child: const Text('SAVE HUD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInspector() {
    double currentScale = 1.0;
    final isExtraBtn = _cfg.extraButtons.any((b) => b.id == _selectedElementId);

    if (_cfg.layoutPositions.containsKey(_selectedElementId)) {
      currentScale = _cfg.layoutPositions[_selectedElementId]!.scale;
    } else if (isExtraBtn) {
      final b = _cfg.extraButtons.firstWhere((b) => b.id == _selectedElementId);
      currentScale = (b.size / 52.0).clamp(0.6, 1.5);
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141824).withOpacity(0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          Text(
            _selectedElementId!.toUpperCase().replaceAll('_', ' '),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF00E5FF),
            ),
          ),
          const SizedBox(width: 16),
          const Text('SCALE:', style: TextStyle(fontSize: 10, color: Colors.white60, fontWeight: FontWeight.bold)),
          Expanded(
            child: Slider(
              value: currentScale.clamp(0.6, 1.5),
              min: 0.6,
              max: 1.5,
              divisions: 9,
              activeColor: const Color(0xFF00E5FF),
              inactiveColor: Colors.white12,
              onChanged: _setScale,
            ),
          ),
          Text(
            '${(currentScale * 100).round()}%',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          if (isExtraBtn) ...[
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF2A4B), size: 20),
              tooltip: 'Remove Button',
              onPressed: _deleteSelectedExtraButton,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildCanvasElements(Size canvasSize) {
    final widgets = <Widget>[];

    // 1. Steering Wheel
    final steerCfg = _cfg.layoutPositions['steering']!;
    final steerSize = 210.0 * steerCfg.scale;
    widgets.add(_buildDraggableWrapper(
      id: 'steering',
      x: steerCfg.x,
      y: steerCfg.y,
      width: steerSize,
      height: steerSize,
      canvasSize: canvasSize,
      child: SteeringWheelWidget(
        config: _cfg,
        onSteerChanged: (_) {},
      ),
    ));

    // 2. Shifter Paddles
    final shiftersCfg = _cfg.layoutPositions['shifters']!;
    final shiftersWidth = 44.0 * shiftersCfg.scale;
    final shiftersHeight = 120.0 * shiftersCfg.scale;
    widgets.add(_buildDraggableWrapper(
      id: 'shifters',
      x: shiftersCfg.x,
      y: shiftersCfg.y,
      width: shiftersWidth,
      height: shiftersHeight,
      canvasSize: canvasSize,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgPanel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.divider),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text('LB', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 10)),
            Divider(color: Colors.white12, height: 1),
            Text('RB', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 10)),
          ],
        ),
      ),
    ));

    // 3. Brake Pedal
    final brakeCfg = _cfg.layoutPositions['brake']!;
    final pedalWidth = 84.0 * brakeCfg.scale;
    final pedalHeight = 220.0 * brakeCfg.scale;
    widgets.add(_buildDraggableWrapper(
      id: 'brake',
      x: brakeCfg.x,
      y: brakeCfg.y,
      width: pedalWidth,
      height: pedalHeight,
      canvasSize: canvasSize,
      child: PedalSliderWidget(
        pedalType: PedalType.brake,
        config: _cfg,
        onValueChanged: (_) {},
      ),
    ));

    // 4. Throttle Pedal
    final throttleCfg = _cfg.layoutPositions['throttle']!;
    final throttleWidth = 84.0 * throttleCfg.scale;
    final throttleHeight = 220.0 * throttleCfg.scale;
    widgets.add(_buildDraggableWrapper(
      id: 'throttle',
      x: throttleCfg.x,
      y: throttleCfg.y,
      width: throttleWidth,
      height: throttleHeight,
      canvasSize: canvasSize,
      child: PedalSliderWidget(
        pedalType: PedalType.throttle,
        config: _cfg,
        onValueChanged: (_) {},
      ),
    ));

    // 5. Optional Clutch Pedal
    if (_cfg.showClutch && _cfg.layoutPositions.containsKey('clutch')) {
      final clutchCfg = _cfg.layoutPositions['clutch']!;
      final clutchWidth = 74.0 * clutchCfg.scale;
      final clutchHeight = 210.0 * clutchCfg.scale;
      widgets.add(_buildDraggableWrapper(
        id: 'clutch',
        x: clutchCfg.x,
        y: clutchCfg.y,
        width: clutchWidth,
        height: clutchHeight,
        canvasSize: canvasSize,
        child: PedalSliderWidget(
          pedalType: PedalType.clutch,
          config: _cfg,
          onValueChanged: (_) {},
        ),
      ));
    }

    // 6. Extra Buttons
    for (final btn in _cfg.extraButtons) {
      widgets.add(_buildDraggableWrapper(
        id: btn.id,
        x: btn.x,
        y: btn.y,
        width: btn.size,
        height: btn.size,
        canvasSize: canvasSize,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141824),
            shape: BoxShape.circle,
            border: Border.all(color: btn.color, width: 2.0),
            boxShadow: [
              BoxShadow(color: btn.color.withOpacity(0.3), blurRadius: 10),
            ],
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(
                  btn.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: btn.color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
    }

    return widgets;
  }

  Widget _buildDraggableWrapper({
    required String id,
    required double x,
    required double y,
    required double width,
    required double height,
    required Size canvasSize,
    required Widget child,
  }) {
    final isSelected = _selectedElementId == id;
    final left = (x * canvasSize.width) - (width / 2);
    final top = (y * canvasSize.height) - (height / 2);

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        onPanUpdate: (d) => _onPanItem(id, d, canvasSize),
        onTap: () {
          setState(() {
            _selectedElementId = id;
          });
        },
        child: Stack(
          children: [
            IgnorePointer(child: child),
            // Selection bounding box & drag handle
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00E5FF) : Colors.white24,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.08) : Colors.transparent,
                ),
              ),
            ),
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E5FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.open_with_rounded, size: 12, color: Colors.black),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1.0;

    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
