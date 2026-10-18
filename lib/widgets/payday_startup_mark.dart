import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PaydayStartupMark extends StatefulWidget {
  final double size;

  const PaydayStartupMark({super.key, this.size = 72});

  @override
  State<PaydayStartupMark> createState() => _PaydayStartupMarkState();
}

class _PaydayStartupMarkState extends State<PaydayStartupMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceElevated,
            AppTheme.surfaceDark,
            AppTheme.backgroundDark,
          ],
        ),
        border: Border.all(color: AppTheme.primary.withAlpha(132)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withAlpha(34),
            blurRadius: 30,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppTheme.secondary.withAlpha(22),
            blurRadius: 42,
            offset: const Offset(8, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.size * 0.68,
            height: widget.size * 0.68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primary.withAlpha(37),
                  AppTheme.accentBlue.withAlpha(9),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Icon(
            Icons.calendar_month_rounded,
            size: widget.size * 0.48,
            color: AppTheme.primary,
          ),
          Positioned(
            right: widget.size * 0.16,
            bottom: widget.size * 0.17,
            child: Container(
              width: widget.size * 0.26,
              height: widget.size * 0.26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.warning, Color(0xFFEAA84B)],
                ),
                border: Border.all(color: AppTheme.surfaceDark, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.warning.withAlpha(52),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                Icons.payments_rounded,
                size: widget.size * 0.14,
                color: AppTheme.backgroundDark,
              ),
            ),
          ),
        ],
      ),
    ),
    builder: (context, child) {
      final pulse = Curves.easeInOut.transform(_controller.value);
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..rotateZ((pulse - 0.5) * 0.035)
          ..scaleByDouble(0.97 + pulse * 0.05, 0.97 + pulse * 0.05, 1, 1),
        child: child,
      );
    },
  );
}
