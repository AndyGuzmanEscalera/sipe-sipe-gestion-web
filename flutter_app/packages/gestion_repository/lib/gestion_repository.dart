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
    } catch (error) {
      return Err(Failure(error.toString()));
    }
  }
}
