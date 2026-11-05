import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/starlit/prefs.dart';
import 'package:fl_clash/starlit/theme.dart';
import 'package:fl_clash/starlit/widgets.dart';
import 'package:flutter/widgets.dart';

class StarlitOnboarding extends StatefulWidget {
  const StarlitOnboarding({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<StarlitOnboarding> createState() => _StarlitOnboardingState();
}

class _StarlitOnboardingState extends State<StarlitOnboarding> {
  final _controller = PageController();
  int _index = 0;

  static const _slides = <({String title, String body, _SlideKind kind})>[
    (
      title: 'YouTube, Instagram, ChatGPT',
      body: 'Открываются как обычно. YouTube — без навязчивой рекламы.',
      kind: _SlideKind.services,
    ),
    (
      title: 'Одна кнопка',
      body:
          'Starlit сам выбирает быстрый сервер и переключается, если пинг просел.',
      kind: _SlideKind.power,
    ),
    (
      title: 'Поддержка в Telegram',
      body:
          'Если что-то не работает, напишите в @starlitvpnbot. Отвечаем быстро.',
      kind: _SlideKind.support,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await StarlitPrefs.setOnboardingDone();
    widget.onDone();
  }

  void _next() {
    if (_index >= _slides.length - 1) {
      unawaited(_finish());
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StarlitScaffold(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => unawaited(_finish()),
                        child: const Text(
                          'Пропустить',
                          style: TextStyle(
                            color: StarlitColors.muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _slides.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (_, i) {
                        final slide = _slides[i];
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            StarlitGlowIcon(child: _SlideGlyph(slide.kind)),
                            const SizedBox(height: 36),
                            Text(
                              slide.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: StarlitColors.text,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              slide.body,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: StarlitColors.muted,
                                fontSize: 16,
                                height: 1.4,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  StarlitPageDots(count: _slides.length, index: _index),
                  const SizedBox(height: 22),
                  StarlitPrimaryButton(
                    label: _index == _slides.length - 1 ? 'Начать' : 'Далее',
                    onPressed: _next,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _SlideKind { services, power, support }

class _SlideGlyph extends StatelessWidget {
  const _SlideGlyph(this.kind);

  final _SlideKind kind;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(40, 40),
      painter: _GlyphPainter(kind),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.kind);

  final _SlideKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF041018)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    switch (kind) {
      case _SlideKind.services:
        canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), 14, p);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(size.width * 0.5, size.height * 0.5),
            width: 14,
            height: 28,
          ),
          p,
        );
        canvas.drawLine(
          Offset(size.width * 0.22, size.height * 0.5),
          Offset(size.width * 0.78, size.height * 0.5),
          p,
        );
      case _SlideKind.power:
        canvas.drawLine(
          Offset(size.width * 0.5, size.height * 0.18),
          Offset(size.width * 0.5, size.height * 0.48),
          p,
        );
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(size.width * 0.5, size.height * 0.56),
            radius: 11,
          ),
          -1.1,
          5.5,
          false,
          p,
        );
      case _SlideKind.support:
        canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.38), 8, p);
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(size.width * 0.5, size.height * 0.72),
            width: 22,
            height: 16,
          ),
          math.pi,
          math.pi,
          false,
          p,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
