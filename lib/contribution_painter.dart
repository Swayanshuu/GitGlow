import 'dart:math';
import 'package:flutter/material.dart';

class ContributionDay {
  final String date;
  final int count;
  final Color color;

  ContributionDay({
    required this.date,
    required this.count,
    required this.color,
  });
}

class GitHubStats {
  final String username;
  final int totalContributions;
  final int currentStreak;
  final int longestStreak;
  final String longestStreakRange;
  final String todayDate;
  final List<ContributionDay> days;

  GitHubStats({
    required this.username,
    required this.totalContributions,
    required this.currentStreak,
    required this.longestStreak,
    required this.longestStreakRange,
    required this.todayDate,
    required this.days,
  });
}

class ContributionPainter extends CustomPainter {
  final GitHubStats? stats;
  final double animationValue;
  final String? errorMessage;

  final Map<String, double>? layoutOffsets;
  final String? fontFamily;

  ContributionPainter({
    this.stats,
    required this.animationValue,
    this.errorMessage,
    this.layoutOffsets,
    this.fontFamily,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    if (errorMessage != null) {
      _drawError(canvas, size, errorMessage!);
      return;
    }

    if (stats == null) {
      _drawLoading(canvas, size);
      return;
    }

    final centerY = size.height / 2;
    final offsets =
        layoutOffsets ??
        {'date': -400, 'map': -180, 'total': 130, 'user': 250, 'info': 450};

    final mapTop = centerY + (offsets['map'] ?? -180);

    // Grid height = 40% of screen so there's always room for the text below
    final maxGridH = (size.height * 0.40).clamp(
      80.0,
      size.height - mapTop - 200,
    );

    // Total text 120px below grid bottom, but never off screen
    final actualTotalY = (mapTop + maxGridH + 120).clamp(0.0, size.height - 80);

    _drawGrid(canvas, size, mapTop, maxGridH);
    _drawStats(canvas, size, actualTotalY, fontFamily ?? 'sans-serif');
  }

  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawColor(Colors.black, BlendMode.src);
  }

  void _drawLoading(Canvas canvas, Size size) {
    // Hidden loading state to keep background clean behind main screens
  }

  void _drawError(Canvas canvas, Size size, String error) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: error,
        style: TextStyle(
          color: Colors.redAccent.withOpacity(0.8),
          fontSize: 16,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: size.width - 60);
    textPainter.paint(
      canvas,
      Offset(size.width / 2 - textPainter.width / 2, size.height / 2),
    );
  }

  void _drawGrid(Canvas canvas, Size size, double topOffset, double maxHeight) {
    final days = stats!.days;
    const double padding = 60;
    const double gap = 5;
    final double availableWidth = size.width - (padding * 2);

    // Auto-calculate box size so ALL weeks fit within maxHeight
    final int numWeeks = (days.length / 7).ceil();
    final double boxFromHeight = (maxHeight - (numWeeks - 1) * gap) / numWeeks;
    final double boxFromWidth = (availableWidth - (6 * gap)) / 7;
    // Use the smaller of the two so it fits both horizontally and vertically
    final double boxSize = boxFromHeight < boxFromWidth
        ? boxFromHeight
        : boxFromWidth;

    canvas.save();
    canvas.translate(padding, topOffset);

    // Number of columns is fixed (7)
    // Number of rows (weeks) will fill the rest of the screen
    for (int i = 0; i < days.length; i++) {
      // Vertical layout: rows are weeks, columns are days
      // To make it fill the screen, we need to decide how many days to show.
      // GitHub gives 1 year (~372 days).

      final int weekIndex = i ~/ 7;
      final int dayOfWeek = i % 7;

      final double left = dayOfWeek * (boxSize + gap);
      final double top = weekIndex * (boxSize + gap);

      // Stop drawing if we exceed the bottom limit, give more space for zoom
      if (top + boxSize > size.height) break;

      final day = days[i];
      final paint = Paint()
        ..color = day.count == 0 ? const Color(0xFF161B22) : day.color
        ..style = PaintingStyle.fill;

      // Scale down dots to 60% of cell size — keeps spacing clean
      // Fixed small dot size regardless of cell size
      const double dotSize = 2.0;
      final double offset = (boxSize - dotSize) / 2;
      final rect = Rect.fromLTWH(left + offset, top + offset, dotSize, dotSize);

      // Smooth sparkle — sin² for soft breathing glow, small phase per dot
      if (day.count > 0) {
        final double raw = sin(animationValue * 2 * pi + i * 0.08);
        final double pulse = raw * raw; // sin² stays in [0,1], always positive
        final double glowSize = 0.5 + (2.0 * pulse); // gentle 0.5–2.5 range
        final double glowOpacity =
            0.5 + (0.5 * pulse); // subtle brightness breathing

        paint.color = day.color.withOpacity(glowOpacity);
        paint.maskFilter = MaskFilter.blur(BlurStyle.outer, glowSize);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          paint,
        );
        // Reset for solid dot
        paint.color = day.color;
        paint.maskFilter = null;
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
    canvas.restore();
  }

  void _drawStats(Canvas canvas, Size size, double totalY, String font) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Yearly Total — drawn at the computed y position right below the grid
    textPainter.text = TextSpan(
      text:
          '${stats!.totalContributions} contributions in ${DateTime.now().year}',
      style: TextStyle(
        color: Colors.white.withOpacity(0.6),
        fontSize: 18,
        fontFamily: font,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size.width / 2 - textPainter.width / 2, totalY),
    );

    // Developer credit 30px below the total text
    final creditPainter = TextPainter(
      text: TextSpan(
        text: '~Developed By Swayanshu',
        style: TextStyle(
          color: Colors.white.withOpacity(0.25),
          fontSize: 11,
          letterSpacing: 1.5,
          fontFamily: font,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    creditPainter.paint(
      canvas,
      Offset(size.width / 2 - creditPainter.width / 2, totalY + 30),
    );
  }

  @override
  bool shouldRepaint(covariant ContributionPainter old) {
    // Only repaint when animation ticks OR data changes — never redundantly
    return old.animationValue != animationValue ||
        old.stats != stats ||
        old.errorMessage != errorMessage ||
        old.layoutOffsets != layoutOffsets ||
        old.fontFamily != fontFamily;
  }
}
