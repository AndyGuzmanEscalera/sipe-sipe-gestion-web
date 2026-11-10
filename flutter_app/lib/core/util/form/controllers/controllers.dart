import 'package:flutter/material.dart';

import 'package:sipe_sipe_gestion/core/util/form/result_validate.dart';

/// Controlador de campo de formulario con clave de validación y foco.
class ControllerFieldPro {
  ControllerFieldPro();

  final _textEditingController = TextEditingController();
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  final _focusNode = FocusNode();

  GlobalKey<FormFieldState<String>> get fieldKey => _fieldKey;
  FocusNode get focusNode => _focusNode;
  TextEditingController get textEditingController => _textEditingController;

  void setValue(String? value) {
    if (value == null) return;
    _textEditingController.text = value;
  }

  String getValue() => _textEditingController.text;

  void clear() => _textEditingController.clear();

  void dispose() {
    _textEditingController.dispose();
    _focusNode.dispose();
  }
}

extension FormKeyValidate on GlobalKey<FormState> {
  bool validateForm() => currentState?.validate() ?? false;

  ResultValidate validateAndGetErrors(
    List<GlobalKey<FormFieldState<Object?>>> fieldKeys,
  ) {
    final errors = <String, String?>{};
    for (final fieldKey in fieldKeys) {
      fieldKey.currentState?.validate();
      errors[fieldKey.toString()] = fieldKey.currentState?.errorText;
    }
    return ResultValidate(
      errors: errors,
      isPassed: currentState?.validate() ?? false,
    );
  }
}
