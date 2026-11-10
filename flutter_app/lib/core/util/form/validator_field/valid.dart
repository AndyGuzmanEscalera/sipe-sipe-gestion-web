import 'validator_field.dart';

/// Regla de validación de un campo.
abstract class AbstractValid {
  String? valid(String? value);
}

/// Campo obligatorio.
class RequiredValid extends AbstractValid {
  RequiredValid({this.error});

  final String? error;

  @override
  String? valid(String? value) {
    if (!InputValidators.isRequired(value)) {
      return error ?? 'Campo requerido';
    }
    return null;
  }
}

/// Longitud mínima (sin espacios al inicio ni al final).
class MinLengthValid extends AbstractValid {
  MinLengthValid(this.minLength, {this.error, this.optional = true});

  final int minLength;
  final String? error;
  final bool optional;

  @override
  String? valid(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return optional ? null : (error ?? 'Campo requerido');
    }
    if (text.runes.length < minLength) {
      return error ?? 'Debe tener al menos $minLength caracteres.';
    }
    return null;
  }
}

/// Longitud máxima.
class MaxLengthValid extends AbstractValid {
  MaxLengthValid(this.maxLength, {this.error});

  final int maxLength;
  final String? error;

  @override
  String? valid(String? value) {
    final text = value ?? '';
    if (text.runes.length > maxLength) {
      return error ?? 'Debe tener como máximo $maxLength caracteres.';
    }
    return null;
  }
}

/// Correo electrónico válido (opcional si el campo está vacío).
class EmailValid extends AbstractValid {
  EmailValid({this.error, this.optional = true});

  final String? error;
  final bool optional;

  @override
  String? valid(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return optional ? null : (error ?? 'Campo requerido');
    }
    if (!InputValidators.isEmail(text)) {
      return error ?? 'Ingrese un correo electrónico válido.';
    }
    return null;
  }
}

/// URL válida (opcional si el campo está vacío).
class UrlValid extends AbstractValid {
  UrlValid({this.error, this.optional = true});

  final String? error;
  final bool optional;

  @override
  String? valid(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return optional ? null : (error ?? 'Campo requerido');
    }
    if (!InputValidators.isUrl(text)) {
      return error ?? 'Ingrese una URL válida (http:// o https://).';
    }
    return null;
  }
}

/// Fecha en formato AAAA-MM-DD.
class IsoDateValid extends AbstractValid {
  IsoDateValid({this.error});

  final String? error;

  @override
  String? valid(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Campo requerido';
    }
    if (!InputValidators.isIsoDate(text)) {
      return error ?? 'Ingrese una fecha válida en formato AAAA-MM-DD.';
    }
    return null;
  }
}

/// Valor numérico entero.
class NumericValid extends AbstractValid {
  NumericValid({this.error});

  final String? error;

  @override
  String? valid(String? value) {
    if (!InputValidators.isNumeric(value)) {
      return error ?? 'Ingrese un valor numérico válido';
    }
    return null;
  }
}

/// Contraseña con longitud mínima.
class PasswordValid extends AbstractValid {
  PasswordValid({this.optional = false});

  final bool optional;
  static const minLength = 12;
  static const maxLength = 255;

  @override
  String? valid(String? value) {
    final text = value ?? '';
    if (text.isEmpty && optional) return null;
    if (text.trim().isEmpty) return 'Ingrese una contraseña.';
    if (text.runes.length < minLength) {
      return 'La contraseña debe tener al menos $minLength caracteres.';
    }
    if (text.runes.length > maxLength) {
      return 'La contraseña debe tener como máximo $maxLength caracteres.';
    }
    return null;
  }
}
