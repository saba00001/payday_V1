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
                colors: [Color(0xFF080C14), Color(0xFF060A12)],
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
                    AppTheme.secondary.withAlpha(20),
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
