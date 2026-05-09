import 'package:flutter/material.dart';

class PinKeypad extends StatelessWidget {
  const PinKeypad({
    required this.onDigit,
    required this.onClear,
    required this.onDone,
    super.key,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onClear;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final numbers = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
    return Column(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: numbers
              .map((number) => _KeyButton(
                    label: number,
                    onPressed: () => onDigit(number),
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(onPressed: onClear, child: const Text('Clear')),
            const SizedBox(width: 16),
            _KeyButton(label: '0', onPressed: () => onDigit('0')),
            const SizedBox(width: 16),
            TextButton(onPressed: onDone, child: const Text('Done')),
          ],
        ),
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 62,
      child: FilledButton.tonal(
        onPressed: onPressed,
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
