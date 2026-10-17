import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class HeroBalanceWidget extends StatefulWidget {
  final double remaining;
  final double earned;
  final double received;
  final double advanceRepaid;
  final VoidCallback onAddPayment;

  const HeroBalanceWidget({
    super.key,
    required this.remaining,
    required this.earned,
    required this.received,
    required this.advanceRepaid,
    required this.onAddPayment,
  });

  @override
  State<HeroBalanceWidget> createState() => _HeroBalanceWidgetState();
}

class _HeroBalanceWidgetState extends State<HeroBalanceWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnim;
  late Animation<double> _fadeAnim;

  double get _progress {
    if (widget.earned <= 0) return 0;
    return ((widget.received + widget.advanceRepaid) / widget.earned).clamp(
      0.0,
      1.0,
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progressAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(HeroBalanceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remaining != widget.remaining ||
        oldWidget.earned != widget.earned ||
        oldWidget.advanceRepaid != widget.advanceRepaid) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceM,
          AppTheme.spaceL,
          AppTheme.spaceM,
          0,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spaceL),
              decoration: BoxDecoration(
                color: AppTheme.glassBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Column(
                children: [
                  // Label
                  const Text(
                    'ᲓᲐᲠᲩᲔᲜᲘᲚᲘ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceS),
                  // Hero amount — use FittedBox to prevent overflow on small screens
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) {
                      final displayVal = widget.remaining * _progressAnim.value;
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: _formatInt(displayVal),
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                  height: 1.0,
                                ),
                              ),
                              const TextSpan(
                                text: ' ₾',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppTheme.spaceM),
                  // Progress arc
                  AnimatedBuilder(
                    animation: _progressAnim,
                    builder: (_, __) =>
                        _ProgressArc(progress: _progress * _progressAnim.value),
                  ),
                  const SizedBox(height: AppTheme.spaceM),
                  // Progress labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ProgressLabel(
                        label: 'გამომუშავებული',
                        value: widget.earned,
                        color: AppTheme.textSecondary,
                      ),
                      _ProgressLabel(
                        label: 'დაფარული',
                        value: widget.received + widget.advanceRepaid,
                        color: AppTheme.primary,
                        alignRight: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceM),
                  // Add payment button — only show when there is something to pay
                  if (widget.earned > 0 && widget.remaining > 0)
                    GestureDetector(
                      onTap: widget.onAddPayment,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(26),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
                          border: Border.all(
                            color: AppTheme.primary.withAlpha(77),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: AppTheme.primary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'გადახდის დამატება',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatInt(double v) {
    final i = v.toInt();
    if (i >= 1000) {
      return i.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
    }
    return i.toString();
  }
}

class _ProgressArc extends StatelessWidget {
  final double progress;

  const _ProgressArc({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: AppTheme.glassBackground,
          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
        ),
      ),
    );
  }
}

class _ProgressLabel extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool alignRight;

  const _ProgressLabel({
    required this.label,
    required this.value,
    required this.color,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        crossAxisAlignment: alignRight
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            AppTheme.formatGel(value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
