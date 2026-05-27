import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A small, reusable circular avatar.
///
/// Shows the cached network image when [avatarUrl] is non-null, otherwise
/// falls back to an initial derived from [displayName] (or '?' when empty).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.avatarUrl,
    this.displayName,
    this.radius = 18,
    this.backgroundColor = const Color(0xFFE5E7EB),
    this.foregroundColor = const Color(0xFF6B7280),
  });

  final String? avatarUrl;
  final String? displayName;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;

  String get _initial {
    final name = displayName?.trim();
    if (name == null || name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = avatarUrl != null && avatarUrl!.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: hasImage ? CachedNetworkImageProvider(avatarUrl!) : null,
      child: hasImage
          ? null
          : Text(
              _initial,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: radius * 0.7,
                color: foregroundColor,
              ),
            ),
    );
  }
}
