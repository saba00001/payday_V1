import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class CalendarBackgroundWidget extends StatelessWidget {
  const CalendarBackgroundWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox.expand(
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D1422), Color(0xFF080D18)],
              ),
            ),
          ),
          Positioned(
            top: -size.height * 0.05,
            right: -size.width * 0.15,
            child: Container(
              width: size.width * 0.5,
              height: size.width * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondary.withAlpha(30),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.08,
            left: -size.width * 0.2,
            child: Container(
              width: size.width * 0.58,
              height: size.width * 0.58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withAlpha(18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
