import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_model.dart';
import '../providers/profile_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
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

    // Populate text fields once the profile loads.
    ref.listen(
      profileControllerProvider.select((s) => s.profile),
      (_, profile) => _fillFields(profile),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AvatarSection(
                    userId: widget.userId,
                    avatarUrl: state.profile?.avatarUrl,
                    isUploading: state.isUploading,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    key: const Key('displayNameField'),
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('usernameField'),
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixText: '@',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('bioField'),
                    controller: _bioController,
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  if (state.errorMessage != null) ...[
                    Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    key: const Key('saveProfileButton'),
                    onPressed: state.isLoading
                        ? null
                        : () => ref
                              .read(profileControllerProvider.notifier)
                              .updateProfile(
                                userId: widget.userId,
                                displayName:
                                    _displayNameController.text.trim(),
                                username: _usernameController.text.trim(),
                                bio: _bioController.text.trim(),
                              ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AvatarSection extends ConsumerWidget {
  const _AvatarSection({
    required this.userId,
    required this.avatarUrl,
    required this.isUploading,
  });

  final String userId;
  final String? avatarUrl;
  final bool isUploading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            key: const Key('profileAvatar'),
            radius: 60,
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? const Icon(Icons.person, size: 60)
                : null,
          ),
          if (isUploading)
            const Positioned.fill(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.black38,
                child: CircularProgressIndicator(),
              ),
            )
          else
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: IconButton(
                key: const Key('uploadAvatarButton'),
                icon: const Icon(Icons.camera_alt, size: 18),
                color: Theme.of(context).colorScheme.onPrimary,
                onPressed: () => ref
                    .read(profileControllerProvider.notifier)
                    .pickAndUploadAvatar(userId),
              ),
            ),
        ],
      ),
    );
  }
}
