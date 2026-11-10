"""Fixtures aisladas para la suite del backend.

La suite usa una base SQLite en memoria propia: nunca toca la base real
`gestion_sipe` ni el volumen de storage del servidor.
"""
import os
import uuid

# Se configuran antes de importar la aplicación: Settings valida el secreto
# al importarse `app.main`.
os.environ.setdefault('APP_ENV', 'development')
os.environ.setdefault('JWT_ACCESS_SECRET', 'test-secret-key-for-gestion-suite-0123456789')
os.environ.setdefault('DATABASE_URL', 'postgresql+psycopg://test:test@localhost:5432/test_gestion')
os.environ.setdefault('STORAGE_ROOT', 'storage')

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import Uuid, create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.core.security import create_access_token, hash_password
from app.core.storage.local_filesystem_storage import LocalFilesystemStorage
from app.main import app
from app.models import Permission, Role, RolePermission, User, UserRole

ALL_PERMISSIONS = [
    'gestion.settings.read', 'gestion.settings.manage',
    'gestion.mayor.read', 'gestion.mayor.manage',
    'gestion.institutional.read', 'gestion.institutional.manage',
    'gestion.authorities.read', 'gestion.authorities.manage',
    'gestion.gaceta.read', 'gestion.gaceta.manage', 'gestion.gaceta.publish',
    'gestion.media.read', 'gestion.media.upload', 'gestion.media.manage',
    'gestion.users.read', 'gestion.users.manage',
    'gestion.roles.read', 'gestion.roles.manage', 'gestion.roles.assign',
]

EDITOR_PERMISSIONS = [
    'gestion.settings.read', 'gestion.mayor.read', 'gestion.institutional.read',
    'gestion.authorities.read', 'gestion.authorities.manage',
    'gestion.gaceta.read', 'gestion.gaceta.manage', 'gestion.gaceta.publish',
    'gestion.media.read', 'gestion.media.upload',
]


@pytest.fixture()
def engine():
    engine = create_engine(
        'sqlite+pysqlite:///:memory:',
        connect_args={'check_same_thread': False},
        poolclass=StaticPool,
    )
    # PostgreSQL trata los UUID de forma nativa; SQLite por defecto los guarda
    # como CHAR(32) y devuelve cadenas. Se iguala el comportamiento para que
    # la suite no difiera del entorno real.
    for table in Base.metadata.tables.values():
        for column in table.columns:
            if isinstance(column.type, Uuid):
                column.type = Uuid(native_uuid=True)
    Base.metadata.create_all(engine)
    try:
        yield engine
    finally:
        Base.metadata.drop_all(engine)
        engine.dispose()


@pytest.fixture()
def db(engine) -> Session:
    session = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture()
def storage(tmp_path, monkeypatch):
    """Redirige el storage a un directorio temporal por test."""
    root = tmp_path / 'storage'
    root.mkdir()
    monkeypatch.setattr(
        'app.main.get_storage_service', lambda: LocalFilesystemStorage(root)
    )
    return root


@pytest.fixture()
def client(db, storage):
    def override_get_db():
        session = db
        try:
            yield session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def _create_user(db: Session, username: str, permission_codes: list[str]) -> User:
    for code in permission_codes:
        if db.query(Permission).filter(Permission.code == code).first() is None:
            db.add(Permission(code=code, description=code))
    db.flush()
    role = Role(code=f'TEST_{username.upper()}', name=f'Test {username}', is_active=True)
    db.add(role)
    db.flush()
    for code in permission_codes:
        permission = db.query(Permission).filter(Permission.code == code).first()
        db.add(RolePermission(role_id=role.id, permission_id=permission.id))
    user = User(
        username=username,
        password_hash=hash_password('TestPassword-2026!'),
        is_active=True,
    )
    db.add(user)
    db.flush()
    db.add(UserRole(user_id=user.id, role_id=role.id))
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture()
def admin_user(db) -> User:
    return _create_user(db, 'test_admin', ALL_PERMISSIONS)


@pytest.fixture()
def editor_user(db) -> User:
    return _create_user(db, 'test_editor', EDITOR_PERMISSIONS)


@pytest.fixture()
def no_permission_user(db) -> User:
    return _create_user(db, 'test_plain', [])


@pytest.fixture()
def admin_headers(admin_user) -> dict:
    token, _ = create_access_token(admin_user.id)
    return {'Authorization': f'Bearer {token}'}


@pytest.fixture()
def editor_headers(editor_user) -> dict:
    token, _ = create_access_token(editor_user.id)
    return {'Authorization': f'Bearer {token}'}


@pytest.fixture()
def plain_headers(no_permission_user) -> dict:
    token, _ = create_access_token(no_permission_user.id)
    return {'Authorization': f'Bearer {token}'}


@pytest.fixture()
def pdf_bytes() -> bytes:
    return b'%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n'


@pytest.fixture()
def jpeg_bytes() -> bytes:
    return b'\xff\xd8\xff\xe0' + b'fake-jpeg-payload' * 8
