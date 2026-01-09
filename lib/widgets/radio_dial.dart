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
        Container(
          height: 30, 
          decoration: BoxDecoration(
            color: Colors.grey[900], // Slightly softer than black
            borderRadius: BorderRadius.circular(12), // <--- NEW: Matches your Cards
            border: Border.all(color: Colors.grey[700]!),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(double.infinity, 30),
                painter: _RulerPainter(color: Colors.white24),
              ),
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

class _RulerPainter extends CustomPainter {
  final Color color;
  _RulerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    const int tickCount = 20;
    final double step = size.width / tickCount;

    for (int i = 0; i <= tickCount; i++) {
      double x = i * step;
      double height = (i % 5 == 0) ? 15.0 : 6.0; 
      canvas.drawLine(Offset(x, size.height), Offset(x, size.height - height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
    final Paint paint = Paint()..color = color..strokeWidth = 2;
    
    canvas.drawLine(
      Offset(center.dx, center.dy - 14), 
      Offset(center.dx, center.dy + 14), 
      paint
    );
  }
}