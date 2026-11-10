import 'package:failures/failures.dart';
import 'package:gestion_api/gestion_api.dart';
import 'package:dio/dio.dart';

class GestionRepository {
  GestionRepository(this.api);
  final GestionApi api;
  Future<Result<Map<String, dynamic>>> login(
          String username, String password) async =>
      _run(() => api.login(username, password));
  Future<Result<Map<String, dynamic>>> me() async => _run(api.me);
  Future<bool> refresh() => api.refresh();
  Future<Result<Map<String, dynamic>?>> mayor() async => _run(api.mayor);
  Future<Result<Map<String, dynamic>>> saveMayor(
          {String? id,
          required String name,
          required String title,
          required String welcomeTitle,
          required String message,
          required String photoNote,
          List<int>? photoBytes,
          String? photoFilename}) async =>
      _run(() => api.saveMayor(
          id: id,
          name: name,
          title: title,
          welcomeTitle: welcomeTitle,
          message: message,
          photoNote: photoNote,
          photoBytes: photoBytes,
          photoFilename: photoFilename));
  Future<Result<Map<String, dynamic>>> settings() async => _run(api.settings);
  Future<Result<Map<String, dynamic>>> saveSettings(
          Map<String, dynamic> data) async =>
      _run(() => api.saveSettings(data));
  Future<Result<Map<String, dynamic>>> institutional() async =>
      _run(api.institutional);
  Future<Result<Map<String, dynamic>>> saveInstitutional(
          String mission, String vision) async =>
      _run(() => api.saveInstitutional(mission, vision));
  Future<Result<List<dynamic>>> values() async => _run(api.values);
  Future<Result<Map<String, dynamic>>> saveValue(
          {String? id,
          required String value,
          required int sortOrder,
          required bool active}) async =>
      _run(() => api.saveValue(
          id: id, value: value, sortOrder: sortOrder, active: active));
  Future<Result<List<dynamic>>> authorities() async => _run(api.authorities);
  Future<Result<Map<String, dynamic>>> saveAuthority(
          {String? id,
          required String name,
          required String professionalTitle,
          required String position,
          required String description,
          required int displayOrder,
          required bool published,
          List<int>? photoBytes,
          String? photoFilename}) async =>
      _run(() => api.saveAuthority(
          id: id,
          name: name,
          professionalTitle: professionalTitle,
          position: position,
          description: description,
          displayOrder: displayOrder,
          published: published,
          photoBytes: photoBytes,
          photoFilename: photoFilename));
  Future<Result<void>> toggleAuthority(String id, String action) async =>
      _run(() => api.toggleAuthority(id, action));
  Future<Result<List<dynamic>>> categories() async => _run(api.categories);
  Future<Result<Map<String, dynamic>>> saveCategory(
          {String? id,
          required String name,
          String? description,
          required int sortOrder,
          required bool active}) async =>
      _run(() => api.saveCategory(
          id: id,
          name: name,
          description: description,
          sortOrder: sortOrder,
          active: active));
  Future<Result<Map<String, dynamic>>> documents({String? query}) async =>
      _run(() => api.documents(query: query));
  Future<Result<List<dynamic>>> users() async => _run(api.users);
  Future<Result<List<dynamic>>> roles() async => _run(api.roles);
  Future<Result<Map<String, dynamic>>> uploadDocument(FormData data,
          {String? id}) async =>
      _run(() async => Map<String, dynamic>.from(
          (await api.uploadDocument(data, id: id)).data as Map));
  Future<Result<void>> toggleDocument(String id, bool publish) async =>
      _run(() => api.toggleDocument(id, publish));
  Future<Result<void>> deleteDocument(String id) async =>
      _run(() => api.deleteDocument(id));
  Future<Result<T>> _run<T>(Future<T> Function() action) async {
    try {
      return Ok(await action());
    } on DioException catch (error) {
      return Err(Failure(_messageFrom(error)));
    } catch (error) {
      // `Err<T>` no admite `const` porque usa un parámetro de tipo.
      // ignore: prefer_const_constructors
      return Err<T>(
          const Failure('Ocurrió un error inesperado. Intente nuevamente.'));
    }
  }

  /// Traduce la respuesta de la API a un mensaje legible para el operador.
  ///
  /// Nunca se muestra la excepción cruda (DioException) al usuario.
  String _messageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          return first['msg'].toString();
        }
      }
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return 'No se pudo conectar con el servidor. Verifique la red e intente nuevamente.';
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'El servidor tardó demasiado en responder. Intente nuevamente.';
      case DioExceptionType.badCertificate:
        return 'El certificado del servidor no es válido.';
      default:
        return 'Ocurrió un error inesperado. Intente nuevamente.';
    }
  }
}
