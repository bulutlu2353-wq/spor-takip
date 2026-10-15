import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../progress/presentation/widgets/card_states.dart';
import '../../workout/application/workout_providers.dart';
import '../../workout/domain/today_workout.dart';
import '../application/notification_providers.dart';
import '../domain/notification_settings.dart';
import '../domain/reminder_inputs.dart';

typedef TimePickerFn = Future<TimeOfDay?> Function(BuildContext context, TimeOfDay initial);

Future<TimeOfDay?> _showPicker(BuildContext context, TimeOfDay initial) =>
    showTimePicker(context: context, initialTime: initial);

/// Hatırlatıcı ayarları (N1 spec §3.1): dört kart, izin uyarısı, web notu.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.pickTime = _showPicker});

  /// Testlerde saat seçici yerine enjekte edilir.
  final TimePickerFn pickTime;

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // Sistem ayarlarından dönünce izin yeniden okunur.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(notificationPermissionProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _save(NotificationSettings next, {bool turningOn = false}) async {
    if (turningOn && ref.read(notificationPermissionProvider).value != true) {
      await ref.read(notificationPermissionProvider.notifier).request();
    }
    await ref.read(notificationSettingsProvider.notifier).save(next);
  }

  Future<void> _pick(ReminderTime current, NotificationSettings Function(ReminderTime time) apply) async {
    final picked = await widget.pickTime(context, TimeOfDay(hour: current.hour, minute: current.minute));
    if (picked != null) await _save(apply(ReminderTime(picked.hour, picked.minute)));
  }

  @override
  Widget build(BuildContext context) {
    final supported = ref.watch(notificationsSupportedProvider);
    final permission = ref.watch(notificationPermissionProvider).value;
    final program = programOf(ref.watch(todayWorkoutProvider).value ?? const NoActiveProgram());
    return Scaffold(
      key: const Key('notifications_screen'),
      appBar: AppBar(title: Text('notifications.title'.tr())),
      body: ref.watch(notificationSettingsProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                Center(child: CardError(onRetry: () => ref.invalidate(notificationSettingsProvider))),
            data: (stored) {
              final s = stored.withWorkoutDaysFrom(program);
              VoidCallback? pickFor(ReminderTime time, NotificationSettings Function(ReminderTime) apply) =>
                  supported ? () => _pick(time, apply) : null;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (!supported)
                    _Banner(
                      key: const Key('notifications_web_note'),
                      icon: Icons.info_outline,
                      text: 'notifications.web_note'.tr(),
                    ),
                  if (supported && permission == false && stored.anyEnabled)
                    _Banner(
                      key: const Key('notifications_permission_warning'),
                      icon: Icons.notifications_off_outlined,
                      text: 'notifications.permission_missing'.tr(),
                      action: TextButton(
                        key: const Key('notifications_open_settings'),
                        onPressed: () => ref.read(reminderSchedulerProvider).openSystemSettings(),
                        child: Text('notifications.open_settings'.tr()),
                      ),
                    ),
                  _ReminderCard(
                    id: 'workout',
                    icon: Icons.fitness_center,
                    title: 'notifications.workout'.tr(),
                    subtitle: 'notifications.workout_desc'.tr(),
                    value: s.workoutEnabled,
                    onChanged: supported ? (on) => _save(s.copyWith(workoutEnabled: on), turningOn: on) : null,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                            FilterChip(
                              key: Key('notif_workout_day_$day'),
                              label: Text('notifications.day_$day'.tr()),
                              selected: s.workoutDays.contains(day),
                              onSelected: supported
                                  ? (on) => _save(s.copyWith(
                                        workoutDays: on ? {...s.workoutDays, day} : ({...s.workoutDays}..remove(day)),
                                      ))
                                  : null,
                            ),
                        ],
                      ),
                      _TimeRow(
                        id: 'workout',
                        label: 'notifications.time'.tr(),
                        time: s.workoutTime,
                        onTap: pickFor(s.workoutTime, (t) => s.copyWith(workoutTime: t)),
                      ),
                    ],
                  ),
                  _ReminderCard(
                    id: 'meals',
                    icon: Icons.restaurant,
                    title: 'notifications.meals'.tr(),
                    subtitle: 'notifications.meals_desc'.tr(),
                    value: s.mealsEnabled,
                    onChanged: supported ? (on) => _save(s.copyWith(mealsEnabled: on), turningOn: on) : null,
                    children: [
                      for (final type in reminderMealTypes)
                        Row(
                          children: [
                            Expanded(child: Text('notifications.meal_${type.name}'.tr())),
                            _TimeButton(
                              buttonKey: Key('notif_meal_${type.name}_time'),
                              time: s.meals[type]!.time,
                              onTap: pickFor(
                                s.meals[type]!.time,
                                (t) => s.copyWith(meals: {...s.meals, type: s.meals[type]!.copyWith(time: t)}),
                              ),
                            ),
                            Switch(
                              key: Key('notif_meal_${type.name}_switch'),
                              value: s.meals[type]!.enabled,
                              onChanged: supported
                                  ? (on) => _save(
                                        s.copyWith(meals: {...s.meals, type: s.meals[type]!.copyWith(enabled: on)}),
                                        turningOn: on && s.mealsEnabled,
                                      )
                                  : null,
                            ),
                          ],
                        ),
                    ],
                  ),
                  _ReminderCard(
                    id: 'nutrition',
                    icon: Icons.nightlight_outlined,
                    title: 'notifications.nutrition'.tr(),
                    subtitle: 'notifications.nutrition_desc'.tr(),
                    value: s.nutritionEnabled,
                    onChanged: supported ? (on) => _save(s.copyWith(nutritionEnabled: on), turningOn: on) : null,
                    children: [
                      _TimeRow(
                        id: 'nutrition',
                        label: 'notifications.time'.tr(),
                        time: s.nutritionTime,
                        onTap: pickFor(s.nutritionTime, (t) => s.copyWith(nutritionTime: t)),
                      ),
                    ],
                  ),
                  _ReminderCard(
                    id: 'weekly',
                    icon: Icons.flag_outlined,
                    title: 'notifications.weekly'.tr(),
                    subtitle: 'notifications.weekly_desc'.tr(),
                    value: s.weeklyEnabled,
                    onChanged: supported ? (on) => _save(s.copyWith(weeklyEnabled: on), turningOn: on) : null,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('notifications.weekly_day'.tr())),
                          DropdownButton<int>(
                            key: const Key('notif_weekly_day'),
                            value: s.weeklyDay,
                            items: [
                              for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                                DropdownMenuItem(value: day, child: Text('home.weekday_$day'.tr())),
                            ],
                            onChanged: supported
                                ? (day) {
                                    if (day != null) _save(s.copyWith(weeklyDay: day));
                                  }
                                : null,
                          ),
                        ],
                      ),
                      _TimeRow(
                        id: 'weekly',
                        label: 'notifications.time'.tr(),
                        time: s.weeklyTime,
                        onTap: pickFor(s.weeklyTime, (t) => s.copyWith(weeklyTime: t)),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(icon, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
            ?action,
          ],
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.children,
  });

  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              key: Key('notif_${id}_switch'),
              contentPadding: EdgeInsets.zero,
              secondary: Icon(icon),
              title: Text(title),
              subtitle: Text(subtitle),
              value: value,
              onChanged: onChanged,
            ),
            for (final child in children) Padding(padding: const EdgeInsets.only(top: 8), child: child),
          ],
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.id, required this.label, required this.time, required this.onTap});

  final String id;
  final String label;
  final ReminderTime time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        _TimeButton(buttonKey: Key('notif_${id}_time'), time: time, onTap: onTap),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.buttonKey, required this.time, required this.onTap});

  final Key buttonKey;
  final ReminderTime time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: buttonKey,
      icon: const Icon(Icons.schedule, size: 18),
      label: Text(time.label),
      onPressed: onTap,
    );
  }
}
