# Sipe Sipe Gestión

Plataforma administrativa modular del Gobierno Autónomo Municipal de Sipe Sipe.

La V1 administra configuración pública, alcalde, información institucional, valores y Gaceta Municipal. Es independiente del sistema de Correspondencia y utiliza la base de datos `gestion_sipe`.

## Estructura

- `backend/`: FastAPI, SQLAlchemy, Alembic, autenticación, RBAC y storage.
- `flutter_app/`: panel administrativo Flutter Web.
- `database/`: documentación y scripts auxiliares de PostgreSQL.
- `deploy/`: archivos de despliegue.

## Backend local

1. Copiar `.env.example` a `.env` y definir `JWT_ACCESS_SECRET`.
2. Levantar PostgreSQL y backend:

```bash
docker compose up --build
```

3. Aplicar migraciones:

```bash
docker compose exec backend alembic upgrade head
```

4. Crear permisos y roles iniciales:

```bash
docker compose exec backend python -m app.scripts.seed
```

5. Crear el primer administrador sin guardar credenciales en el repositorio:

```bash
docker compose exec backend python -m app.scripts.create_admin --username admin --email admin@gamsipesipe.gob.bo
```

El comando solicita la contraseña de forma interactiva. API: `http://localhost:8001/docs`.

## Flutter

```bash
cd flutter_app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8001
```

Build:

```bash
flutter build web --release --dart-define=API_BASE_URL=/gestion-api
```

## Tests

```bash
cd backend
pytest -q

cd ../flutter_app
flutter analyze
flutter test
```

La suite del backend usa una base SQLite en memoria propia: nunca toca la base
real `gestion_sipe` ni el volumen de storage.

## Variables y backup

La configuración está en `.env.example`. Respaldar siempre la base `gestion_sipe` **y** el volumen/directorio configurado en `STORAGE_ROOT`; PostgreSQL no contiene el binario de los PDFs e imágenes.

### `PUBLIC_BASE_URL` (backend)

URL pública por la que se sirve la API. Es la base de las URLs de media que el
sitio público incrusta (`/api/public/media/{id}`).

- En desarrollo: `http://localhost:8001`.
- En producción: **obligatoria**, con `https://` y **sin** `localhost`,
  `127.0.0.1` ni `0.0.0.0`. El backend **falla al arrancar** si no se cumple,
  para no publicar URLs que apunten a la máquina local.

```bash
APP_ENV=production
PUBLIC_BASE_URL=https://api.gamsipesipe.gob.bo
```

### `PUBLIC_GESTION_API_URL` (web pública)

Variable `PUBLIC_*` de Vite/Astro: la URL del backend que consume el sitio
público. Sin ella, la web se construye con los datos de respaldo.

**GitHub Actions** (workflow `Deploy to GitHub Pages`):
*Settings → Secrets and variables → Actions → Variables* → añadir
`PUBLIC_GESTION_API_URL`. También se acepta como *Secret*
(el workflow usa `vars.PUBLIC_GESTION_API_URL || secrets.PUBLIC_GESTION_API_URL`).

**Cloudflare Pages**: *Settings → Environment variables* (producción y
previsualización) → `PUBLIC_GESTION_API_URL`.

El valor no se escribe en el código: siempre llega por variable de entorno.

## Integración con la web pública

| Contenido | Mecanismo | ¿Requiere rebuild? |
|---|---|---|
| Gaceta (listado, PDF, bloque lateral del inicio) | Runtime: `fetch` en el navegador contra `/api/public/gaceta` | **No** |
| Configuración, alcalde, institucional, contacto | Build-time: `fetch` en el frontmatter con respaldo | Sí |
| Noticias, eventos, trámites, turismo, avisos, galería | Contenido estático en `src/data/*.ts` | Sí |

La Gaceta tiene **una sola fuente de verdad**: el bloque del inicio y la
página `/gaceta/` consultan la misma API pública. No existen documentos de
respaldo en el sitio.

## Estrategia de archivos (Media)

- Todo archivo subido vive en el volumen persistente `gestion_storage`
  (`STORAGE_ROOT`), en claves `gaceta/<año>/<id>/<id>.pdf` y
  `media/<año>/<id>/<id>.<ext>`.
- **No se borra ningún binario automáticamente.** Los archivos se dan de baja
  lógicamente (`media.is_active = false`) para conservar la auditoría.
- Al **reemplazar** el PDF de un documento o la foto del alcalde, el archivo
  anterior queda con `is_active = false` y `superseded_at` informado: deja de
  servirse públicamente pero se conserva en disco.
- La baja desde el panel (`DELETE /api/admin/media/{id}`) marca `deleted_at` y
  **rechaza** la operación si el archivo está en uso por un documento de
  Gaceta vigente o por el alcalde vigente (`409`).

## Permisos

17 permisos con el patrón `gestion.<recurso>.<acción>`. Todos están en uso por
al menos un endpoint; el test `backend/tests/test_permissions_are_used.py`
falla si algún permiso del seed queda sin uso o si un endpoint usa un permiso
no declarado.

| Permiso | Uso |
|---|---|
| `gestion.settings.read` / `.manage` | Configuración del sitio |
| `gestion.mayor.read` / `.manage` | Alcalde |
| `gestion.institutional.read` / `.manage` | Misión, visión y valores |
| `gestion.gaceta.read` / `.manage` / `.publish` | Gaceta y categorías |
| `gestion.media.read` / `.upload` / `.manage` | Biblioteca de medios |
| `gestion.users.read` / `.manage` | Usuarios |
| `gestion.roles.read` / `.manage` | Roles y permisos |
| `gestion.roles.assign` | Asignar roles a un usuario |

`ADMIN` tiene los 17. `EDITOR` tiene 8: lectura general, Gaceta completa
(incluido publicar) y subida de media; **no** puede modificar usuarios, roles,
configuración crítica, alcalde ni contenido institucional.
