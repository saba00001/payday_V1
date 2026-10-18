import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class HomeBackgroundWidget extends StatelessWidget {
  const HomeBackgroundWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox.expand(
      child: Stack(
        children: [
          // Deep background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.backgroundDark,
                  AppTheme.surfaceDark,
                  AppTheme.backgroundDark,
                ],
              ),
            ),
          ),
          // Top-left ambient orb — cyan
          Positioned(
            top: -size.height * 0.1,
            left: -size.width * 0.2,
            child: Container(
              width: size.width * 0.7,
              height: size.width * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withAlpha(34),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom-right ambient orb — violet
          Positioned(
            bottom: -size.height * 0.1,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.6,
              height: size.width * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondary.withAlpha(27),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Mid subtle orb
          Positioned(
            top: size.height * 0.35,
            right: size.width * 0.1,
            child: Container(
              width: size.width * 0.4,
              height: size.width * 0.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accentBlue.withAlpha(18),
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
