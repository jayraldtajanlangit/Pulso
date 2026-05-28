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

  /// Always read from the live controller state so optimistic updates
  /// (reactions, view counts) flow back into the viewer without forcing
  /// the user to leave and re-open the story.
  List<StoryModel> get _currentStories {
    final live = ref.read(storyControllerProvider).storiesByUser;
    return live[_userIds[_userIndex]] ??
        widget.storiesByUser[_userIds[_userIndex]] ??
        [];
  }

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
    // Subscribe to the story controller so reactions / views update the UI
    // immediately without needing to leave and re-open the viewer.
    ref.watch(storyControllerProvider);

    final story = _currentStory;
    final stories = _currentStories;
    final currentUserId =
        ref.watch(authControllerProvider.select((s) => s.session?.userId));
    final isOwnStory = story.userId == currentUserId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: StoryReactionOverlay(
        child: GestureDetector(
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
              )
            else if (currentUserId != null)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 12,
                right: 12,
                child: _StoryReactionButton(
                  storyId: story.id,
                  storyOwnerId: story.userId,
                  currentUserId: currentUserId,
                  isLiked: story.isLikedByMe,
                ),
              ),
          ],
        ),
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

class _StoryReactionButton extends ConsumerStatefulWidget {
  const _StoryReactionButton({
    required this.storyId,
    required this.storyOwnerId,
    required this.currentUserId,
    required this.isLiked,
  });

  final String storyId;
  final String storyOwnerId;
  final String currentUserId;
  final bool isLiked;

  @override
  ConsumerState<_StoryReactionButton> createState() =>
      _StoryReactionButtonState();
}

class _StoryReactionButtonState extends ConsumerState<_StoryReactionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    final wasLiked = widget.isLiked;
    _animController.forward(from: 0);
    if (!wasLiked) StoryReactionOverlay.showHeart(context);

    try {
      await ref.read(storyControllerProvider.notifier).toggleReaction(
            storyId: widget.storyId,
            currentUserId: widget.currentUserId,
            storyOwnerId: widget.storyOwnerId,
          );
      if (!mounted) return;
      // Show a clean confirmation chip only on a fresh react.
      if (!wasLiked) {
        StoryReactionOverlay.showToast(context, 'Reaction sent');
      }
    } catch (_) {
      // Errors are already handled in the controller (state reverts).
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          shape: BoxShape.circle,
        ),
        child: ScaleTransition(
          scale: _scale,
          child: Icon(
            widget.isLiked ? Icons.favorite : Icons.favorite_border,
            color: widget.isLiked ? Colors.red : Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

/// Inherited entry-point so the reaction button can show a big floating
/// heart in the centre of the screen. The viewer wraps its body in
/// [StoryReactionOverlay] and exposes the controller via [of].
class StoryReactionOverlay extends StatefulWidget {
  const StoryReactionOverlay({super.key, required this.child});

  final Widget child;

  /// Trigger the floating heart animation from a descendant widget.
  static void showHeart(BuildContext context) {
    context.findAncestorStateOfType<_StoryReactionOverlayState>()?.show();
  }

  /// Show a brief, clean confirmation toast (a dark rounded chip near the
  /// bottom of the viewer). Use for tiny status messages like "Reaction sent".
  static void showToast(BuildContext context, String message) {
    context
        .findAncestorStateOfType<_StoryReactionOverlayState>()
        ?.showToast(message);
  }

  @override
  State<StoryReactionOverlay> createState() => _StoryReactionOverlayState();
}

class _StoryReactionOverlayState extends State<StoryReactionOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  bool _visible = false;

  // Toast (small chip) overlay state, separate from the floating heart.
  String? _toastMessage;
  late final AnimationController _toastCtrl;
  late final Animation<double> _toastOpacity;
  late final Animation<Offset> _toastOffset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 20),
    ]).animate(_ctrl);
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_ctrl);
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _visible = false);
      }
    });

    _toastCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _toastOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 64),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 24),
    ]).animate(_toastCtrl);
    _toastOffset = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _toastCtrl, curve: Curves.easeOutCubic),
    );
    _toastCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _toastMessage = null);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _toastCtrl.dispose();
    super.dispose();
  }

  void show() {
    setState(() => _visible = true);
    _ctrl.forward(from: 0);
  }

  void showToast(String message) {
    setState(() => _toastMessage = message);
    _toastCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_visible)
          IgnorePointer(
            child: Center(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, child) => Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: child,
                  ),
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Color(0xFFED4956),
                  size: 120,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 28),
                  ],
                ),
              ),
            ),
          ),
        if (_toastMessage != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 90,
            child: IgnorePointer(
              child: Center(
                child: AnimatedBuilder(
                  animation: _toastCtrl,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _toastOpacity.value,
                      child: SlideTransition(
                        position: _toastOffset,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: Color(0xFFED4956),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _toastMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
