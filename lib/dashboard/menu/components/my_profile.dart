import 'dart:async';

import 'package:chatspot/dashboard/menu/components/account_menu.dart';
import 'package:chatspot/services/user/profile_service.dart';
import 'package:chatspot/services/user/user_profile.dart';
import 'package:chatspot/services/user/user_repository.dart';
import 'package:chatspot/views/common/user_avatar.dart';
import 'package:flutter/material.dart';

enum _UsernameState { unchanged, invalid, checking, available, taken, error }

class ProfilePage extends StatefulWidget {
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static final RegExp _usernamePattern = RegExp(r'^[a-z0-9_]{5,20}$');

  final _formKey = GlobalKey<FormState>();
  late final UserProfile? _initial = UserRepository.instance.me.value;
  late final TextEditingController _nameController =
      TextEditingController(text: _initial?.name ?? '');
  late final TextEditingController _usernameController = TextEditingController(
      text: (_initial?.username ?? '').replaceFirst('@', ''));

  _UsernameState _usernameState = _UsernameState.unchanged;
  Timer? _usernameDebounce;
  int _checkGeneration = 0;
  bool _saving = false;

  String get _originalUsername => _initial?.username ?? '';

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final username = value.trim().toLowerCase();
    if ('@$username' == _originalUsername) {
      setState(() => _usernameState = _UsernameState.unchanged);
      return;
    }
    if (!_usernamePattern.hasMatch(username)) {
      setState(() => _usernameState = _UsernameState.invalid);
      return;
    }
    setState(() => _usernameState = _UsernameState.checking);
    // One small read once typing pauses, not one per keystroke.
    final generation = ++_checkGeneration;
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      _UsernameState result;
      try {
        result = await ProfileService.isUsernameTaken('@$username')
            ? _UsernameState.taken
            : _UsernameState.available;
      } catch (_) {
        result = _UsernameState.error;
      }
      if (mounted && generation == _checkGeneration) {
        setState(() => _usernameState = result);
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();
    final username = '@${_usernameController.text.trim().toLowerCase()}';
    final usernameChanged = username != _originalUsername;
    if (usernameChanged && _usernameState != _UsernameState.available) return;

    setState(() => _saving = true);
    await ProfileService.update(
      name: name != _initial?.name ? name : null,
      username: usernameChanged ? username : null,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Profile updated'),
      behavior: SnackBarBehavior.floating,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canSave = !_saving &&
        (_usernameState == _UsernameState.unchanged ||
            _usernameState == _UsernameState.available);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // This removes the back button
        title: const Text('My profile'),
        actions: [
          TextButton(
            onPressed: canSave ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: ValueListenableBuilder<UserProfile?>(
        valueListenable: UserRepository.instance.me,
        builder: (context, me, _) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(
                      name: me?.displayName ?? '',
                      photoUrl: me?.photoUrl ?? '',
                      radius: 48,
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: IconButton.filled(
                        icon: const Icon(Icons.camera_alt, size: 18),
                        tooltip: 'Change photo',
                        onPressed: () => changeProfilePhoto(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Enter your name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixText: '@',
                  prefixIcon: const Icon(Icons.alternate_email),
                  border: const OutlineInputBorder(),
                  helperText: _usernameHelper(),
                  helperStyle: TextStyle(color: _usernameColor(scheme)),
                  suffixIcon: _usernameSuffix(scheme),
                ),
                onChanged: _onUsernameChanged,
              ),
              const SizedBox(height: 24),
              _readOnlyTile(Icons.cake_outlined, 'Date of birth', me?.dob),
              _readOnlyTile(Icons.wc_outlined, 'Gender', me?.gender),
              _readOnlyTile(Icons.mail_outline, 'Email', me?.email),
            ],
          ),
        ),
      ),
    );
  }

  String? _usernameHelper() {
    switch (_usernameState) {
      case _UsernameState.unchanged:
        return _originalUsername.isEmpty
            ? 'Pick a username so friends can find you'
            : null;
      case _UsernameState.invalid:
        return '5–20 characters: lowercase letters, numbers and _';
      case _UsernameState.checking:
        return 'Checking…';
      case _UsernameState.available:
        return 'Available';
      case _UsernameState.taken:
        return 'Already taken';
      case _UsernameState.error:
        return "Couldn't check right now. Try again.";
    }
  }

  Color? _usernameColor(ColorScheme scheme) {
    switch (_usernameState) {
      case _UsernameState.available:
        return Colors.green.shade600;
      case _UsernameState.invalid:
      case _UsernameState.taken:
      case _UsernameState.error:
        return scheme.error;
      default:
        return null;
    }
  }

  Widget? _usernameSuffix(ColorScheme scheme) {
    switch (_usernameState) {
      case _UsernameState.checking:
        return const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
        );
      case _UsernameState.available:
        return Icon(Icons.check_circle, color: Colors.green.shade600);
      case _UsernameState.taken:
      case _UsernameState.invalid:
        return Icon(Icons.error_outline, color: scheme.error);
      default:
        return null;
    }
  }

  Widget _readOnlyTile(IconData icon, String label, String? value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label, style: Theme.of(context).textTheme.labelMedium),
      subtitle: Text(
        (value == null || value.isEmpty) ? 'Not specified' : value,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
