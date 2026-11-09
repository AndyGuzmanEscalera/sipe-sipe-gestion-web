# AUDITORÍA UI/UX Y DE CONSISTENCIA
## Sipe Sipe Gestión — Panel administrativo Flutter Web

**Fecha:** 19/10/2026
**Alcance:** auditoría de solo lectura. No se modificó código, backend, Astro ni base de datos.
**Proyecto auditado:** `C:\dev\sipe_sipe_gestion`
**Referencia arquitectónica:** `C:\dev\correspondencia_sipe_sipe`

### Método

1. Lectura íntegra de `flutter_app/lib/main.dart` (1054 líneas, archivo único de UI).
2. Lectura del design system y widgets de Correspondencia (`core/theme/`, `shared/widgets/`, `core/auth/`, `features/administration/`).
3. Levantar backend real (Docker + PostgreSQL `gestion_sipe`) con datos de auditoría representativos.
4. Capturar **13 pantallas reales** con Chrome headless (Playwright) sobre el build `flutter build web` de Flutter, en 1440×900, 1280×800, 900×700 y 420×820.
5. Verificar en código el origen exacto de cada hallazgo.

Capturas en `e2e/shots/` (ignoradas por git, no forman parte del repositorio).

---

# 1. Resumen ejecutivo

## Veredicto

**Funcionalmente sólido, visualmente en estado de prototipo.** El panel cumple su objetivo operativo y el flujo crítico de Gaceta ya funciona de extremo a extremo (crear → editar → publicar → despublicar → baja lógica con refresco automático). Sin embargo, **el panel no comparte design system con Correspondencia**: no tiene `core/theme/`, no tiene `shared/widgets/`, no tiene `AppDataGrid`, no tiene `AppFormDialog`, no tiene `StatusBadge`, no tiene `EmptyState`, no tiene `PermissionGuard` y no tiene sidebar oscuro con secciones.

## Diagnóstico resumido

| Dimensión | Estado | Nota |
|---|---|---|
| Funcionalidad de negocio | Bien | Endpoints y flujos correctos; Gaceta completo |
| Coherencia con Correspondencia | Ausente | 0 de 12 widgets reutilizables del panel de referencia |
| Design system propio | Inexistente | 6 colores literales, sin tokens, sin tema Material consolidado |
| Densidad / layout | Deficiente | Formularios a 1290 px de ancho, ~450 px de vacío bajo el contenido |
| Responsive | Roto | El encabezado de Gaceta colapsa a 10 px y renderiza texto vertical |
| Accesibilidad básica | Débil | 0 `Semantics`, 1 `Tooltip`, iconos de acción sin texto |
| Tablas | Ausentes | 0 `DataTable`/`AppDataGrid`; 3 `ListTile` que simulan tablas |
| Feedback | Parcial | Gaceta tiene snackbars; Settings/Institucional/Valores no |
| Permisos visibles | Parcial | Solo Gaceta los aplica; el resto de pantallas no |

## Los cinco problemas que más impactan al usuario

1. **P0 — Los módulos de administración no se pueden administered desde la UI.** Usuarios, Roles, Valores y Categorías son de solo lectura: no hay creación, edición, activación/desactivación ni ordenamiento, aunque el backend expone `POST/PUT /api/admin/users`, `POST /api/admin/users/{id}/activate|deactivate`, `POST/PUT /api/admin/roles`, `PUT /api/admin/institutional/values/{id}` y `POST .../activate|deactivate`. En particular **no existe botón "Nuevo usuario"** en `UsersPage` (`main.dart:949-1000`) ni **listado de categorías** en `GacetaPage` (el botón "Categorías" solo abre un diálogo de alta, `main.dart:789-814`).

2. **P0 — La columna de fecha del documento de Gaceta no es editable.** `_documentDialog` (`main.dart:816-932`) no tiene campo de fecha: en alta se fija `DateTime.now()` (líneas 899-903) y en edición se copia `existing['published_at']` sin exponerlo. El requisito funcional "establecer fecha" es inalcanzable desde la UI.

3. **P1 — El responsive de Gaceta está roto de forma verificable.** `_GacetaHeader` (`main.dart:935-947`) es un `Row` con anchos fijos (130+120+120+260 = 630 px) sin el `LayoutBuilder` que sí tienen las filas (`main.dart:683-722`). A 420 px el encabezado se comprime a ~10 px y "Número / título" se dibuja **letra por letra en vertical** (captura `23-mobile-gaceta.png`). A 900 px el encabezado muestra columnas while las filas usan el layout apilado → **encabezado y filas desalineados** (`23-tablet-gaceta.png`).

4. **P1 — La acción destructiva "Eliminar" es visualmente idéntica a "Guardar".** En `_deleteDocument` (`main.dart:766-771`) el botón de confirmación es un `FilledButton` verde, el mismo componente y color que el guardado de todos los formularios. Un `AppDataGridAction` de Correspondencia resuelve esto con `color` configurable (`shared/widgets/data_grid/app_data_grid_action.dart:14,22`).

5. **P1 — El formulario de Configuración del sitio expone nombres de clave de API como etiquetas.** `_label()` (`main.dart:373-375`) solo humaniza `shortName`; el resto se muestra como `LocationLine`, `SupportEmail`, `ShortName`… Evidencia en captura `02-shell-sitio.png`. Además el campo "Hours" **recorta su contenido** ("…y 14:00–18:0(") porque el `TextField` es de una sola línea con ancho fijo de 360 px (líneas 350-359).

---

# 2. Arquitectura visual actual

## Estructura real del proyecto Flutter

```
flutter_app/
├── lib/
│   └── main.dart          ← 1054 líneas: TODO el panel
├── packages/
│   ├── failures/
│   ├── gestion_api/
│   └── gestion_repository/
└── test/failures_test.dart
```

**No existe** `lib/core/`, `lib/features/`, `lib/shared/`, `lib/injection/` ni `lib/core/theme/`. Verificado:

```
Test-Path flutter_app/lib/core\theme  → False
Test-Path flutter_app/shared         → False
Get-ChildItem flutter_app/lib -Recurse -File → 1 archivo (main.dart)
```

## Inventario de widgets del panel (todo en `main.dart`)

| Widget | Línea | Responsabilidad |
|---|---|---|
| `GestionApp` | 47-68 | `MaterialApp` + `ThemeData` inline + `RepositoryProvider` + `BlocProvider` |
| `SessionCubit` | 23-45 | Login, restore por refresh, logout |
| `AppShell` | 70-158 | `Scaffold` + `Row` con `NavigationRail` + `AppHeader` + páginas |
| `AppHeader` | 160-187 | Título, usuario, logout |
| `LoginPage` | 189-274 | Formulario de acceso |
| `AdminPageState` | 276-295 | Base abstracta: `loading`, `error`, `run()`, `decoration()` |
| `SettingsPage` | 297-376 | 15 campos de configuración |
| `MayorPage` | 378-471 | 5 campos + upload de foto |
| `InstitutionalPage` | 473-527 | Misión y visión |
| `ValuesPage` | 529-607 | Listado de valores + diálogo de alta |
| `GacetaPage` | 609-933 | Listado de documentos + categorías + diálogo de documento |
| `_GacetaHeader` | 935-947 | Encabezado de columnas de la tabla manual |
| `UsersPage` | 949-1000 | Listado de usuarios (solo lectura) |
| `RolesPage` | 1002-1054 | Listado de roles (solo lectura) |

## Capas de datos

El patrón de acceso a datos es correcto y consistente con Correspondencia:

```
Widget → AdminPageState.repository → GestionRepository → Result<T> → GestionApi (Dio) → FastAPI
```

`GestionRepository` envuelve cada llamada en `Result<T>` con `_run()` (`gestion_repository.dart:74-80`) y traduce excepciones a `Failure`. El Cubit (`SessionCubit`) es el único `Cubit` del proyecto; el resto de pantallas heredan de `AdminPageState`, que es un `State` con estado local, no un Cubit.

**Riesgo estructural:** al no existir features separadas, cualquier equipo queMedicare la V1inalesгура de un módulo toca el mismo archivo de 1054 líneas. Eso contradice el objetivo declarado de "plataforma modular" y va a impedir crecer hacia los módulos futuros (funcionarios, asistencia, RRHH).

## Navegación

`AppShell` (`main.dart:106-156`) construye:

```
Scaffold
└── Row
    ├── NavigationRail (7 destinos, sin secciones)
    ├── VerticalDivider(width: 1)
    └── Expanded
        └── Column
            ├── AppHeader (76 px)
            └── Expanded(pages[index])
```

La navegación es un índice numérico (`int index = 0`) con dos listas paralelas: `titles` (líneas 84-92) y `pages` (líneas 97-105). Añadir un módulo exige editar **las dos listas**, y el orden no está agrupado.

---

# 3. Design system actual

## Realidad: no hay design system

El tema se define inline en `GestionApp.build` (`main.dart:57-63`):

```dart
theme: ThemeData(
  colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xff087443),
      brightness: Brightness.light),
  scaffoldBackgroundColor: const Color(0xfff6f8f7),
  useMaterial3: true,
),
```

`ColorScheme.fromSeed` genera la paleta completa a partir de una semilla. Consecuencias:

- El verde `#087443` produce un `primary` usable, pero **todos** los colores secundarios, terciarios, superficies y contenedores son derivados algorítmicamente, no escolhidos. De ahí el tinte verde de la tarjeta del login (`surfaceContainerLow`).
- **No hay `textTheme` custom**: tipografía, pesos y alturas son los de Material por defecto.
- **No hay `inputDecorationTheme`**: cada `TextField` declara `border: const OutlineInputBorder()` inline (línea 294 y en todas las pantallas). El radio de esquina, el `fillColor`, el `contentPadding` y el `focusedBorder` son los del tema M3 por defecto, distintos de Correspondencia.
- **No hay `cardTheme`, `dialogTheme`, `chipTheme`, `dataTableTheme`, `elevatedButtonTheme`, `outlinedButtonTheme`, `textButtonTheme`**.

## Colores literales dispersos (medición sobre `main.dart`)

| Literal | Veces | Ubicación | Significado implícito |
|---|---|---|---|
| `0xff087443` | 3 | 59 (seed), 116 (icono rail), 214 (icono login) | Verde institucional |
| `0xfff6f8f7` | 1 | 61 | Fondo de scaffold |
| `0xffdce8e0` | 1 | 170 | Borde del header |
| `0xff52675e` | 1 | 179 | Texto secundario (usuario) |
| `0xffd9f2e3` | 1 | 696 | Fondo chip "Publicado" |
| `0xfff1f1ed` | 1 | 696 | Fondo chip "Borrador" |

Adicionalmente **32 referencias a `Colors.*` e `Icons.*`** sin tokenizar.

## Contraste de tokens con Correspondencia

| Rol | Correspondencia (`ui_colors.dart`) | Gestión (`main.dart`) | ¿Coincide? |
|---|---|---|---|
| Verde primario | `#08813A` (línea 5) | `#087443` | **No** |
| Fondo | `#F8FAFC` (línea 11) | `#F6F8F7` | **No** |
| Borde | `#E2E8F0` (línea 14) | `#DCE8E0` | **No** |
| Borde claro | `#F1F5F9` (línea 15) | — | Ausente |
| Texto primario | `#10251A` (línea 21) | — | Ausente |
| Texto secundario | `#64748B` (línea 22) | `#52675E` | **No** |
| Texto muted | `#94A3B8` (línea 23) | — | Ausente |
| Sidebar | `#10251A` (línea 17) | — | Ausente |
| Peligro | `#DC2626` (línea 33) | — | Ausente |

**El verde institucional oficial documentado en Correspondencia (`PROJECT_CONTEXT.md`: "Verde oficial #08813A centralizado") no es el que usa Gestión.** Los dos sistemas municipales muestran verdes distintos en pantalla. Este es el hallazgo de consistencia más fácil de corregir y de mayor visibilidad.

## Radios, sombras y espaciado

| Concepto | Correspondencia | Gestión |
|---|---|---|
| Radio | 10 / 16 / 24 / 32 (`app_decorations.dart:5-8`) | Solo el default M3 (~4-12 px) |
| Sombra | 3 niveles (`shadowSm/Md/Lg`) | `elevation: 0` en el login; ninguna en el resto |
| Superficie elevada | `surfaceCard()` con borde `borderLight` + `shadowMd` | Indefinido |
| Padding de página | `PageContainer` 32/28/32/32 | `EdgeInsets.all(28)` repetido en 5 pantallas |
| Padding de contenido | `AdminContent` 16 o 28 según `isSmallScreen` | Fijo 28 |

## Tipografía

Gestión usa la `TextTheme` por defecto de Material 3. Los únicos ajustes explícitos:

- `headlineSmall` + `FontWeight.w800` en el título del login (líneas 216-221).
- `titleLarge` + `FontWeight.w700` en el header (líneas 172-177).
- `titleMedium` en "Usuarios autorizados" (980) y "Roles y permisos" (1033) — **sin `FontWeight`**, se ven más débiles que los títulos de pantalla.
- `bodySmall` para la línea categoría·fecha en Gaceta (690).
- `TextStyle(fontWeight: FontWeight.w600)` para el título de fila (687).

No hay control de altura de línea (`bodyLarge`/`bodyMedium` con `height: 1.5/1.45` en Correspondencia). No hay `letterSpacing` definido.

Correspondencia fija `fontFamily: 'Segoe UI'` (`app_theme.dart:7`). Gestión usa la fuente por defecto del sistema en Flutter Web.

---

# 4. Problemas globales

| # | Prio | Archivo / zona | Problema |
|---|---|---|---|
| G1 | **P0** | `main.dart:949-1054` (Users/Roles), `529-607` (Values), `789-814` (Categorías) | CRUD incompletos: el backend soporta alta/edición/baja/orden, la UI solo lista (o ni lista) |
| G2 | **P0** | `main.dart:816-932` | La fecha de publicación del documento no es editable |
| G3 | **P1** | `main.dart:106-156` | Sin sidebar ni agrupación de módulos; 7 destinos planos sin secciones "Página Web / Gaceta / Administración" |
| G4 | **P1** | `main.dart:57-63` | Sin `core/theme/`; sin tokens; verde institucional distinto al de Correspondencia |
| G5 | **P1** | `main.dart:673-375` y todas las pantallas | Sin `shared/widgets/`; 0 `AppDataGrid`, 0 `AppFormDialog`, 0 `StatusBadge`, 0 `EmptyState`, 0 `PermissionGuard` |
| G6 | **P1** | `main.dart:107-146` | La navegación no filtra por permisos: un EDITOR ve "Usuarios" y "Roles" (y recibe 403 al abrir) |
| G7 | **P1** | `main.dart:766-771` | Acción destructiva con el mismo `FilledButton` verde que "Guardar" |
| G8 | **P1** | `main.dart:935-947` vs `683-722` | `_GacetaHeader` no comparte el `LayoutBuilder` de las filas → desalineación y colapso |
| G9 | **P1** | `main.dart:350-359` | Ancho fijo de 360 px por campo + `Wrap` → filas huérfanas y recorte de contenido ("Hours") |
| G10 | **P1** | `main.dart:280-291` (`AdminPageState.run`) | Sin feedback de éxito: Settings e Institucional guardan en silencio |
| G11 | **P2** | `main.dart:282-291` | `run()` captura el error y lo muestra como texto plano en el centro de la página, no como snackbar |
| G12 | **P2** | `main.dart:280-281` | `busyOrError()` muestra `CircularProgressIndicator` sin contenedor ni mensaje de contexto |
| G13 | **P2** | `main.dart` (todo el archivo) | Sin `Semantics` (0 usos) → lectores de pantalla no anuncian estados ni acciones |
| G14 | **P2** | `main.dart:734-742` | Solo las acciones de Gaceta tienen `Tooltip` (1 uso en todo el panel) |
| G15 | **P2** | `main.dart:181-184` | Logout solo con icono; sin rótulo visible del rol ni confirmación |
| G16 | **P3** | `main.dart` | 1054 líneas en un archivo; sin separación por features |
| G17 | **P3** | `main.dart:213-214`, `115-116` | Icono `Icons.account_balance` genérico en lugar del escudo oficial del GAM |
| G18 | **P3** | `main.dart:1-3` | `dart:html` importado con `ignore` → workaround local en vez de servicio de plataforma |

---

# 5. Auditoría por pantalla

## 5.1 Login — `main.dart:189-274`

Captura: `01-login-desktop.png`, `01-login-mobile.png`

| Aspecto | Evaluación |
|---|---|
| Composición | Correcta: tarjeta centrada con `ConstrainedBox(maxWidth: 420)` |
| Identidad | **Débil.** `Icons.account_balance` (línea 213) es un icono genérico de Material, no el escudo oficial. Correspondencia usa `OfficialLogo(white: true)` con el PNG real (`side_menu_widget.dart:48`) |
| Subtítulo | "Plataforma de Gestión Municipal" presente y correcto (línea 222) |
| Color de tarjeta | El `Card` sin `color` explícito toma `surfaceContainerLow` del seed → **verde muy tenue**. Se ve como un bloque verde en lugar de una tarjeta blanca |
| Campos | Correctos: label + `OutlineInputBorder`. Sin iconos, sin autofill, sin "mostrar contraseña" |
| Botón | Correcto, `FilledButton` con spinner de 18 px (246-252) |
| Error | Texto rojo plano bajo el campo (237-244). Sin icono, sin fondo, sin `Semantics` |
| Loading | Correcto: el botón se deshabilita y muestra spinner |
| Responsive | El `ConstrainedBox(420)` + `Padding(32)` deja los inputs a ~8 px del borde a 420 px de ancho. Aceptable pero apretado |

**P2** — Usar el escudo oficial (`assets/branding/`) en lugar de `Icons.account_balance`.
**P2** — Fijar `color: Colors.white` en la `Card` o usar un `AppSurface` con borde.
**P3** — Añadir `prefixIcon` de usuario/candado y `autofillHints`.

## 5.2 Shell y navegación — `main.dart:70-187`

Capturas: `02-shell-sitio.png`, `22-tablet-shell.png`, `22-mobile-shell.png`

| Aspecto | Evaluación |
|---|---|
| Marca | **Ausente.** Solo un icono verde de 32 px (115-116). No aparece "Sipe Sipe Gestión" en ningún lugar del shell |
| Tipo de navegación | `NavigationRail` en lugar de sidebar. Ocupa ~88 px y **no admite secciones** |
| Agrupación | **Ausente.** 7 destinos planos: Sitio, Alcalde, Institucional, Valores, Gaceta, Usuarios, Roles. El usuario pidió explícitamente "Página Web / Gaceta / Administración" |
| Estado activo | Correcto: fondo verde tenue + icono filled (Rail behavior por defecto) |
| Header | Altura fija 76 px, fondo blanco, borde `0xffdce8e0`. Título a la izquierda, usuario + logout a la derecha |
| Usuario | Solo el username. No se muestra el rol ni los permisos efectivos |
| Logout | `IconButton` con `Tooltip` (181-184). Es la única acción con tooltip del panel |
| Breadcrumb / descripción | Ausentes. El header solo dice "Gaceta municipal" sin contexto de la página ni del módulo |
| Responsive | **El `NavigationRail` es fijo y no tiene alternativa.** En 420 px ocupa el 21 % del ancho útil |

**P1** — Sustituir `NavigationRail` por sidebar oscuro de 280 px (como Correspondencia) con secciones. Ganancia: espacio para etiquetas largas, agrupación, identidad institucional visible.
**P1** — Mostrar el rol del usuario en el header (`ADMIN` / `EDITOR`).
**P2** — Añadir subtítulo de página bajo el título.
**P3** — Mostrar el escudo y el nombre del sistema en el header del sidebar.

## 5.3 Configuración del sitio — `main.dart:297-376`

Captura: `02-shell-sitio.png`

| Aspecto | Evaluación |
|---|---|
| Agrupación | **Ausente.** 15 campos planos en un `Wrap` (350-359) |
| Etiquetas | **Defectuosas.** `_label()` (373-375) solo humaniza `shortName`. Se ven `LocationLine`, `SupportEmail`, `ShortName` en pantalla |
| Ancho | 360 px fijos. A 1440 px salen 3 columnas; la última fila queda con 2 campos huérfanos |
| Recorte | **Defectuoso.** El campo "Hours" corta su contenido ("…14:00–18:0(") — `TextField` de una línea, ancho fijo |
| Helper text | Ausente en los 15 campos |
| Validación | Ninguna. URL sin validar, email sin validar, horas sin validar |
| Botón Guardar | Correcto, alineado a la izquierda (361-369) |
| Feedback de éxito | **Ausente.** `run()` (282-291) no muestra snackbar |
| Feedback de error | Solo como texto plano en el centro de la página, que sustituye el formulario entero |
| Estado sucio | **Ausente.** No se detecta si hay cambios sin guardar |

**P1** — Humanizar las 15 etiquetas con un mapa explícito (o un helper `humanize` con diccionario de excepciones: `locationLine` → "Ubicación", `supportEmail` → "Correo de soporte", etc.).
**P1** — Agrupar en secciones con subtítulos: *Identidad* / *Contacto* / *Institucional* / *Redes sociales*.
**P1** — Feedback de éxito explícito ("Configuración guardada").
**P2** — `TextField` con `maxLines: 2` para campos largos (horarios, dirección, lema) o ancho mayor.
**P2** — Helper text en URLs ("https://…") y emails.
**P3** — Indicador de cambios sin guardar.

## 5.4 Alcalde — `main.dart:378-471`

Captura: `03-alcalde.png`

| Aspecto | Evaluación |
|---|---|
| Ancho | **Todo a 1290 px.** "Nombre" y "Cargo" son inputs de una línea de 1290 px para 20-30 caracteres. Muy anti-ergonómico |
| Distribución | Una sola columna vertical. Sin panel lateral para la foto |
| Preview de foto | **Ausente.** No hay imagen de la foto guardada, ni miniatura, ni previsualización del archivo nuevo |
| Upload | `OutlinedButton.icon` a ancho completo (439-448) → visualmente parece un campo deshabilitado, no un botón |
| Reemplazo | Cuando ya hay foto, el botón dice "Seleccionar foto" (448), sin indicar que reemplazará la existente |
| Campo "Mensaje" | `minLines: 4` con valor vacío → **la etiqueta "Mensaje" queda flotando en el centro del área** (visible en captura). Parece roto |
| Botón Guardar | `FilledButton` a **ancho completo** (450-451) → botón gigante |
| Feedback | Correcto: snackbar "Alcalde guardado" / error (463-469) |
| Nota de foto | Campo de texto libre sin explicación de para qué sirve |

**P1** — Contenedor de formulario con ancho máximo (720-820 px) y dos columnas en desktop: foto a la izquierda, datos a la derecha.
**P1** — Previsualizar la foto actual y la nueva seleccionada (con `Image.network` sobre `photo.url`).
**P2** — Corregir el campo "Mensaje": usar `minLines: 5` con etiqueta flotante correcta o `labelText` con `alignLabelWithHint: true`.
**P2** — Button "Reemplazar foto" cuando ya existe, "Seleccionar foto" cuando no.
**P3** — Quitar el botón de ancho completo.

## 5.5 Institucional — `main.dart:473-527`

Captura: `04-institucional.png`

| Aspecto | Evaluación |
|---|---|
| Layout | Correcto: misión y visión apiladas |
| Ancho | 1290 px completos para textos de 2 líneas |
| Altura | `minLines: 5` → ~155 px por campo para 2 líneas de contenido. ~70 % de espacio vacío |
| Relación con Valores | Los valores están en **otra página del rail** ("Valores"), no dentro de "Institucional". Conceptualmente son el mismo bloque institucional |
| Botón | Alineado a la izquierda, correcto |
| Feedback de éxito | **Ausente** (mismo `run()`) |

**P2** — Ancho máximo 820 px y `minLines: 3`.
**P2** — Reconsiderar: ¿Valores dentro de la página Institucional con un subsection, o mantener la página separada pero con el rail mostrando la relación? El brief del usuario pide "jerarquía entre contenido institucional y valores" en la misma pantalla.
**P1** — Feedback de éxito.

## 5.6 Valores institucionales — `main.dart:529-607`

Captura: `05-valores.png`

| Aspecto | Evaluación |
|---|---|
| Listado | `ListTile` + `Divider` (567-579). 4 campos (valor, orden, estado, id) repartidos entre `title`/`subtitle`/`trailing` |
| Acciones | **Ninguna.** No se puede editar, activar/desactivar ni cambiar el orden, aunque la API soporta `PUT /api/admin/institutional/values/{id}` y `POST .../deactivate` |
| Estado | "Activo"/"Inactivo" como **texto plano** en el `trailing` (576-577) → inconsistente con el `Chip` de Gaceta |
| Orden | Se muestra "Orden: N" pero es de solo lectura. El `sortOrder` se calcula como `items.length` al crear (597) → los valores creados quedan al final y nunca se reordenan |
| Botón | "Nuevo valor" `FilledButton.icon` (561-565). Correcto |
| Diálogo | `AlertDialog` crudo (583-605), un solo campo, sin `AppFormDialog` |
| Feedback | **Ausente.** Al guardar no hay snackbar; solo se cierra y recarga |
| Estado vacío | **Ausente.** Con 0 valores se ve un `ListView` vacío sin explicación |
| Espacio | ~340 px vacíos bajo la lista |

**P0** — Añadir acciones por fila: editar, activar/desactivar, subir/bajar orden. El backend ya soporta todo.
**P1** — Cambiar el estado a `StatusBadge` (como Correspondencia).
**P1** — Diálogo de edición (no solo alta) con `AppFormDialog`.
**P1** — Feedback de éxito/Error.
**P2** — `EmptyState` con icono y llamada a la acción ("Crear el primer valor").

## 5.7 Gaceta Municipal — `main.dart:609-947`

> Detalle en la sección 6.

## 5.8 Categorías de Gaceta

Captura: `10-gaceta-categorias.png`

| Aspecto | Evaluación |
|---|---|
| Pantalla | **No existe.** El botón "Categorías" (651-653) abre directamente un diálogo de alta (789-814) |
| Listado | **Ausente.** No se ven las categorías existentes, no se pueden editar, activar/desactivar ni ordenar |
| Backend | `/api/admin/gaceta/categories` soporta GET/POST/PUT y `POST /{id}/activate|deactivate` |
| Flujo actual | El usuario tiene que adivinar el nombre de la categoría en el desplegable del documento, sin poder ver ni gestionar el catálogo |

**P0** — Pantalla de gestión de categorías (listado + CRUD + orden + activar/desactivar), alcanzable desde Gaceta.
**P1** — En el diálogo de documento, el desplegable de categoría debería mostrar solo activas y marcar visualmente la seleccionada.

## 5.9 Usuarios — `main.dart:949-1000`

Captura: `07-usuarios.png`

| Aspecto | Evaluación |
|---|---|
| Listado | `ListTile` (984-998). Username, email, roles y estado comprimidos en título+subtítulo+trailing |
| Columnas | No hay. Con 4 campos distintos por usuario, la tabla es la forma correcta |
| Alta | **Ausente.** No hay botón "Nuevo usuario" pese a que `POST /api/admin/users` existe |
| Edición | **Ausente.** `PUT /api/admin/users/{id}` existe |
| Activar/desactivar | **Ausente.** `POST /api/admin/users/{id}/activate|deactivate` existe |
| Contraseña | No se puede establecer ni restablecer |
| Roles | Se muestran como texto en el subtítulo. No hay selector |
| Búsqueda | Ausente. Con decenas de usuarios el listado es inmanejable |
| Estado | "Activo"/"Inactivo" texto plano (995-997), inconsistente con el chip de Gaceta |
| Título | "Usuarios autorizados" con `titleMedium` sin peso (980-981) |
| Permisos | La página no verifica `gestion.users.read`; un EDITOR sin permiso recibe un 403 y la pantalla queda en blanco con el error plano |

**P0** — Implementar el CRUD completo con `AppDataGrid` (alta, edición, activar/desactivar, reset de contraseña, selector de roles) y buscador.
**P1** — Badge de estado.
**P1** — Guard de permisos con `PermissionGuard` para mostrar "Acceso restringido" en vez de un error vacío.

## 5.10 Roles — `main.dart:1002-1054`

Captura: `08-roles.png`

| Aspecto | Evaluación |
|---|---|
| Listado | `ListTile` (1037-1052) |
| Permisos | Solo el **número** ("17 permisos"). No se puede ver ni editar la lista |
| Selección de permisos | **Ausente.** `POST/PUT /api/admin/roles` acepta `permission_ids` |
| Agrupación de permisos | Ausente (no hay UI) |
| Alta/edición de roles | **Ausente** |
| Activar/desactivar | **Ausente** |
| Naming | "Roles" en el rail vs "Roles y permisos" en la página → inconsistencia de terminología |
| Permisos en la UI | La pantalla no verifica `gestion.roles.read` |

**P0** — Implementar gestión de roles con selección de permisos agrupada por recurso.
**P1** — Cambiar la etiqueta del rail a "Roles y permisos" o el título de página a "Roles".

---

# 6. Auditoría de Gaceta (detalle)

## 6.1 Estado del problema reportado por el usuario

> "En la pantalla Gaceta municipal los documentos se muestran en una lista […] pero no existen acciones visibles para editar, publicar, despublicar, abrir PDF, eliminar/desactivar."

**Resolución parcial verificada.** Las acciones existen y funcionan (commit `df244a8`); la captura `06-gaceta.png` muestra las cuatro acciones por fila con iconos: lápiz (Editar), flecha arriba (Publicar/Despublicar), picture-as-pdf (Abrir PDF) y papelera (Eliminar).

**Pero el problema de fondo persiste:** las acciones son **icon-only**. El usuario tuvo que pedir explícitamente las acciones por su ausencia; un usuario nuevo no sabría qué significa el icono de flecha ascendente para "Publicar". Los tooltips existen (1 uso en todo el panel) pero requieren hover y no sonBJ襄ibles en táctil ni visibles en captura.

## 6.2 Lo que funciona correctamente

| Verificación | Estado | Evidencia |
|---|---|---|
| Columnas número, título, categoría, fecha, estado, acciones | Correcto | `06-gaceta.png` |
| Badge Publicado/Borrador | Correcto, con icono y color | `06-gaceta.png` |
| Publicar / despublicar alternos | Correcto | Fila 3 cambia a "Despublicar" y el badge a verde |
| Editar precarga los campos | Correcto | `11-gaceta-editar.png` |
| PDF actual visible al editar | Correcto | "PDF actual: test-document.pdf" |
| Reemplazo de PDF | Correcto | `PUT /api/admin/gaceta/{id}` con nuevo `media_id` y `storage_path` |
| Baja lógica con confirmación | Correcto | `12-gaceta-confirmar-baja.png` |
| Refresco automático tras cada acción | Correcto | Traza: `POST unpublish` → `GET categorías` → `GET documentos` |
| Feedback por snackbar | Correcto | "Documento publicado.", "Documento despublicado.", "Documento dado de baja." |
| Permisos ocultan acciones | Correcto | `hasPermission` (76-80) + `canManage`/`canPublish` (638-639, 699-712) |

## 6.3 Lo que todavía necesita mejora

### Gac-1 · P0 · La fecha de publicación no es editable
`_documentDialog` (`main.dart:816-932`) no incluye ningún campo de fecha. En alta:
```dart
'published_at': existing?['published_at'] as String? ??
    DateTime.now().toIso8601String().substring(0, 10),   // líneas 899-903
```
En edición se reutiliza el valor original sin exponerlo. **El requisito "establecer fecha" no se puede cumplir desde la UI.** La captura `11-gaceta-editar.png` lo confirma: los campos son Categoría, Número, Título, Descripción y PDF; no hay fecha.

### Gac-2 · P1 · La tabla es manual, no `AppDataGrid`
`_documentRow` (677-732) construye un `Row` con anchos fijos. No es `AppDataGrid`, que en Correspondencia ya resuelve:
- Sort por columna (`app_data_grid.dart:32-33, 216-240`)
- Paginación server-side (`app_data_grid.dart:41-45, 209-214` y `app_data_grid_pagination.dart`)
- Columnas declarativas (`AppDataGridColumn<T>`)
- Acciones con `visibleWhen` / `enabledWhen` / `color` (`app_data_grid_action.dart:11-13`)
- Layout responsive real: tabla en desktop, cards en móvil (`app_data_grid.dart:142-177`)

Gestión tiene **0** usos de `AppDataGrid`.

### Gac-3 · P1 · Anchos de columna fijos (130/120/120/260)
`main.dart:725-728` y `935-947`. Con un nombre de categoría largo el texto se desborda en una caja de 130 px. La tabla no es proporcional ni elástica.

### Gac-4 · P1 · `_GacetaHeader` no es responsive — CONFIRMADO
`main.dart:935-947` es un `Row` estático. Las filas sí usan `LayoutBuilder` con `constraints.maxWidth < 900` (714). Resultados capturados:

- **420 px** (`23-mobile-gaceta.png`): el `Expanded(flex: 4)` del encabezado queda con ~10 px porque los `SizedBox` fijos (630 px) consumen todo el ancho. "Número / título" se dibuja **vertical, letra por letra**. Las etiquetas "Categoría / Fecha / Estado" flotan sin datos debajo. El botón "Nuevo documento" queda cortado en el borde derecho.
- **900 px** (`23-tablet-gaceta.png`): el contenido útil es 812 px (< 900) → las filas pasan a layout apilado, pero el encabezado mantiene el layout horizontal. **Columnas y filas desalineadas**, acciones desconectadas del badge.

Es el defecto responsive más grave del panel y es verificable con capturas.

### Gac-5 · P1 · Iconos ambiguos
| Acción | Icono actual | Problema |
|---|---|---|
| Publicar | `Icons.publish` (704) | Renderiza como flecha **hacia arriba**, se lee como "subir archivo" |
| Despublicar | `Icons.visibility_off_outlined` (704) | Renders como ojo tachado, no como "despublicar" |
| Abrir PDF | `Icons.picture_as_pdf_outlined` (708) | Genérico; no comunica "descargar" |
| Eliminar | `Icons.delete_outline` (712) | Correcto, pero **mismo color y peso** que el resto |

Correspondencia resuelve esto con `PopupMenuButton` etiquetado cuando hay más de 2 acciones (`app_data_grid_actions_bar.dart:24-38`): muestra el texto de la acción.

### Gac-6 · P1 · "Eliminar" es verde
`main.dart:768-770`: `FilledButton` → verde primario, idéntico a "Guardar". Una acción destructiva debe usar `UiColors.danger` (`ui_colors.dart:33`) o un `OutlinedButton` con texto de peligro.

### Gac-7 · P1 · Sin buscador, sin filtros, sin paginación
`main.dart:616` (`List<dynamic> documents`), `623-631` (`_load` sin parámetros). El endpoint ya acepta `page`, `page_size`, `q` y `category` (`backend/app/main.py`, `@app.get('/api/admin/gaceta')`), y el cliente ya los envía (`gestion_api.dart`: `documents({String? query})` con `page: 1, page_size: 100`). La UI no expone ninguno. Con 500 gacetas se cargan todas en memoria.

### Gac-8 · P2 · Datos duplicados en la fila
Cada fila muestra la categoría y la fecha **dos veces**: en el subtítulo (689) y en columnas dedicadas (725-726). occupying espacio sin aportar información.

### Gac-9 · P2 · Botones "Categorías" y "Nuevo documento" ambos primarios
`main.dart:649-659`: dos `FilledButton` verdes contiguos. "Categorías" es una acción de navegación/administración, no la acción principal de la pantalla. Debería ser `OutlinedButton` o un enlace.

### Gac-10 · P2 · Chip de estado con colores literales
`main.dart:692-697`: `backgroundColor: published ? Color(0xffd9f2e3) : Color(0xfff1f1ed)`. El gris `0xfff1f1ed` es casi indistinguible de blanco; Correspondencia usa `StatusBadge` con paleta semántica y borde (`shared/widgets/status_badge.dart:26-31`).

### Gac-11 · P2 · Empty state sin tratamiento
`main.dart:666`: `Center(child: Text('No hay documentos de Gaceta.'))`. Sin icono, sin color differentiated, sin llamada a la acción ("Crear el primer documento"). Correspondencia tiene `EmptyState` con círculo de icono, título y mensaje (`shared/widgets/empty_state.dart:4-49`).

### Gac-12 · P2 · Falta el campo "Publicado" en el formulario
`_documentDialog` no ofrece el interruptor de publicación; el estado se conserva oculto (`existing?['is_published']`). El usuario edita un documento publicado sin saberlo ni poder despublicarlo desde el formulario (debe usar la acción de la fila).

### Gac-13 · P3 · Terminología inconsistente
- Página: "Gaceta municipal"
- Diálogo: "Nuevo documento de Gaceta"
- Botón: "Nuevo documento"
- Botón: "Categorías" (sin contexto)
- Diálogo: "Nueva categoría"
- Acción: "Eliminar documento" (pero es baja lógica)

### Gac-14 · P3 · Sin contador de resultados
No hay "3 documentos" ni "12 de 48". Con paginación esto será necesario.

---

# 7. Responsive

## Medición por viewport (capturas reales)

| Viewport | Login | Shell | Gaceta |
|---|---|---|---|
| 1440×900 | Correcto | Correcto | Correcto (tabla alineada) |
| 1280×800 | Correcto | Correcto | Correcto |
| 900×700 | Correcto | Rail ocupa 88 px de 900 | **Desalineado**: encabezado horizontal + filas apiladas |
| 420×820 | Correcto (ajustado) | Rail ocupa 21 % del ancho | **Roto**: columna de 10 px, texto vertical, botón cortado |

## Desbordamientos identificados en código

| Ubicación | Problema |
|---|---|
| `main.dart:935-947` | `_GacetaHeader`: 630 px fijos sin `Expanded` elástico → colapso total a 420 px |
| `main.dart:725-728` | Anchos fijos de columna en las filas (se adaptan al apilado, el encabezado no) |
| `main.dart:350-359` | `Wrap` con `SizedBox(width: 360)`: a 420 px de útil son 1 columna, pero el padding de 28+28 y el rail de 88 dejan 304 px → el campo de 360 px **desborda** |
| `main.dart:422-452` | `Column` con `crossAxisAlignment: stretch` → los inputs del Alcalde ocupan 100 % del ancho disponible; sin ancho máximo, a 420 px quedan ilegibles |
| `main.dart:106-146` | `NavigationRail` fijo, sin `Drawer` ni breakpoint |
| `main.dart:836-838` | `SizedBox(width: 460)` dentro del `AlertDialog` → a 420 px el diálogo es más ancho que la pantalla |
| `main.dart:161-186` | `AppHeader` con `Row`: título + usuario + logout. A 420 px el título se comprime |

## Veredicto responsive

**El panel está diseñado y validado únicamente en desktop.** No hay un solo breakpoint en el código. La responsive de las filas de Gaceta existe (el `LayoutBuilder` de la línea 683), pero es parcial y desincronizada del encabezado. El resto de pantallas (Settings, Alcalde, Institucional) no considera el ancho en absoluto.

Prioridad correcta según el brief: **no rompe el uso administrativo diario en desktop**, pero sí es un P1 porque la捕获 de evidencia muestra rotura visual real en tablet y móvil, y porque el panel ya se despliega como Flutter Web accesible desde cualquier equipo.

---

# 8. Comparación con Correspondencia

## 8.1 Lo que Gestión debería conservar de Correspondencia

| Componente | Ruta en Correspondencia | Por qué |
|---|---|---|
| `AppDataGrid` + `AppDataGridColumn` + `AppDataGridAction` | `lib/shared/widgets/data_grid/` (10 archivos) | Sort, paginación, responsive real, acciones con `visibleWhen`/`enabledWhen`/`color` |
| `AppFormDialog` | `lib/shared/widgets/app_form_dialog.dart` | Header sticky, footer fijo, scroll con `Scrollbar`, `maxHeight` 90 %, responsive |
| `AppTextField` + `AppDropdown` + `AppSearchableDropdown` + `AppTextPassword` | `lib/shared/widgets/form/` | Validación integrada, estilos unificados, `dropdownDecoration` con `isDense` (resuelve el bug de altura del dropdown) |
| `StatusBadge` | `lib/shared/widgets/status_badge.dart` | Badge semántico con `Semantics`, borde y paleta por estado |
| `EmptyState` | `lib/shared/widgets/empty_state.dart` | Icono + título + mensaje + CTA opcional |
| `SearchField` + `DataPanel` | `lib/shared/widgets/status_badge.dart:68-110` | Buscador y contenedor de tabla ya resueltos |
| `confirmAdminLogicalDelete` | `lib/features/administration/common/admin_logical_delete_dialog.dart` | Diálogo de baja lógica con `Cancelar`/`Eliminar` |
| `admin_active_filter` | `lib/features/administration/common/` | Filtro activos/inactivos/todos |
| `admin_upsert_bloc_listener` | `lib/features/administration/common/` | Feedback unificado tras upsert |
| `PermissionGuard` | `lib/core/auth/permission_guard.dart` | "Acceso restringido" en vez de error vacío |
| `Permissions` (constantes) | `lib/core/auth/permissions.dart` | Códigos de permiso centralizados en vez de strings literales |
| `UiColors` + `AppDecorations` + `AppTheme` | `lib/core/theme/` | Tokens de color, radios, sombras y tema Material completo |
| Sidebar oscuro con secciones | `lib/features/home/side_menu/widgets/side_menu_widget.dart` | Agrupación de módulos, marca institucional, ancho 280 px |
| Patrón `list_*` / `upsert_*` | `lib/features/administration/basic_data/units/` | Plantilla CRUD probada y usada por 5 módulos |
| `ControllerFieldPro` + validadores | `lib/core/util/form/` | Formularios con validación declarativa |
| `AppSurface` / `PageContainer` / `SectionHeader` | `lib/shared/widgets/` | Layout consistente |
| `OfficialLogo` | `lib/shared/widgets/official_logo.dart` | Escudo oficial real |

## 8.2 Lo que Correspondencia hace mal y Gestión no debe copiar

| Problema en Correspondencia | Observación | Recomendación para Gestión |
|---|---|---|
| `AppDecorations.heroStart/heroMid/heroEnd` (líneas 36-38) | Tokens de gradiente heredados que el propio archivo marca como "Legacy surface tokens; no gradients" | No replicar |
| `shadowMd`/`shadowLg` (`app_decorations.dart:22-41`) | Sombras de 24-48 px de blur en superficies de un panel administrativo | Usar solo `shadowSm` o ninguna; el brief pide explícitamente "sin sombras pesadas" |
| `radiusXl = 32` (`app_decorations.dart:8`) | Radio extremo para superficies de datos | Limitar a 16 px en Gestión |
| `UiColors.textMuted` sobre `UiColors.background` | Contraste bajo (~2.6:1) para texto auxiliar | No usarlo para texto informativo en Gestión |
| `AppDataGridAction` sin label visible | Solo tooltip; en móvil tampoco hay contexto | Añadir etiqueta textual en el `PopupMenuButton` |
| `StatusBadge` con `withOpacity` (línea 27) | API obsoleta en Flutter 3.22+ | Usar `withValues(alpha:)` si se adopta |
| Sidebar de 280 px fijos | Consume mucho ancho en laptop de 1366 px | Considerar 240 px colapsable |

## 8.3 Brecha cuantificada

| Capacidad | Correspondencia | Gestión | Brecha |
|---|---|---|---|
| `AppDataGrid` | Sí | No | Alta |
| `AppFormDialog` | Sí | No | Alta |
| `StatusBadge` | Sí | No (chip ad-hoc) | Media |
| `EmptyState` | Sí | No (texto plano) | Media |
| `SearchField` | Sí | No | Alta |
| `PermissionGuard` | Sí | No | Alta |
| Constantes de permisos | Sí | No (strings en línea) | Media |
| `UiColors` / tema | Sí | No | Alta |
| Sidebar con secciones | Sí | No (`NavigationRail`) | Alta |
| Filtro activos/inactivos | Sí | No | Media |
| Diálogo de baja lógica reutilizable | Sí | No (inline) | Media |
| Estructura por features | Sí | No (archivo único) | Alta |
| Pattern list/upsert | Sí | No | Alta |

**Veredicto:** Gestión replica el *comportamiento* funcional de Correspondencia pero no su *sistema visual*. El resultado son pantallas que funcionan pero que un desarrollador que conoce Correspondencia no reconocería.

---

# 9. Componentes reutilizables que deben conservarse

| Componente | Ubicación actual en Gestión | Acción recomendada |
|---|---|---|
| `GestionApi` (Dio + `ApiMethod`) | `packages/gestion_api/lib/gestion_api.dart` | **Conservar.** Correcto, tipado, con interceptor de token |
| `GestionRepository` (`Result<T>`) | `packages/gestion_repository/lib/gestion_repository.dart` | **Conservar.** Idéntico al patrón de Correspondencia |
| `failures` package | `packages/failures/lib/failures.dart` | **Conservar.** `Result`/`Ok`/`Err`/`Failure` idénticos |
| `SessionCubit` | `main.dart:23-45` | **Conservar** la lógica; mover a `lib/features/authentication/session/` |
| `hasPermission` | `main.dart:76-80` | **Conservar** la idea; mover a `lib/core/auth/permissions.dart` junto a las constantes |
| `_togglePublish`, `_deleteDocument`, `_documentDialog` | `main.dart:744-932` | **Conservar la lógica**; migrar a features con `AppDataGrid` |
| Validación de permisos en backend | Backend | **Conservar intacta.** Es la autoridad real |
| Reemplazo de PDF con mantenimiento del anterior | `main.dart:909-914` | **Conservar.** La estrategia de auditoría es correcta |

---

# 10. Componentes que deberían ajustarse

| Elemento | Archivo | Ajuste |
|---|---|---|
| `ThemeData` inline | `main.dart:57-63` | Extraer a `lib/core/theme/app_theme.dart` con `UiColors` + `AppDecorations` |
| `NavigationRail` | `main.dart:109-147` | Sustituir por sidebar con secciones y permisos |
| `_GacetaHeader` + `_documentRow` | `main.dart:677-947` | Migrar a `AppDataGrid` |
| 4 × `AlertDialog` crudo | `main.dart:585, 761, 793, 832` | Migrar a `AppFormDialog` |
| `ListTile` en Valores/Usuarios/Roles | `main.dart:573, 991, 1045` | Migrar a `AppDataGrid` |
| `Chip` de estado | `main.dart:692-697` | Migrar a `StatusBadge` |
| Textos "Activo"/"Inactivo" | `main.dart:576, 995, 1049` | Migrar a `StatusBadge` |
| `busyOrError()` | `main.dart:280-281` | Separar loading de error; usar `EmptyState` para vacío |
| `run()` sin feedback de éxito | `main.dart:282-291` | Añadir snackbar de éxito unificado |
| `decoration()` | `main.dart:293-294` | Reemplazar por `AppFormFieldStyle` / `AppTextField` |
| Colores literales | 6 ocurrencias | Migrar a `UiColors` |
| `_label()` | `main.dart:373-375` | Mapa explícito de etiquetas legibles |
| Icono del login y del rail | `main.dart:213, 115` | `OfficialLogo` con el escudo real |

---

# 11. Problemas de consistencia

| # | Problema | Implementaciones en conflicto |
|---|---|---|
| C1 | **Diálogos** | 4 `AlertDialog` crudos, cada uno con su propio layout y sus propios `TextButton`/`FilledButton`. Correspondencia tiene un único `AppFormDialog` |
| C2 | **Listados** | 3 formatos distintos: `ListTile`+`Divider` (Valores, Usuarios, Roles), tabla manual `Row`+`ListView.separated` (Gaceta), `Wrap` de campos (Settings) |
| C3 | **Estado** | 3 representaciones: `Chip` con avatar (Gaceta, línea 692), texto plano "Activo/Inactivo" (Valores 576, Usuarios 995, Roles 1049), `Chip` sin avatar en ninguna otra parte |
| C4 | **Tablas** | 0 tablas reales. Ninguna columna está declarada, ninguna es ordenable, ninguna tiene paginación |
| C5 | **Inputs** | 3 estilos: `TextField` + `decoration()` (Gestión), `TextField` + `OutlineInputBorder` directo (login, líneas 227-236), `AppTextField` + `AppFormFieldStyle` (Correspondencia) |
| C6 | **Botones** | `FilledButton` (11 usos), `OutlinedButton.icon` (2), `TextButton` (4), `IconButton` (acciones de Gaceta, logout) — sin jerarquía definida. Dos `FilledButton` verdes contiguos en Gaceta |
| C7 | **Feedback** | 3 mecanismos: `ScaffoldMessenger.showSnackBar` (6 usos), `run()` escribiendo en `error` (y mostrando texto en el centro de la página), y silencio absoluto (Settings, Institucional, Valores, Categorías) |
| C8 | **Colores de estado** | `0xffd9f2e3` (chip publicado) vs `0xfff1f1ed` (chip borrador) vs `UiColors.successSoft`/`primarySoft` en Correspondencia vs `error` del tema M3 para errores |
| C9 | **Verde institucional** | `#087443` en Gestión vs `#08813A` en Correspondencia |
| C10 | **Vacío** | `Center(Text(...))` en Gaceta (666) vs `EmptyState` con icono en Correspondencia vs nada en las otras 3 listas |
| C11 | **Iconografía** | `Icons.delete_outline` / `Icons.publish` / `Icons.picture_as_pdf_outlined` / `Icons.category` (que renderiza como una caja rara) sin一套 unificada |
| C12 | **Padding de página** | `EdgeInsets.all(28)` en 5 pantallas, `EdgeInsets.all(32)` en el login, `EdgeInsets.symmetric(horizontal: 28)` en el header → tres reglas distintas |
| C13 | **Títulos de página** | "Usuarios autorizados" y "Roles y permisos" (subtítulo) vs "Gaceta municipal" (título del rail) → jerarquía de títulos inconsistente |

---

# 12. Problemas UX

| # | Prio | Problema | Escena concreta |
|---|---|---|---|
| UX1 | **P0** | El usuario no puede crear, editar ni desactivar **usuarios, roles, valores ni categorías** | Un ADMIN abre "Usuarios": no hay ningún botón. El backend sí lo permite |
| UX2 | **P0** | No se puede elegir la fecha de publicación de un documento de Gaceta | El editor de un documento publicado de 2024 no puede corregir la fecha |
| UX3 | **P1** | El editor de Gaceta no ofrece el interruptor "Publicado" | Para despublicar hay que volver a la lista y pulsar un icono |
| UX4 | **P1** | Las acciones de Gaceta solo son iconos | El usuario tuvo que pedir las acciones explícitamente: la señal visual no era suficiente |
| UX5 | **P1** | Las etiquetas de Configuración del sitio son claves de API | `LocationLine`, `SupportEmail` |
| UX6 | **P1** | "Eliminar" es verde, igual que "Guardar" | El usuario puede confirmar una baja pensando que guarda |
| UX7 | **P1** | Guardar en Settings/Institucional no da ninguna confirmación | El usuario no sabe si funcionó |
| UX8 | **P1** | El rail muestra "Usuarios" y "Roles" a usuarios sin permiso | Un EDITOR pulsa y ve una pantalla vacía con un error plano |
| UX9 | **P1** | El contenido "Horarios" se recorta y no es legible | `…y 14:00–18:0(` |
| UX10 | **P1** | Responsive roto en tablet y móvil | Texto vertical en el encabezado de Gaceta |
| UX11 | **P2** | No hay indication de cambios sin guardar | El usuario puede perder cambios al navegar |
| UX12 | **P2** | "Nuevo documento" está deshabilitado sin explicación cuando no hay categorías | No hay texto que diga "crea una categoría primero" |
| UX13 | **P2** | El botón Guardar del diálogo de Gaceta está deshabilitado sin explicar por qué | Falta el PDF |
| UX14 | **P2** | Sin búsqueda en ninguna lista | Con cientos de gacetas es inmanejable |
| UX15 | **P2** | El diálogo de baja lógica usa comillas dobles `"` embebidas | `¿Deseas dar de baja "Documento acciones"?` — las comillas interferen con el título |
| UX16 | **P2** | No se puede reordenar valores ni categorías | `sort_order` existe en la API pero solo se puede asignar al crear |
| UX17 | **P2** | El listado de Gaceta no indica cuántos hay | Sin paginación ni contador |
| UX18 | **P3** | El header no muestra el rol | El ADMIN no sabe si está acting como ADMIN o EDITOR |
| UX19 | **P3** | El logout no pide confirmación | Un clic cierra sesión |
| UX20 | **P3** | Terminología inconsistente | "Gaceta municipal" / "documento de Gaceta" / "Nuevo documento" |

---

# 13. Problemas visuales

| # | Prio | Problema | Ubicación |
|---|---|---|---|
| V1 | **P1** | El verde de la tarjeta del login (`surfaceContainerLow` del seed) la hace parecer un bloque verde, no una tarjeta | `main.dart:205` |
| V2 | **P1** | Anchos de columna fijos sin proporcionalidad ni wrapping | `main.dart:725-728`, `935-947` |
| V3 | **P1** | Encabezado de tabla sin fondo, sin peso y sin separación de la primera fila | `main.dart:935-947` |
| V4 | **P1** | Formularios a 1290 px de ancho | `main.dart:422-452`, `501-516` |
| V5 | **P1** | Botón "Guardar alcalde" a ancho completo | `main.dart:450-451` |
| V6 | **P1** | El botón de selección de foto a ancho completo parece un input deshabilitado | `main.dart:439-448` |
| V7 | **P2** | Chip "Borrador" con fondo `0xfff1f1ed` casi indistinguible del fondo | `main.dart:696` |
| V8 | **P2** | Doble acción primaria verde contigua | `main.dart:649-659` |
| V9 | **P2** | ~350-450 px de espacio vertical vacío bajo el contenido en 5 de 7 pantallas | Todas |
| V10 | **P2** | Icono `Icons.category` renderiza como un glifo de caja poco legible | `main.dart:652` |
| V11 | **P2** | La etiqueta "Mensaje" del Alcalde flota en el centro del área vacía | `main.dart:431-435` |
| V12 | **P2** | `Icons.account_balance` en lugar del escudo oficial | `main.dart:115, 213` |
| V13 | **P2** | Tipografía sin jerarquía: "Usuarios autorizados" compite visualmente con el título de la pantalla | `main.dart:980, 1033` |
| V14 | **P3** | Radio de esquina del tema M3 por defecto en lugar de los 10/16 px institucionales | Global |
| V15 | **P3** | Sin `fontFamily` explícito | `main.dart:57-63` |

---

# 14. Mejoras rápidas

> Cambios pequeños, de alto impacto, sin tocar arquitectura ni backend.

| # | Prio | Mejora | Archivo / líneas | Esfuerzo |
|---|---|---|---|---|
| R1 | P0 | Añadir campo de fecha (`DatePicker` o `TextField` de fecha) al diálogo de documento | `main.dart:816-932` | 30 min |
| R2 | P0 | Botón "Nuevo usuario" + diálogo de alta con usuario, email, password y roles | `main.dart:949-1000` | 1-2 h |
| R3 | P0 | Pantalla de Categorías: listado + CRUD + activar/desactivar, alcanzable desde Gaceta | `main.dart:789-814` | 2-3 h |
| R4 | P1 | Humanizar las 15 etiquetas de Settings con un mapa explícito | `main.dart:373-375` | 20 min |
| R5 | P1 | Snackbar de éxito en `run()` y en el guardado de Settings/Institucional | `main.dart:282-291` | 20 min |
| R6 | P1 | Filtrar el rail por permisos (`hasPermission`) para ocultar "Usuarios"/"Roles" a EDITOR | `main.dart:109-147` | 30 min |
| R7 | P1 | Color de peligro en el botón "Eliminar" del diálogo de baja lógica | `main.dart:768-770` | 10 min |
| R8 | P1 | Hacer el `_GacetaHeader` responsive con el mismo `LayoutBuilder` que las filas | `main.dart:935-947` | 30 min |
| R9 | P1 | Envolver `_GacetaHeader` y las filas en un `SingleChildScrollView` horizontal en desktop | `main.dart:662, 664-672` | 30 min |
| R10 | P2 | Ancho máximo de formulario (720 px) en Settings, Alcalde e Institucional | `main.dart:346, 419, 501` | 30 min |
| R11 | P2 | Corregir el recorte de "Hours": `maxLines: 2` | `main.dart:352-359` | 10 min |
| R12 | P2 | Badge de estado reutilizable en Valores, Usuarios y Roles (texto con fondo y borde) | `main.dart:576, 995, 1049` | 40 min |
| R13 | P2 | `EmptyState` con icono y CTA en las 4 listas | `main.dart:666` + listados | 40 min |
| R14 | P2 | Añadir explanation cuando "Nuevo documento" está deshabilitado por falta de categorías | `main.dart:657` | 20 min |
| R15 | P2 | Añadir explanatory text cuando "Guardar" está deshabilitado por falta de PDF | `main.dart:889-891` | 15 min |
| R16 | P2 | Quitar el botón "Guardar alcalde" a ancho completo | `main.dart:450-451` | 10 min |
| R17 | P3 | Mostrar el rol junto al usuario en el header | `main.dart:178-180` | 15 min |
| R18 | P3 | Unificar terminología: "Rol y permisos" / "Roles y permisos" | `main.dart:88, 1033` | 5 min |

---

# 15. Mejoras de nivel medio

> Requieren trabajo estructural, pero no cambian backend ni API.

| # | Prio | Mejora | Alcance |
|---|---|---|---|
| M1 | **P0** | **CRUD completo de Usuarios**: `AppDataGrid` con columnas (usuario, email, roles, estado), alta, edición, activar/desactivar, reset de contraseña, selector de roles, buscador | 1-2 días |
| M2 | **P0** | **CRUD completo de Roles**: listado + editor con selección de permisos agrupada por recurso + activar/desactivar | 1-2 días |
| M3 | **P0** | **CRUD completo de Valores**: edición, activar/desactivar, reordenar | 0.5-1 día |
| M4 | **P1** | **Extraer `core/theme/`**: `ui_colors.dart`, `app_decorations.dart`, `app_theme.dart` copiados y adaptados de Correspondencia, con el verde `#08813A` institucional y los 6 literales actuales migrados | 0.5 día |
| M5 | **P1** | **Extraer `shared/widgets/`**: `AppDataGrid`, `AppFormDialog`, `AppTextField`, `AppDropdown`, `StatusBadge`, `EmptyState`, `SearchField`, `confirmAdminLogicalDelete`, `AppSurface`, `SectionHeader` | 1-2 días |
| M6 | **P1** | **Migrar Gaceta a `AppDataGrid`**: sort, paginación server-side, buscador, filtro por categoría, filtro por estado, acciones etiquetadas en `PopupMenuButton` | 1-2 días |
| M7 | **P1** | **Sidebar oscuro con secciones** (Página Web / Gaceta / Administración), logo oficial, ancho 240-280 px, y filtrado por permisos | 1 día |
| M8 | **P1** | **Estructura por features**: `lib/features/{site_settings,mayor,institutional,values,gaceta,categories,users,roles}/` con el patrón `list_*`/`upsert_*` | 1-2 días |
| M9 | **P2** | **Alcalde**: layout de dos columnas, preview de la foto actual y de la nueva, `Image.network` sobre `photo.url` | 0.5 día |
| M10 | **P2** | **Settings**: agrupar en 4 secciones con subtítulos, helper text, validación de URL/email | 0.5-1 día |
| M11 | **P2** | `PermissionGuard` y `core/auth/permissions.dart` con las constantes de los 17 códigos | 0.5 día |
| M12 | **P2** | Diálogo de Gaceta con `AppFormDialog`: header sticky, scroll, ancho adaptativo, interruptor "Publicado", selector de fecha | 0.5 día |
| M13 | **P2** | Estado sucio (cambios sin guardar) con confirmación al navegar | 0.5 día |
| M14 | **P3** | `fontFamily: 'Segoe UI'` para igualar la tipografía de Correspondencia | 10 min |
| M15 | **P3** | Breadcrumb o subtítulo de página en el header | 30 min |

---

# 16. Cambios NO recomendados

| # | No hacer | Motivo |
|---|---|---|
| N1 | **Dashboard con KPIs o gráficas** | El brief lo prohíbe explícitamente. La pantalla actual de "Sitio" ya cumple su función |
| N2 | **Modo oscuro** | Añade una dimensión completa de mantenimiento sin necesidad operativa |
| N3 | **Animaciones o transiciones** | El brief las prohíbe. El feedback por snackbar es suficiente |
| N4 | **Gradientes, sombras pesadas, glassmorphism** | Contradice el principio "administrativo, serio, institucional" |
| N5 | **Cards grandes con métricas** | Sin datos que justifiquen; Correspondencia ya tiene su propio dashboard |
| N6 | **Iconografía propia / set de iconos ilustrativo** | `Material Icons` es coherente con Correspondencia |
| N7 | **Cambiar la paleta institucional** | `#08813A` es el verde oficial documentado; Gestión debe **adoptarlo**, no inventar otro |
| N8 | **Rediseñar el backend, los repositorios o los contratos API** | La API funciona y es correcta; la auditoría es de UI |
| N9 | **Reescribir el sistema de permisos** | La lógica de `hasPermission` + validación en backend ya es la correcta |
| N10 | **Migrar a Riverpod, Provider o MobX** | Correspondencia usa Cubit/BLoC; la coherencia lo exige |
| N11 | **Sustituir `NavigationRail` por algo peor** | Un rail no es el problema; el problema es que no agrupa y no filtra permisos |
| N12 | **Hacer la tabla de Gaceta más "bonita" sin adding función** | Ya cumple; lo que falta son filtros y semántica de acciones |
| N13 | **Icono de escudo dibujado a mano en Flutter** | El PNG oficial ya existe en Correspondencia `assets/branding/`; reutilizarlo |
| N14 | **Añadir un `dashboard` al menú** | Duplicaría Correspondencia y aportaría poco |

---

# 17. Propuesta visual final

## Principios

1. **Institucional, no decorativo.** Verde oficial `#08813A` sobre superficies blancas y `#F8FAFC`. Tipografía Segoe UI. Radios 10-16 px. Sin sombras pesadas.
2. **Sidebar oscuro de 260 px a la izquierda**, fijo en desktop (≥1024 px), colapsable a drawer en tablet/móvil. Logo oficial + "Sipe Sipe Gestión" arriba. Secciones rotuladas en versalita:
   ```
   PÁGINA WEB
     Configuración del sitio
     Alcalde
     Información institucional
     Valores institucionales
   GACETA
     Documentos
     Categorías
   ADMINISTRACIÓN
     Usuarios
     Roles y permisos
   ```
   Solo se muestran las entradas cuyo permiso el usuario tiene.
3. **Header de 64 px**, no 76, con: título de página a la izquierda, y a la derecha un chip con el rol + avatar con iniciales + menú de sesión. Sin borde inferior si la superficie ya está delimitada.
4. **Una sola tabla**: `AppDataGrid` con encabezado en `UiColors.background`, texto 12 px `letterSpacing 0.6`, separadores `UiColors.borderLight`, filas de 48 px, zebra sutil opcional.
5. **Acciones etiquetadas**: hasta 2 iconos inline (Editar, PDF) y el resto en un `PopupMenuButton` con texto ("Publicar", "Despublicar", "Eliminar"). Eliminar siempre en rojo.
6. **Formularios**: ancho máximo 720 px, `AppTextField` con etiquetas flotantes, helper text, agrupados en secciones con subtítulo. Botón primario abajo a la izquierda, con snackbar de éxito.
7. **Estados con un lenguaje único**: `StatusBadge` semántico (Borrador gris, Publicado verde, Inactivo gris, Activo verde), `EmptyState` con icono y CTA, `CircularProgressIndicator` dentro de un contenedor con mensaje ("Cargando documentos de Gaceta…").
8. **Responsive real**: `AppDataGrid` ya resuelve desktop/móvil. En móvil, el rail se convierte en `Drawer` con botón de menú en el header; los diálogos usan `maxWidth` y `maxHeight` con scroll.

## Cómo se vería la pantalla de Gaceta

```
┌──────────────────────────────────────────────────────────────────────────┐
│ Sipe Sipe Gestión │                                                      │
│                  │  Gaceta municipal                        [ADMIN] [AD] ⏻ │
│  PÁGINA WEB      │  ┌──────────────────────────────────────────────────┐ │
│   Configuración  │  │ [🔍 Buscar…]  [Categoría ▾] [Estado ▾]  [+ Nuevo]│ │
│   Alcalde        │  ├──────────────────────────────────────────────────┤ │
│   Institucional  │  │ Número / título      Categoría  Fecha  Estado   ⋮  │ │
│   Valores       │  │──────────────────────────────────────────────────│ │
│  GACETA          │  │ N° 012/2026          Ordenanzas 2026-02-10 (●) ✎ ⋮│ │
│   Documentos     │  │ Ordenanza de presup…                                    │ │
│   Categorías     │  │ N° 011/2026          Reglament. 2026-01-28 (●) ✎ ⋮ │ │
│  ADMINISTRACIÓN │  └──────────────────────────────────────────────────┘ │
│   Usuarios       │        Mostrando 3 de 3            ‹ 1  2  3 ›         │
│   Roles          │                                                      │
└──────────────────────────────────────────────────────────────────────────┘
```

## Cómo se vería el flujo de una acción

```
Row del documento → clic en ⋮ → menú con texto:
   ┌──────────────────┐
   │ ✎ Editar         │
   │ ⬆ Publicar       │
   │ 📄 Abrir PDF     │
   │ ─────────────────│
   │ 🗑 Eliminar      │  ← rojo, separado por divisor
   └──────────────────┘
→ Fila se actualiza en el sitio (sin recarga)
→ Snackbar: "Documento publicado."
```

---

# 18. Plan de implementación

Orden pensado para **no romper la funcionalidad validada** en ningún momento. Cada fase es independiente y verificable con `flutter analyze` + `flutter test` + `flutter build web` + recorrido manual de la pantalla tocada.

## Fase 0 — Baseline y protección (0.5 día)

- Registrar capturas del estado actual de las 10 pantallas (las de `e2e/shots/` de esta auditoría sirven de referencia).
- Verificar que `flutter analyze`, `flutter test` y `flutter build web` pasan antes de tocar nada.
- Confirmar que el flujo E2E de Gaceta sigue verde (script de validación existente).

**Salida:** baseline documentado. Criterio de salida: build verde.

## Fase 1 — Quick wins de Gaceta y Settings (1 día)

Aplicar **R1, R4, R5, R6, R7, R8, R9, R11, R12, R14, R15, R18**:
- Fecha editable en el diálogo de documento.
- Encabezado responsive sincronizado con las filas.
- Etiquetas legibles en Settings.
- Feedback de éxito unificado.
- Filtrado del rail por permisos.
- Color de peligro en "Eliminar".
- Badge de estado reutilizable.
- Explicaciones de botones deshabilitados.
- Terminología unificada.

**Salida:** Gaceta y Settings usables de extremo a extremo por un EDITOR.
**Verificación:** recorrido manual de Gaceta con ADMIN y con EDITOR + `flutter analyze/test/build`.

## Fase 2 — Design system compartido (2-3 días)

- **M4**: crear `lib/core/theme/{ui_colors,app_decorations,app_theme}.dart` adaptando los de Correspondencia:
  - `UiColors.primary = #08813A` (verde oficial).
  - Migrar los 6 literales actuales a tokens.
  - `AppTheme` con `textTheme`, `inputDecorationTheme`, `cardTheme`, `dialogTheme`, `chipTheme`, `dataTableTheme`, `buttonTheme`s.
- **M5**: copiar `shared/widgets/` de Correspondencia y adaptar los imports:
  - `AppDataGrid` + columnas + acciones + paginación.
  - `AppFormDialog`.
  - `AppTextField`, `AppDropdown`, `AppSearchableDropdown`, `AppTextPassword`.
  - `StatusBadge`, `EmptyState`, `SearchField`, `DataPanel`.
  - `confirmAdminLogicalDelete`.
  - `AppSurface`, `SectionHeader`, `PageContainer`.
- **M11**: `lib/core/auth/permissions.dart` con las constantes de los 17 códigos + `PermissionGuard`.

**Salida:** tokens y widgets disponibles; la UI actual compila sin cambios visuales mayores (el verde cambia de `#087443` a `#08813A`).
**Verificación:** `flutter analyze/test/build` + comparación visual de las 10 pantallas.

## Fase 3 — Migración de listados a DataGrid (2-3 días)

En este orden (de menor a mayor riesgo):
1. **Valores** (M3) → `AppDataGrid` + CRUD completo con el patrón `list_*`/`upsert_*`.
2. **Categorías** (R3) → nueva pantalla `gaceta/categories` con `AppDataGrid` + CRUD.
3. **Usuarios** (M1) → `AppDataGrid` + CRUD completo + roles + reset de contraseña.
4. **Roles** (M2) → `AppDataGrid` + editor de permisos agrupados.
5. **Gaceta** (M6) → `AppDataGrid` con sort, paginación server-side, buscador, filtros y acciones etiquetadas.

**Salida:** ningún listado es una lista de `ListTile`; todas las pantallas de administración tienen CRUD completo.
**Verificación:** tests de widget para los CRUD nuevos + recorrido manual + E2E de Gaceta.

## Fase 4 — Shell y navegación (1-2 días)

- **M7**: sidebar oscuro con secciones, logo oficial, ancho 260 px, `Drawer` en móvil, filtrado por permisos.
- Header de 64 px con rol, avatar y menú de sesión.
- Breadcrumb o subtítulo de página.

**Salida:** navegación agrupada y coherente con la identidad institucional.
**Verificación:** recorrido de los 2 roles (ADMIN, EDITOR) en 4 viewports.

## Fase 5 — Formularios (1-2 días)

- **M10**: Settings agrupado en secciones, helper text, validación.
- **M9**: Alcalde con layout de dos columnas y preview de foto.
- **M12**: diálogo de Gaceta con `AppFormDialog`, interruptor "Publicado", selector de fecha.
- **M13**: estado sucio.

**Salida:** todos los formularios con ancho máximo, agrupación y validación.
**Verificación:** recorrido de guardado en cada formulario.

## Fase 6 — Reestructuración por features (1-2 días)

- **M8**: mover el código a `lib/features/<módulo>/{list_*,upsert_*,cubit,views,helpers,widgets}` y `lib/core/`, `lib/shared/`, `lib/injection/`.
- Sin cambios de comportamiento: es un movimiento de archivos.

**Salida:** el panel queda preparado para crecer hacia los módulos futuros (funcionarios, asistencia, RRHH).
**Verificación:** `flutter analyze/test/build` idénticos + import paths revisados.

## Fase 7 — Pulido (0.5-1 día)

- R14-R18 pendientes, M13-M15 pendientes, N-items aplicables.
- `OfficialLogo` en login y sidebar.
- Revisión de contraste de los badges.

**Salida:** panel cerrado y listo para QA municipal.

---

## Resumen de prioridad

| Tramo | Ítems | Esfuerzo |
|---|---|---|
| P0 — bloqueantes | CRUD de Usuarios/Roles/Valores/Categorías, fecha de Gaceta | 4-6 días |
| P1 — importantes | Design system, DataGrid, shell, responsive, feedback, permisos, etiquetas | 5-7 días |
| P2 — relevantes | Formularios, badges, empty states, búsqueda, contador, filtros | 3-4 días |
| P3 — polish | Iconografía oficial, tipografía, terminología, rol en header | 1 día |

**Total estimado: 13-18 días de trabajo efectivo** para dejar el panel coherente con Correspondencia, funcional en todos los módulos de la V1 y con responsive real. La V1 actual **no se rompe** en ninguna fase: cada fase es aditiva o un reemplazo de presentation con paridad funcional verificada.

---

## Anexo — Evidencia fotográfica

| Archivo | Contenido |
|---|---|
| `e2e/shots/01-login-desktop.png` | Login en 1440×900 |
| `e2e/shots/01-login-mobile.png` | Login en 420×820 |
| `e2e/shots/02-shell-sitio.png` | Configuración del sitio (etiquetas camelCase, recorte de "Hours") |
| `e2e/shots/03-alcalde.png` | Alcalde (inputs a 1290 px, botón a ancho completo) |
| `e2e/shots/04-institucional.png` | Institucional (campos de 155 px para 2 líneas) |
| `e2e/shots/05-valores.png` | Valores (sin acciones, estado como texto plano) |
| `e2e/shots/06-gaceta.png` | Gaceta en desktop (tabla manual con acciones por fila) |
| `e2e/shots/09-gaceta-nuevo-doc.png` | Diálogo de nuevo documento (sin campo fecha, Guardar deshabilitado sin explicación) |
| `e2e/shots/10-gaceta-categorias.png` | Diálogo de alta de categoría (no hay pantalla de listado) |
| `e2e/shots/11-gaceta-editar.png` | Diálogo de edición (precarga correcta, PDF actual visible) |
| `e2e/shots/12-gaceta-confirmar-baja.png` | Confirmación de baja (botón verde idéntico a "Guardar") |
| `e2e/shots/13-valores-nuevo.png` | Diálogo de valor (AlertDialog crudo, un campo) |
| `e2e/shots/07-usuarios.png` | Usuarios (sin alta, sin acciones, sin buscador) |
| `e2e/shots/08-roles.png` | Roles (solo contador de permisos) |
| `e2e/shots/22-tablet-shell.png` | Shell en 900×700 |
| `e2e/shots/23-tablet-gaceta.png` | Gaceta en 900×700 (**encabezado y filas desalineados**) |
| `e2e/shots/23-mobile-gaceta.png` | Gaceta en 420×820 (**encabezado colapsado, texto vertical**) |

> Las capturas y los datos de auditoría se eliminaron al finalizar. No forman parte del repositorio (`e2e/` está en `.gitignore`).

---

**Fin de la auditoría.** No se modificó ningún archivo de Flutter, backend, Astro ni Correspondencia. No se realizaron commits.
