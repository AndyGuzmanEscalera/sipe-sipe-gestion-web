"""Configuración de entorno: PUBLIC_BASE_URL y secretos de producción."""
import pytest
from pydantic import ValidationError

from app.core.config import Settings

SECRET = 'x' * 40


def _settings(**overrides):
    base = {
        'app_env': 'development',
        'jwt_access_secret': SECRET,
        'public_base_url': 'http://localhost:8001',
    }
    base.update(overrides)
    return Settings(**base)


def test_development_allows_localhost_public_base_url():
    settings = _settings()
    assert settings.public_base_url == 'http://localhost:8001'


def test_production_rejects_localhost_public_base_url():
    with pytest.raises(ValidationError) as error:
        _settings(app_env='production', cookie_secure=True, public_base_url='http://localhost:8001')
    assert 'localhost' in str(error.value)


def test_production_rejects_loopback_ip_public_base_url():
    with pytest.raises(ValidationError) as error:
        _settings(app_env='production', cookie_secure=True, public_base_url='https://127.0.0.1')
    assert 'PUBLIC_BASE_URL' in str(error.value)


def test_production_requires_public_base_url():
    with pytest.raises(ValidationError) as error:
        _settings(app_env='production', cookie_secure=True, public_base_url='')
    assert 'PUBLIC_BASE_URL' in str(error.value)


def test_production_requires_https_public_base_url():
    with pytest.raises(ValidationError) as error:
        _settings(app_env='production', cookie_secure=True, public_base_url='http://api.municipio.gob.bo')
    assert 'https://' in str(error.value)


def test_production_accepts_public_https_base_url():
    settings = _settings(app_env='production', cookie_secure=True, public_base_url='https://api.municipio.gob.bo')
    assert settings.public_base_url == 'https://api.municipio.gob.bo'


def test_public_base_url_trailing_slash_is_normalized():
    settings = _settings(public_base_url='http://localhost:8001/')
    assert settings.public_base_url == 'http://localhost:8001'


def test_production_still_requires_strong_secret():
    with pytest.raises(ValidationError):
        _settings(app_env='production', cookie_secure=True, jwt_access_secret='corto')
