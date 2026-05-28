import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_model.dart';
import '../providers/auth_providers.dart';
import '../providers/follow_providers.dart';
import '../widgets/profile_avatar.dart';

class NewMessageScreen extends ConsumerStatefulWidget {
  const NewMessageScreen({super.key});

  @override
  ConsumerState<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends ConsumerState<NewMessageScreen> {
  final _searchController = TextEditingController();
  List<ProfileModel> _all = [];
  List<ProfileModel> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);
    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = ref.read(authControllerProvider).session?.userId;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final repo = ref.read(followRepositoryProvider);
      final results = await Future.wait([
        repo.getFollowingProfiles(userId),
        repo.getFollowerProfiles(userId),
      ]);
      final deduped = _dedupe([...results[0], ...results[1]]);
      if (!mounted) return;
      setState(() {
        _all = deduped;
        _filtered = _applyFilter(deduped, _searchController.text);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ProfileModel> _dedupe(List<ProfileModel> list) {
    final seen = <String, ProfileModel>{};
    for (final p in list) {
      seen.putIfAbsent(p.id, () => p);
    }
    return seen.values.toList();
  }

  void _onSearch() {
    setState(() => _filtered = _applyFilter(_all, _searchController.text));
  }

  List<ProfileModel> _applyFilter(List<ProfileModel> list, String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return list;
    return list.where((p) {
      return (p.username ?? '').toLowerCase().contains(q) ||
          (p.displayName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text(
          'New message',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Text(
                  'To: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_filtered.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'No accounts found',
                  style: TextStyle(color: Color(0xFF9CA3AF)),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final profile = _filtered[i];
                  final name = profile.username ?? profile.displayName ?? '?';
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: ProfileAvatar(
                      avatarUrl: profile.avatarUrl,
                      displayName: name,
                      radius: 24,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: profile.displayName != null &&
                            profile.displayName != profile.username
                        ? Text(
                            profile.displayName!,
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          )
                        : null,
                    onTap: () => Navigator.pop(context, profile),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
