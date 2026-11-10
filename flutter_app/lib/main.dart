// This panel is intentionally built for Flutter Web and opens public PDFs in a browser tab.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:gestion_api/gestion_api.dart';
import 'package:gestion_repository/gestion_repository.dart';

import 'core/util/form/controllers/controllers.dart';
import 'core/util/form/validator_field/valid.dart';
import 'core/util/form/validator_field/validator_field.dart';
import 'core/util/gaceta_date.dart';
import 'shared/widgets/form/app_text_field.dart';

final getIt = GetIt.instance;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  getIt.registerSingleton<GestionApi>(GestionApi());
  getIt.registerSingleton<GestionRepository>(
      GestionRepository(getIt<GestionApi>()));
  runApp(const GestionApp());
}

class SessionCubit extends Cubit<Map<String, dynamic>?> {
  SessionCubit(this.repository) : super(null);
  final GestionRepository repository;
  Future<String?> login(String username, String password) async {
    final result = await repository.login(username, password);
    if (!result.isSuccess) return result.failure?.message;
    final payload = result.value!;
    emit(Map<String, dynamic>.from(payload['user'] as Map));
    return null;
  }

  Future<void> restore() async {
    if (await repository.refresh()) {
      final result = await repository.me();
      if (result.isSuccess) emit(result.value);
    }
  }

  Future<void> logout() async {
    await repository.api.logout();
    emit(null);
  }
}

class GestionApp extends StatelessWidget {
  const GestionApp({super.key});
  @override
  Widget build(BuildContext context) => RepositoryProvider.value(
        value: getIt<GestionRepository>(),
        child: BlocProvider(
          create: (_) => SessionCubit(getIt<GestionRepository>())..restore(),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Sipe Sipe Gestión',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xff40902f),
                  brightness: Brightness.light),
              scaffoldBackgroundColor: const Color(0xfff6f8f7),
              useMaterial3: true,
            ),
            home: const AppShell(),
          ),
        ),
      );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

bool hasPermission(Map<String, dynamic> session, String permission) {
  final permissions = (session['permissions'] as List<dynamic>? ?? [])
      .map((value) => value.toString());
  return permissions.contains(permission);
}

/// Valida una fecha en formato AAAA-MM-DD (el que espera el backend).

class _AppShellState extends State<AppShell> {
  int index = 0;
  final titles = const [
    'Configuración del sitio',
    'Alcalde',
    'Información institucional',
    'Valores institucionales',
    'Autoridades / Gabinete',
    'Gaceta municipal',
    'Usuarios',
    'Roles'
  ];
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionCubit>().state;
    if (session == null) return const LoginPage();
    final pages = [
      const SettingsPage(),
      const MayorPage(),
      const InstitutionalPage(),
      const ValuesPage(),
      const AuthoritiesPage(),
      const GacetaPage(),
      const UsersPage(),
      const RolesPage(),
    ];
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
                padding: EdgeInsets.only(bottom: 28),
                child: Icon(Icons.account_balance,
                    color: Color(0xff40902f), size: 32)),
            destinations: const [
              NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Sitio')),
              NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Alcalde')),
              NavigationRailDestination(
                  icon: Icon(Icons.info_outline),
                  selectedIcon: Icon(Icons.info),
                  label: Text('Institucional')),
              NavigationRailDestination(
                  icon: Icon(Icons.format_list_bulleted),
                  selectedIcon: Icon(Icons.format_list_bulleted),
                  label: Text('Valores')),
              NavigationRailDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups),
                  label: Text('Autoridades')),
              NavigationRailDestination(
                  icon: Icon(Icons.description_outlined),
                  selectedIcon: Icon(Icons.description),
                  label: Text('Gaceta')),
              NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Usuarios')),
              NavigationRailDestination(
                  icon: Icon(Icons.security_outlined),
                  selectedIcon: Icon(Icons.security),
                  label: Text('Roles')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
              child: Column(children: [
            AppHeader(title: titles[index], session: session),
            Expanded(child: pages[index]),
          ])),
        ],
      ),
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({required this.title, required this.session, super.key});
  final String title;
  final Map<String, dynamic> session;
  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xffdce8e0)))),
        child: Row(children: [
          Expanded(
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700))),
          Text(session['username'] as String? ?? '',
              style: const TextStyle(color: Color(0xff52675e))),
          const SizedBox(width: 14),
          IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () => context.read<SessionCubit>().logout(),
              icon: const Icon(Icons.logout)),
        ]),
      );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.account_balance,
                          size: 48, color: Color(0xff087443)),
                      const SizedBox(height: 14),
                      Text('Sipe Sipe Gestión',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const Text('Plataforma de Gestión Municipal',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 28),
                      TextField(
                          controller: username,
                          decoration: const InputDecoration(
                              labelText: 'Usuario',
                              border: OutlineInputBorder())),
                      const SizedBox(height: 14),
                      TextField(
                          controller: password,
                          obscureText: true,
                          decoration: const InputDecoration(
                              labelText: 'Contraseña',
                              border: OutlineInputBorder())),
                      if (error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(error!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error))),
                      const SizedBox(height: 22),
                      FilledButton(
                          onPressed: loading ? null : _submit,
                          child: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Ingresar')),
                    ]),
              ),
            ),
          ),
        ),
      );
  Future<void> _submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    final message =
        await context.read<SessionCubit>().login(username.text, password.text);
    if (mounted) {
      setState(() {
        loading = false;
        error = message;
      });
    }
  }
}

abstract class AdminPageState<T extends StatefulWidget> extends State<T> {
  bool loading = true;
  String? error;
  GestionRepository get repository => context.read<GestionRepository>();
  Widget busyOrError() => Center(
      child: error == null ? const CircularProgressIndicator() : Text(error!));
  Future<void> run(Future<void> Function() action) async {
    setState(() => loading = true);
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  InputDecoration decoration(String label) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder());
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends AdminPageState<SettingsPage> {
  final formKey = GlobalKey<FormState>();
  final fields = <String, ControllerFieldPro>{};
  final keys = const [
    'name',
    'shortName',
    'motto',
    'locationLine',
    'email',
    'supportEmail',
    'phone',
    'address',
    'hours',
    'copyright',
    'edition',
    'facebook',
    'instagram',
    'youtube'
  ];
  @override
  void initState() {
    super.initState();
    for (final key in keys) {
      fields[key] = ControllerFieldPro();
    }
    _load();
  }

  Future<void> _load() async {
    final result = await repository.settings();
    if (!mounted) return;
    if (result.isSuccess) {
      for (final key in keys) {
        fields[key]!.setValue(result.value![key] as String? ?? '');
      }
    } else {
      error = result.failure?.message;
    }
    setState(() => loading = false);
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return busyOrError();
    return Form(
      key: formKey,
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(
                spacing: 16,
                runSpacing: 16,
                children: keys
                    .map((key) => SizedBox(
                        width: 360,
                        child: AppTextField(
                            controller: fields[key]!,
                            label: _label(key),
                            validators: _validators(key))))
                    .toList()),
            const SizedBox(height: 24),
            Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                    onPressed: () => _save(),
                    child: const Text('Guardar configuración')))
          ])),
    );
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) {
      _showFormError('Revise los campos marcados.');
      return;
    }
    await run(() async {
      final result = await repository
          .saveSettings({for (final key in keys) key: fields[key]!.getValue()});
      if (!result.isSuccess) throw result.failure!.message;
    });
    if (mounted && error == null) _showFormMessage('Configuración guardada.');
  }

  void _showFormMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showFormError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  List<AbstractValid> _validators(String key) {
    switch (key) {
      case 'name':
        return [RequiredValid(error: 'Indique el nombre oficial.')];
      case 'shortName':
        return [RequiredValid(error: 'Indique el nombre corto.')];
      case 'email':
      case 'supportEmail':
        return [EmailValid()];
      case 'facebook':
      case 'instagram':
      case 'youtube':
        return [UrlValid()];
      case 'motto':
      case 'locationLine':
      case 'phone':
      case 'address':
      case 'hours':
      case 'copyright':
      case 'edition':
        return const [];
      default:
        return const [];
    }
  }

  String _label(String key) => switch (key) {
        'name' => 'Nombre oficial',
        'shortName' => 'Nombre corto',
        'motto' => 'Lema',
        'locationLine' => 'Ubicación',
        'email' => 'Correo',
        'supportEmail' => 'Correo de soporte',
        'phone' => 'Teléfono',
        'address' => 'Dirección',
        'hours' => 'Horario',
        'copyright' => 'Copyright',
        'edition' => 'Edición',
        'facebook' => 'Facebook',
        'instagram' => 'Instagram',
        'youtube' => 'YouTube',
        _ => key,
      };
}

class MayorPage extends StatefulWidget {
  const MayorPage({super.key});
  @override
  State<MayorPage> createState() => _MayorPageState();
}

class _MayorPageState extends AdminPageState<MayorPage> {
  final formKey = GlobalKey<FormState>();
  final name = ControllerFieldPro(),
      title = ControllerFieldPro(),
      welcome = ControllerFieldPro(),
      message = ControllerFieldPro(),
      note = ControllerFieldPro();
  String? mayorId;
  PlatformFile? photo;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    name.dispose();
    title.dispose();
    welcome.dispose();
    message.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await repository.mayor();
    if (result.isSuccess) {
      final item = result.value;
      if (item != null) {
        mayorId = item['id'] as String?;
        name.setValue(item['name'] ?? '');
        title.setValue(item['title'] ?? '');
        welcome.setValue(item['welcome_title'] ?? '');
        message.setValue(item['message'] ?? '');
        note.setValue(item['photo_note'] ?? '');
      }
    } else {
      error = result.failure?.message;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => loading
      ? busyOrError()
      : Form(
          key: formKey,
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                        controller: name,
                        label: 'Nombre',
                        maxLength: 200,
                        validators: [
                          RequiredValid(
                              error: 'Indique el nombre del alcalde.'),
                        ]),
                    AppTextField(
                        controller: title,
                        label: 'Cargo',
                        maxLength: 200,
                        validators: [
                          RequiredValid(error: 'Indique el cargo del alcalde.'),
                        ]),
                    AppTextField(
                        controller: welcome,
                        label: 'Título de bienvenida',
                        maxLength: 300),
                    AppTextField(
                        controller: message,
                        label: 'Mensaje',
                        minLines: 4,
                        maxLines: 8,
                        maxLength: 2000),
                    AppTextField(
                        controller: note,
                        label: 'Nota de foto',
                        maxLength: 500),
                    OutlinedButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.platform
                              .pickFiles(type: FileType.image, withData: true);
                          if (result != null && mounted) {
                            setState(() => photo = result.files.single);
                          }
                        },
                        icon: const Icon(Icons.image),
                        label: Text(photo?.name ?? 'Seleccionar foto')),
                    const SizedBox(height: 22),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                            onPressed: () => _save(),
                            child: const Text('Guardar alcalde')))
                  ])),
        );

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) {
      _showMessage('Revise los campos marcados.');
      return;
    }
    final result = await repository.saveMayor(
        id: mayorId,
        name: name.getValue(),
        title: title.getValue(),
        welcomeTitle: welcome.getValue(),
        message: message.getValue(),
        photoNote: note.getValue(),
        photoBytes: photo?.bytes,
        photoFilename: photo?.name);
    if (!result.isSuccess && mounted) {
      _showMessage(result.failure!.message);
    } else if (mounted) {
      _showMessage('Alcalde guardado');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class InstitutionalPage extends StatefulWidget {
  const InstitutionalPage({super.key});
  @override
  State<InstitutionalPage> createState() => _InstitutionalPageState();
}

class _InstitutionalPageState extends AdminPageState<InstitutionalPage> {
  final formKey = GlobalKey<FormState>();
  final mission = ControllerFieldPro(), vision = ControllerFieldPro();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    mission.dispose();
    vision.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await repository.institutional();
    if (result.isSuccess) {
      mission.setValue(result.value!['mission'] ?? '');
      vision.setValue(result.value!['vision'] ?? '');
    } else {
      error = result.failure?.message;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => loading
      ? busyOrError()
      : Form(
          key: formKey,
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                        controller: mission,
                        label: 'Misión',
                        minLines: 5,
                        maxLines: 10,
                        maxLength: 2000),
                    AppTextField(
                        controller: vision,
                        label: 'Visión',
                        minLines: 5,
                        maxLines: 10,
                        maxLength: 2000),
                    const SizedBox(height: 8),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                            onPressed: () => _save(),
                            child: const Text('Guardar información')))
                  ])),
        );

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) {
      _showMessage('Revise los campos marcados.');
      return;
    }
    await run(() async {
      final result = await repository.saveInstitutional(
          mission.getValue(), vision.getValue());
      if (!result.isSuccess) throw result.failure!.message;
    });
    if (mounted && error == null) {
      _showMessage('Información institucional guardada.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class ValuesPage extends StatefulWidget {
  const ValuesPage({super.key});
  @override
  State<ValuesPage> createState() => _ValuesPageState();
}

class _ValuesPageState extends AdminPageState<ValuesPage> {
  List<dynamic> items = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await repository.values();
    if (result.isSuccess) {
      items = result.value!;
    } else {
      error = result.failure?.message;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => loading
      ? busyOrError()
      : Padding(
          padding: const EdgeInsets.all(28),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                    onPressed: () => _dialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo valor'))),
            const SizedBox(height: 18),
            Expanded(
                child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, i) {
                      final item = items[i] as Map;
                      return ListTile(
                          title: Text(item['value'] as String),
                          subtitle: Text('Orden: ${item['sort_order']}'),
                          trailing: Text(item['is_active'] == true
                              ? 'Activo'
                              : 'Inactivo'));
                    }))
          ]));
  Future<void> _dialog() async {
    final controller = ControllerFieldPro();
    final formKey = GlobalKey<FormState>();
    await showDialog(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Nuevo valor'),
                content: Form(
                    key: formKey,
                    child: AppTextField(
                        controller: controller,
                        label: 'Valor',
                        maxLength: 500,
                        validators: [
                          RequiredValid(
                              error: 'Indique el valor institucional.'),
                        ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final result = await repository.saveValue(
                            value: controller.getValue(),
                            sortOrder: items.length,
                            active: true);
                        if (result.isSuccess && mounted) {
                          Navigator.pop(context);
                          _load();
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(result.failure?.message ??
                                  'No se pudo guardar el valor.')));
                        }
                      },
                      child: const Text('Guardar'))
                ]));
    controller.dispose();
  }
}

class AuthoritiesPage extends StatefulWidget {
  const AuthoritiesPage({super.key});
  @override
  State<AuthoritiesPage> createState() => _AuthoritiesPageState();
}

class _AuthoritiesPageState extends AdminPageState<AuthoritiesPage> {
  List<dynamic> items = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await repository.authorities();
    if (result.isSuccess) {
      items = result.value!;
    } else {
      error = result.failure?.message;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => loading
      ? busyOrError()
      : Padding(
          padding: const EdgeInsets.all(28),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                    onPressed: () => _dialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva autoridad'))),
            const SizedBox(height: 18),
            Expanded(
                child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, i) {
                      final item = items[i] as Map;
                      final published = item['is_published'] == true;
                      final active = item['is_active'] == true;
                      return ListTile(
                          title: Text(item['name'] as String? ?? ''),
                          subtitle: Text(
                              '${item['position'] ?? ''} · Orden ${item['display_order'] ?? 0}'),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              Text(published ? 'Publicada' : 'Borrador'),
                              Text(active ? 'Activa' : 'Inactiva'),
                              IconButton(
                                  tooltip: 'Editar',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _dialog(existing: item)),
                              IconButton(
                                  tooltip: published ? 'Despublicar' : 'Publicar',
                                  icon: Icon(published
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined),
                                  onPressed: () => _toggle(
                                      item['id'] as String,
                                      published ? 'unpublish' : 'publish')),
                            ],
                          ));
                    }))
          ]));

  Future<void> _toggle(String id, String action) async {
    await run(() async {
      final result = await repository.toggleAuthority(id, action);
      if (!result.isSuccess) throw result.failure!.message;
      await _load();
    });
  }

  Future<void> _dialog({Map? existing}) async {
    final name = ControllerFieldPro();
    final professionalTitle = ControllerFieldPro();
    final position = ControllerFieldPro();
    final description = ControllerFieldPro();
    final order = ControllerFieldPro();
    name.setValue(existing?['name'] as String? ?? '');
    professionalTitle.setValue(existing?['professional_title'] as String? ?? '');
    position.setValue(existing?['position'] as String? ?? '');
    description.setValue(existing?['description'] as String? ?? '');
    order.setValue('${existing?['display_order'] ?? items.length}');
    PlatformFile? photo;
    final formKey = GlobalKey<FormState>();
    final published = existing?['is_published'] == true;
    var publishNow = published;

    await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                    title: Text(existing == null
                        ? 'Nueva autoridad'
                        : 'Editar autoridad'),
                    content: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppTextField(
                                controller: name,
                                label: 'Nombre',
                                validators: [
                                  RequiredValid(
                                      error: 'Indique el nombre completo.'),
                                ]),
                            AppTextField(
                                controller: professionalTitle,
                                label: 'Título profesional'),
                            AppTextField(
                                controller: position,
                                label: 'Cargo',
                                validators: [
                                  RequiredValid(error: 'Indique el cargo.'),
                                ]),
                            AppTextField(
                                controller: description,
                                label: 'Descripción',
                                minLines: 3,
                                maxLines: 6),
                            AppTextField(
                                controller: order,
                                label: 'Orden de visualización',
                                validators: [
                                  RequiredValid(error: 'Indique el orden.'),
                                ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              Checkbox(
                                  value: publishNow,
                                  onChanged: (value) => setDialogState(
                                      () => publishNow = value ?? false)),
                              const Expanded(
                                  child: Text('Publicar en el sitio web')),
                            ]),
                            TextButton.icon(
                                onPressed: () async {
                                  final picked = await FilePicker.platform
                                      .pickFiles(type: FileType.image);
                                  if (picked != null) {
                                    setDialogState(
                                        () => photo = picked.files.single);
                                  }
                                },
                                icon: const Icon(Icons.photo_outlined),
                                label: Text(photo?.name ?? 'Seleccionar foto')),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final displayOrder =
                                int.tryParse(order.getValue()) ?? 0;
                            final result = await repository.saveAuthority(
                                id: existing?['id'] as String?,
                                name: name.getValue(),
                                professionalTitle: professionalTitle.getValue(),
                                position: position.getValue(),
                                description: description.getValue(),
                                displayOrder: displayOrder,
                                published: publishNow,
                                photoBytes: photo?.bytes,
                                photoFilename: photo?.name);
                            if (result.isSuccess && mounted) {
                              Navigator.pop(context);
                              _load();
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(result.failure?.message ??
                                          'No se pudo guardar la autoridad.')));
                            }
                          },
                          child: const Text('Guardar'))
                    ])));
    name.dispose();
    professionalTitle.dispose();
    position.dispose();
    description.dispose();
    order.dispose();
  }
}

class GacetaPage extends StatefulWidget {
  const GacetaPage({super.key});
  @override
  State<GacetaPage> createState() => _GacetaPageState();
}

class _GacetaPageState extends AdminPageState<GacetaPage> {
  List<dynamic> categories = [], documents = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    final cats = await repository.categories();
    final docs = await repository.documents();
    if (cats.isSuccess) categories = cats.value!;
    if (docs.isSuccess) documents = (docs.value!['items'] as List<dynamic>);
    if (!cats.isSuccess) error = cats.failure?.message;
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return busyOrError();
    final session = context.watch<SessionCubit>().state!;
    final canRead = hasPermission(session, 'gestion.gaceta.read');
    final canManage = hasPermission(session, 'gestion.gaceta.manage');
    final canPublish = hasPermission(session, 'gestion.gaceta.publish');
    if (!canRead) {
      return const Center(
          child: Text('No tienes permisos para ver la Gaceta.'));
    }

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (canManage)
            FilledButton.icon(
                onPressed: _categoryDialog,
                icon: const Icon(Icons.category),
                label: const Text('Categorías')),
          if (canManage) const SizedBox(width: 12),
          if (canManage)
            FilledButton.icon(
                onPressed: categories.isEmpty ? null : _documentDialog,
                icon: const Icon(Icons.add),
                label: const Text('Nuevo documento')),
        ]),
        const SizedBox(height: 18),
        _GacetaHeader(),
        const Divider(height: 1),
        Expanded(
            child: documents.isEmpty
                ? const Center(child: Text('No hay documentos de Gaceta.'))
                : ListView.separated(
                    itemCount: documents.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _documentRow(documents[i] as Map,
                        canManage: canManage, canPublish: canPublish),
                  ))
      ]),
    );
  }

  Widget _documentRow(Map doc,
      {required bool canManage, required bool canPublish}) {
    final published = doc['is_published'] == true;
    final pdf = doc['pdf'] as Map?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(builder: (context, constraints) {
        final details =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${doc['number']} · ${doc['title']}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${doc['category']['name']} · ${doc['published_at']}',
              style: Theme.of(context).textTheme.bodySmall),
        ]);
        final status = Chip(
          avatar: Icon(published ? Icons.public : Icons.edit_note, size: 16),
          label: Text(published ? 'Publicado' : 'Borrador'),
          backgroundColor:
              published ? const Color(0xffd9f2e3) : const Color(0xfff1f1ed),
        );
        final actions = Wrap(spacing: 4, children: [
          if (canManage)
            _actionButton(
                Icons.edit_outlined, 'Editar', () => _documentDialog(doc)),
          if (canPublish)
            _actionButton(
                published ? Icons.visibility_off_outlined : Icons.publish,
                published ? 'Despublicar' : 'Publicar',
                () => _togglePublish(doc, !published)),
          if (pdf != null)
            _actionButton(Icons.picture_as_pdf_outlined, 'Abrir PDF',
                () => html.window.open(pdf['url'] as String, '_blank')),
          if (canManage)
            _actionButton(
                Icons.delete_outline, 'Eliminar', () => _deleteDocument(doc)),
        ]);
        if (constraints.maxWidth < 900) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                details,
                const SizedBox(height: 8),
                Row(children: [status, const Spacer(), actions]),
              ]);
        }
        return Row(children: [
          Expanded(flex: 4, child: details),
          SizedBox(width: 130, child: Text(doc['category']['name'] as String)),
          SizedBox(width: 120, child: Text(doc['published_at'] as String)),
          SizedBox(width: 120, child: status),
          SizedBox(width: 260, child: actions),
        ]);
      }),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onPressed) {
    return Tooltip(
      message: label,
      child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          visualDensity: VisualDensity.compact),
    );
  }

  Future<void> _togglePublish(Map doc, bool publish) async {
    final result =
        await repository.toggleDocument(doc['id'] as String, publish);
    if (!result.isSuccess && mounted) {
      _showMessage(result.failure!.message);
      return;
    }
    await _load();
    if (mounted) {
      _showMessage(
          publish ? 'Documento publicado.' : 'Documento despublicado.');
    }
  }

  Future<void> _deleteDocument(Map doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar documento'),
        content: Text('¿Deseas dar de baja "${doc['title']}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await repository.deleteDocument(doc['id'] as String);
    if (!result.isSuccess && mounted) {
      _showMessage(result.failure!.message);
      return;
    }
    await _load();
    if (mounted) _showMessage('Documento dado de baja.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Categorías que puede usar el documento:
  /// - al crear: solo las activas;
  /// - al editar: las activas más la propia, aunque esté inactiva
  ///   (el backend acepta conservarla y solo exige que la nueva esté activa).
  List<Map> _availableCategories(Map? existing) {
    final currentId = existing?['category_id'] as String?;
    return categories
        .where((item) => item['is_active'] == true || item['id'] == currentId)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> _categoryDialog() async {
    final name = ControllerFieldPro();
    final formKey = GlobalKey<FormState>();
    await showDialog(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Nueva categoría'),
                content: Form(
                    key: formKey,
                    child: AppTextField(
                        controller: name,
                        label: 'Nombre',
                        maxLength: 150,
                        validators: [
                          RequiredValid(
                              error: 'Indique el nombre de la categoría.'),
                        ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final result = await repository.saveCategory(
                            name: name.getValue(),
                            sortOrder: categories.length,
                            active: true);
                        if (result.isSuccess && mounted) {
                          Navigator.pop(context);
                          _load();
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(result.failure?.message ??
                                  'No se pudo guardar la categoría.')));
                        }
                      },
                      child: const Text('Guardar'))
                ]));
    name.dispose();
  }

  Future<void> _documentDialog([Map? existing]) async {
    final number = ControllerFieldPro(),
        title = ControllerFieldPro(),
        description = ControllerFieldPro(),
        publishedAt = ControllerFieldPro();
    final formKey = GlobalKey<FormState>();
    String? category = existing?['category_id'] as String? ??
        categories.first['id'] as String?;
    PlatformFile? file;
    final currentPdf = existing?['pdf'] as Map?;
    if (existing != null) {
      number.setValue(existing['number'] as String? ?? '');
      title.setValue(existing['title'] as String? ?? '');
      description.setValue(existing['description'] as String? ?? '');
    }
    publishedAt.setValue(initialPublishedAt(existing));
    await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (context, refresh) => AlertDialog(
                    title: Text(existing == null
                        ? 'Nuevo documento de Gaceta'
                        : 'Editar documento de Gaceta'),
                    content: SizedBox(
                        width: 460,
                        child: Form(
                            key: formKey,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DropdownButtonFormField<String>(
                                      value: category,
                                      decoration: decoration('Categoría'),
                                      validator: (value) =>
                                          Validator.validation(
                                              value,
                                              [
                                                RequiredValid(
                                                    error:
                                                        'Seleccione una categoría.')
                                              ],
                                              fieldLabel: 'Categoría'),
                                      items: _availableCategories(existing)
                                          .map((item) => DropdownMenuItem(
                                              value: item['id'] as String,
                                              child:
                                                  Text(item['name'] as String)))
                                          .toList(),
                                      onChanged: (value) =>
                                          refresh(() => category = value)),
                                  AppTextField(
                                      controller: number,
                                      label: 'Número',
                                      maxLength: 100,
                                      validators: [
                                        RequiredValid(
                                            error:
                                                'Indique el número del documento.'),
                                      ]),
                                  AppTextField(
                                      controller: title,
                                      label: 'Título',
                                      maxLength: 500,
                                      validators: [
                                        RequiredValid(
                                            error:
                                                'Indique el título del documento.'),
                                      ]),
                                  AppTextField(
                                      controller: description,
                                      label: 'Descripción',
                                      maxLength: 2000),
                                  AppTextField(
                                      controller: publishedAt,
                                      label: 'Fecha de publicación',
                                      helperText: 'Formato AAAA-MM-DD',
                                      maxLength: 10,
                                      validators: [IsoDateValid()]),
                                  if (currentPdf != null && file == null)
                                    Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                            'PDF actual: ${currentPdf['original_filename']}')),
                                  OutlinedButton.icon(
                                      onPressed: () async {
                                        final result = await FilePicker.platform
                                            .pickFiles(
                                                type: FileType.custom,
                                                allowedExtensions: ['pdf'],
                                                withData: true);
                                        if (result != null) {
                                          refresh(
                                              () => file = result.files.single);
                                        }
                                      },
                                      icon: const Icon(Icons.upload_file),
                                      label: Text(file == null
                                          ? (existing == null
                                              ? 'Seleccionar PDF'
                                              : 'Reemplazar PDF')
                                          : file!.name))
                                ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: (existing == null && file == null) ||
                                  category == null
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }
                                  final dateValue =
                                      publishedAt.getValue().trim();
                                  final data = FormData.fromMap({
                                    'category_id': category,
                                    'number': number.getValue(),
                                    'title': title.getValue(),
                                    'description': description.getValue(),
                                    'published_at': dateValue,
                                    'is_published':
                                        existing?['is_published'] == true
                                            ? 'true'
                                            : 'false',
                                  });
                                  if (file != null) {
                                    data.files.add(MapEntry(
                                        'pdf',
                                        MultipartFile.fromBytes(file!.bytes!,
                                            filename: file!.name)));
                                  }
                                  final navigator = Navigator.of(context);
                                  final result =
                                      await repository.uploadDocument(data,
                                          id: existing?['id'] as String?);
                                  if (result.isSuccess && mounted) {
                                    navigator.pop();
                                    await _load();
                                    _showMessage(existing == null
                                        ? 'Documento creado.'
                                        : 'Documento actualizado.');
                                  } else if (mounted) {
                                    _showMessage(result.failure?.message ??
                                        'No se pudo guardar el documento.');
                                  }
                                },
                          child: const Text('Guardar'))
                    ])));
    number.dispose();
    title.dispose();
    description.dispose();
    publishedAt.dispose();
  }
}

class _GacetaHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Expanded(flex: 4, child: Text('Número / título')),
          SizedBox(width: 130, child: Text('Categoría')),
          SizedBox(width: 120, child: Text('Fecha')),
          SizedBox(width: 120, child: Text('Estado')),
          SizedBox(width: 260, child: Text('Acciones')),
        ]),
      );
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends AdminPageState<UsersPage> {
  List<dynamic> items = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await repository.users();
    if (result.isSuccess) {
      items = result.value!;
    } else {
      error = result.failure?.message;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => loading
      ? busyOrError()
      : Padding(
          padding: const EdgeInsets.all(28),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Usuarios autorizados',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Expanded(
                child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, i) {
                      final item = items[i] as Map;
                      final roles =
                          (item['roles'] as List<dynamic>? ?? []).join(', ');
                      return ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(item['username'] as String),
                          subtitle: Text('${item['email'] ?? ''} · $roles'),
                          trailing: Text(item['is_active'] == true
                              ? 'Activo'
                              : 'Inactivo'));
                    }))
          ]));
}

class RolesPage extends StatefulWidget {
  const RolesPage({super.key});
  @override
  State<RolesPage> createState() => _RolesPageState();
}

class _RolesPageState extends AdminPageState<RolesPage> {
  List<dynamic> items = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await repository.roles();
    if (result.isSuccess) {
      items = result.value!;
    } else {
      error = result.failure?.message;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => loading
      ? busyOrError()
      : Padding(
          padding: const EdgeInsets.all(28),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Roles y permisos',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Expanded(
                child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, i) {
                      final item = items[i] as Map;
                      final permissions =
                          (item['permission_ids'] as List<dynamic>? ?? [])
                              .length;
                      return ListTile(
                          leading: const Icon(Icons.security_outlined),
                          title: Text('${item['name']} (${item['code']})'),
                          subtitle: Text('$permissions permisos'),
                          trailing: Text(item['is_active'] == true
                              ? 'Activo'
                              : 'Inactivo'));
                    }))
          ]));
}
