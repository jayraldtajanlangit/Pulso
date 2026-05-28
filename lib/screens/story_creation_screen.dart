import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/auth_providers.dart';
import '../providers/story_providers.dart';
import '../story/music_clip_model.dart';

class StoryCreationScreen extends ConsumerStatefulWidget {
  const StoryCreationScreen({super.key});

  @override
  ConsumerState<StoryCreationScreen> createState() =>
      _StoryCreationScreenState();
}

class _StoryCreationScreenState extends ConsumerState<StoryCreationScreen> {
  File? _imageFile;
  MusicClipModel? _selectedClip;
  final _audioPlayer = AudioPlayer();
  String? _playingClipId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(storyControllerProvider.notifier).loadMusicClips();
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _imageFile = File(picked.path));
  }

  Future<void> _previewClip(MusicClipModel clip) async {
    if (_playingClipId == clip.id) {
      await _audioPlayer.stop();
      setState(() => _playingClipId = null);
      return;
    }
    await _audioPlayer.stop();
    await _audioPlayer.play(UrlSource(clip.audioUrl));
    setState(() => _playingClipId = clip.id);
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingClipId = null);
    });
  }

  Future<void> _shareStory() async {
    final image = _imageFile;
    if (image == null) return;
    final userId = ref.read(authControllerProvider).session?.userId;
    if (userId == null) return;

    await ref.read(storyControllerProvider.notifier).createStory(
          userId: userId,
          imageFile: image,
          musicClipId: _selectedClip?.id,
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final musicClips =
        ref.watch(storyControllerProvider.select((s) => s.musicClips));
    final isPosting =
        ref.watch(storyControllerProvider.select((s) => s.isPosting));
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Create Story',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFD1D5DB),
                    width: 1.5,
                  ),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 40, color: Color(0xFF9CA3AF)),
                          SizedBox(height: 8),
                          Text(
                            'Tap to pick a photo',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.music_note_outlined, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Add Music (optional)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                if (_selectedClip != null) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _selectedClip = null),
                    child: const Text(
                      'Remove',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            if (musicClips.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              ...musicClips.map(
                (clip) => _MusicClipTile(
                  clip: clip,
                  isSelected: _selectedClip?.id == clip.id,
                  isPlaying: _playingClipId == clip.id,
                  onTap: () => setState(() {
                    _selectedClip =
                        _selectedClip?.id == clip.id ? null : clip;
                  }),
                  onPreview: () => _previewClip(clip),
                  primaryColor: primary,
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: (_imageFile != null && !isPosting) ? _shareStory : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Share Story',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicClipTile extends StatelessWidget {
  const _MusicClipTile({
    required this.clip,
    required this.isSelected,
    required this.isPlaying,
    required this.onTap,
    required this.onPreview,
    required this.primaryColor,
  });

  final MusicClipModel clip;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPreview;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? primaryColor : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.music_note,
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clip.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${clip.artist} · ${clip.durationSeconds}s',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isPlaying
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline,
                color: isSelected ? primaryColor : const Color(0xFF6B7280),
              ),
              onPressed: onPreview,
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: primaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}
