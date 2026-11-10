import 'package:equatable/equatable.dart';

/// Resultado de validar un formulario: errores por campo y si pasó la validación.
class ResultValidate extends Equatable {
  const ResultValidate({
    required this.errors,
    required this.isPassed,
  });

  final Map<String, String?> errors;
  final bool isPassed;

  List<String> getErrors() {
    return errors.values
        .where((value) => value != null)
        .cast<String>()
        .toList();
  }

  @override
  List<Object?> get props => [errors, isPassed];
}
