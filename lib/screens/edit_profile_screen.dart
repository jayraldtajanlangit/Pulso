import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_model.dart';
import '../providers/profile_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _fieldsFilled = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(profileControllerProvider.notifier)
          .loadProfile(widget.userId),
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _fillFields(ProfileModel? profile) {
    if (!_fieldsFilled && profile != null) {
      _displayNameController.text = profile.displayName ?? '';
      _usernameController.text = profile.username ?? '';
      _bioController.text = profile.bio ?? '';
      _fieldsFilled = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);

    ref.listen(
      profileControllerProvider.select((s) => s.profile),
      (_, profile) => _fillFields(profile),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              key: const Key('saveProfileButton'),
              onPressed: state.isLoading
                  ? null
                  : () async {
                      await ref
                          .read(profileControllerProvider.notifier)
                          .updateProfile(
                            userId: widget.userId,
                            displayName: _displayNameController.text.trim(),
                            username: _usernameController.text.trim(),
                            bio: _bioController.text.trim(),
                          );
                      if (context.mounted) Navigator.pop(context);
                    },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: state.isLoading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar
            Center(
              child: GestureDetector(
                key: const Key('uploadAvatarButton'),
                onTap: () => ref
                    .read(profileControllerProvider.notifier)
                    .pickAndUploadAvatar(widget.userId),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      key: const Key('profileAvatar'),
                      radius: 50,
                      backgroundColor: const Color(0xFFE0E7FF),
                      backgroundImage: state.profile?.avatarUrl != null
                          ? NetworkImage(state.profile!.avatarUrl!)
                          : null,
                      onBackgroundImageError: state.profile?.avatarUrl != null
                          ? (_, _) {}
                          : null,
                      child: state.profile?.avatarUrl == null
                          ? Text(
                              _displayNameController.text.isNotEmpty
                                  ? _displayNameController.text[0].toUpperCase()
                                  : _usernameController.text.isNotEmpty
                                  ? _usernameController.text[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            )
                          : null,
                    ),
                    if (state.isUploading)
                      const Positioned.fill(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.black26,
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      )
                    else
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Tap to change avatar',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Display name',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('displayNameField'),
              controller: _displayNameController,
              decoration: InputDecoration(
                hintText: 'Your display name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 20),
            // Username
            const Text(
              'Username',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('usernameField'),
              controller: _usernameController,
              decoration: InputDecoration(
                hintText: 'Your username',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Bio
            const Text(
              'Bio',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('bioField'),
              controller: _bioController,
              decoration: InputDecoration(
                hintText: 'Tell us about yourself...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              maxLines: 3,
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                state.errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
