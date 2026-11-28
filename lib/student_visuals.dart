import 'package:flutter/material.dart';

const List<Color> _studentAvatarPalette = [
  Color(0xFFD94B55), Color(0xFF2878D0), Color(0xFF21966B),
  Color(0xFF8156C8), Color(0xFFE18A2D), Color(0xFF008F9C),
  Color(0xFFB34D91), Color(0xFF687BC7),
];

Color studentAvatarColor(String name) {
  final normalized = name.trim().toLowerCase();
  var hash = 0;
  for (final unit in normalized.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return _studentAvatarPalette[hash % _studentAvatarPalette.length];
}

String studentAvatarInitial(String name) {
  final value = name.trim();
  return value.isEmpty ? '؟' : String.fromCharCode(value.runes.first).toUpperCase();
}

class StudentAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;
  const StudentAvatar({super.key, required this.name, this.imageUrl, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final hasImage = url.startsWith('http://') || url.startsWith('https://');
    return CircleAvatar(
      radius: radius,
      backgroundColor: studentAvatarColor(name),
      backgroundImage: hasImage ? NetworkImage(url) : null,
      child: hasImage ? null : Text(
        studentAvatarInitial(name),
        style: TextStyle(color: Colors.white, fontSize: radius * .92,
          fontWeight: FontWeight.w900),
      ),
    );
  }
}

class BrandedDialogTitle extends StatelessWidget {
  final Widget? title;
  const BrandedDialogTitle({super.key, this.title});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 52, height: 52,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: const Color(0xFF17365D),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFF3B8BEB).withValues(alpha: .65)),
        ),
        child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded,
            color: Colors.white, size: 31)),
      ),
      if (title != null) ...[
        const SizedBox(height: 13),
        DefaultTextStyle.merge(
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          child: title!,
        ),
      ],
    ],
  );
}
