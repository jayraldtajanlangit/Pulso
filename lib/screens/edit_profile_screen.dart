import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_model.dart';
import '../providers/profile_providers.dart';
import '../widgets/profile_avatar.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _fieldsFilled = false;

  // Initial values captured the moment we hydrate from the DB. Used to
  // detect whether the user has made any unsaved edits.
  String _initialUsername = '';
  String _initialDisplayName = '';
  String _initialBio = '';

  @override
  void initState() {
    super.initState();
    // If the profile is already cached, populate fields immediately so the
    // user sees their current values on first frame (rather than waiting
    // for ref.listen to fire on a state change that may never come).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cached =
          ref.read(profileControllerProvider(widget.userId)).profile;
      if (cached != null) _fillFields(cached);
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _fillFields(ProfileModel? profile) {
    if (!_fieldsFilled && profile != null) {
      _usernameController.text = profile.username ?? '';
      _displayNameController.text = profile.displayName ?? '';
      _bioController.text = profile.bio ?? '';
      _initialUsername = _usernameController.text;
      _initialDisplayName = _displayNameController.text;
      _initialBio = _bioController.text;
      _fieldsFilled = true;
    }
  }

  bool get _hasUnsavedChanges {
    return _usernameController.text.trim() != _initialUsername.trim() ||
        _displayNameController.text.trim() != _initialDisplayName.trim() ||
        _bioController.text.trim() != _initialBio.trim();
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedChanges) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved edits. If you leave now, your changes will be '
          'lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _save() async {
    await ref
        .read(profileControllerProvider(widget.userId).notifier)
        .updateProfile(
          username: _usernameController.text.trim(),
          displayName: _displayNameController.text.trim(),
          bio: _bioController.text.trim(),
        );
    if (!mounted) return;
    // Sync the initial-values baseline so the discard dialog doesn't fire
    // on the way out after a successful save.
    _initialUsername = _usernameController.text;
    _initialDisplayName = _displayNameController.text;
    _initialBio = _bioController.text;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider(widget.userId));

    ref.listen(
      profileControllerProvider(widget.userId).select((s) => s.profile),
      (_, profile) => _fillFields(profile),
    );

    if (state.isLoading &&
        state.profile == null &&
        state.errorMessage == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Edit Profile',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscard();
        if (shouldPop && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Edit Profile',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () async {
              final shouldPop = await _confirmDiscard();
              if (shouldPop && mounted) Navigator.pop(context);
            },
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                key: const Key('saveProfileButton'),
                onPressed: state.isLoading ? null : _save,
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
              if (state.errorMessage != null) ...[
                Text(
                  state.errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              Center(
                child: GestureDetector(
                  key: const Key('uploadAvatarButton'),
                  onTap: () => ref
                      .read(profileControllerProvider(widget.userId).notifier)
                      .pickAndUploadAvatar(),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      ProfileAvatar(
                        key: const Key('profileAvatar'),
                        avatarUrl: state.profile?.avatarUrl,
                        displayName: _displayNameController.text.isNotEmpty
                            ? _displayNameController.text
                            : _usernameController.text,
                        radius: 50,
                        backgroundColor: const Color(0xFFE0E7FF),
                      ),
                      if (state.isUploading)
                        const Positioned.fill(
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.black26,
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          ),
                        )
                      else
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
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
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Your name',
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
              const Text(
                'Username',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('usernameField'),
                controller: _usernameController,
                onChanged: (_) => setState(() {}),
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
              const Text(
                'Bio',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('bioField'),
                controller: _bioController,
                onChanged: (_) => setState(() {}),
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
            ],
          ),
        ),
      ),
    );
  }
}
