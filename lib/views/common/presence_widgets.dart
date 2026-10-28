import 'package:chatspot/services/friend/friend_models.dart';
import 'package:chatspot/services/friend/friend_repository.dart';
import 'package:chatspot/services/presence/presence_service.dart';
import 'package:chatspot/views/chat/chat_main/main_chat_screen.dart';
import 'package:flutter/material.dart';

import 'user_avatar.dart';

const Color _activeGreen = Color(0xFF31A24C);

/// Rebuilds when presence changes or a minute passes.
class _PresenceBuilder extends StatelessWidget {
  const _PresenceBuilder({required this.builder});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  Widget build(BuildContext context) {
    final service = PresenceService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([service.presence, service.clock]),
      builder: (context, _) => builder(context, DateTime.now()),
    );
  }
}

/// [UserAvatar] with a green dot when the user is active now, or a small
/// "5m" badge when they left less than an hour ago.
class PresenceAvatar extends StatelessWidget {
  const PresenceAvatar({
    super.key,
    required this.uid,
    required this.name,
    required this.photoUrl,
    this.radius = 24,
    this.onTap,
  });

  final String uid;
  final String name;
  final String photoUrl;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = UserAvatar(
        name: name, photoUrl: photoUrl, radius: radius, onTap: onTap);
    return _PresenceBuilder(builder: (context, now) {
      final presence = PresenceService.instance.of(uid);
      final ring = Theme.of(context).scaffoldBackgroundColor;
      Widget? indicator;
      if (presence.isActiveNow(now)) {
        final size = radius * 0.55;
        indicator = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _activeGreen,
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: radius > 20 ? 2.5 : 2),
          ),
        );
      } else if (presence.minutesAway(now) case final minutes?) {
        indicator = Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFDDF5E1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ring, width: 2),
          ),
          child: Text(
            '${minutes}m',
            style: const TextStyle(
              color: Color(0xFF1E7B34),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }
      if (indicator == null) return avatar;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(right: -2, bottom: -2, child: indicator),
        ],
      );
    });
  }
}

/// "Active now" / "Active 5m ago", e.g. under a name in an app bar.
/// Shows [fallback] (or nothing) when unknown or more than a week ago.
class PresenceLabel extends StatelessWidget {
  const PresenceLabel({super.key, required this.uid, this.style, this.fallback});

  final String uid;
  final TextStyle? style;
  final String? fallback;

  @override
  Widget build(BuildContext context) {
    return _PresenceBuilder(builder: (context, now) {
      final presence = PresenceService.instance.of(uid);
      final label = presence.label(now) ?? fallback;
      if (label == null || label.isEmpty) return const SizedBox.shrink();
      final active = presence.isActiveNow(now);
      return Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: (style ?? Theme.of(context).textTheme.bodySmall)?.copyWith(
          color: active ? _activeGreen : null,
          fontWeight: active ? FontWeight.w600 : null,
        ),
      );
    });
  }
}

/// Friends who are active now or were in the last hour, newest first, for
/// the top of the chat list. Hidden when there are none.
class ActiveFriendsStrip extends StatelessWidget {
  const ActiveFriendsStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FriendsState>(
      valueListenable: FriendRepository.instance.state,
      builder: (context, friends, _) => _PresenceBuilder(
        builder: (context, now) {
          final service = PresenceService.instance;
          final recent = friends.friends.where((f) {
            final presence = service.of(f.uid);
            return presence.isActiveNow(now) ||
                presence.minutesAway(now) != null;
          }).toList()
            ..sort((a, b) {
              final pa = service.of(a.uid), pb = service.of(b.uid);
              final activeA = pa.isActiveNow(now), activeB = pb.isActiveNow(now);
              if (activeA != activeB) return activeA ? -1 : 1;
              return pb.lastActive!.compareTo(pa.lastActive!);
            });
          if (recent.isEmpty) return const SizedBox.shrink();

          final theme = Theme.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 92,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: recent.length,
                  itemBuilder: (context, index) {
                    final friend = recent[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserChatScreen(
                              userId: friend.uid,
                              userName: friend.displayName),
                        ),
                      ),
                      child: SizedBox(
                        width: 72,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PresenceAvatar(
                              uid: friend.uid,
                              name: friend.displayName,
                              photoUrl: friend.photoUrl,
                              radius: 26,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              friend.displayName.split(' ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
            ],
          );
        },
      ),
    );
  }
}
