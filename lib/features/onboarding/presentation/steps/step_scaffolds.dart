import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/text_case.dart';

class WizardStepScaffold extends StatelessWidget {
  const WizardStepScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.isValid,
    required this.onNext,
    required this.onBack,
    required this.stepNumber,
    required this.totalSteps,
    this.nextLabel,
  });

  final String title;
  final Widget child;
  final bool isValid;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final int stepNumber;
  final int totalSteps;
  final String? nextLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stepLabel = 'onboarding.step_of'.tr(namedArgs: {
      'current': stepNumber.toString(),
      'total': totalSteps.toString(),
    });
    return Scaffold(
      appBar: AppBar(
        leading: onBack == null
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepSegments(current: stepNumber, total: totalSteps),
            const SizedBox(height: 12),
            Text(
              upperCaseFor(stepLabel, Localizations.localeOf(context).languageCode),
              key: const Key('wizard_step_label'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                fontFamily: AppFonts.heading,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 24),
            Expanded(child: child),
            FilledButton(
              key: const Key('wizard_next_button'),
              onPressed: isValid ? onNext : null,
              child: Text(nextLabel ?? 'onboarding.next'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Her adım için bir parça; tamamlanan ve şu anki adımlar neon (spec §4.1).
class _StepSegments extends StatelessWidget {
  const _StepSegments({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      key: const Key('wizard_step_segments'),
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              key: Key('wizard_segment_$i'),
              height: 4,
              decoration: BoxDecoration(
                color: i < current ? scheme.primary : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class NumericStepScreen extends StatefulWidget {
  const NumericStepScreen({
    super.key,
    required this.title,
    required this.hintText,
    required this.min,
    required this.max,
    required this.initialValue,
    required this.onSave,
    required this.onNext,
    required this.onBack,
    required this.stepNumber,
    required this.totalSteps,
    this.unit,
  });

  final String title;
  final String hintText;
  final double min;
  final double max;
  final double? initialValue;
  final ValueChanged<double> onSave;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final int stepNumber;
  final int totalSteps;
  final String? unit;

  @override
  State<NumericStepScreen> createState() => _NumericStepScreenState();
}

class _NumericStepScreenState extends State<NumericStepScreen> {
  late final TextEditingController _controller;
  double? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
    _controller = TextEditingController(text: widget.initialValue?.toString() ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid => _value != null && _value! >= widget.min && _value! <= widget.max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return WizardStepScaffold(
      title: widget.title,
      stepNumber: widget.stepNumber,
      totalSteps: widget.totalSteps,
      isValid: _isValid,
      onBack: widget.onBack,
      onNext: () {
        widget.onSave(_value!);
        widget.onNext();
      },
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                key: const Key('numeric_step_field'),
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900, fontSize: 56),
                decoration: InputDecoration.collapsed(
                  hintText: widget.hintText,
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
                onChanged: (text) => setState(() => _value = double.tryParse(text)),
              ),
            ),
            if (widget.unit != null) ...[
              const SizedBox(width: 8),
              Text(
                widget.unit!,
                key: const Key('numeric_step_unit'),
                style: theme.textTheme.titleLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ChoiceStepScreen<T> extends StatelessWidget {
  const ChoiceStepScreen({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onSave,
    required this.onNext,
    required this.onBack,
    required this.stepNumber,
    required this.totalSteps,
  });

  final String title;
  final List<(T value, String label, IconData icon)> options;
  final T? selected;
  final ValueChanged<T> onSave;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final int stepNumber;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return WizardStepScaffold(
      title: title,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
      isValid: selected != null,
      onBack: onBack,
      onNext: onNext,
      child: ListView.separated(
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final (value, label, icon) = options[index];
          return _ChoiceCard(
            key: Key('choice_option_$value'),
            label: label,
            icon: icon,
            selected: value == selected,
            onTap: () => onSave(value),
          );
        },
      ),
    );
  }
}

/// İkonlu seçim kartı; seçiliyse neon kenarlık ve onay işareti (spec §4.2).
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const radius = BorderRadius.all(Radius.circular(16));
    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: selected ? BorderSide(color: scheme.primary, width: 2) : BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        customBorder: const RoundedRectangleBorder(borderRadius: radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              if (selected) Icon(Icons.check_circle, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class TextStepScreen extends StatefulWidget {
  const TextStepScreen({
    super.key,
    required this.title,
    required this.hintText,
    required this.initialValue,
    required this.required,
    required this.onSave,
    required this.onNext,
    required this.onBack,
    required this.stepNumber,
    required this.totalSteps,
    this.nextLabel,
  });

  final String title;
  final String hintText;
  final String? initialValue;
  final bool required;
  final ValueChanged<String?> onSave;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final int stepNumber;
  final int totalSteps;
  final String? nextLabel;

  @override
  State<TextStepScreen> createState() => _TextStepScreenState();
}

class _TextStepScreenState extends State<TextStepScreen> {
  late final TextEditingController _controller;
  late String _text;

  @override
  void initState() {
    super.initState();
    _text = widget.initialValue ?? '';
    _controller = TextEditingController(text: _text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isValid = !widget.required || _text.trim().isNotEmpty;
    return WizardStepScaffold(
      title: widget.title,
      stepNumber: widget.stepNumber,
      totalSteps: widget.totalSteps,
      isValid: isValid,
      onBack: widget.onBack,
      nextLabel: widget.nextLabel,
      onNext: () {
        final trimmed = _text.trim();
        widget.onSave(trimmed.isEmpty ? null : trimmed);
        widget.onNext();
      },
      child: TextField(
        key: const Key('text_step_field'),
        controller: _controller,
        maxLines: 5,
        decoration: InputDecoration(hintText: widget.hintText),
        onChanged: (value) => setState(() => _text = value),
      ),
    );
  }
}
