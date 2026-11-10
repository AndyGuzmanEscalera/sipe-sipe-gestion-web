import 'package:flutter_test/flutter_test.dart';
import 'package:sipe_sipe_gestion/core/util/form/validator_field/valid.dart';
import 'package:sipe_sipe_gestion/core/util/form/validator_field/validator_field.dart';

void main() {
  group('RequiredValid', () {
    test('rechaza vacío o solo espacios', () {
      final validator = RequiredValid();
      expect(validator.valid(null), 'Campo requerido');
      expect(validator.valid(''), 'Campo requerido');
      expect(validator.valid('   '), 'Campo requerido');
    });

    test('acepta texto con contenido', () {
      final validator = RequiredValid();
      expect(validator.valid('GAM Sipe Sipe'), isNull);
    });

    test('permite mensaje de error propio', () {
      final validator = RequiredValid(error: 'Indique el nombre oficial.');
      expect(validator.valid(''), 'Indique el nombre oficial.');
    });
  });

  group('MaxLengthValid', () {
    test('rechaza textos más largos que el máximo', () {
      final validator = MaxLengthValid(5);
      expect(validator.valid('123456'), isNotNull);
      expect(validator.valid('12345'), isNull);
    });

    test('permite vacío', () {
      expect(MaxLengthValid(5).valid(''), isNull);
    });
  });

  group('MinLengthValid', () {
    test('rechaza textos más cortos que el mínimo', () {
      final validator = MinLengthValid(3, optional: false);
      expect(validator.valid('ab'), isNotNull);
      expect(validator.valid('abc'), isNull);
    });

    test('opcional acepta vacío', () {
      expect(MinLengthValid(3).valid(''), isNull);
    });
  });

  group('EmailValid', () {
    test('rechaza correos inválidos', () {
      final validator = EmailValid();
      expect(validator.valid('correo'), isNotNull);
      expect(validator.valid('correo@'), isNotNull);
      expect(validator.valid('@municipio.gob.bo'), isNotNull);
    });

    test('acepta correos válidos', () {
      final validator = EmailValid();
      expect(validator.valid('comunicacion@gamsipesipe.gob.bo'), isNull);
    });

    test('opcional acepta vacío', () {
      expect(EmailValid().valid(''), isNull);
    });

    test('obligatorio rechaza vacío', () {
      expect(EmailValid(optional: false).valid(''), isNotNull);
    });
  });

  group('UrlValid', () {
    test('rechaza URLs sin esquema http', () {
      final validator = UrlValid();
      expect(validator.valid('facebook.com'), isNotNull);
      expect(validator.valid('www.facebook.com'), isNotNull);
    });

    test('acepta URLs http y https', () {
      final validator = UrlValid();
      expect(validator.valid('https://facebook.com/'), isNull);
      expect(validator.valid('http://instagram.com/municipio'), isNull);
    });
  });

  group('IsoDateValid', () {
    test('exige una fecha AAAA-MM-DD existente', () {
      final validator = IsoDateValid();
      expect(validator.valid(''), 'Campo requerido');
      expect(validator.valid('16/10/2026'), isNotNull);
      expect(validator.valid('2026-13-01'), isNotNull);
      expect(validator.valid('2026-10-16'), isNull);
    });
  });

  group('Validator', () {
    test('devuelve el primer error encontrado', () {
      final error = Validator.validation('', [
        RequiredValid(error: 'Indique el nombre.'),
        MaxLengthValid(3),
      ]);
      expect(error, 'Indique el nombre.');
    });

    test('encadena el label cuando el error es "Campo requerido"', () {
      final error = Validator.validation('', [RequiredValid()], fieldLabel: 'Título');
      expect(error, 'Título: Este campo es obligatorio.');
    });

    test('devuelve null cuando todas las reglas pasan', () {
      expect(Validator.validation('valor', [RequiredValid(), MaxLengthValid(10)]), isNull);
    });
  });
}
