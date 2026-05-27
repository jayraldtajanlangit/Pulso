import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/story_providers.dart';
import '../story/story_model.dart';

class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.storiesByUser,
    required this.initialUserId,
  });

  final Map<String, List<StoryModel>> storiesByUser;
  final String initialUserId;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with TickerProviderStateMixin {
  late final List<String> _userIds;
  late int _userIndex;
  int _storyIndex = 0;
  AnimationController? _progressController;
  final _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _userIds = widget.storiesByUser.keys.toList();
    _userIndex = _userIds.indexOf(widget.initialUserId);
    if (_userIndex < 0) _userIndex = 0;
    _showStory();
  }

  @override
  void dispose() {
    _progressController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  List<StoryModel> get _currentStories =>
      widget.storiesByUser[_userIds[_userIndex]] ?? [];

  StoryModel get _currentStory => _currentStories[_storyIndex];

  void _showStory() {
    _progressController?.dispose();
    _audioPlayer.stop();

    final story = _currentStory;

    final viewerId = ref.read(authControllerProvider).session?.userId;
    if (viewerId != null) {
      ref.read(storyControllerProvider.notifier).recordView(
            storyId: story.id,
            viewerId: viewerId,
          );
    }

    if (story.musicClip != null) {
      _audioPlayer.play(UrlSource(story.musicClip!.audioUrl));
    }

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      })
      ..forward();

    setState(() {});
  }

  void _next() {
    if (_storyIndex < _currentStories.length - 1) {
      setState(() => _storyIndex++);
      _showStory();
    } else if (_userIndex < _userIds.length - 1) {
      setState(() {
        _userIndex++;
        _storyIndex = 0;
      });
      _showStory();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previous() {
    if (_storyIndex > 0) {
      setState(() => _storyIndex--);
      _showStory();
    } else if (_userIndex > 0) {
      setState(() {
        _userIndex--;
        _storyIndex = 0;
      });
      _showStory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = _currentStory;
    final stories = _currentStories;
    final currentUserId =
        ref.watch(authControllerProvider.select((s) => s.session?.userId));
    final isOwnStory = story.userId == currentUserId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 2) {
            _previous();
          } else {
            _next();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: story.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => const ColoredBox(color: Colors.black),
              errorWidget: (_, _, _) =>
                  const ColoredBox(color: Color(0xFF1E293B)),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: Row(
                children: List.generate(stories.length, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: i < _storyIndex
                            ? Container(height: 2.5, color: Colors.white)
                            : i == _storyIndex
                                ? AnimatedBuilder(
                                    animation: _progressController!,
                                    builder: (_, _) => LinearProgressIndicator(
                                      value: _progressController!.value,
                                      minHeight: 2.5,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.4),
                                      valueColor:
                                          const AlwaysStoppedAnimation(
                                              Colors.white),
                                    ),
                                  )
                                : Container(
                                    height: 2.5,
                                    color:
                                        Colors.white.withValues(alpha: 0.4),
                                  ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: story.authorAvatarUrl != null
                        ? NetworkImage(story.authorAvatarUrl!)
                        : null,
                    child: story.authorAvatarUrl == null
                        ? const Icon(Icons.person, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story.authorUsername ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _relativeTime(story.createdAt),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (story.musicClip != null)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story.musicClip!.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '♪ ${story.musicClip!.artist}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (isOwnStory)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                right: 16,
                child: Row(
                  children: [
                    const Icon(Icons.remove_red_eye_outlined,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${story.viewCount}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
