import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_model.dart';
import '../providers/auth_providers.dart';
import '../providers/follow_providers.dart';
import '../widgets/follow_button.dart';
import '../widgets/profile_avatar.dart';
import 'profile_screen.dart';

enum FollowListMode { followers, following }

class FollowListScreen extends ConsumerStatefulWidget {
  const FollowListScreen({
    super.key,
    required this.userId,
    required this.mode,
  });

  final String userId;
  final FollowListMode mode;

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure follow state is loaded so FollowButtons show correct state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUserId =
          ref.read(authControllerProvider).session?.userId;
      if (currentUserId != null) {
        ref
            .read(followControllerProvider.notifier)
            .loadFollowingIds(currentUserId);
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final profilesAsync = widget.mode == FollowListMode.following
        ? ref.watch(followingProfilesProvider(widget.userId))
        : ref.watch(followerProfilesProvider(widget.userId));
    final title = widget.mode == FollowListMode.following
        ? 'Following'
        : 'Followers';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(
                'Failed to load $title',
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        data: (profiles) {
          if (profiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Color(0xFFD1D5DB),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.mode == FollowListMode.following
                        ? 'Not following anyone yet'
                        : 'No followers yet',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              widget.mode == FollowListMode.following
                  ? ref.invalidate(followingProfilesProvider(widget.userId))
                  : ref.invalidate(followerProfilesProvider(widget.userId));
            },
            child: ListView.separated(
              itemCount: profiles.length,
              separatorBuilder: (context, i) => const Divider(
                height: 1,
                thickness: 0.5,
                indent: 72,
                color: Color(0xFFF3F4F6),
              ),
              itemBuilder: (context, i) =>
                  _UserTile(profile: profiles[i]),
            ),
          );
        },
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.profile});

  final ProfileModel profile;

  String get _displayName =>
      profile.displayName?.isNotEmpty == true
          ? profile.displayName!
          : profile.username ?? profile.id.substring(0, 8);

  String? get _username =>
      profile.username?.isNotEmpty == true ? '@${profile.username}' : null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: GestureDetector(
        onTap: () => _openProfile(context),
        child: ProfileAvatar(
          avatarUrl: profile.avatarUrl,
          displayName: _displayName,
          radius: 22,
        ),
      ),
      title: GestureDetector(
        onTap: () => _openProfile(context),
        child: Text(
          _displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      subtitle: _username != null
          ? Text(
              _username!,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
              ),
            )
          : null,
      trailing: FollowButton(
        targetUserId: profile.id,
        compact: true,
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(userId: profile.id),
      ),
    );
  }
}
