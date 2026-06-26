import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Avatar người chơi — ảnh Google nếu có, không thì chữ cái đầu.
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String displayName;
  final double radius;

  const UserAvatar({
    super.key,
    this.photoUrl,
    required this.displayName,
    this.radius = 20,
  });

  static const _fallbackBg = Color(0xFFFFD54F);
  static const _fallbackFg = Color(0xFF5D0000);

  String get _initial {
    final name = displayName.trim();
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    final size = radius * 2;

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: _fallbackBg,
        child: ClipOval(
          child: kIsWeb
              ? Image.network(
                  url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  cacheWidth: (size * 2).round(),
                  errorBuilder: (_, _, _) => _initialBadge(),
                )
              : CachedNetworkImage(
                  imageUrl: url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  memCacheWidth: (size * 2).round(),
                  placeholder: (_, _) => _initialBadge(),
                  errorWidget: (_, _, _) => _initialBadge(),
                ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: _fallbackBg,
      child: _initialBadge(),
    );
  }

  Widget _initialBadge() {
    return Text(
      _initial,
      style: TextStyle(
        color: _fallbackFg,
        fontWeight: FontWeight.bold,
        fontSize: radius * 0.8,
      ),
    );
  }
}
