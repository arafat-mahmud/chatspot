import 'package:chatspot/dashboard/menu/components/my_profile.dart';
import 'package:chatspot/dashboard/menu/components/settings/settings.dart';
import 'package:chatspot/dashboard/menu/components/settings/theme.dart';
import 'package:chatspot/services/app_messenger.dart';
import 'package:chatspot/services/cloudinary_service.dart';
import 'package:chatspot/services/friend/friend_models.dart';
import 'package:chatspot/services/friend/friend_repository.dart';
import 'package:chatspot/services/session/session_service.dart';
import 'package:chatspot/services/user/profile_service.dart';
import 'package:chatspot/services/user/user_profile.dart';
import 'package:chatspot/services/user/user_repository.dart';
import 'package:chatspot/views/chat/chat_main/image_handler.dart';
import 'package:chatspot/views/common/state_views.dart';
import 'package:chatspot/views/common/user_avatar.dart';
import 'package:chatspot/views/friends/friend_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// The signed-in user's photo, name and username, shared by the drawer and
/// the Menu page. Reads the live profile from memory: opening either costs
/// nothing.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: UserRepository.instance.me,
      builder: (context, me, _) {
        if (me == null) {
          return const SizedBox(height: 96);
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    name: me.displayName,
                    photoUrl: me.photoUrl,
                    radius: 32,
                    onTap: me.photoUrl.isEmpty
                        ? null
                        : () => ImageHandler.showFullScreenImage(
                            context, me.photoUrl),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Material(
                      color: theme.colorScheme.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => changeProfilePhoto(context),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.camera_alt,
                              size: 14, color: theme.colorScheme.onPrimary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: me.hasUsername
                          ? () {
                              Clipboard.setData(
                                  ClipboardData(text: me.username));
                              AppMessenger.show('Username copied');
                            }
                          : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              me.hasUsername ? me.username : 'No username yet',
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                          if (me.hasUsername) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.copy,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// My Profile, Friends, Settings and Log out.
class AccountMenuItems extends StatelessWidget {
  const AccountMenuItems({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('My profile'),
          onTap: () => _push(context, ProfilePage()),
        ),
        ValueListenableBuilder<FriendsState>(
          valueListenable: FriendRepository.instance.state,
          builder: (context, friends, _) => ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Friends'),
            trailing: friends.unseenCount > 0
                ? CountBadge(friends.unseenCount)
                : null,
            // New requests waiting: open straight on the Requests tab.
            onTap: () => _push(
              context,
              FriendListScreen(initialTab: friends.unseenCount > 0 ? 1 : 0),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Settings'),
          onTap: () =>
              _push(context, SettingsPage(setTheme: ThemeService.changeTheme)),
        ),
        const Divider(),
        ListTile(
          leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
          title: Text('Log out',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          onTap: () => _confirmSignOut(context),
        ),
      ],
    );
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll stop receiving messages and calls on this "
            'device until you sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    // The auth gate returns to the sign-in screen by itself.
    if (confirmed == true) await SessionService.instance.signOut();
  }
}

/// Picks, uploads and saves a new profile photo. Saving copies the URL to
/// friends' lists and chats (see [ProfileService.update]).
Future<void> changeProfilePhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ],
      ),
    ),
  );
  if (source == null) return;

  final image = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1024,
    imageQuality: 85,
  );
  if (image == null) return;

  AppMessenger.show('Uploading photo…');
  try {
    final url = await CloudinaryService().uploadProfilePicture(image.path);
    await ProfileService.update(photoUrl: url);
    AppMessenger.show('Profile photo updated');
  } catch (e) {
    debugPrint('changeProfilePhoto: $e');
    AppMessenger.error("Couldn't update your photo");
  }
}
