import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

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
            LinearProgressIndicator(value: stepNumber / totalSteps),
            const SizedBox(height: 8),
            Text(
              'onboarding.step_of'.tr(namedArgs: {
                'current': stepNumber.toString(),
                'total': totalSteps.toString(),
              }),
            ),
            const SizedBox(height: 24),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            Expanded(child: child),
            ElevatedButton(
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
      child: TextField(
        key: const Key('numeric_step_field'),
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(hintText: widget.hintText),
        onChanged: (text) => setState(() => _value = double.tryParse(text)),
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
  final List<(T value, String label)> options;
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
      child: RadioGroup<T>(
        groupValue: selected,
        onChanged: (value) {
          if (value != null) onSave(value);
        },
        child: ListView(
          children: [
            for (final option in options)
              RadioListTile<T>(
                key: Key('choice_option_${option.$1}'),
                title: Text(option.$2),
                value: option.$1,
              ),
          ],
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
