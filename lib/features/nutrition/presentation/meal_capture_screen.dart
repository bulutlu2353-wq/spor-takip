import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/text_case.dart';
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

  /// Düzeltme adımındaki önizleme için seçilen fotoğraf (R2 spec §4.3).
  Uint8List? _photoBytes;

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
    setState(() => _photoBytes = bytes);
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
    final title = state is MealCaptureReviewing
        ? 'nutrition.meal_type_${state.mealType.name}'.tr()
        : 'nutrition.capture_title'.tr();

    return Scaffold(
      key: const Key('meal_capture_screen'),
      appBar: AppBar(title: Text(title)),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = _selectedType != null;
    return ListView(
      children: [
        Text(
          upperCaseFor('nutrition.which_meal'.tr(), context.locale.languageCode),
          style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MealType.values.map((type) {
            final selected = _selectedType == type;
            return ChoiceChip(
              key: Key('meal_type_${type.name}_chip'),
              label: Text(
                'nutrition.meal_type_${type.name}'.tr(),
                style: TextStyle(
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
              ),
              selected: selected,
              showCheckmark: false,
              selectedColor: scheme.primary,
              onSelected: (_) => setState(() => _selectedType = type),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _CaptureTile(
          key: const Key('capture_take_photo_button'),
          icon: Icons.photo_camera_outlined,
          title: 'nutrition.take_photo'.tr(),
          subtitle: 'nutrition.take_photo_hint'.tr(),
          primary: true,
          onTap: enabled ? () => _capture(ImageSource.camera) : null,
        ),
        const SizedBox(height: 12),
        _CaptureTile(
          key: const Key('capture_gallery_button'),
          icon: Icons.photo_library_outlined,
          title: 'nutrition.pick_from_gallery'.tr(),
          primary: false,
          onTap: enabled ? () => _capture(ImageSource.gallery) : null,
        ),
      ],
    );
  }

  Widget _buildUploadError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('nutrition.upload_error'.tr(), key: const Key('capture_upload_error')),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('capture_retry_button'),
            onPressed: () => ref.read(mealCaptureProvider.notifier).reset(),
            child: Text('nutrition.retry'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewing(MealCaptureReviewing state) {
    final notifier = ref.read(mealCaptureProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final photo = _photoBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            children: [
              if (photo != null) _PhotoPreview(bytes: photo, itemCount: state.items.length),
              if (state.aiFailureReason != AiFailureReason.none)
                Container(
                  key: const Key('capture_ai_failure_banner'),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    state.aiFailureReason == AiFailureReason.quotaExceeded
                        ? 'nutrition.ai_quota_exceeded'.tr()
                        : 'nutrition.ai_unavailable'.tr(),
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              for (var i = 0; i < state.items.length; i++)
                Padding(
                  key: state.itemKeys[i],
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FoodItemEditTile(
                    item: state.items[i],
                    index: i,
                    onChanged: (updated) => notifier.updateItem(i, updated),
                    onGramsChanged: (grams) => notifier.updateItemGrams(i, grams),
                    onRemove: () => notifier.removeItem(i),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('capture_add_item_button'),
                  onPressed: notifier.addManualItem,
                  icon: const Icon(Icons.add),
                  label: Text('nutrition.add_item_manually'.tr()),
                ),
              ),
            ],
          ),
        ),
        _TotalBar(totalCalories: state.totalCalories, onSave: state.canSave ? notifier.confirmSave : null),
      ],
    );
  }
}

/// Seçim adımındaki büyük dokunma kutusu; [onTap] null ise soluk ve pasif.
class _CaptureTile extends StatelessWidget {
  const _CaptureTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.primary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = primary ? scheme.onPrimary : scheme.onSurface;
    final subtitle = this.subtitle;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: primary ? scheme.primary : scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: primary ? BorderSide.none : BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: foreground),
                const SizedBox(height: 6),
                Text(title, style: theme.textTheme.titleMedium?.copyWith(color: foreground)),
                if (subtitle != null)
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: foreground)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.bytes, required this.itemCount});

  final Uint8List bytes;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: const Key('capture_photo_preview'),
      height: 140,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            bytes,
            fit: BoxFit.cover,
            // Çözülemeyen görüntüde boş zemin kalsın, hata fırlatılmasın.
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'nutrition.items_found'.tr(namedArgs: {'count': '$itemCount'}),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Düzeltme adımının altındaki sabit toplam + Kaydet.
class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.totalCalories, required this.onSave});

  final double totalCalories;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                upperCaseFor('nutrition.total'.tr(), context.locale.languageCode),
                style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
              ),
              const Spacer(),
              Text(
                '${totalCalories.round()} ${'nutrition.kcal'.tr()}',
                key: const Key('capture_total_calories'),
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('capture_save_button'),
            onPressed: onSave,
            child: Text('nutrition.save'.tr()),
          ),
        ],
      ),
    );
  }
}
