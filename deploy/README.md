# Despliegue

El backend escucha internamente en el puerto 8000 y el compose lo publica localmente en 8001. En producción debe exponerse detrás de HTTPS mediante el reverse proxy institucional, por ejemplo bajo `gestion-api.example.gob.bo`.

Requisitos:

- `DATABASE_URL` apuntando exclusivamente a `gestion_sipe`.
- `JWT_ACCESS_SECRET` generado fuera del repositorio.
- volumen persistente montado en `STORAGE_ROOT`.
- HTTPS antes de habilitar `COOKIE_SECURE=true`.
- respaldo coordinado de PostgreSQL y del volumen de storage.

No se incluye una configuración de dominio municipal porque el hostname final requiere confirmación.
