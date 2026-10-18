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
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
    child: Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF173D3B), Color(0xFF18213A)],
        ),
        border: Border.all(color: AppTheme.primary.withAlpha(110)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withAlpha(45),
            blurRadius: 28,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Icon(
        Icons.account_balance_wallet_rounded,
        size: widget.size * 0.48,
        color: AppTheme.primary,
      ),
    ),
  );
}
