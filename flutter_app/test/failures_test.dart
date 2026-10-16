import 'package:failures/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Result exposes successful value', () {
    const result = Ok<String>('ok');
    expect(result.isSuccess, isTrue);
    expect(result.value, 'ok');
  });
}
