import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Inputs the wheel can produce. Screens react to these.
mixin WheelHandler {
  void onRotate(int steps) {}
  void onCenter() {}
  void onCenterLong() {}
  void onMenu() {}
  void onPrev() {}
  void onNext() {}
  void onBottom() {}
  void onBottomLong() {}
}

/// Round click wheel: drag around the ring to rotate, tap the four
/// edge zones or the center button. Mouse scroll also rotates.
class ClickWheel extends StatefulWidget {
  const ClickWheel({super.key, required this.handler, this.size = 260});

  final WheelHandler handler;
  final double size;

  /// Degrees of rotation per step (15 steps per full turn).
  static const stepDegrees = 24.0;

  @override
  State<ClickWheel> createState() => _ClickWheelState();
}

class _ClickWheelState extends State<ClickWheel> {
  double? _lastAngle;
  double _accum = 0;

  double get _r => widget.size / 2;
  double get _centerR => widget.size * 0.19;

  Offset _rel(Offset local) => local - Offset(_r, _r);

  void _tick(int steps) {
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
    widget.handler.onRotate(steps);
  }

  void _panStart(DragStartDetails d) {
    final p = _rel(d.localPosition);
    _lastAngle = p.distance > _centerR ? math.atan2(p.dy, p.dx) : null;
    _accum = 0;
  }

  void _panUpdate(DragUpdateDetails d) {
    if (_lastAngle == null) return;
    final p = _rel(d.localPosition);
    if (p.distance < _centerR * 0.6) return;
    final a = math.atan2(p.dy, p.dx);
    var delta = a - _lastAngle!;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;
    _lastAngle = a;
    _accum += delta * 180 / math.pi;
    final steps = (_accum / ClickWheel.stepDegrees).truncate();
    if (steps != 0) {
      _accum -= steps * ClickWheel.stepDegrees;
      _tick(steps); // clockwise = positive
    }
  }

  /// Which zone a tap hit: 'center', 'menu', 'next', 'bottom', 'prev'.
  String? _zone(Offset local) {
    final p = _rel(local);
    if (p.distance > _r) return null;
    if (p.distance <= _centerR) return 'center';
    final deg = math.atan2(p.dy, p.dx) * 180 / math.pi; // 0 = right, 90 = bottom
    if (deg >= -135 && deg < -45) return 'menu';
    if (deg >= -45 && deg < 45) return 'next';
    if (deg >= 45 && deg < 135) return 'bottom';
    return 'prev';
  }

  void _tap(TapUpDetails d) {
    final h = widget.handler;
    HapticFeedback.lightImpact();
    switch (_zone(d.localPosition)) {
      case 'center':
        h.onCenter();
      case 'menu':
        h.onMenu();
      case 'next':
        h.onNext();
      case 'bottom':
        h.onBottom();
      case 'prev':
        h.onPrev();
    }
  }

  void _longPress(LongPressStartDetails d) {
    HapticFeedback.mediumImpact();
    switch (_zone(d.localPosition)) {
      case 'center':
        widget.handler.onCenterLong();
      case 'bottom':
        widget.handler.onBottomLong();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = Palette.of(context);
    final s = widget.size;
    return Listener(
      onPointerSignal: (e) {
        if (e is PointerScrollEvent && e.scrollDelta.dy != 0) {
          _tick(e.scrollDelta.dy > 0 ? 1 : -1);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _panStart,
        onPanUpdate: _panUpdate,
        onPanEnd: (_) => _lastAngle = null,
        onTapUp: _tap,
        onLongPressStart: _longPress,
        child: SizedBox(
          width: s,
          height: s,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pal.wheel,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: s * 0.07,
                child: Text('MENU',
                    style: TextStyle(
                        color: pal.wheelLabel,
                        fontWeight: FontWeight.w700,
                        fontSize: s * 0.055,
                        letterSpacing: 1.5)),
              ),
              Positioned(
                left: s * 0.06,
                child: Icon(Icons.skip_previous_rounded, color: pal.wheelLabel, size: s * 0.1),
              ),
              Positioned(
                right: s * 0.06,
                child: Icon(Icons.skip_next_rounded, color: pal.wheelLabel, size: s * 0.1),
              ),
              Positioned(
                bottom: s * 0.06,
                child: Icon(Icons.replay_rounded, color: pal.wheelLabel, size: s * 0.09),
              ),
              Container(
                width: _centerR * 2,
                height: _centerR * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pal.wheelCenter,
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
