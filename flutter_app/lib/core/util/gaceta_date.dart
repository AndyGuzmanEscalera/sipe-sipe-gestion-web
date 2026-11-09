/// Utilidades de fecha para el formulario de Gaceta.
///
/// Se mantienen en una biblioteca propia (y no en `main.dart`) para poder
/// verificarlas con `flutter test` en la VM, donde `dart:html` no está
/// disponible.
library;

/// Valida una fecha en formato AAAA-MM-DD (el que espera el backend).
bool isIsoDate(String value) {
  final match = RegExp(r'^\d{4}-\d{2}-\d{2}$').firstMatch(value);
  if (match == null) return false;
  final parts = value.split('-').map(int.parse).toList();
  final parsed = DateTime(parts[0], parts[1], parts[2]);
  return parsed.year == parts[0] &&
      parsed.month == parts[1] &&
      parsed.day == parts[2];
}

/// Fecha de publicación inicial del formulario de Gaceta.
///
/// Al editar devuelve la fecha ya registrada (se conserva si el usuario no
/// la cambia); al crear devuelve la fecha del día.
String initialPublishedAt(Map? existing) {
  final stored = existing?['published_at'] as String?;
  if (stored != null && stored.trim().isNotEmpty) return stored.trim();
  return DateTime.now().toIso8601String().substring(0, 10);
}
