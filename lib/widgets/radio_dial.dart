import 'package:flutter/material.dart';

class RadioDial extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final Color activeColor;

  const RadioDial({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.activeColor = Colors.redAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The Dial Container - REDUCED HEIGHT TO 30 (50%)
        Container(
          height: 30, 
          decoration: BoxDecoration(
            color: Colors.grey[900], 
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[700]!),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1))],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // LAYER 1: The Ruler
              CustomPaint(
                size: const Size(double.infinity, 30),
                painter: _RulerPainter(color: Colors.white24),
              ),
              
              // LAYER 2: The Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 0, 
                  thumbShape: _NeedleThumbShape(color: activeColor), 
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 8), 
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  tickMarkShape: SliderTickMarkShape.noTickMark,
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- PAINTER: SCALED DOWN RULER ---
class _RulerPainter extends CustomPainter {
  final Color color;
  _RulerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.0; // Thinner lines for smaller scale

    const int tickCount = 20;
    final double step = size.width / tickCount;

    for (int i = 0; i <= tickCount; i++) {
      double x = i * step;
      // Height scaled down: 5th line is 15px, others are 6px
      double height = (i % 5 == 0) ? 15.0 : 6.0; 
      canvas.drawLine(Offset(x, size.height), Offset(x, size.height - height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- SHAPE: SCALED DOWN NEEDLE ---
class _NeedleThumbShape extends SliderComponentShape {
  final Color color;
  const _NeedleThumbShape({required this.color});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(2, 30);

  @override
  void paint(PaintingContext context, Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final Paint paint = Paint()..color = color..strokeWidth = 2; // Slightly thinner needle
    
    // Draw vertical line +/- 14px from center (fits in 30px height)
    canvas.drawLine(
      Offset(center.dx, center.dy - 14), 
      Offset(center.dx, center.dy + 14), 
      paint
    );
  }
}