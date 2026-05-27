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
      () => ref.read(postControllerProvider.notifier).clearPendingImages(),
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

    return Scaffold(
      appBar: AppBar(title: const Text('New Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MultiImagePicker(
              images: state.pendingImages
                  .map((img) => img.bytes)
                  .toList(),
              onAdd: () =>
                  ref.read(postControllerProvider.notifier).addImages(),
              onRemove: (i) =>
                  ref.read(postControllerProvider.notifier).removeImage(i),
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

class _MultiImagePicker extends StatelessWidget {
  const _MultiImagePicker({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  final List<dynamic> images; // List<Uint8List>
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return OutlinedButton.icon(
        key: const Key('addImageButton'),
        onPressed: onAdd,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Add Photos'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(100),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              if (i == images.length) {
                return GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 90,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Color(0xFF9CA3AF),
                      size: 32,
                    ),
                  ),
                );
              }

              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ColoredBox(
                      color: Colors.black,
                      child: Image.memory(
                        images[i],
                        width: 90,
                        height: 110,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => onRemove(i),
                      child: const CircleAvatar(
                        backgroundColor: Colors.black54,
                        radius: 12,
                        child: Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                  if (i == 0)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Cover',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${images.length} photo${images.length == 1 ? '' : 's'} selected',
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
        ),
      ],
    );
  }
}
