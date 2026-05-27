import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_model.dart';
import '../providers/follow_providers.dart';
import '../providers/supabase_providers.dart';
import 'profile_avatar.dart';

Future<ProfileModel?> showUserPickerModal(BuildContext context) {
  return showModalBottomSheet<ProfileModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _UserPickerContent(),
  );
}

class _UserPickerContent extends ConsumerStatefulWidget {
  const _UserPickerContent();

  @override
  ConsumerState<_UserPickerContent> createState() => _UserPickerContentState();
}

class _UserPickerContentState extends ConsumerState<_UserPickerContent> {
  List<ProfileModel> _profiles = [];
  List<ProfileModel> _filtered = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFollowing();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowing() async {
    try {
      final client = ref.read(supabaseClientProvider);
      if (client == null) return;

      final ids =
          ref.read(followControllerProvider).followingByCurrentUser.toList();
      if (ids.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await client
          .from('profiles')
          .select(
              'id, username, display_name, avatar_url, bio, created_at, updated_at')
          .inFilter('id', ids);

      final profiles = (response as List)
          .map((r) => ProfileModel.fromMap(r as Map<String, dynamic>))
          .toList();

      setState(() {
        _profiles = profiles;
        _filtered = profiles;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _profiles
          .where((p) =>
              (p.username ?? '').toLowerCase().contains(query) ||
              (p.displayName ?? '').toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Send to',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No users found',
                          style: TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final profile = _filtered[i];
                          return ListTile(
                            leading: ProfileAvatar(
                              avatarUrl: profile.avatarUrl,
                              displayName: profile.displayName ??
                                  profile.username ??
                                  '?',
                              radius: 20,
                            ),
                            title: Text(
                              profile.username ?? profile.displayName ?? '?',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: profile.displayName != null
                                ? Text(profile.displayName!)
                                : null,
                            onTap: () => Navigator.of(context).pop(profile),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
