import 'package:flutter/material.dart';

class AgreementCheckboxTile extends StatelessWidget {
  const AgreementCheckboxTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: (next) => onChanged(next ?? false),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: subtitle == null ? null : Text(subtitle!),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
