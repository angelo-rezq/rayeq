import 'dart:ui' show FontVariation;

import 'brand_wordmark.dart';

import 'package:flutter/material.dart';

import 'brand_paths.dart';
import 'localization.dart';
import 'royal_theme.dart';
export 'brand_paths.dart' show RayeqBrandMark;

class RayeqAnimatedBrand extends StatefulWidget {
  const RayeqAnimatedBrand({super.key});
  @override
  State<RayeqAnimatedBrand> createState() => _RayeqAnimatedBrandState();
}

class _RayeqAnimatedBrandState extends State<RayeqAnimatedBrand>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, __) => RayeqBrandLockup(
      progress: MediaQuery.disableAnimationsOf(context) ? 1 : controller.value,
    ),
  );
}

class RayeqBrandLockup extends StatelessWidget {
  final double progress;
  const RayeqBrandLockup({super.key, this.progress = 1});
  @override
  Widget build(BuildContext context) {
    final en = appLocale.value.languageCode == 'en';
    final opacity = ((progress - .67) / .33).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RayeqBrandMark(progress: (progress / .85).clamp(0.0, 1.0), size: 156),
        const SizedBox(height: 24),
        Opacity(
          opacity: opacity,
          child: Column(
            children: [
              if (en)
                const Text(
                  'RAYEQ',
                  style: TextStyle(
                    fontFamily: 'BrandLatin',
                    fontSize: 43,
                    letterSpacing: 5.5,
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                    color: royalText,
                  ),
                )
              else
                const RayeqArabicWordmark(width: 142),
              const SizedBox(height: 16),
              const SizedBox(width: 286, child: BrandTagline()),
            ],
          ),
        ),
      ],
    );
  }
}

class RayeqStartup extends StatefulWidget {
  final Widget child;
  const RayeqStartup({super.key, required this.child});
  @override
  State<RayeqStartup> createState() => _RayeqStartupState();
}

class _RayeqStartupState extends State<RayeqStartup>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..forward();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, __) {
      final done =
          controller.isCompleted || MediaQuery.disableAnimationsOf(context);
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(offstage: !done, child: widget.child),
          if (!done)
            Scaffold(
              body: Center(
                child: RayeqBrandLockup(
                  progress: (controller.value * 2800 / 2600).clamp(0.0, 1.0),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class BrandTagline extends StatelessWidget {
  final bool compact;
  const BrandTagline({super.key, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final en = appLocale.value.languageCode == 'en';
    return Text(
      en ? 'Your barber, at your door' : 'حلاقك لحد باب بيتك',
      textAlign: compact ? TextAlign.start : TextAlign.center,
      maxLines: compact ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: en ? 'BrandLatin' : 'BrandArabic',
        fontSize: compact ? 12 : (en ? 13 : 15),
        height: 1.7,
        fontWeight: en ? FontWeight.w300 : FontWeight.w400,
        fontVariations: [
          FontVariation('wght', en ? 300 : 400),
          FontVariation('wdth', 100),
        ],
        letterSpacing: en ? (compact ? .6 : 1.7) : 0,
        wordSpacing: en ? 0 : (compact ? 1.4 : 4.5),
        color: compact ? royalGold : royalMuted,
      ),
    );
  }
}
