import 'package:dio/dio.dart';

class GestionApi {
  GestionApi({String? baseUrl})
      : _dio = Dio(BaseOptions(
            baseUrl: baseUrl ??
                const String.fromEnvironment('API_BASE_URL',
                    defaultValue: 'http://localhost:8001'),
            extra: {'withCredentials': true})) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (_accessToken != null) {
        options.headers['Authorization'] = 'Bearer $_accessToken';
      }
      handler.next(options);
    }));
  }

  final Dio _dio;
  String? _accessToken;
  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _dio.post('/api/admin/auth/login',
        data: {'username': username, 'password': password});
    _accessToken = response.data['access_token'] as String;
    return _map(response);
  }

  Future<void> logout() async {
    await _dio.post('/api/admin/auth/logout');
    _accessToken = null;
  }

  Future<bool> refresh() async {
    try {
      final response = await _dio.post('/api/admin/auth/refresh');
      _accessToken = response.data['access_token'] as String;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> me() async =>
      _map(await _dio.get('/api/admin/auth/me'));
  Future<Map<String, dynamic>?> mayor() async {
    final response = await _dio.get('/api/admin/mayor');
    return response.data == null ? null : _map(response);
  }

  Future<Map<String, dynamic>> saveMayor(
      {String? id,
      required String name,
      required String title,
      required String welcomeTitle,
      required String message,
      required String photoNote,
      List<int>? photoBytes,
      String? photoFilename}) async {
    final data = FormData.fromMap({
      'name': name,
      'title': title,
      'welcome_title': welcomeTitle,
      'message': message,
      'photo_note': photoNote
    });
    if (photoBytes != null && photoFilename != null) {
      data.files.add(MapEntry('photo',
          MultipartFile.fromBytes(photoBytes, filename: photoFilename)));
    }
    return _map(id == null
        ? await _dio.post('/api/admin/mayor', data: data)
        : await _dio.put('/api/admin/mayor/$id', data: data));
  }

  Future<Map<String, dynamic>> settings() async =>
      _map(await _dio.get('/api/admin/site-settings'));
  Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> data) async =>
      _map(await _dio.put('/api/admin/site-settings', data: data));
  Future<Map<String, dynamic>> institutional() async =>
      _map(await _dio.get('/api/admin/institutional'));
  Future<Map<String, dynamic>> saveInstitutional(
          String mission, String vision) async =>
      _map(await _dio.put('/api/admin/institutional',
          data: {'mission': mission, 'vision': vision}));
  Future<List<dynamic>> values() async =>
      _list(await _dio.get('/api/admin/institutional/values'));
  Future<Map<String, dynamic>> saveValue(
      {String? id,
      required String value,
      required int sortOrder,
      required bool active}) async {
    final data = {'value': value, 'sort_order': sortOrder, 'is_active': active};
    return _map(id == null
        ? await _dio.post('/api/admin/institutional/values', data: data)
        : await _dio.put('/api/admin/institutional/values/$id', data: data));
  }

  Future<List<dynamic>> categories() async =>
      _list(await _dio.get('/api/admin/gaceta/categories'));
  Future<Map<String, dynamic>> saveCategory(
      {String? id,
      required String name,
      String? description,
      required int sortOrder,
      required bool active}) async {
    final data = {
      'name': name,
      'description': description,
      'sort_order': sortOrder,
      'is_active': active
    };
    return _map(id == null
        ? await _dio.post('/api/admin/gaceta/categories', data: data)
        : await _dio.put('/api/admin/gaceta/categories/$id', data: data));
  }

  Future<Map<String, dynamic>> documents({String? query}) async =>
      _map(await _dio.get('/api/admin/gaceta',
          queryParameters: {'page': 1, 'page_size': 100, 'q': query}));
  Future<List<dynamic>> users() async =>
      _list(await _dio.get('/api/admin/users'));
  Future<List<dynamic>> roles() async =>
      _list(await _dio.get('/api/admin/roles'));
  Future<Response<dynamic>> uploadDocument(FormData data, {String? id}) =>
      id == null
          ? _dio.post('/api/admin/gaceta', data: data)
          : _dio.put('/api/admin/gaceta/$id', data: data);
  Future<void> toggleDocument(String id, bool publish) async =>
      _dio.post('/api/admin/gaceta/$id/${publish ? 'publish' : 'unpublish'}');
  Future<void> deleteDocument(String id) async =>
      _dio.delete('/api/admin/gaceta/$id');
  Map<String, dynamic> _map(Response<dynamic> response) =>
      Map<String, dynamic>.from(response.data as Map);
  List<dynamic> _list(Response<dynamic> response) =>
      List<dynamic>.from(response.data as List);
}
