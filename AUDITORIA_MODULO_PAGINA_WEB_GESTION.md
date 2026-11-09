# AUDITORÍA DEL MÓDULO "ADMINISTRACIÓN DE LA PÁGINA WEB"
## Sipe Sipe Gestión

**Fecha:** 19/10/2026
**Alcance:** auditoría de solo lectura. No se modificó código, backend, Flutter, Astro ni base de datos. No se hicieron commits.
**Proyectos auditados:** `C:\dev\sipe_sipe_gestion`, `C:\dev\website_sipe_sipe`
**Referencia:** `C:\dev\correspondencia_sipe_sipe` (solo lectura)

---

# 1. Resumen ejecutivo

## Veredicto

**El módulo "Página Web" está en ~15 % de completitud funcional, aunque lo implementado es sólido.**

De los **10 bloques de contenido público** que el sitio muestra, Gestión administra hoy **2 completos** (Configuración general, Institucional/Valores), **1 a medias** (Alcalde) y **1 completo a nivel de CRUD** (Gaceta). Los **6 restantes** (Noticias, Eventos, Trámites, Turismo, Avisos, Galería) **no existen** ni en backend ni en Flutter: siguen siendo arrays literales en `src/data/*.ts` de Astro.

La arquitectura base sí está bien encaminada:

- Entidades correctas y bien separadas para lo que existe.
- RBAC operativo con 13 permisos usados por endpoints.
- Storage persistente con validación de MIME, SHA-256, límites de tamaño y protección contra path traversal.
- Gaceta es un CRUD completo real (crear, editar, publicar, despublicar, reemplazar PDF, baja lógica, descarga pública) **y ya funciona de extremo a extremo**.

## Cifras medidas

| Métrica | Valor |
|---|---|
| Endpoints totales del backend | 39 |
| Endpoints públicos | 7 |
| Endpoints de administración | 28 |
| Endpoints de health | 2 |
| Endpoints de auth | 2 (`login`, `refresh`, `logout`, `me` = 4 con `me`) |
| Entidades SQLAlchemy | 13 |
| Permisos declarados | 17 |
| Permisos **usados por algún endpoint** | 13 |
| Permisos **muertos** | **4** (`gestion.media.read`, `gestion.media.upload`, `gestion.media.manage`, `gestion.roles.assign`) |
| Entidades de contenido público | 4 (`SiteSetting`, `InstitutionalContent`, `InstitutionalValue`, `Mayor`) + 2 de Gaceta |
| Pantallas Flutter del panel | 7 |
| Pantallas Flutter del módulo Página Web | 5 (`Settings`, `Alcalde`, `Institucional`, `Valores`, `Gaceta`) |
| Rutas públicas de Astro | 10 |
| Contenido público que se actualiza **sin rebuild** | **1** (Gaceta) |
| Contenido público que requiere rebuild | 4 bloques (settings, alcalde, institucional, contacto) |
| Contenido público **100 % estático** | ~60 % del sitio |
| Imágenes en `public/images/` | 15 (3 huérfanas) |
| PDFs en el repositorio | **0** |
| Archivos en el storage persistente | 0 (volumen limpio tras auditoría) |

## Los cinco hallazgos P0

1. **P0 — El workflow de GitHub Pages no define `PUBLIC_GESTION_API_URL`.**
   `.github/workflows/deploy-pages.yml:30-34` solo exporta `GITHUB_ACTIONS: true`. Como `src/lib/gestionPublic.ts:1` lee `import.meta.env.PUBLIC_GESTION_API_URL` y devuelve `null` si falta, **en producción el build nunca consulta la API**: todo el sitio renderiza el fallback estático. La integración Astro funciona en local pero **está inactiva en el deploy real**.

2. **P0 — No existe entidad, endpoint ni UI para 6 de los 10 bloques de contenido público.** Noticias, Eventos, Trámites, Turismo, Avisos/Comunicados y Galería son `NO IMPLEMENTADO` en backend y en Flutter. Solo existen como literales en `src/data/news.ts`, `events.ts`, `tramites.ts`, `tourism.ts`, `notices.ts` y `media.ts`.

3. **P0 — `Media` es una entidad sin gestión.** No existe `/api/admin/media` (ni listado, ni borrado, ni baja). `Media.is_active` solo se *lee* (`main.py:360`), nunca se pone en `False`. No hay `delete(Media)` en el código. Consecuencia: cada reemplazo de PDF o de foto del alcalde **crea una fila `Media` y un archivo huérfanos**.

4. **P0 — 4 de los 17 permisos no los valida ningún endpoint.** `gestion.media.read`, `gestion.media.upload`, `gestion.media.manage` y `gestion.roles.assign` aparecen en `seed.py:8-9` y en la tabla `permissions`, pero **no aparecen en ninguna llamada a `require_permission`**. Un EDITOR con `gestion.media.manage` no puede hacer nada con él; y `gestion.media.upload` no es lo que autoriza subir un PDF (eso lo hace `gestion.gaceta.manage`).

5. **P0 — La Gaceta del sitio público tiene dos fuentes de verdad simultáneas.** `src/pages/gaceta/index.astro` usa `LiveGaceta` (runtime, API), pero `src/components/NoticesBoard.astro:6,57` sigue importando `gacetaEntries` de `src/data/gaceta.ts` (build-time, 3 entradas fixture). El bloque lateral del inicio muestra **documentos que ya no existen en la BD** y que la página `/gaceta/` no lista.

---

# 2. Arquitectura actual

```
┌────────────────────────────────────────────────────────────────────┐
│  Sipe Sipe Gestión (C:\dev\sipe_sipe_gestion)                       │
│                                                                    │
│  Flutter Web ──► GestionApi (Dio) ──► FastAPI ──► PostgreSQL      │
│  (7 pantallas)      gestion_repository        (39 endpoints)  13 │
│                      Result<T>/Failure                          tablas│
│                          │                                         │
│                          ▼                                         │
│                    StorageService (Protocol)                       │
│                    └─ LocalFilesystemStorage                      │
│                       /app/storage  (volumen Docker)              │
│                                                                    │
│  Docker: sipe_gestion_db (5433) + sipe_gestion_backend (8001)      │
│  Volúmenes: gestion_postgres_data + gestion_storage                │
└────────────────────────────────────────────────────────────────────┘
                            │
                            │  /api/public/*  (sin auth)
                            ▼
┌────────────────────────────────────────────────────────────────────┐
│  Website Astro (C:\dev\website_sipe_sipe)                          │
│  10 rutas · src/data/*.ts (12 archivos, contenido fixture)        │
│  Build estático → GitHub Pages                                    │
│  src/lib/gestionPublic.ts → fetchGestion() (build-time)           │
│  src/components/LiveGaceta.astro → fetch() (runtime, en navegador) │
└────────────────────────────────────────────────────────────────────┘
```

## Flujo de datos actual

| Momento | Mecanismo | Contenido afectado |
|---|---|---|
| Build de Astro | `await fetchGestion()` en el frontmatter | settings, alcalde, institucional, contacto |
| Build de Astro | Imports estáticos de `src/data/*.ts` | noticias, eventos, trámites, turismo, avisos, galería, transparencia, navegación, estadísticas, autoridades, concejo |
| Navegación del usuario | `fetch()` dentro de `<script>` | únicamente Gaceta |
| Runtime del backend | PostgreSQL + filesystem | todo lo que esté conectado |

## Entidades actuales (`backend/app/models.py`)

| Entidad | Tabla | Contenido público | Tiene CRUD admin | Tiene UI Flutter |
|---|---|---|---|---|
| `SiteSetting` | `site_settings` | General | Sí (14 claves) | Sí |
| `Mayor` | `mayors` | Alcalde | Sí | Sí |
| `InstitutionalContent` | `institutional_content` | Misión/Visión | Sí | Sí |
| `InstitutionalValue` | `institutional_values` | Valores | Sí (falta reactivar) | Parcial |
| `GacetaCategory` | `gaceta_categories` | Gaceta | Sí | Parcial |
| `GacetaDocument` | `gaceta_documents` | Gaceta | Sí | Sí |
| `Media` | `media` | Fotos/PDFs | **No** | No |
| `User` / `Role` / `Permission` / `UserRole` / `RolePermission` / `AuthSession` | varias | — | Sí | Parcial |

---

# 3. Mapa completo del contenido público

| Contenido | Astro | Backend | Flutter | Estado |
|---|---|---|---|---|
| Nombre oficial / corto / lema | `site.ts` + `BaseLayout` | `site_settings` | `SettingsPage` | **Implementado** (build-time) |
| Dirección / teléfono / correos / horario | `site.ts` + `Footer`, `TopBar`, `CitizenBand`, `contacto` | `site_settings` | `SettingsPage` | **Implementado** (build-time) |
| Ubicación / `locationLine` | `site.ts` + `Footer` | `site_settings` | `SettingsPage` | Implementado |
| Redes sociales (FB/IG/YT) | `site.ts` | `site_settings` (3 claves) | `SettingsPage` | **Implementado** pero **no renderizadas** en Astro |
| Copyright / edición | `site.ts` + `Footer` | `site_settings` | `SettingsPage` | Implementado |
| Estadísticas del municipio (4) | `site.ts.stats` + `HeroEditorial` | — | — | **NO IMPLEMENTADO** |
| `topLinks` (Intranet, correo) | `site.ts.topLinks` + `TopBar` | — | — | **NO IMPLEMENTADO** |
| Alcalde: nombre/cargo/mensaje/bienvenida | `site.ts.mayor` + `WelcomeMayor` + `institucional` | `mayors` | `MayorPage` | **Implementado** (build-time) |
| Alcalde: fotografía | `site.ts.mayor.photo` (`/images/alcaldeblanco.png`) | `media.photo_media_id` | `MayorPage` (upload) | **Implementado** |
| Alcalde: nota de foto | `site.ts.mayor.photoNote` | `mayors.photo_note` | `MayorPage` | Implementado |
| Misión / Visión | `institucional.ts` | `institutional_content` | `InstitutionalPage` | **Implementado** (build-time) |
| Valores institucionales | `institucional.ts.values` | `institutional_values` | `ValuesPage` | **Implementado** (sin editar/desactivar) |
| Autoridades (gabinete, 4) | `institucional.ts.executiveAuthorities` | — | — | **NO IMPLEMENTADO** |
| Unidades organizacionales (9) | `institucional.ts.organizationalUnits` | — | — | **NO IMPLEMENTADO** |
| Notícias (4) | `news.ts` + `index.astro` + `[slug].astro` | — | — | **NO IMPLEMENTADO** |
| Categorías de noticias | (implícitas en `article.category`) | — | — | **NO IMPLEMENTADO** |
| Eventos (4) | `events.ts` + `eventos/index.astro` | — | — | **NO IMPLEMENTADO** |
| Trámites (4) | `tramites.ts` + `tramites/index.astro` | — | — | **NO IMPLEMENTADO** |
| Turismo (4) | `tourism.ts` + `turismo/index.astro` | — | — | **NO IMPLEMENTADO** |
| Gaceta: documentos | `gaceta/index.astro` (runtime) + `notices.ts` (build) | `gaceta_documents` | `GacetaPage` | **Implementado** (doble fuente) |
| Gaceta: categorías | implícitas | `gaceta_categories` | diálogo de alta | **Implementado** (sin pantalla) |
| Gaceta: PDF | `pdfUrl: '#'` (fixture) | `media.storage_path` | upload | **Implementado** |
| Avisos / comunicados (4) | `notices.ts` + `NoticesBoard` + `HeroEditorial` | — | — | **NO IMPLEMENTADO** |
| `heroShortcuts` (6) | `notices.ts` + `HeroEditorial` | — | — | **NO IMPLEMENTADO** |
| `transparencyLinks` (4) | `notices.ts` + `TransparencyStrip` | — | — | **NO IMPLEMENTADO** |
| Galería de inicio (4) | `media.ts.homeGallery` + `PhotoGallery` | — | — | **NO IMPLEMENTADO** |
| Créditos fotográficos | `media.ts.photoCredits` + `Footer` | — | — | **NO IMPLEMENTADO** |
| Menú principal (9) | `navigation.ts.mainNav` + `Header` + `Footer` | — | — | **NO IMPLEMENTADO** |
| `homeQuickLinks` (6) | `navigation.ts` (nunca importado) | — | — | **NO IMPLEMENTADO** |
| `heroSlides` (3) | `heroes.ts` (nunca importado) | — | — | **NO IMPLEMENTADO** |
| Catálogo de Concejo | `concejo.ts` + `concejo/index.astro` | — | — | **NO IMPLEMENTADO** |
| Hero editorial (imágenes, textos fijos) | `HeroEditorial.astro` | — | — | **NO IMPLEMENTADO** |

**Balance:** 8 filas implementadas, 4 implementadas parcialmente, 22 no implementadas.

---

# 4. Configuración general

## Backend

- Modelo `SettingValues` (`main.py:34-49`): 14 campos, `model_config = ConfigDict(extra='forbid')` → **allowlist estricta**. Claves arbitrarias enviadas por Flutter son rechazadas con 422.
- Persistencia: tabla `site_settings` (key/value) con `updated_by_user_id` y `updated_at`.
- Endpoints: `GET /api/public/site-settings` (158), `GET /api/admin/site-settings` (162, `gestion.settings.read`), `PUT /api/admin/site-settings` (166, `gestion.settings.manage`).
- `PUT` escribe **las 14 claves siempre**, creando filas vacías si no existen.

## Flutter

- `SettingsPage` (`main.dart:297-376`).
- `keys` (305-320) = las mismas 14 claves. `_label()` (373-375) solo humaniza `shortName`.
- Sin agrupamiento, sin helper text, sin validación, ancho fijo 360 px.
- **Sin feedback de éxito** (usa `run()`, que solo captura errores).

## Astro

- `BaseLayout.astro:16-17` → `fetchGestion('/api/public/site-settings')` en build; si devuelve `null` usa `site.ts`.
- `contacto/index.astro:7-11` → solo 4 campos con fallback (`address`, `phone`, `supportEmail`, `hours`).
- **`Footer.astro:30-37`, `TopBar.astro:9`, `CitizenBand.astro:7-10`, `HeroEditorial.astro:45,95` siguen usando `site.ts` directamente, sin consultar la API.** Aunque el backend tenga el valor correcto, el footer, la barra superior y la franja de atención citrate mostrarán el valor fixture.

## Cobertura real

| Clave | Backend | Flutter | Astro (API) | Astro (fixture) |
|---|---|---|---|---|
| name / shortName / motto | Sí | Sí | `BaseLayout` (título) | `Footer`, `TopBar`, `HeroEditorial` |
| address / phone / supportEmail / hours | Sí | Sí | `contacto` | `Footer`, `TopBar`, `CitizenBand`, `HeroEditorial` |
| locationLine | Sí | Sí | **No** | `Footer` |
| email | Sí | Sí | **No** | `CitizenBand` |
| copyright / edition | Sí | Sí | **No** | `Footer` |
| facebook / instagram / youtube | Sí | Sí | **No** | **No se renderizan** |

## Hallazgos

- **P1** — 7 de las 14 claves administrables **no se renderizan en ninguna parte** de Astro (locationLine, email, copyright, edition, facebook, instagram, youtube). Editarlas en el panel no produce ningún efecto visible.
- **P1** — `Footer`, `TopBar`, `CitizenBand` y `HeroEditorial` no consultan la API → los datos de contacto del sitio son fixtures aunque el panel los edite.
- **P1** — `site.stats` (4 métricas del municipio) y `site.topLinks` (Intranet) **no tienen contraparte en el backend**: no se pueden administrar.
- **P2** — El logo del sitio (favicon, `favicon.svg`, `favicon.ico`) no es administrable.
- **P2** — La meta description por página (`BaseLayout.astro:14-18`) es un string fijo; solo hay un override por página.

---

# 5. Alcalde

## Backend

- Entidad `Mayor` (`models.py`): `id, name, title, welcome_title, message, photo_media_id FK→media, photo_note, is_active, created_at, updated_at`.
- **Invariante de "un solo alcalde activo"**: `POST` (195) y `PUT` (210) desactivan todos los demás con `db.query(Mayor).update({Mayor.is_active: False})`.
- Endpoints: `GET /api/public/mayor` (182) devuelve el activo más reciente; `GET /api/admin/mayor` (186, `gestion.mayor.read`); `POST` (190, `gestion.mayor.manage`); `PUT /{mayor_id}` (201, `gestion.mayor.manage`).
- La foto es `multipart` opcional: `photo: UploadFile | None = File(default=None)` → si no se envía, se conserva la anterior.

## Flutter

- `MayorPage` (`main.dart:378-471`).
- Carga (`398-414`): si `repository.mayor()` devuelve `null` (no hay alcalde), deja los campos vacíos. **No hay estado "no hay alcalde configurado"** visible.
- Guardado (`453-470`): `saveMayor(id: mayorId, ...)`. Si `mayorId` es `null` → `POST` (crea); si no → `PUT` (actualiza). Correcto.
- Foto: `FilePicker` con `FileType.image, withData: true` (441-442). **No hay preview** de la foto actual ni de la nueva.
- Feedback: snackbar "Alcalde guardado" / error (463-469). Correcto.

## Astro

- `WelcomeMayor.astro:4-23` → `fetchGestion('/api/public/mayor')` en build, con fallback a `site.mayor`.
- `institucional/index.astro:23-31` → segunda llamada a `/api/public/mayor`, con fallback.
- **La foto se resuelve por `photo.url`** (que el backend construye con `PUBLIC_BASE_URL`, `main.py:91-92`) o por `gestionMediaUrl(id)` (`src/lib/gestionPublic.ts:14-16`) → `https://<PUBLIC_GESTION_API_URL>/api/public/media/{id}`.

## Hallazgos

- **P1** — El `welcome_title` y el `message` se administran en Flutter pero **la web pública nunca los lee de la API para `welcome_title`**: `WelcomeMayor.astro:26` sí lo usa (viene del objeto `managedMayor`), correcto. Verificado.
- **P1** — La web pública **sí** muestra el mensaje del alcalde (`WelcomeMayor.astro:28`). Correcto.
- **P2** — Sin preview de foto en Flutter ni en la web.
- **P2** — El backend expone `Mayor.is_active` pero **no hay endpoint para desactivar un alcalde**. El único camino es crear otro (que desactiva el anterior). No hay historial consultable: `GET /api/admin/mayor` devuelve solo el más reciente.
- **P3** — `photo_note` es texto libre sin formato definido; la web lo muestra tal cual (`WelcomeMayor.astro:30`).

---

# 6. Institucional

## Backend

- `InstitutionalContent`: tabla singleton con `mission`, `vision`. `GET /api/public/institutional` (215-219) devuelve también los `InstitutionalValue` activos ordenados por `sort_order, created_at`.
- Endpoints admin: `GET` (221, `gestion.institutional.read`), `PUT` (225, `gestion.institutional.manage`), valores `GET` (235, `gestion.institutional.read`), `POST` (240, `.manage`), `PUT /{id}` (246, `.manage`), `POST /{id}/deactivate` (253, `.manage`).

## Flutter

- `InstitutionalPage` (`main.dart:473-527`): misión y visión con `minLines: 5`.
- `ValuesPage` (`main.dart:529-607`): lista de valores con `ListTile`. Solo tiene "Nuevo valor" (561-565). El diálogo (581-605) solo crea.
- **Falta en Flutter:** editar valor, activar/reactivar valor, cambiar `sort_order`, desactivar.
- **Falta en backend:** `POST /api/admin/institutional/values/{id}/activate` (solo existe `deactivate`).

## Astro

- `institucional/index.astro:15-21` → `fetchGestion('/api/public/institutional')` con fallback a `institucional.ts`.
- Usa `mission`, `vision` y `values` (línea 21: `managedInstitutional?.values?.map(item => item.value) ?? values`).

## Hallazgos

- **P0** — Las **autoridades** (`institucional.ts.executiveAuthorities`, 4 secretarios con foto/bio) y las **unidades organizacionales** (`institucional.ts.organizationalUnits`, 9) se muestran en `/institucional/` pero **no tienen entidad, endpoint ni UI**. `NO IMPLEMENTADO`.
- **P1** — El backend no tiene `activate` para valores: un valor desactivado **no se puede reactivar** ni desde Flutter ni desde la API. `REQUIERE CONFIRMACIÓN` de si debe existir.
- **P1** — `sort_order` solo se asigna al crear (`items.length`, `main.dart:597`). No hay forma de reordenar valores desde la UI.
- **P2** — La web pública `/institucional/` no muestra el bloque "Gabinete" desde la API porque no existe.

---

# 7. Noticias

**Estado: `NO IMPLEMENTADO`** en backend y Flutter.

## Estado actual en Astro

| Elemento | Ubicación |
|---|---|
| Datos | `src/data/news.ts` — 4 artículos fixture |
| Tipo | `src/types/content.ts:17-28` (`NewsArticle`) |
| Consumidores | `pages/index.astro:13` (`getLatestNews(4)`), `pages/noticias/index.astro:5`, `pages/noticias/[slug].astro:3` |
| Componentes | `NewsCard.astro`, `NewsFeatured.astro` |

## Campos definidos pero sin destino

El tipo `NewsArticle` ya define: `slug`, `title`, `excerpt`, `body`, `category`, `publishedAt`, `author`, `coverGradient`, `coverImage`, `coverAlt`. El `body` se separa en párrafos con `\n\n` (`[slug].astro:40`) → el formateo ya está resuelto en el consumidor.

## Con qué habría que construirlo

- Entidad `CmsNews` + `CmsNewsCategory` (la `category` es hoy un string libre: "Salud", "Obras", "Educación", "Economía").
- Endpoints `/api/admin/news` (listado paginado con `q`, `category`, `is_published`), CRUD, `publish`/`unpublish`.
- `GET /api/public/news` y `GET /api/public/news/{slug}`.
- `[slug].astro` con `getStaticPaths()` async (ya es `getStaticPaths`; hoy lee del array local).
- Permisos: `gestion.news.read`, `gestion.news.manage`, `gestion.news.publish`.
- Pantalla Flutter con CRUD.

## Hallazgos

- **P0** — `NewsArticle.coverGradient` está en el tipo pero **no se renderiza en ningún componente** (verificado: `CoverArt.astro` es huérfano). El campo es muerto.
- **P0** — No existe `NewsCategory` como entidad. La `category` actual es un string; si se quiere administrar categorías hay que crearla.
- **P1** — `[slug].astro` genera las rutas en build. Con noticias dinámicas, `/noticias/{slug}/` **requeriría rebuild** o pasar a SSR. Es la misma decisión de arquitectura que la Gaceta pero con coste mayor (una página por noticia).
- **P1** — `coverImage` apunta hoy a `/images/*.jpg` (ruta de `public/`). Con Media el path pasaría a ser una URL de API → **las noticias.admin requerirían que la imagen viva en la BD**, o un doble mecanismo.
- **P3** — `author` es string libre ("Unidad de Comunicación", "Obras Públicas").

---

# 8. Eventos

**Estado: `NO IMPLEMENTADO`** en backend y Flutter.

## Estado actual en Astro

| Elemento | Ubicación |
|---|---|
| Datos | `src/data/events.ts` — 4 eventos fixture |
| Tipo | `src/types/content.ts:30-38` (`MunicipalEvent`: `id, title, description, location, startsAt, endsAt?, image`) |
| Consumidores | `pages/index.astro:14` (`getUpcomingEvents(4)`), `pages/eventos/index.astro:5` |
| Componente | `EventCard.astro` |

## Particularidades

- `startsAt` / `endsAt` son ISO datetime (`2026-04-02T15:00:00`) sin zona horaria.
- `getUpcomingEvents` (events.ts:41-45) ordena ascendente y corta, pero **no filtra por fecha futura**: el nombre dice "upcoming" y la implementación no lo cumple.

## Hallazgos

- **P0** — Sin entidad, endpoint ni UI.
- **P1** — `getUpcomingEvents` no filtra eventos pasados: el nombre de la función es engañoso y el comportamiento habría que decidirlo explícitamente al migrar.
- **P1** — `endsAt` es opcional en el tipo pero el `EventCard` (`EventCard.astro:25`) solo muestra `startsAt`. El campo "hora de cierre" no se muestra públicamente.
- **P1** — `image` apunta a `/images/*.jpg` → mismo problema que noticias: requeriría migrar a Media.
- **P2** — `id` es un string tipo `'evt-001'`; con BD pasaría a UUID.

---

# 9. Trámites

**Estado: `NO IMPLEMENTADO`** en backend y Flutter.

## Estado actual en Astro

| Elemento | Ubicación |
|---|---|
| Datos | `src/data/tramites.ts` — 4 trámites fixture |
| Tipo | `src/types/content.ts:49-56` (`Tramite`: `id, name, unit, durationDays, requirements[], costBs: number | null`) |
| Consumidor | `pages/tramites/index.astro:4` |

## Campos

- `unit`: unidad responsable (string: "Secretaría General", "Dirección de Asuntos Municipales", "Obras y Urbanismo", "Servicios Públicos").
- `requirements`: lista de strings.
- `costBs`: `number | null` → `null` se renderiza como "A consulta" (`tramites/index.astro:36`).

## Hallazgos

- **P0** — Sin entidad, endpoint ni UI.
- **P1** — `unit` es un string libre. Si se quiere administrar las unidades, debería referenciar `OrganizationalUnit` (que tampoco existe) o un catálogo propio.
- **P1** — **No hay ningún PDF descargable asociado a trámites** en el sitio actual. El brief menciona "documentos descargables si corresponden" → `NO IMPLEMENTADO` y sin referencia actual en Astro que lo justifique.
- **P2** — `requirements` como array de strings: en BD sería JSONB o tabla relacionada (Correspondencia no tiene equivalente; `REQUIERE CONFIRMACIÓN` de preferencia).

---

# 10. Turismo

**Estado: `NO IMPLEMENTADO`** en backend y Flutter.

## Estado actual en Astro

| Elemento | Ubicación |
|---|---|
| Datos | `src/data/tourism.ts` — 4 sitios fixture |
| Tipo | `src/types/content.ts:40-47` (`TourismSpot`: `id, name, summary, distanceKm, coverGradient, image`) |
| Consumidores | `pages/index.astro:15`, `pages/turismo/index.astro:5` |
| Componente | `TourismCard.astro` |

## Hallazgos

- **P0** — Sin entidad, endpoint ni UI.
- **P1** — No existe ruta de detalle por sitio (`/turismo/[id]/`): solo hay un listado de cards. El brief menciona "galería si aplica" → **no hay galería por sitio** en el sitio actual. `REQUIERE CONFIRMACIÓN` si el municipio quiere esa funcionalidad.
- **P1** — `coverGradient` está en el tipo pero no se usa (el card usa `image` + overlay). Campo muerto, igual que `NewsArticle.coverGradient`.
- **P2** — `distanceKm` se muestra como "X km del centro".

---

# 11. Gaceta

**Estado: `IMPLEMENTADO COMPLETO`** en backend y Flutter. Es el único módulo con CRUD real y verificado E2E.

## Backend

| Pieza | Detalle |
|---|---|
| `GacetaCategory` | `id, name (único), description, sort_order, is_active` |
| `GacetaDocument` | `id, category_id FK, number, title, description, published_at (date), pdf_media_id FK, is_published, created_by_user_id, created_at, updated_at, deleted_at` |
| Integridad | Índice único parcial `uq_gaceta_number_active` sobre `number` donde `deleted_at IS NULL` (`0001_initial.py`) |
| Índice | `ix_gaceta_published` sobre `(is_published, published_at DESC)` |
| Filtro público | `document_query(db, public=True)` → `deleted_at IS NULL AND is_published = True` (`main.py:290-295`) |
| Búsqueda | `q` busca por `title` o `number`, `ilike` |
| Filtro | `category` (UUID) |
| Paginación | `page` (≥1), `page_size` (1-100) → `PaginatedResponse` |
| PDF obligatorio | En alta, `pdf` es `File(...)`; si falta → 422 |
| Categoría válida | `save_document` (325) exige que exista y esté **activa** |
| Baja lógica | `DELETE` → `deleted_at = now()` + `is_published = False` |
| Publicación | `POST /{id}/publish` / `unpublish` con permiso `gestion.gaceta.publish` |
| Reemplazo de PDF | `PUT` con `pdf` opcional: si llega, crea un `Media` nuevo y **cambia `pdf_media_id`**; el anterior queda huérfano |
| Descarga pública | `GET /api/public/gaceta/{id}/pdf` → `stream_media` → `Content-Type` del mime + `Content-Disposition: inline; filename="..."` |

## Flutter (`GacetaPage`, `main.dart:609-933`)

| Capacidad | Estado | Ubicación |
|---|---|---|
| Listado | Sí | 664-672 |
| Tabla | Manual (`Row` + anchos fijos), **no `AppDataGrid`** | 677-732 |
| Crear | Sí | `_documentDialog()` 816-932 |
| Editar | Sí | `_documentDialog(existing)` |
| Publicar / Despublicar | Sí | `_togglePublish` 744-756 |
| Abrir PDF | Sí | `html.window.open(pdf['url'])` 707-709 |
| Eliminar (baja lógica) | Sí | `_deleteDocument` 758-782 |
| Confirmación | Sí, `AlertDialog` | 759-773 |
| Reemplazar PDF | Sí | 909-914 |
| Feedback | Snackbar en todas las acciones | `_showMessage` 784-787 |
| Refresh automático | Sí, `_load()` tras cada acción | 623-631 |
| Categorías: crear | Sí | `_categoryDialog` 789-814 |
| Categorías: listar/editar/activar | **No** | — |
| Buscador | **No** (el backend lo soporta) | — |
| Filtro por categoría / estado | **No** (el backend lo soporta) | — |
| Paginación en UI | **No** (siempre `page_size: 100`) | `gestion_api.dart` |
| Interruptor "Publicado" en el formulario | **No** (el estado se conserva oculto) | 905-907 |
| Campo de fecha editable | **No** (fija a hoy) | 899-903 |
| Permisos por acción | Sí (`gestion.gaceta.read/manage/publish`) | 636-639, 699-712 |

## Astro

- `pages/gaceta/index.astro` → `<LiveGaceta />` (runtime).
- `LiveGaceta.astro:21` → `fetch('/api/public/gaceta?page=1&page_size=50')` **en el navegador**.
- `LiveGaceta.astro:33` → enlace a `/api/public/gaceta/{id}/pdf` con `target="_blank"`.
- `components/NoticesBoard.astro:6,57` → **sigue usando `gacetaEntries` de `src/data/gaceta.ts`** (3 fixtures con `pdfUrl: '#'`).

## Hallazgos

- **P0** — Doble fuente de verdad en Gaceta (runtime vs fixture) descrita en §1.5.
- **P0** — La fecha de publicación no es editable desde la UI (`main.dart:899-903`).
- **P1** — La página `/gaceta/` no tiene filtro por categoría, ni búsqueda, ni paginación, pese a que el endpoint público (`main.py:297`) soporta `q` y `category`. Con más de 50 documentos, `LiveGaceta` **trunca silenciosamente** (`page_size=50`).
- **P1** — El bloque lateral de la home (`NoticesBoard`) no se conecta a la API → muestra 3 documentos inexistentes.
- **P1** — La categoría se desactiva sin efectos: `save_document` (325) rechaza categorías inactivas, pero la UI muestra **todas** las categorías en el desplegable, incluidas las inactivas (`main.dart:843-847` no filtra por `is_active`).
- **P2** — `pdfUrl: '#'` en `src/data/gaceta.ts:9,16,23` produce un enlace de descarga roto si alguien usa el fixture.
- **P2** — El `LiveGaceta` no muestra estado de carga ni error distinguido: un solo `<p>` que cambia de texto.
- **P2** — No hay contador de documentos ni paginación en la vista pública.
- **P3** — El endpoint público `/api/public/gaceta/{id}` no se usa desde Astro (solo el listado y el PDF).

---

# 12. Avisos y comunicados

**Estado: `NO IMPLEMENTADO`** en backend y Flutter.

## Estado actual en Astro

| Elemento | Ubicación |
|---|---|
| Datos | `src/data/notices.ts:12-37` — 4 avisos fixture |
| Tipo | No hay tipo; son objetos inline `{date, tag, title, href}` |
| Consumidores | `components/HeroEditorial.astro:4,7` (toma `notices[0]` como aviso destacado), `components/NoticesBoard.astro:5` (lista los 4) |
| Etiquetas usadas | "Convocatoria", "Comunicado", "Aviso", "Participación" |
| `href` | Mixto: un enlace interno a `/noticias/becas-escolares-2026/` y 3 externos a `/noticias/`, `/tramites/`, `/eventos/` |

## Hallazgos

- **P0** — Sin entidad, endpoint ni UI.
- **P1** — El aviso destacado del hero (`HeroEditorial.astro:7,25-34`) está **hardcodeado en el texto**: el `<span>` dice literalmente "Becas escolares 2026" mientras el título viene de `notices[0].title`. Si cambia el aviso, el texto del badge queda desincronizado. Es un bug actual, no solo una limitación.
- **P1** — `tag` es un string libre; no hay catálogo administrable.
- **P1** — `href` admite rutas internas y externas sin validación. Una entrada mal formada rompería el enlace.
- **P2** — El orden es por el orden del array, no por `date` (el array ya viene ordenado desc, pero no hay sort real).

---

# 13. Galería

**Estado: `NO IMPLEMENTADO`** en backend y Flutter.

## Estado actual en Astro

| Elemento | Ubicación |
|---|---|
| Datos | `src/data/media.ts:29-50` — `homeGallery` con 4 fotos `{src, alt, caption}` |
| Consumidor | `components/PhotoGallery.astro:4,6` — la primera es "destacada" (ocupa 2×2) |
| Créditos | `src/data/media.ts:1-27` — `photoCredits` con enlace a Wikimedia Commons, renderizados en `Footer.astro:4,63` |

## Hallazgos

- **P0** — Sin entidad, endpoint ni UI.
- **P1** — El concepto de "destacado" **ya existe visualmente** (`PhotoGallery.astro:20`: `md:col-span-2 md:row-span-2`) pero está implícito por posición en el array. Con backend, hace falta un booleano explícito (`is_featured`) o un `sort_order` + regla.
- **P1** — `photoCredits` es un catálogo de atribución con enlaces a Wikimedia. Si las imágenes pasan a `Media`, **los créditos deben seguir mostrándose** → requieren entidad o campo `credit`/`source_url` en `Media`.
- **P2** — `alt` y `caption` son obligatorios hoy; el modelo de Media actual (`models.py`) **no tiene campos de accesibilidad**.

---

# 14. Transparencia

**Estado: `NO IMPLEMENTADO`** en backend y Flutter.

## Estado actual en Astro

| Elemento | Ubicación |
|---|---|
| Datos | `src/data/notices.ts:39-44` — `transparencyLinks` con 4 entradas `{label, description, icon}` |
| Consumidor | `components/TransparencyStrip.astro:3,19` |
| Iconos | `megaphone`, `chart`, `check`, `coins` (del set de `Icon.astro`) |

Los 4 enlaces apuntan a:
- Rendición de cuentas → `/institucional/`
- POA y presupuesto → `/institucional/`
- Contrataciones (SICOES) → `/institucional/`
- Tributos municipales → `/institucional/`

## Hallazgos

- **P0** — Sin entidad, endpoint ni UI.
- **P1** — **No hay ningún PDF público de transparencia en el sitio.** El brief menciona "documentos de transparencia" y "posibles PDFs" → `NO IMPLEMENTADO`; no existe ningún documento que hoy lo justifique.
- **P2** — `icon` es un string que debe coincidir con una clave de `Icon.astro`. Si se administra desde Flutter, hay que exponer el catálogo de iconos o validar contra él.
- **P2** — Los 4 enlaces apuntan a la misma ruta (`/institucional/`), por lo que el enlace externo es puramente decorativo hoy.

---

# 15. Navegación y accesos rápidos

**Estado: `NO IMPLEMENTADO`** en backend y Flutter.

## Estado actual en Astro

| Elemento | Ubicación | Nota |
|---|---|---|
| `mainNav` (9 items) | `src/data/navigation.ts:3-13` | Consumido por `Header.astro:2` (desktop y móvil) y `Footer.astro:3` (mapa del sitio) |
| `homeQuickLinks` (6 items) | `src/data/navigation.ts:16-46` | **Declarado pero NUNCA importado.** `QuickLinks.astro` es un componente huérfano |
| `heroShortcuts` (6 items) | `src/data/notices.ts:3-10` | Consumido por `HeroEditorial.astro:4,101-119`. Etiqueta + href + `icon` |
| `heroSlides` (3 items) | `src/data/heroes.ts:3-28` | **Declarado pero NUNCA importado.** `HeroCarousel.astro` es huérfano |

## Hallazgos

- **P0** — Sin entidad, endpoint ni UI. El menú principal del sitio **no se puede modificar** desde el panel.
- **P1** — El menú de `Header.astro` tiene lógica de etiquetas abreviadas (`navLabels` en `Header.astro:6-9` mapea `/concejo/` → "Concejo" y `/gaceta/` → "Gaceta"). Si el menú se administra, esta lógica debe pasar a ser un campo del ítem (`short_label`) o eliminarse.
- **P1** — `homeQuickLinks` y `heroSlides` son datos **muertos**: están declarados, ocupan mantenimiento y no se renderizan. Hay que decidir si se activan o se eliminan. `REQUIERE CONFIRMACIÓN`.
- **P2** — `heroShortcuts` referencia iconos por nombre (`Icon.astro`), igual que `transparencyLinks`.
- **P2** — No hay "enlaces destacados" / banners configurables.

---

# 16. Media / imágenes / PDFs

## Entidad `Media` (`backend/app/models.py`)

```python
id, original_filename, mime_type, size_bytes, sha256,
storage_path (UNIQUE), kind ('pdf'|'image'), uploaded_by_user_id,
created_at, is_active
```

## Validación de subida (`store_upload`, `main.py:99-121`)

| Control | Implementado | Detalle |
|---|---|---|
| Allowlist MIME | Sí | `pdf` → `application/pdf`; `image` → `image/jpeg`, `image/png`, `image/webp` (línea 100) |
| Validación de firma binaria | Sí | PDF debe empezar por `%PDF-`; imagen por `\xff\xd8\xff` (JPEG), `\x89PNG` (PNG) o `RIFF` (WebP) — líneas 108-111 |
| Tamaño máximo | Sí | `MAX_PDF_SIZE_MB` (25) / `MAX_IMAGE_SIZE_MB` (8) — `.env.example` |
| Archivo vacío | Sí | 413 (línea 106) |
| MIME real vs declarado | **No** | Se valida el `content_type` declarado por el cliente, **no** se re-detecta el tipo desde los bytes. Un `.exe` renombrado a `.pdf` con `content-type: application/pdf` y firma `%PDF-` pasa el filtro. Riesgo **medio**: el archivo se sirve con el MIME declarado y `Content-Disposition: inline` |
| Sanitización de nombre | Sí | Regex `[^A-Za-z0-9._-]+` → `_`, trim, máx 200 chars (línea 113) |
| Path traversal | Sí | `validate_storage_key` (`storage_service.py:10-14`) rechaza absoluto y `..`; `LocalFilesystemStorage._resolve` (líneas 8-12) verifica que el resultado esté dentro del root |
| SHA-256 | Sí | Línea 118 |
| Clave de storage | Sí | `gaceta/{year}/{media_id}/{media_id}.pdf` o `media/{year}/{media_id}/{media_id}.{ext}` (línea 116) |
| Escritura | Sí | `put()` crea directorios con `mkdir(parents=True)` |

## Endpoints de Media

| Método | Endpoint | Permiso | Estado |
|---|---|---|---|
| GET | `/api/public/media/{media_id}` | — (público) | **Implementado** (`main.py:366`) |
| GET | `/api/public/gaceta/{document_id}/pdf` | — (público, solo publicados) | **Implementado** (`main.py:370`) |
| GET | `/api/admin/media` | — | **`NO IMPLEMENTADO`** |
| POST | `/api/admin/media` | `gestion.media.upload` | **`NO IMPLEMENTADO`** (el upload solo existe embebido en mayor/gaceta) |
| DELETE | `/api/admin/media/{id}` | `gestion.media.manage` | **`NO IMPLEMENTADO`** |

## Archivos huérfanos

| Origen | Comportamiento | Riesgo |
|---|---|---|
| Reemplazar PDF de un documento | Se crea `Media` nuevo + archivo nuevo. El `Media` viejo queda `is_active=True`, sin referencia FK y con su archivo en disco | **Medio**: crecimiento indefinido. `Media.is_active` existe pero **nunca se pone en `False`** (verificado: la única referencia es la lectura en `main.py:360`) |
| Reemplazar foto del alcalde | Ídem | Ídem |
| Baja lógica de un documento | El `Media` y el archivo **se conservan** (correcto para auditoría) | Bajo, pero sin política documentada |
| Eliminar una categoría | No hay cascada; los documentos con esa categoría quedan referenciándola | **Alto**: `gaceta_documents.category_id` es FK sin `ON DELETE`. `save_document` rechaza la categoría inactiva → **los documentos existentes de una categoría desactivada quedan sin poder editarse** (`main.py:325`) |

## Imágenes actuales en `public/images/` (15 archivos, ~5.3 MB)

| Archivo | Tamaño | Referencias | Estado |
|---|---|---|---|
| `escudo-sipe-sipe.jpg` | 34 KB | 2 (`Header`, `Footer`) | En uso |
| `sipe-sipe-amanecer.jpg` | 230 KB | 4 | En uso |
| `iglesia-san-pedro.jpg` | 262 KB | 4 | En uso |
| `iglesia-san-pedro-fachada.jpg` | 272 KB | 4 | En uso |
| `iglesia-san-pedro-plaza.jpg` | 169 KB | 4 | En uso |
| `inka-raqay.jpg` | 583 KB | 4 | En uso |
| `inka-raqay-amanecer.jpg` | 168 KB | 1 (`tourism.ts`) | En uso |
| `inka-raqay-camino.jpg` | 561 KB | 1 (`news.ts`) | En uso |
| `inka-raqay-muros.jpg` | 806 KB | 1 (`gaceta/index.astro`) | En uso |
| `puente-viloma.jpg` | 600 KB | 5 | En uso |
| `alcaldeblanco.png` | 1.195 MB | 2 (`site.ts` + fallback `WelcomeMayor`) | En uso — **foto del alcalde declarada** |
| `alcaldesa.jpg` | 266 KB | 1 (`institucional.ts`) | En uso — **foto de un alcalde distinto** |
| `ALCALDE.jpeg` | 96 KB | **0** | **Huérfana** |
| `bandera-sipe-sipe.jpg` | 16 KB | **0** | **Huérfana** |
| `simbolos-sipe-sipe.jpg` | 48 KB | **0** | **Huérfana** |

**Inconsistencia de alcalde (ya detectada en la auditoría anterior, sigue vigente):** `site.ts:25` declara a **"Fredy Patzi Barrios"** con `/images/alcaldeblanco.png`; `institucional.ts:18-22` declara a **"Lic. Roberto Mamani Condori"** con `/images/alcaldesa.jpg`. La web pública muestra ambos en pantallas distintas.

## Formatos y workflow

| Aspecto | Estado actual |
|---|---|
| Formatos aceptados | JPG, PNG, WebP (imágenes); PDF (documentos) |
| Conversión / thumbnails | **NO IMPLEMENTADO**. No hay miniaturas ni resized |
| Preview en Flutter | **NO IMPLEMENTADO**. No hay `Image.network` en ninguna pantalla |
| Reemplazo | Implementado solo en Alcalde y Gaceta |
| Almacenamiento | Volumen Docker `gestion_storage` montado en `/app/storage` |
| URL pública | `PUBLIC_BASE_URL` + `/api/public/media/{id}` (construida en `main.py:91-92`) |
| URL en Astro | `photo.url` del backend o `gestionMediaUrl(id)` (`src/lib/gestionPublic.ts:14-16`) |
| `alt` / accesibilidad | **NO IMPLEMENTADO**. `Media` no tiene campos `alt`/`caption`/`credit` |
| Listado / biblioteca de archivos | **NO IMPLEMENTADO** |

## Hallazgos

- **P0** — No hay biblioteca de medios: el usuario no puede ver qué archivos ha subido, qué PDF corresponde a qué documento ni recuperar un archivo reemplazado.
- **P0** — `Media.is_active` nunca se desactiva → los huérfanos son invisibles e inevitables.
- **P0** — `Media` no tiene `alt`, `caption`, `credit` ni `source_url`, campos que la web pública necesita (accesibilidad de la galería, créditos de Wikimedia).
- **P1** — No se valida el MIME real del archivo, solo el declarado.
- **P1** — `Content-Disposition: inline` en `stream_media` (`main.py:364`): un PDF se abre en el navegador en lugar de descargarse. Para la Gaceta es deseable; para otros tipos puede no serlo.
- **P1** — `PUBLIC_BASE_URL` por defecto es `http://localhost:8001`. Si no se configura en producción, **la web pública incrustará URLs `localhost`** en el HTML del alcalde.
- **P2** — Sin thumbnails: las miniaturas de la galería y del alcalde cargarían el original completo (la foto del alcalde pesa 1.2 MB).
- **P2** — Las 3 imágenes huérfanas y la inconsistencia entre las dos fotos de alcalde.

---

# 17. Storage

## Implementación

| Pieza | Archivo | Detalle |
|---|---|---|
| Contrato | `backend/app/core/storage/storage_service.py` | `Protocol` con `put/read/exists/delete` + `validate_storage_key` |
| Implementación | `backend/app/core/storage/local_filesystem_storage.py` | `LocalFilesystemStorage(root)` |
| Fábrica | `backend/app/core/storage/__init__.py` | `get_storage_service()` crea la instancia con `settings.storage_root` |
| Raíz | `.env` / `.env.example` | `STORAGE_ROOT=/app/storage` en Docker |
| Volumen | `docker-compose.yml:39` | `gestion_storage:/app/storage` (volumen nombrado, **persistente**) |
| Postgres | `docker-compose.yml:13` | `gestion_postgres_data:/var/lib/postgresql/data` |

## Protección contra path traversal (correcta, doble capa)

1. `validate_storage_key` (storage_service.py:10-14): rechaza vacío, absoluto (`/...`), `PurePosixPath.is_absolute()` y cualquier `..` en las partes.
2. `LocalFilesystemStorage._resolve` (líneas 8-12): resuelve la ruta y comprueba que `self._root in candidate.parents or candidate == self._root` → lanza `ValueError` si escapa.

**Verificado por test**: `backend/tests/test_storage.py` cubre round-trip y rechazo de `../outside.pdf`.

## Puntos débiles

- **P1** — `validate_storage_key` **no bloquea la clave vacía después del strip** si es solo espacios… sí lo hace (`if not normalized`). Correcto.
- **P1** — La clave se construye con `datetime.now().year` (año del servidor). Un archivo subido en enero de 2027 y consultado en diciembre de 2026 sigue accesible por `storage_path` (la ruta es la que se guarda, no se recalcula). Correcto.
- **P1** — **No hay borrado físico expuesto.** `StorageService.delete()` existe en el Protocol y en la implementación, pero **ningún endpoint lo llama**. Los archivos solo se acumulan.
- **P2** — No hayreo de integridad: nada verifica que el archivo exista o que su SHA-256 coincida con el registrado. `stream_media` solo comprueba `FileNotFoundError` (línea 363) → 404.
- **P2** — No hay cuota ni límite total de almacenamiento.
- **P2** — El bind mount `./backend:/app` (línea 38) expone el código fuente; combinado con `--reload` es correcto para desarrollo, pero **debe quitarse en producción**.

## Persistencia verificada

En la validación E2E anterior se reinició el contenedor backend **sin** `docker compose down -v` y el PDF siguió descargándose con el mismo SHA-256. **Persistencia confirmada.**

## Backups

`README.md` indica respaldar `gestion_sipe` + el volumen de storage y advierte que "respaldar solo PostgreSQL NO respalda PDFs". Correcto. **Falta**:
- Procedimiento concreto (`pg_dump` + copia del volumen).
- Ubicación de los respaldos.
- Prueba de restauración.

---

# 18. API existente

| Método | Endpoint | Permiso | Flutter | Astro | Estado |
|---|---|---|---|---|---|
| GET | `/health` | — | — | — | Implementado |
| GET | `/health/database` | — | — | — | Implementado |
| POST | `/api/admin/auth/login` | — | Sí | — | Implementado |
| POST | `/api/admin/auth/refresh` | — | Sí | — | Implementado |
| POST | `/api/admin/auth/logout` | — | Sí | — | Implementado |
| GET | `/api/admin/auth/me` | sesión | Sí | — | Implementado |
| GET | `/api/public/site-settings` | — | — | Sí | Implementado |
| GET | `/api/admin/site-settings` | `settings.read` | Sí | — | Implementado |
| PUT | `/api/admin/site-settings` | `settings.manage` | Sí | — | Implementado |
| GET | `/api/public/mayor` | — | — | Sí | Implementado |
| GET | `/api/admin/mayor` | `mayor.read` | Sí | — | Implementado |
| POST | `/api/admin/mayor` | `mayor.manage` | Sí | — | Implementado |
| PUT | `/api/admin/mayor/{id}` | `mayor.manage` | Sí | — | Implementado |
| GET | `/api/public/institutional` | — | — | Sí | Implementado |
| GET | `/api/admin/institutional` | `institutional.read` | Sí | — | Implementado |
| PUT | `/api/admin/institutional` | `institutional.manage` | Sí | — | Implementado |
| GET | `/api/admin/institutional/values` | `institutional.read` | Sí | — | Implementado |
| POST | `/api/admin/institutional/values` | `institutional.manage` | Sí | — | Implementado |
| PUT | `/api/admin/institutional/values/{id}` | `institutional.manage` | Sí | — | Implementado |
| POST | `/api/admin/institutional/values/{id}/deactivate` | `institutional.manage` | **No** | — | Implementado, **sin UI** |
| POST | `/api/admin/institutional/values/{id}/activate` | — | — | — | **`NO IMPLEMENTADO`** |
| GET | `/api/admin/gaceta/categories` | `gaceta.read` | Sí | — | Implementado |
| POST | `/api/admin/gaceta/categories` | `gaceta.manage` | Sí | — | Implementado |
| PUT | `/api/admin/gaceta/categories/{id}` | `gaceta.manage` | **No** | — | Implementado, **sin UI** |
| POST | `/api/admin/gaceta/categories/{id}/activate` | `gaceta.manage` | **No** | — | Implementado, **sin UI** |
| POST | `/api/admin/gaceta/categories/{id}/deactivate` | `gaceta.manage` | **No** | — | Implementado, **sin UI** |
| GET | `/api/public/gaceta` | — | — | Sí (runtime) | Implementado |
| GET | `/api/public/gaceta/{id}` | — | — | **No** | Implementado, **sin uso** |
| GET | `/api/admin/gaceta` | `gaceta.read` | Sí | — | Implementado |
| GET | `/api/admin/gaceta/{id}` | `gaceta.read` | **No** | — | Implementado, **sin UI** |
| POST | `/api/admin/gaceta` | `gaceta.manage` | Sí | — | Implementado |
| PUT | `/api/admin/gaceta/{id}` | `gaceta.manage` | Sí | — | Implementado |
| DELETE | `/api/admin/gaceta/{id}` | `gaceta.manage` | Sí | — | Implementado |
| POST | `/api/admin/gaceta/{id}/publish` | `gaceta.publish` | Sí | — | Implementado |
| POST | `/api/admin/gaceta/{id}/unpublish` | `gaceta.publish` | Sí | — | Implementado |
| GET | `/api/public/media/{id}` | — | — | Sí | Implementado |
| GET | `/api/public/gaceta/{id}/pdf` | — | — | Sí | Implementado |
| GET | `/api/admin/media` | `media.read` | — | — | **`NO IMPLEMENTADO`** |
| POST | `/api/admin/media` | `media.upload` | — | — | **`NO IMPLEMENTADO`** |
| DELETE | `/api/admin/media/{id}` | `media.manage` | — | — | **`NO IMPLEMENTADO`** |
| GET | `/api/admin/users` | `users.read` | Sí | — | Implementado |
| POST | `/api/admin/users` | `users.manage` | **No** | — | Implementado, **sin UI** |
| PUT | `/api/admin/users/{id}` | `users.manage` | **No** | — | Implementado, **sin UI** |
| POST | `/api/admin/users/{id}/activate` | `users.manage` | **No** | — | Implementado, **sin UI** |
| POST | `/api/admin/users/{id}/deactivate` | `users.manage` | **No** | — | Implementado, **sin UI** |
| GET | `/api/admin/roles` | `roles.read` | Sí | — | Implementado |
| GET | `/api/admin/permissions` | `roles.read` | **No** | — | Implementado, **sin UI** |
| POST | `/api/admin/roles` | `roles.manage` | **No** | — | Implementado, **sin UI** |
| PUT | `/api/admin/roles/{id}` | `roles.manage` | **No** | — | Implementado, **sin UI** |

**Resumen:**
- **Implementado y usado en Flutter:** 26
- **Implementado pero sin UI Flutter:** 9 (`values/{id}/activate` no existe; `values/{id}/deactivate`, `categories` PUT/activate/deactivate, `gaceta/{id}` GET, `users` POST/PUT/activate/deactivate, `roles` POST/PUT, `permissions` GET)
- **UI Flutter sin backend:** 0
- **No implementado:** 4 (los 3 de media + `values/{id}/activate`)

---

# 19. Entidades existentes

| Entidad | Tabla | Campos | Integridad referencial |
|---|---|---|---|
| `User` | `users` | id, username (único), email (único), password_hash, is_active, last_login_at, created_at, updated_at | — |
| `Role` | `roles` | id, code (único), name, description, is_active, created_at, updated_at | — |
| `Permission` | `permissions` | id, code (único), description | — |
| `UserRole` | `user_roles` | user_id, role_id | FK `ON DELETE CASCADE` |
| `RolePermission` | `role_permissions` | role_id, permission_id | FK `ON DELETE CASCADE` |
| `AuthSession` | `auth_sessions` | id, user_id, refresh_token_hash (único), expires_at, last_used_at, revoked_at, created_at | FK `ON DELETE CASCADE` |
| `SiteSetting` | `site_settings` | key (PK), value, updated_by_user_id, updated_at | FK users (sin cascade) |
| `InstitutionalContent` | `institutional_content` | id, mission, vision, updated_by_user_id, created_at, updated_at | FK users |
| `InstitutionalValue` | `institutional_values` | id, value, sort_order, is_active, created_at, updated_at | — |
| `Media` | `media` | id, original_filename, mime_type, size_bytes, sha256, storage_path (único), kind, uploaded_by_user_id, created_at, is_active | FK users |
| `Mayor` | `mayors` | id, name, title, welcome_title, message, photo_media_id, photo_note, is_active, created_at, updated_at | FK media |
| `GacetaCategory` | `gaceta_categories` | id, name (único), description, sort_order, is_active, created_at, updated_at | — |
| `GacetaDocument` | `gaceta_documents` | id, category_id, number, title, description, published_at, pdf_media_id, is_published, created_by_user_id, created_at, updated_at, deleted_at | FK category (sin cascade), FK media |

**Observaciones de modelo:**
- `Mayor` y `GacetaDocument` apuntan a `media.id` **sin `ON DELETE`** → un `DELETE` de Media con referencias falla por FK. Coherente con que no exista endpoint de borrado.
- No hay columna `deleted_at` en `Media` (solo `is_active`), mientras que `GacetaDocument` sí la tiene. **Dos convenciones de baja lógica para archivos y documentos.**
- `SiteSetting.value` es `TEXT` sin tipo → todo es string. No hay booleanos, números ni JSON.
- `InstitutionalContent` no tiene `UNIQUE` ni singleton garantizada a nivel de BD: el código toma siempre la primera fila (`main.py:217,227`).

---

# 20. Entidades faltantes

Derivadas del contenido público real de Astro. **No se proposes SQL; solo el dominio.**

| Entidad propuesta | Campos mínimos | Bloque de contenido | Evidencia en Astro |
|---|---|---|---|
| `CmsNews` | id, slug (único), title, excerpt, body, category_id, author, published_at, cover_media_id, cover_alt, is_published, created_by, created_at, updated_at, deleted_at | Noticias | `src/data/news.ts` |
| `CmsNewsCategory` | id, name (único), slug, sort_order, is_active | Noticias | `article.category` (4 strings) |
| `CmsEvent` | id, title, description, location, starts_at, ends_at, image_media_id, is_published, created_at, updated_at, deleted_at | Eventos | `src/data/events.ts` |
| `CmsTramite` | id, name, unit, duration_days, requirements (JSONB o tabla), cost_bs (nullable), is_active, sort_order | Trámites | `src/data/tramites.ts` |
| `CmsTourismSpot` | id, name, summary, distance_km, image_media_id, is_published, sort_order | Turismo | `src/data/tourism.ts` |
| `CmsGalleryItem` | id, media_id, title, caption, alt, credit, source_url, sort_order, is_featured, is_active | Galería | `src/data/media.ts.homeGallery` + `photoCredits` |
| `CmsNotice` | id, date, tag, title, href, is_published, sort_order | Avisos | `src/data/notices.ts` |
| `CmsTransparencyLink` | id, label, description, icon_name, href, sort_order, is_active | Transparencia | `src/data/notices.ts.transparencyLinks` |
| `CmsNavigationItem` | id, label, short_label, href, location ('main'\|'footer'\|'quick_access'), sort_order, is_active | Navegación | `src/data/navigation.ts.mainNav` |
| `CmsHeroShortcut` | id, label, href, icon_name, sort_order, is_active | Accesos rápidos | `src/data/notices.ts.heroShortcuts` |
| `CmsAuthority` | id, name, role, bio, photo_media_id, sort_order, is_active | Autoridades | `src/data/institucional.ts.executiveAuthorities` |
| `CmsOrganizationalUnit` | id, name, sort_order, is_active | Unidades | `src/data/institucional.ts.organizationalUnits` |
| `CmsCouncilMember` | id, name, block, commission, sort_order, is_active | Concejo | `src/data/concejo.ts.councilMembers` |
| `CmsCouncilSetting` | singleton |_schedule, president_name | Concejo | `src/data/concejo.ts` |
| `CmsSiteStat` | id, value, label, sort_order | Estadísticas | `src/data/site.ts.stats` |
| `CmsSiteLink` | id, label, href, sort_order | `topLinks` | `src/data/site.ts.topLinks` |

**Extensión de entidades existentes:**
- `Media`: añadir `alt`, `caption`, `credit`, `source_url`, `deleted_at` (para unificar la baja lógica), `width`/`height` (para thumbs).
- `SiteSetting`: hoy es key/value genérica; no soporta listas ni objetos (`stats`, `topLinks`, `social`). Opciones: (a) columnas dedicadas para stats/topLinks, (b) `CmsSiteStat`/`CmsSiteLink` propias (recomendado), (c) JSONB en una fila.

**Nota sobre el patrón de Gaceta como plantilla:** `CmsNews`, `CmsEvent` y `CmsTourismSpot` deberían seguir el mismo esqueleto (`is_published`, `deleted_at`, `created_by_user_id`, FK a `Media`, orden por `published_at DESC`), lo que reduce el riesgo y hace el CRUD uniforme.

---

# 21. Integración Astro actual

| Ruta | Componente | Datos | Origen | Runtime | Build necesario |
|---|---|---|---|---|---|
| `/` | `index.astro` | Noticias (4) | `data/news.ts` | No | **Sí** |
| `/` | `index.astro` | Eventos (4) | `data/events.ts` | No | **Sí** |
| `/` | `index.astro` | Turismo (4) | `data/tourism.ts` | No | **Sí** |
| `/` | `index.astro` | Gaceta lateral (3) | `data/gaceta.ts` | No | **Sí** |
| `/` | `index.astro` | Avisos (4) | `data/notices.ts` | No | **Sí** |
| `/` | `index.astro` | Estadísticas (4) | `site.ts.stats` | No | **Sí** |
| `/` | `index.astro` | Hero + accesos (6) | `HeroEditorial.astro`, `notices.ts` | No | **Sí** |
| `/` | `index.astro` | Texto del hero | `HeroEditorial.astro` fijo | No | **Sí** |
| `/` | `index.astro` | Galería (4) | `data/media.ts` | No | **Sí** |
| `/` | `index.astro` | transparencia (4) | `notices.ts` | No | **Sí** |
| `/` | `index.astro` | Alcalde | `WelcomeMayor` → **API (build)** | No | **Sí** |
| `/` | `index.astro` | Contacto | `CitizenBand` → `site.ts` | No | **Sí** |
| `/` | `index.astro` | Lema, horario | `HeroEditorial` → `site.ts` | No | **Sí** |
| `/institucional/` | `institucional/index.astro` | Misión, Visión, Valores | **API (build)** + fallback | No | **Sí** |
| `/institucional/` | `institucional/index.astro` | Alcalde | **API (build)** + fallback | No | **Sí** |
| `/institucional/` | `institucional/index.astro` | Gabinete (4) | `institucional.ts` | No | **Sí** |
| `/institucional/` | `institucional/index.astro` | Unidades (9) | `institucional.ts` | No | **Sí** |
| `/concejo/` | `concejo/index.astro` | Presidente, 6tho, sesión | `data/concejo.ts` | No | **Sí** |
| `/gaceta/` | `gaceta/index.astro` → `LiveGaceta` | Documentos | **API** | **Sí** | No |
| `/noticias/` | `noticias/index.astro` | Noticias | `data/news.ts` | No | **Sí** |
| `/noticias/[slug]/` | `noticias/[slug].astro` | Noticia | `data/news.ts` | No | **Sí** (una ruta por noticia) |
| `/eventos/` | `eventos/index.astro` | Eventos | `data/events.ts` | No | **Sí** |
| `/tramites/` | `tramites/index.astro` | Trámites | `data/tramites.ts` | No | **Sí** |
| `/turismo/` | `turismo/index.astro` | Turismo | `data/tourism.ts` | No | **Sí** |
| `/contacto/` | `contacto/index.astro` | Dirección, teléfono, correos, horario | **API (build)** + fallback | No | **Sí** |
| `/contacto/` | `contacto/index.astro` | Formulario | Fijo (sin backend) | — | **Sí** |
| Global | `BaseLayout.astro` | `shortName`, `motto` | **API (build)** + fallback | No | **Sí** |
| Global | `Footer.astro` | Contacto, copyright, edición, créditos, menú | `site.ts`, `navigation.ts`, `media.ts` | No | **Sí** |
| Global | `TopBar.astro` | Horario, `topLinks` | `site.ts` | No | **Sí** |
| Global | `Header.astro` | Menú (9) | `navigation.ts` | No | **Sí** |

## Clasificación de actualización sin rebuild

| Bloque | Clasificación | Notas |
|---|---|---|
| **Gaceta (listado y PDF)** | **RUNTIME** | `LiveGaceta` → `fetch()` en el navegador. Verificado E2E: publicar → aparece sin build |
| Settings (14 claves) | **BUILD-TIME con fallback** | `fetchGestion` en el frontmatter. **Hoy inactivo en producción** (sin `PUBLIC_GESTION_API_URL` en el workflow) |
| Alcalde | **BUILD-TIME con fallback** | Ídem |
| Institucional (misión/visión/valores) | **BUILD-TIME con fallback** | Ídem |
| Contacto (4 campos) | **BUILD-TIME con fallback** | Ídem |
| Noticias | **ESTÁTICO** | `NO IMPLEMENTADO` |
| Eventos | **ESTÁTICO** | `NO IMPLEMENTADO` |
| Trámites | **ESTÁTICO** | `NO IMPLEMENTADO` |
| Turismo | **ESTATAL** | `NO IMPLEMENTADO` |
| Avisos | **ESTÁTICO** | `NO IMPLEMENTADO` |
| Galería | **ESTÁTICO** | `NO IMPLEMENTADO` |
| Transparencia | **ESTÁTICO** | `NO IMPLEMENTADO` |
| Navegación | **ESTÁTICO** | `NO IMPLEMENTADO` |
| Autoridades / Unidades / Concejo | **ESTÁTICO** | `NO IMPLEMENTADO` |
| Estadísticas / `topLinks` | **ESTÁTICO** | `NO IMPLEMENTADO` |

**Resultado: 1 de 15 bloques de contenido se actualiza sin rebuild.** Ese 1 es el más importante (Gaceta) y está verificado.

## Bloqueo de producción

```
.github/workflows/deploy-pages.yml:30-34
  - name: Build site
    env:
      GITHUB_ACTIONS: true
```
No hay `PUBLIC_GESTION_API_URL`. Como `src/lib/gestionPublic.ts:1-4` devuelve `null` sin esa variable, **el build de GitHub Pages jamás consulta la API**. Los bloques "build-time" se convierten de hecho en **estáticos puros** en producción.

Además, aunque se añadiera la variable, un build de GH Pages **no puede alcanzar un backend en `localhost`**: necesitaría una URL pública y el backend tendría que exponer CORS para el build (o el fetch se ejecuta en el runner, no en el navegador → no requiere CORS).

---

# 22. Flujo editorial actual

## Flujo que SÍ funciona (Gaceta)

```
Flutter (GacetaPage)
  └─ POST /api/admin/gaceta  (multipart: category_id, number, title,
                               description, published_at, is_published, pdf)
       └─ store_upload() → SHA-256 + storage_key → Media + archivo en volumen
       └─ GacetaDocument (is_published=false)
            ↓
   Usuario pulsa "Publicar"
     └─ POST /api/admin/gaceta/{id}/publish  (permiso gestion.gaceta.publish)
          └─ is_published = true
               ↓
   Visitante abre https://<web>/gaceta/
     └─ LiveGaceta → fetch() en el navegador
          └─ GET /api/public/gaceta  (filtra deleted_at IS NULL AND is_published)
               └─ aparece el documento  ✅ SIN REBUILD
                    ↓
   Clic en "Descargar"
     └─ GET /api/public/gaceta/{id}/pdf
          └─ Response bytes + Content-Type: application/pdf
               + Content-Disposition: inline; filename="..."
```

**Verificado de extremo a extremo** en la validación anterior: crear desde la UI, publicar, aparecer en Astro sin build, descargar el PDF con SHA-256 idéntico, despublicar y desaparecer.

## Flujo de los demás bloques

```
Flutter → PUT /api/admin/site-settings → site_settings (PostgreSQL)
                                            ↓
                       ✗ NO HAY CONSUMIDOR RUNTIME
                       ✓ Solo fetch en build de Astro (y hoy ni eso en prod)
```

**Consecuencia:** editar el teléfono en el panel **no cambia nada visible** hasta que alguien ejecute `npm run build` con `PUBLIC_GESTION_API_URL` correctamente configurado, y ese build además debe desplegarse.

---

# 23. Problemas funcionales P0

| # | Problema | Archivo / ubicación | Impacto |
|---|---|---|---|
| P0-1 | `PUBLIC_GESTION_API_URL` ausente en el workflow → la integración con la API está **inactiva en producción** | `website/.github/workflows/deploy-pages.yml:30-34` + `src/lib/gestionPublic.ts:1` | Todo el contenido "build-time" (settings, alcalde, institucional, contacto) es estático en el deploy real |
| P0-2 | Noticias, Eventos, Trámites, Turismo, Avisos, Galería, Transparencia, Navegación, Autoridades, Unidades y Concejo **no tienen entidad, endpoint ni UI** | Backend + Flutter | ~60 % del contenido público no es administrable |
| P0-3 | No existe `/api/admin/media`: sin listado, sin borrado, sin baja | `backend/app/main.py` | Los archivos subidos son invisibles; no hay biblioteca de medios |
| P0-4 | `Media.is_active` nunca se pone en `False` y no hay `delete(Media)` | `backend/app/main.py:360` (única referencia) | Cada reemplazo de PDF/foto deja una fila y un archivo huérfanos, sin forma de limpiarlos |
| P0-5 | 4 permisos muertos: `media.read`, `media.upload`, `media.manage`, `roles.assign` | `backend/app/scripts/seed.py:8-9` vs `require_permission` en `main.py` | El modelo de permisos miente sobre lo que el sistema controla |
| P0-6 | Gaceta con doble fuente de verdad | `website/src/components/NoticesBoard.astro:6,57` vs `src/pages/gaceta/index.astro` (LiveGaceta) | El bloque lateral del inicio muestra 3 documentos inexistentes con `pdfUrl: '#'` |
| P0-7 | La fecha de publicación de un documento de Gaceta no es editable | `flutter_app/lib/main.dart:899-903` | Requisito funcional incumplido |
| P0-8 | `Media` no tiene `alt`, `caption`, `credit` ni `source_url` | `backend/app/models.py` | Los créditos de Wikimedia y la accesibilidad no se pueden administrar |
| P0-9 | Categoría de Gaceta desactivada bloquea la edición de sus documentos | `backend/app/main.py:325` (`save_document` exige categoría activa) | Un documento con categoría desactivada queda "atascado": no se puede guardar |
| P0-10 | El formulario de contacto del sitio no tiene backend | `website/src/pages/contacto/index.astro:36-67` | Los mensajes del formulario no se guardan en ningún sitio (acción `action="#"`, `type="button"`) |

---

# 24. Problemas UX P1

| # | Problema | Ubicación |
|---|---|---|
| P1-1 | No hay biblioteca de medios: el usuario no ve sus archivos | Backend |
| P1-2 | Los valores institucionales no se pueden editar, desactivar ni reordenar | `main.dart:529-607` |
| P1-3 | No hay pantalla de categorías de Gaceta (solo diálogo de alta) | `main.dart:789-814` |
| P1-4 | El desplegable de categoría muestra también las inactivas | `main.dart:843-847` |
| P1-5 | La web pública de Gaceta trunca a 50 documentos sin avisar | `LiveGaceta.astro:21` |
| P1-6 | Sin filtros (categoría, estado) ni búsqueda en la página pública de Gaceta, pese a que el endpoint los soporta | `main.py:297-298` |
| P1-7 | Sin búsqueda en ninguna pantalla del panel | `main.dart` |
| P1-8 | Sin paginación en ninguna pantalla del panel | `main.dart` |
| P1-9 | El badge del hero muestra texto fijo "Becas escolares 2026" aunque cambie el aviso | `HeroEditorial.astro:31` |
| P1-10 | Las 3 redes sociales se administran pero no se renderizan en ningún sitio | `site.ts:13-17` |
| P1-11 | `Footer`, `TopBar`, `CitizenBand` y `HeroEditorial` leen `site.ts` directamente, no la API | `website/src/components/*` |
| P1-12 | 7 de las 14 claves de settings no tienen consumidor en Astro | `main.py:34-49` vs `website/src` |
| P1-13 | Sin preview de imagen en Alcalde ni en Gaceta | `main.dart:439-448`, `867-883` |
| P1-14 | El formulario de Gaceta no permite cambiar el estado de publicación | `main.dart:905-907` |
| P1-15 | `Media` no tiene gestión de `alt` (accesibilidad) | `backend/app/models.py` |
| P1-16 | El sitio público tiene dos behaviours distintos en Gaceta (runtime vs build) | `website/src` |
| P1-17 | El formulario de contacto del sitio público no hace nada | `website/src/pages/contacto/index.astro:36-67` |

---

# 25. Mejoras visuales P2

| # | Mejora | Ubicación |
|---|---|---|
| P2-1 | Estandarizar el verde institucional entre Gestión y el sitio (`#087443` vs `#08813A`) | `main.dart:59` / `website/src/styles/global.css` |
| P2-2 | Formularios con ancho máximo y agrupación por sección | `main.dart:346,419,501` |
| P2-3 | Tabla de Gaceta con `AppDataGrid` (sort, paginación, responsive) | `main.dart:677-947` |
| P2-4 | `_GacetaHeader` responsive (mismo breakpoint que las filas) | `main.dart:935-947` |
| P2-5 | Encabezado de tabla con fondo/peso y separación visual | `main.dart:935-947` |
| P2-6 | Badges de estado semánticos (`StatusBadge`) | `main.dart:692-697,576,995,1049` |
| P2-7 | `EmptyState` con icono y CTA en las 4 listas | `main.dart:666` y listados |
| P2-8 | Sidebar con secciones "Página Web / Gaceta / Administración" y filtrado por permisos | `main.dart:109-147` |
| P2-9 | Icono oficial del GAM en lugar de `Icons.account_balance` | `main.dart:115,213` |
| P2-10 | Thumbnails para media | Backend/Flutter |
| P2-11 | Etiquetas legibles en Configuración (hoy `LocationLine`, `SupportEmail`) | `main.dart:373-375` |
| P2-12 | Contador de resultados y paginación visual | Todas las listas |
| P2-13 | Vista de la biblioteca de medios con previsualización | Nuevo módulo |

---

# 26. Responsive

| Viewport | Estado verificado en la auditoría UI/UX previa |
|---|---|
| 1440 px | Correcto en todas las pantallas |
| 1280 px | Correcto |
| 900 px | **Gaceta desalineada**: encabezado horizontal + filas apiladas |
| 420 px | **Gaceta rota**: encabezado colapsado a ~10 px con texto vertical; botón "Nuevo documento" cortado |

Hallazgos responsive específicos de esta auditoría:

- **P1** — `_GacetaHeader` (`main.dart:935-947`) no comparte el `LayoutBuilder` de las filas (`683-722`).
- **P1** — `SettingsPage` usa `SizedBox(width: 360)` fijo (`main.dart:355`): a 420 px, con rail (88) + padding (56), el contenido útil es 276 px → **overflow**.
- **P1** — `MayorPage` y `InstitutionalPage` usan `Column` con `stretch`: inputs a 100 % del ancho, ilegibles en móvil.
- **P1** — El diálogo de Gaceta fija `SizedBox(width: 460)` (`main.dart:836-838`): más ancho que un móvil de 420 px.
- **P2** — `AppHeader` (`main.dart:165-186`) no considera el ancho: título + usuario + logout en un `Row` sin `Flexible`.

---

# 27. Permisos

## Existentes (17, `backend/app/scripts/seed.py:5-10`)

| Código | Usado por endpoint | ADMIN | EDITOR |
|---|---|---|---|
| `gestion.settings.read` | `GET /api/admin/site-settings` | Sí | Sí |
| `gestion.settings.manage` | `PUT /api/admin/site-settings` | Sí | **No** |
| `gestion.mayor.read` | `GET /api/admin/mayor` | Sí | Sí |
| `gestion.mayor.manage` | `POST`/`PUT /api/admin/mayor` | Sí | **No** |
| `gestion.institutional.read` | `GET /api/admin/institutional`, `GET .../values` | Sí | Sí |
| `gestion.institutional.manage` | `PUT /api/admin/institutional`, `POST`/`PUT`/`deactivate` values | Sí | **No** |
| `gestion.gaceta.read` | `GET /api/admin/gaceta`, `GET .../{id}`, `GET .../categories` | Sí | Sí |
| `gestion.gaceta.manage` | `POST`/`PUT`/`DELETE` gaceta, `POST`/`PUT`/toggle categories | Sí | Sí |
| `gestion.gaceta.publish` | `POST .../publish|unpublish` | Sí | Sí |
| `gestion.media.read` | **NINGUNO** | Sí | Sí |
| `gestion.media.upload` | **NINGUNO** | Sí | Sí |
| `gestion.media.manage` | **NINGUNO** | Sí | **No** |
| `gestion.users.read` | `GET /api/admin/users` | Sí | **No** |
| `gestion.users.manage` | `POST`/`PUT`/`toggle` users | Sí | **No** |
| `gestion.roles.read` | `GET /api/admin/roles`, `GET .../permissions` | Sí | **No** |
| `gestion.roles.manage` | `POST`/`PUT /api/admin/roles` | Sí | **No** |
| `gestion.roles.assign` | **NINGUNO** | Sí | **No** |

## Faltantes (para completar el módulo)

| Código propuesto | Bloque | Nota |
|---|---|---|
| `gestion.news.read` / `.manage` / `.publish` | Noticias | nuevo |
| `gestion.news_categories.manage` | Noticias | nuevo |
| `gestion.events.read` / `.manage` / `.publish` | Eventos | nuevo |
| `gestion.tramites.read` / `.manage` | Trámites | nuevo |
| `gestion.tourism.read` / `.manage` / `.publish` | Turismo | nuevo |
| `gestion.notices.read` / `.manage` / `.publish` | Avisos | nuevo |
| `gestion.gallery.read` / `.manage` | Galería | nuevo |
| `gestion.transparency.read` / `.manage` | Transparencia | nuevo |
| `gestion.navigation.read` / `.manage` | Navegación y accesos | nuevo |
| `gestion.institutional.authorities.manage` | Autoridades y unidades | nuevo, o reutilizar `institutional.manage` |
| `gestion.council.manage` | Concejo | nuevo, o reutilizar `institutional.manage` |

**Recomendación de diseño (no aplicada):** mantener el patrón `gestion.<recurso>.<acción>` con tres acciones (`read`, `manage`, `publish`) solo donde tiene sentido publicar/despublicar. `publish` separado de `manage` permite un futuro rol "Revisor".

---

# 28. Comparación con Correspondencia

## Lo que Correspondencia resuelve y el módulo Página Web necesita

| Componente | Ruta en Correspondencia | Aplicabilidad al módulo Página Web |
|---|---|---|
| `AppDataGrid` + columnas + acciones | `lib/shared/widgets/data_grid/` (10 archivos) | **Alta.** Todas las pantallas del módulo son listados con CRUD |
| `AppFormDialog` | `lib/shared/widgets/app_form_dialog.dart` | **Alta.** 6+ formularios (settings, alcalde, institucional, valor, categoría, documento, noticia, evento…) |
| `AppTextField` | `lib/shared/widgets/form/app_text_field.dart` | **Alta.** Sustituye el `decoration()` inline |
| `AppDropdown` / `AppSearchableDropdown` | `lib/shared/widgets/form/` | **Alta.** Categorías, unidades, noticias, eventos |
| `AppTextPassword` | `lib/shared/widgets/form/` | Alta (usuarios) |
| `StatusBadge` | `lib/shared/widgets/status_badge.dart` | **Alta.** Publicado/Borrador/Activo/Inactivo |
| `EmptyState` | `lib/shared/widgets/empty_state.dart` | **Alta.** 8+ listados |
| `SearchField` + `DataPanel` | `lib/shared/widgets/status_badge.dart:68-110` | **Alta.** Buscador y contenedor de tabla |
| `confirmAdminLogicalDelete` | `lib/features/administration/common/` | **Alta.** Baja lógica de noticias, eventos, categorías |
| `admin_active_filter` | `lib/features/administration/common/` | **Alta.** Filtro activos/inactivos |
| `admin_upsert_bloc_listener` | `lib/features/administration/common/` | **Alta.** Feedback unificado tras guardar |
| `PermissionGuard` | `lib/core/auth/permission_guard.dart` | **Alta.** Ocultar secciones por permiso |
| Constantes de permisos | `lib/core/auth/permissions.dart` | **Alta.** 17+ códigos literales |
| `UiColors` + `AppDecorations` + `AppTheme` | `lib/core/theme/` | **Alta.** Resuelve la divergencia de color |
| `AppSurface` / `PageContainer` / `SectionHeader` | `lib/shared/widgets/` | Media |
| Sidebar con secciones + `OfficialLogo` | `lib/features/home/side_menu/` | **Alta.** La estructura de secciones propuesta en el brief se implementa aquí |
| `ControllerFieldPro` + validadores | `lib/core/util/form/` | **Alta.** Validación de formularios |
| Patrón `list_*` / `upsert_*` | `lib/features/administration/basic_data/units/` | **Alta.** Plantilla para los 8 CRUD nuevos |
| `AppDataGrid` responsive (tabla↔cards) | `app_data_grid.dart:142-177` | **Alta.** Resuelve el responsive de Gaceta |
| `AppDataGridPagination` | `app_data_grid_pagination.dart` | Alta |

## Lo que Correspondencia **no** resuelve y el módulo necesita

| Necesidad | Observación |
|---|---|
| Upload de archivos con preview | Correspondencia tiene adjuntos pero no un **selector de archivos** reutilizable en Flutter Web (`file_picker` sí está en su `pubspec.yaml`) |
| Biblioteca de medios | **NO EXISTE** en Correspondencia. Hay que diseñarla |
| Thumbnails | **NO EXISTE** en Correspondencia |
| `alt` / `caption` / `credit` en medios | **NO EXISTE** en Correspondencia |
| Fecha como campo de formulario | No hay un `AppDateField` equivalente |
| Tabla de medios con acciones | **NO EXISTE** |

---

# 29. Componentes reutilizables

## De Correspondencia (copiar/adaptar, sin dependencia runtime)

| # | Componente | Archivo origen | Prioridad |
|---|---|---|---|
| 1 | `AppDataGrid` + `AppDataGridColumn` + `AppDataGridAction` + `AppDataGridActionsBar` + `AppDataGridPagination` + `AppDataGridMobileItem` + `AppDataGridDesktopTable` | `lib/shared/widgets/data_grid/` | P1 |
| 2 | `AppFormDialog` | `lib/shared/widgets/app_form_dialog.dart` | P1 |
| 3 | `AppTextField`, `AppDropdown`, `AppSearchableDropdown`, `AppTextPassword`, `AppFormFieldStyle` | `lib/shared/widgets/form/` | P1 |
| 4 | `StatusBadge`, `SearchField`, `DataPanel` | `lib/shared/widgets/status_badge.dart` | P1 |
| 5 | `EmptyState` | `lib/shared/widgets/empty_state.dart` | P1 |
| 6 | `confirmAdminLogicalDelete` | `lib/features/administration/common/` | P1 |
| 7 | `admin_active_filter`, `admin_upsert_bloc_listener` | `lib/features/administration/common/` | P1 |
| 8 | `PermissionGuard` + `Permissions` | `lib/core/auth/` | P1 |
| 9 | `UiColors`, `AppDecorations`, `AppTheme` | `lib/core/theme/` | P1 |
| 10 | `AppSurface`, `PageContainer`, `SectionHeader` | `lib/shared/widgets/` | P2 |
| 11 | `OfficialLogo` | `lib/shared/widgets/official_logo.dart` | P2 |
| 12 | `ControllerFieldPro` + validadores (`RequiredValid`, etc.) | `lib/core/util/form/` | P2 |
| 13 | `ListenerPro`, `FullWidgetGeneric` | `lib/core/helpers/` | P2 |
| 14 | Sidebar con secciones (adaptar `SideMenuWidget`) | `lib/features/home/side_menu/widgets/` | P2 |
| 15 | `AppStatusBadge` (del data grid) | `lib/shared/widgets/data_grid/app_status_badge.dart` | P2 |

## De Gestión (ya existen, hay que consolidar)

| # | Componente | Ubicación | Nota |
|---|---|---|---|
| 1 | `GestionApi` (Dio) | `packages/gestion_api/` | Correcto. Extender con los nuevos endpoints |
| 2 | `GestionRepository` (`Result<T>`) | `packages/gestion_repository/` | Correcto |
| 3 | `failures` | `packages/failures/` | Idéntico a Correspondencia |
| 4 | `SessionCubit` | `flutter_app/lib/main.dart:23-45` | Mover a `lib/features/authentication/session/` |
| 5 | `hasPermission` | `main.dart:76-80` | Mover a `lib/core/auth/` con las constantes |

## Nuevos, necesarios y sin equivalente

| Componente | Para qué |
|---|---|
| `AppDateField` | Fecha de publicación de noticias, eventos y gaceta |
| `AppMediaPicker` | Selección de archivo + preview + subida (envuelve `file_picker`) |
| `AppMediaLibrary` | Listado de medios con filtros por `kind`, tabla y acciones |
| `AppConfirmDialog` | Confirmaciones con color de peligro (extender el de Correspondencia) |
| `AppSectionCard` / `AppFieldGroup` | Agrupación de formularios en secciones con título |

---

# 30. Recomendación de estructura final del módulo Página Web

La estructura propuesta en el brief **es adecuada** y encaja con el código real. Ajuste recomendado:

```
Página Web
├── General
│   ├── Configuración          → SiteSettings (14 claves + stats + topLinks)
│   ├── Alcalde                → Mayor + Media
│   └── Institucional           → InstitutionalContent + InstitutionalValue
│                                 + Autoridades + Unidades
│
├── Contenido
│   ├── Noticias               → CmsNews + CmsNewsCategory
│   ├── Eventos                → CmsEvent
│   ├── Avisos                 → CmsNotice
│   └── Galería                → CmsGalleryItem + Media
│
├── Servicios
│   ├── Trámites               → CmsTramite
│   └── Turismo                → CmsTourismSpot
│
├── Documentos
│   ├── Gaceta                 → GacetaDocument (existente)
│   ├── Categorías             → GacetaCategory (existente)
│   ├── Transparencia          → CmsTransparencyLink
│   └── Concejo                → CmsCouncilMember + CmsCouncilSetting
│
└── Configuración avanzada
    ├── Navegación             → CmsNavigationItem
    └── Accesos rápidos        → CmsHeroShortcut
```

**Observaciones sobre la propuesta:**

1. **"Institucional" debe absorber Valores, Autoridades y Unidades.** Hoy son 2 páginas del rail (`Institucional` y `Valores`) y soloInstitucional tiene la mitad del contenido. Unificarlas reduce el número de destinos del rail y hace coherente el bloque.

2. **"General" debería incluir un acceso a "Medios".** Sin una biblioteca de medios, el resto de pantallas no pueden seleccionar imágenes ni PDFs de forma útil. Recomiendo un bloque transversal:
   ```
   └── Medios (transversal, visible en todas las pantallas de contenido)
   ```
   o, alternativamente, `Medios` dentro de "Configuración avanzada".

3. **"Gaceta" y "Categorías" pueden vivir en la misma pantalla** con un panel lateral o un `TabBar`, porque las categorías son few (4-8) y subordinate. Pero mantenerlas separadas es válido si la lista de categorías crece.

4. **"Documentos" debería incluir Transparencia** porque ambos son "recursos oficiales descargables". Si transparencia no llega a tener PDFs, su volumen no justifica una sección propia y bastaría con un bloque dentro de "General".

5. **"Avisos" y "Accesos rápidos" son configuración, no contenido editorial.** Ambos son listas cortas de rótulo+enlace. Agruparlos en "Configuración avanzada" reduciría el ruido del menú. La propuesta del brief los separa, lo cual es defendible si los avisos pasan a tener cuerpo completo.

6. **El rail actual tiene 7 destinos y no tiene sección.** Con esta estructura serían ~13-15 destinos en 5 secciones → **un sidebar es obligatorio** (un `NavigationRail` no admite secciones).

**Bloques que hoy no tienen dónde caer:**
- **Estadísticas del municipio** (`site.stats`) → "General > Configuración", en una subsección "Estadísticas".
- **`topLinks`** (Intranet, correo) → "General > Configuración", subsección "Enlaces del sitio".
- **Formulario de contacto** del sitio público → sin destino: requiere un endpoint de recepción de mensajes (entidad nueva). `REQUIERE CONFIRMACIÓN` de si debe entrar en alcance.

---

# 31. Plan de implementación

> Propuesta de fases. **No implementado.** Cada fase deja el sistema en estado funcional.

## Fase 0 — Baseline y decisions pendientes (0.5 día)

- Confirmar con el municipio: categorías de Gaceta definitivas, contenido real del alcalde (la inconsistencia "Fredy Patzi Barrios" vs "Lic. Roberto Mamani Condori" sigue abierta), estadísticas, y si el formulario de contacto debe receptar mensajes.
- Decidir la arquitectura de entrega de Astro: **build-time vs runtime** (afecta a todo el plan).
- Decidir el modelo de `Media` ampliado (alt, caption, credit, `deleted_at`).
- Snapshot de la base actual para reversibilidad.

**Criterio de salida:** decisiones documentadas + backup verificable.

## Fase 1 — Consolidar design system y componentes (3-4 días)

- Extraer `lib/core/theme/` desde Correspondencia (`UiColors`, `AppDecorations`, `AppTheme`) y **unificar el verde en `#08813A`**.
- Copiar `lib/shared/widgets/` (`AppDataGrid`, `AppFormDialog`, `AppTextField`, `AppDropdown`, `StatusBadge`, `EmptyState`, `SearchField`, `DataPanel`).
- Copiar `lib/core/auth/` (`PermissionGuard`, `Permissions` con los 17 códigos actuales).
- Extraer el panel a `lib/features/` sin cambiar comportamiento.
- Migrar **Gaceta** a `AppDataGrid` (esto arregla de paso el responsive P1).
- Migrar los 4 diálogos a `AppFormDialog`.
- Migrar los 4 listados a `AppDataGrid`.

**Criterio de salida:** los 7 pantallas actuales con la UI de Correspondencia, sin regresiones. `flutter analyze`/`test`/`build` verdes.

## Fase 2 — Cierre de la base de contenidos (3-4 días)

**Objetivo:** que los bloques que ya existen en el backend queden completos y conectados.

- **Media:** añadir `/api/admin/media` (listado con filtros `kind`/`q`, paginado), `POST` de subida genérica, `DELETE` con baja lógica (`is_active=False` + `deleted_at`), y **desactivar los huérfanos** al reemplazar un PDF/foto (o marcarlos `superseded`).
- Extender `Media` con `alt`, `caption`, `credit`, `source_url`.
- **Gaceta:** pantalla de categorías (CRUD + activar/desactivar), filtro por categoría/estado en la UI, buscador, paginación, campo de fecha editable, interruptor de publicación, `activate` para valores institucionales.
- **Permisos:** activar `gestion.media.*` (con endpoints reales) y `gestion.roles.assign` (o retirarlos del seed).
- **Alcalde:** preview de foto, endpoint de desactivación, historial.
- **Settings:** agrupar en secciones, humanizar etiquetas, **conectar en Astro `Footer`, `TopBar`, `CitizenBand`, `HeroEditorial`**, y añadir `stats` y `topLinks` como entidades propias.

**Criterio de salida:** los 5 bloques existentes son 100 % administrables y la web los refleja.

## Fase 3 — Multimedia y biblioteca (3-4 días)

- `AppMediaPicker` (Flutter) con preview.
- `AppMediaLibrary` (pantalla) con tabla, filtros por tipo, acciones (descargar, editar alt/caption, dar de baja).
- Migrar las 15 imágenes de `public/images/` a `Media` (script de carga única), conservando la ruta pública.
- **Thumbnail**: decidir si se genera en el backend (Pillow no está en `requirements.txt` → dependencia nueva) o se sirve el original. `REQUIERE CONFIRMACIÓN` si se puede añadir dependencia.

**Criterio de salida:** cualquier pantalla de contenido puede elegir una imagen de la biblioteca.

## Fase 4 — Noticias y Eventos (5-6 días)

- Entidades `CmsNews`, `CmsNewsCategory`, `CmsEvent` + migraciones Alembic.
- Endpoints admin (CRUD + publish/unpublish + filtros) y públicos (listado paginado, detalle por slug).
- Permisos `gestion.news.*`, `gestion.events.*`.
- Flutter: `list_news` + `upsert_news` (con `AppFormDialog`, `AppDataGrid`, `AppDateField`, `AppMediaPicker`), `list_events` + `upsert_events`.
- **Astro:** `/noticias/` y `/noticias/[slug]/` → API. Decidir runtime vs build (ver Fase 8).

**Criterio de salida:** una noticia creada en el panel aparece en la web pública con su imagen.

## Fase 5 — Trámites y Turismo (3-4 días)

- Entidades `CmsTramite`, `CmsTourismSpot`.
- Endpoints + permisos + UI con el mismo esqueleto.
- **Astro:** `/tramites/` y `/turismo/` → API.

**Criterio de salida:** trámites y turismo administrables.

## Fase 6 — Avisos, Galería, Transparencia, Navegación (4-5 días)

- Entidades `CmsNotice`, `CmsGalleryItem`, `CmsTransparencyLink`, `CmsNavigationItem`, `CmsHeroShortcut`.
- Endpoints + permisos + UI.
- **Astro:** `NoticesBoard`, `PhotoGallery`, `TransparencyStrip`, `Header`/`Footer` (menú), `HeroEditorial` (accesos rápidos).
- Corregir el texto fijo del badge del hero (`HeroEditorial.astro:31`).

**Criterio de salida:** todo el contenido visible del home es administrable.

## Fase 7 — Autoridades, Unidades y Concejo (2-3 días)

- Entidades `CmsAuthority`, `CmsOrganizationalUnit`, `CmsCouncilMember`, `CmsCouncilSetting`.
- Fusionar la página "Valores" dentro de "Institucional".
- **Astro:** `/institucional/` y `/concejo/` → API.

**Criterio de salida:** `/institucional/` y `/concejo/` 100 % administrables.

## Fase 8 — Integración Astro completa y entrega sin rebuild (4-6 días)

**Este es el punto crítico.** Requiere una decisión de arquitectura:

**Opción A — Mantener estático (GitHub Pages)**
- Migrar todos los listados a `fetch()` runtime en el navegador (como `LiveGaceta`). Ventaja: cero rebuild, publicación inmediata. Coste: se pierde el SEO de las páginas de detalle (las noticias individual不再 prerenderizadas) y se añade JS al cliente.
- `/noticias/[slug]/` deja de ser una ruta pregenerada → pasa a ser una ruta cliente → **hay que revisar el sitemap y el SEO**.

**Opción B — Migrar a SSR (Node)**
- `astro.config.mjs` → `output: 'server'` + `@astrojs/node`.
- Todos los listados y detalles se renderizan en runtime con la API → **una sola fuente de verdad, sin duplicar fetch client-side**.
- La web pasa de GitHub Pages a un contenedor Node junto al backend.
- Ventaja: coherencia, SSR, SEO intacto, una sola implementación de cada página.
- Coste: cambiar el despliegue; añadir `@astrojs/node` (dependencia nueva).

**Recomendación: Opción B.** El brief exige que "todo el contenido pueda actualizarse sin `npm run build`" y ya existe un backend propio desplegable. La Opción A obliga a reescribir cada página con fetch client-side y rompe el prerenderizado de `/noticias/[slug]/`.

- En cualquiera de las dos: configurar `PUBLIC_GESTION_API_URL` en el entorno de build/despliegue y **dejar de usar el fallback silencioso** (hoy `fetchGestion` devuelve `null` y el sitio publica datos fixture sin avisar → riesgo de publicar contenido desactualizado creyendo que es el real).

**Criterio de salida:** **cualquier** contenido publicado desde el panel aparece en la web sin rebuild ni redeploy.

## Fase 9 — QA municipal y operación (3-5 días)

- Backups: procedimiento `pg_dump` + copia del volumen, con **prueba de restauración**.
- `.env` de producción: `JWT_ACCESS_SECRET`, `PUBLIC_BASE_URL` (público), `COOKIE_SECURE=true`, `APP_ENV=production`, `CORS_ALLOW_ORIGINS` restringido.
- Quitar el bind mount `./backend:/app` y `--reload` del compose de producción.
- Migrar el contenido fixture real (los 4 noticias, 4 eventos, 4 trámites, 4 turismo, 3 gacetas, 4 avisos, 4 galería, 9 unidades, 4 autoridades, 6 concejales) desde `src/data/*.ts` a la BD, con revisión municipal.
- Resolver la inconsistencia de la foto del alcalde.
- QA con el personal municipal usando los 2 roles.

---

## Resumen de fases y esfuerzo

| Fase | Alcance | Esfuerzo |
|---|---|---|
| 0 | Decisiones + baseline | 0.5 d |
| 1 | Design system + DataGrid + FormDialog | 3-4 d |
| 2 | Cierre de base (Media, Gaceta, Alcalde, Settings, permisos) | 3-4 d |
| 3 | Biblioteca de medios + migración de imágenes | 3-4 d |
| 4 | Noticias + Eventos | 5-6 d |
| 5 | Trámites + Turismo | 3-4 d |
| 6 | Avisos + Galería + Transparencia + Navegación | 4-5 d |
| 7 | Autoridades + Unidades + Concejo | 2-3 d |
| 8 | Integración Astro completa (runtime o SSR) | 4-6 d |
| 9 | QA + operación + backup | 3-5 d |
| | **Total** | **28-41 días** |

> El bloque crítico es la **Fase 8**. Si se mantiene GitHub Pages con fetch client-side, la Fase 8 baja a ~2-3 días pero se pierde SEO en las páginas de detalle y se duplica la lógica de fetch.

---

## Anexo — Inventario de fixtures que deben migrarse

| Archivo | Registros | Destino |
|---|---|---|
| `src/data/news.ts` | 4 noticias | `CmsNews` + `CmsNewsCategory` |
| `src/data/events.ts` | 4 eventos | `CmsEvent` |
| `src/data/tramites.ts` | 4 trámites | `CmsTramite` |
| `src/data/tourism.ts` | 4 sitios | `CmsTourismSpot` |
| `src/data/gaceta.ts` | 3 gacetas (sin PDF real) | `GacetaDocument` (requiere PDFs reales del municipio) |
| `src/data/notices.ts` | 4 avisos + 4 transparencia + 6 heroShortcuts | `CmsNotice` + `CmsTransparencyLink` + `CmsHeroShortcut` |
| `src/data/media.ts` | 4 galería + 5 créditos | `CmsGalleryItem` + campos de crédito en `Media` |
| `src/data/navigation.ts` | 9 menú + 6 quickLinks (sin uso) | `CmsNavigationItem` |
| `src/data/institucional.ts` | 4 autoridades + 9 unidades + 5 valores | `CmsAuthority` + `CmsOrganizationalUnit` + `InstitutionalValue` |
| `src/data/concejo.ts` | presidente + 6|teamantes + horario | `CmsCouncilMember` + `CmsCouncilSetting` |
| `src/data/site.ts` | 4 stats + 2 topLinks + 15 settings + alcalde | `CmsSiteStat` + `CmsSiteLink` + `SiteSetting` + `Mayor` |
| `src/data/heroes.ts` | 3 slides (sin uso) | **Decidir**: activar (`CmsHeroSlide`) o eliminar |

**Total: 71 registros fixture** distributed across 16 entidades nuevas + 4 existentes.

---

**Fin de la auditoría.** No se modificó ningún archivo de Flutter, backend, Astro ni Correspondencia. No se realizaron commits, no se crearon endpoints, entidades ni pantallas.
