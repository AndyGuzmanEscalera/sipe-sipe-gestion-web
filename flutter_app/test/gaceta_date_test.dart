import 'package:flutter_test/flutter_test.dart';
import 'package:sipe_sipe_gestion/core/util/gaceta_date.dart';

void main() {
  group('isIsoDate', () {
    test('acepta una fecha válida en formato AAAA-MM-DD', () {
      expect(isIsoDate('2026-10-16'), isTrue);
    });

    test('rechaza formatos incorrectos', () {
      expect(isIsoDate('16/10/2026'), isFalse);
      expect(isIsoDate('2026-10'), isFalse);
      expect(isIsoDate('2026-10-16T00:00:00'), isFalse);
      expect(isIsoDate(''), isFalse);
    });

    test('rechaza fechas que no existen en el calendario', () {
      expect(isIsoDate('2026-13-01'), isFalse);
      expect(isIsoDate('2026-02-30'), isFalse);
    });
  });

  group('initialPublishedAt', () {
    test('conserva la fecha ya registrada al editar', () {
      final existing = <String, dynamic>{
        'id': 'doc-1',
        'published_at': '2024-03-15',
      };
      expect(initialPublishedAt(existing), '2024-03-15');
    });

    test('usa la fecha del día al crear un documento nuevo', () {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      expect(initialPublishedAt(null), today);
    });

    test('usa la fecha del día si el documento no trae fecha', () {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      expect(initialPublishedAt(<String, dynamic>{'id': 'doc-1'}), today);
    });

    test('la fecha inicial es válida para el backend', () {
      expect(isIsoDate(initialPublishedAt(null)), isTrue);
    });
  });
}
