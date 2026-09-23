import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../application/meal_capture_notifier.dart';
import '../application/meal_capture_state.dart';
import '../data/meal_repository.dart';
import '../domain/meal_type.dart';
import 'widgets/food_item_edit_tile.dart';

class MealCaptureScreen extends ConsumerStatefulWidget {
  const MealCaptureScreen({super.key, this.pickImageOverride});

  final Future<Uint8List?> Function(ImageSource source)? pickImageOverride;

  @override
  ConsumerState<MealCaptureScreen> createState() => _MealCaptureScreenState();
}

class _MealCaptureScreenState extends ConsumerState<MealCaptureScreen> {
  MealType? _selectedType;

  @override
  void initState() {
    super.initState();
    // Bir önceki, tamamlanmamış çekimden kalan Reviewing/Error durumunu
    // temizle — kullanıcı geri gidip yeniden girdiğinde her zaman temiz
    // (Idle) bir ekranla karşılaşsın.
    Future.microtask(() => ref.read(mealCaptureProvider.notifier).reset());
  }

  Future<Uint8List?> _pickImage(ImageSource source) async {
    if (widget.pickImageOverride != null) return widget.pickImageOverride!(source);
    final file = await ImagePicker().pickImage(source: source);
    if (file == null) return null;
    return file.readAsBytes();
  }

  Future<void> _capture(ImageSource source) async {
    final type = _selectedType;
    if (type == null) return;
    final bytes = await _pickImage(source);
    if (bytes == null) return;
    if (!mounted) return;
    await ref
        .read(mealCaptureProvider.notifier)
        .startCapture(mealType: type, photoBytes: bytes);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MealCaptureState>(mealCaptureProvider, (previous, next) {
      if (next is MealCaptureSaved) {
        ref.read(mealCaptureProvider.notifier).reset();
        if (context.mounted) context.pop();
      }
    });

    final state = ref.watch(mealCaptureProvider);

    return Scaffold(
      key: const Key('meal_capture_screen'),
      appBar: AppBar(title: Text('nutrition.capture_title'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(MealCaptureState state) {
    return switch (state) {
      MealCaptureIdle() => _buildIdle(),
      MealCaptureUploading() => Center(child: _loadingLabel('nutrition.uploading'.tr())),
      MealCaptureAnalyzing() => Center(child: _loadingLabel('nutrition.analyzing'.tr())),
      MealCaptureReviewing() => _buildReviewing(state),
      MealCaptureSaving() => Center(child: _loadingLabel('nutrition.saving'.tr())),
      MealCaptureSaved() => const SizedBox.shrink(),
      MealCaptureUploadError() => _buildUploadError(),
    };
  }

  Widget _loadingLabel(String text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [const CircularProgressIndicator(), const SizedBox(height: 12), Text(text)],
    );
  }

  Widget _buildIdle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('nutrition.select_meal_type'.tr()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: MealType.values.map((type) {
            return ChoiceChip(
              key: Key('meal_type_${type.name}_chip'),
              label: Text('nutrition.meal_type_${type.name}'.tr()),
              selected: _selectedType == type,
              onSelected: (_) => setState(() => _selectedType = type),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          key: const Key('capture_take_photo_button'),
          onPressed: _selectedType == null ? null : () => _capture(ImageSource.camera),
          child: Text('nutrition.take_photo'.tr()),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('capture_gallery_button'),
          onPressed: _selectedType == null ? null : () => _capture(ImageSource.gallery),
          child: Text('nutrition.pick_from_gallery'.tr()),
        ),
      ],
    );
  }

  Widget _buildUploadError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('nutrition.upload_error'.tr(), key: const Key('capture_upload_error')),
        const SizedBox(height: 12),
        ElevatedButton(
          key: const Key('capture_retry_button'),
          onPressed: () => ref.read(mealCaptureProvider.notifier).reset(),
          child: Text('nutrition.retry'.tr()),
        ),
      ],
    );
  }

  Widget _buildReviewing(MealCaptureReviewing state) {
    final notifier = ref.read(mealCaptureProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.aiFailureReason != AiFailureReason.none)
          Container(
            key: const Key('capture_ai_failure_banner'),
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Text(
              state.aiFailureReason == AiFailureReason.quotaExceeded
                  ? 'nutrition.ai_quota_exceeded'.tr()
                  : 'nutrition.ai_unavailable'.tr(),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              return FoodItemEditTile(
                key: state.itemKeys[index],
                item: state.items[index],
                index: index,
                onChanged: (updated) => notifier.updateItem(index, updated),
                onRemove: () => notifier.removeItem(index),
              );
            },
          ),
        ),
        OutlinedButton(
          key: const Key('capture_add_item_button'),
          onPressed: notifier.addManualItem,
          child: Text('nutrition.add_item_manually'.tr()),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          key: const Key('capture_save_button'),
          onPressed: state.canSave ? notifier.confirmSave : null,
          child: Text('nutrition.save'.tr()),
        ),
      ],
    );
  }
}
