# Base de datos

La base de datos de este proyecto es `gestion_sipe`, separada de `correspondencia_sipe`.

La cadena Alembic vive en `backend/alembic/` y tiene una sola head. Los archivos binarios no se guardan en PostgreSQL: `Media.storage_path` apunta al volumen persistente configurado por `STORAGE_ROOT`.
