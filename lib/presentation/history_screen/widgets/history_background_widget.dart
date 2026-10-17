import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class HistoryBackgroundWidget extends StatelessWidget {
  const HistoryBackgroundWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox.expand(
      child: Stack(
        children: [
          Container(color: AppTheme.backgroundDark),
          Positioned(
            bottom: -size.height * 0.05,
            left: -size.width * 0.1,
            child: Container(
              width: size.width * 0.5,
              height: size.width * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondary.withAlpha(15),
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
