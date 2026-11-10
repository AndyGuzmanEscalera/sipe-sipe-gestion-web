import 'valid.dart';

/// Reglas de validación de entrada reutilizables.
class InputValidators {
  static bool isRequired(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  static bool isNumeric(String? value) {
    if (value == null || value.isEmpty) return false;
    return RegExp(r'^[0-9]+$').hasMatch(value.trim());
  }

  static bool isEmail(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$').hasMatch(value.trim());
  }

  static bool isUrl(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    return RegExp(r'^https?://[^\s]+$', caseSensitive: false)
        .hasMatch(value.trim());
  }

  static bool isIsoDate(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value.trim())) return false;
    final parts = value.trim().split('-').map(int.parse).toList();
    final parsed = DateTime(parts[0], parts[1], parts[2]);
    return parsed.year == parts[0] &&
        parsed.month == parts[1] &&
        parsed.day == parts[2];
  }
}

/// Encadena reglas de validación y devuelve el primer error encontrado.
class Validator {
  static String? validation(String? value, List<AbstractValid> validators,
      {String? fieldLabel}) {
    for (final element in validators) {
      final error = element.valid(value);
      if (error != null) {
        return error == 'Campo requerido' && fieldLabel != null
            ? '$fieldLabel: Este campo es obligatorio.'
            : error;
      }
    }
    return null;
  }
}
