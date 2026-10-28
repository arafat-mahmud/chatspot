import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Profile photo with an initial-letter fallback. Images are decoded at the
/// displayed size and cached on disk, so lists scroll smoothly and photos
/// aren't downloaded twice.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    this.radius = 24,
    this.onTap,
  });

  final String name;
  final String photoUrl;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = radius * 2;
    final initial = Text(
      name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
      style: TextStyle(
        fontSize: radius * 0.8,
        fontWeight: FontWeight.w600,
        color: scheme.onPrimaryContainer,
      ),
    );
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      child: initial,
    );

    final Widget avatar = photoUrl.isEmpty
        ? fallback
        : ClipOval(
            child: CachedNetworkImage(
              imageUrl: photoUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback,
            ),
          );

    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }
}
