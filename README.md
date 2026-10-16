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

## Variables y backup

La configuración está en `.env.example`. Respaldar siempre la base `gestion_sipe` **y** el volumen/directorio configurado en `STORAGE_ROOT`; PostgreSQL no contiene el binario de los PDFs e imágenes.

## Decisión de integración Astro

La web pública conserva su build estático para no romper GitHub Pages. Las páginas migradas consumen la API pública en build-time; la Gaceta se publica sin modificar código, pero el deploy estático deberá reconstruirse automáticamente mediante un webhook o workflow posterior. Para disponibilidad inmediata en runtime, la web deberá trasladarse posteriormente a un servidor con SSR o proxy de API.
