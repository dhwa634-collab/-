// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shared branded content for every in-app bottom notification.
class BrandedNoticeContent extends StatelessWidget {
  final Widget child;

  const BrandedNoticeContent({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 25,
            height: 25,
            child: SvgPicture.asset(
              'assets/brand/app_icon.svg',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(child: child),
      ],
    );
  }
}
