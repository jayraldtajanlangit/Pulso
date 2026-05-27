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

    ref.listen(postControllerProvider.select((s) => s.postCreated), (_, created) {
      if (created && mounted) Navigator.of(context).pop();
    });

    final imageBytes = state.pendingImageBytes;

    return Scaffold(
      appBar: AppBar(title: const Text('New Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageBytes == null)
              OutlinedButton.icon(
                key: const Key('addImageButton'),
                onPressed: () =>
                    ref.read(postControllerProvider.notifier).pickImage(),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add Photo'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(100),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else
              Stack(
                key: const Key('postImagePreview'),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      imageBytes,
                      width: double.infinity,
                      height: 260,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      key: const Key('removeImageButton'),
                      onTap: () => ref
                          .read(postControllerProvider.notifier)
                          .clearPendingImage(),
                      child: const CircleAvatar(
                        backgroundColor: Colors.black54,
                        radius: 14,
                        child: Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
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
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
