import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sipe_sipe_gestion/core/util/form/controllers/controllers.dart';
import 'package:sipe_sipe_gestion/core/util/form/validator_field/valid.dart';
import 'package:sipe_sipe_gestion/core/util/form/validator_field/validator_field.dart';
import 'package:sipe_sipe_gestion/shared/widgets/form/app_form_field_style.dart';

/// Campo de texto con las reglas de validación del panel.
///
/// Replica el patrón de Correspondencia: el controlador aporta la clave del
/// `FormField` y el foco, y las reglas se declaran con [AbstractValid].
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    super.key,
    this.title,
    this.icon,
    this.validators,
    this.inputType,
    this.inputFormatters,
    this.maxLength,
    this.minLines,
    this.maxLines = 1,
    this.helperText,
    this.readOnly = false,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
  });

  final ControllerFieldPro controller;
  final String label;
  final String? title;
  final IconData? icon;
  final List<AbstractValid>? validators;
  final TextInputType? inputType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int? minLines;
  final int? maxLines;
  final String? helperText;
  final bool readOnly;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final Iterable<String>? autofillHints;

  String? _validate(String? value) {
    if (validators == null || validators!.isEmpty) return null;
    return Validator.validation(value, validators!, fieldLabel: label);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: AppFormFieldStyle.title),
            const SizedBox(height: 8),
          ],
          TextFormField(
            key: controller.fieldKey,
            controller: controller.textEditingController,
            focusNode: controller.focusNode,
            readOnly: readOnly,
            maxLength: maxLength,
            minLines: minLines,
            maxLines: maxLines,
            keyboardType: inputType,
            inputFormatters: inputFormatters,
            autofillHints: autofillHints,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: _validate,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            style: AppFormFieldStyle.fieldText,
            decoration: AppFormFieldStyle.decoration(
              label: label,
              helperText: helperText,
              prefixIcon: icon,
            ),
          ),
        ],
      ),
    );
  }
}
