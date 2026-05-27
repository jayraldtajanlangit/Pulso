import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/post_providers.dart';

class PostCreationScreen extends ConsumerStatefulWidget {
  const PostCreationScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<PostCreationScreen> createState() =>
      _PostCreationScreenState();
}

class _PostCreationScreenState extends ConsumerState<PostCreationScreen> {
  final _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Reset the controller state so postCreated flag starts false.
    Future.microtask(
      () => ref.read(postControllerProvider.notifier).clearPendingImage(),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postControllerProvider);

    // Pop on successful post creation.
    ref.listen(postControllerProvider.select((s) => s.postCreated), (_, created) {
      if (created && mounted) Navigator.of(context).pop();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('New Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ImagePreviewSection(
              imageBytes: state.pendingImageBytes,
              onPickImage: () =>
                  ref.read(postControllerProvider.notifier).pickImage(),
              onClearImage: () =>
                  ref.read(postControllerProvider.notifier).clearPendingImage(),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('postContentField'),
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: "What's on your mind?",
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            if (state.errorMessage != null) ...[
              Text(
                state.errorMessage!,
                key: const Key('postErrorMessage'),
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              key: const Key('submitPostButton'),
              onPressed: state.isCreating
                  ? null
                  : () => ref
                        .read(postControllerProvider.notifier)
                        .createPost(
                          userId: widget.userId,
                          caption: _contentController.text,
                        ),
              child: state.isCreating
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreviewSection extends StatelessWidget {
  const _ImagePreviewSection({
    required this.imageBytes,
    required this.onPickImage,
    required this.onClearImage,
  });

  final dynamic imageBytes; // Uint8List?
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;

  @override
  Widget build(BuildContext context) {
    if (imageBytes != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              imageBytes,
              key: const Key('postImagePreview'),
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          IconButton(
            key: const Key('removeImageButton'),
            icon: const CircleAvatar(
              backgroundColor: Colors.black54,
              radius: 16,
              child: Icon(Icons.close, color: Colors.white, size: 16),
            ),
            onPressed: onClearImage,
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      key: const Key('addImageButton'),
      onPressed: onPickImage,
      icon: const Icon(Icons.add_photo_alternate_outlined),
      label: const Text('Add Photo'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(100),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
