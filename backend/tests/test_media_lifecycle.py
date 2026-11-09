"""Ciclo de vida de Media: permisos, listado, subida y baja lógica."""
import uuid
from datetime import date

import pytest

from app.models import GacetaCategory, GacetaDocument, Mayor, Media


def _pdf_upload(name='documento.pdf'):
    return ('pdf', (name, b'%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF\n', 'application/pdf'))


def _jpeg_upload(name='foto.jpg'):
    return ('photo', (name, b'\xff\xd8\xff\xe0' + b'payload' * 16, 'image/jpeg'))


def test_media_list_requires_media_read_permission(client, plain_headers, db):
    response = client.get('/api/admin/media', headers=plain_headers)
    assert response.status_code == 403, response.text


def test_media_list_requires_authentication(client):
    response = client.get('/api/admin/media')
    assert response.status_code == 401, response.text


def test_media_list_returns_uploaded_files(client, admin_headers):
    upload = client.post(
        '/api/admin/media',
        headers=admin_headers,
        data={'kind': 'pdf'},
        files={'file': _pdf_upload()[1]},
    )
    assert upload.status_code == 200, upload.text
    uploaded_id = upload.json()['id']

    listing = client.get('/api/admin/media', headers=admin_headers)
    assert listing.status_code == 200, listing.text
    payload = listing.json()
    assert payload['total'] == 1
    assert payload['items'][0]['id'] == uploaded_id
    assert payload['items'][0]['kind'] == 'pdf'
    assert payload['items'][0]['is_active'] is True
    assert payload['items'][0]['deleted_at'] is None


def test_media_upload_requires_media_upload_permission(client, editor_headers):
    # EDITOR tiene gestion.media.upload: debe poder subir.
    response = client.post(
        '/api/admin/media',
        headers=editor_headers,
        data={'kind': 'pdf'},
        files={'file': _pdf_upload()[1]},
    )
    assert response.status_code == 200, response.text


def test_media_upload_rejects_disallowed_mime(client, admin_headers):
    response = client.post(
        '/api/admin/media',
        headers=admin_headers,
        data={'kind': 'pdf'},
        files={'file': ('evil.txt', b'not a pdf', 'text/plain')},
    )
    assert response.status_code == 422, response.text


def test_media_upload_rejects_invalid_kind(client, admin_headers):
    response = client.post(
        '/api/admin/media',
        headers=admin_headers,
        data={'kind': 'exe'},
        files={'file': _pdf_upload()[1]},
    )
    assert response.status_code == 422, response.text


def test_media_detail_and_deactivate(client, admin_headers, db):
    upload = client.post(
        '/api/admin/media',
        headers=admin_headers,
        data={'kind': 'pdf'},
        files={'file': _pdf_upload()[1]},
    )
    assert upload.status_code == 200, upload.text
    media_id = upload.json()['id']

    detail = client.get(f'/api/admin/media/{media_id}', headers=admin_headers)
    assert detail.status_code == 200, detail.text
    assert detail.json()['original_filename'] == 'documento.pdf'

    deleted = client.delete(f'/api/admin/media/{media_id}', headers=admin_headers)
    assert deleted.status_code == 200, deleted.text
    assert deleted.json()['is_active'] is False
    assert deleted.json()['deleted_at'] is not None

    row = db.get(Media, uuid.UUID(media_id))
    assert row is not None
    assert row.is_active is False
    assert row.deleted_at is not None


def test_media_deactivate_requires_media_manage_permission(client, editor_headers):
    upload = client.post(
        '/api/admin/media',
        headers=editor_headers,
        data={'kind': 'pdf'},
        files={'file': _pdf_upload()[1]},
    )
    media_id = upload.json()['id']

    response = client.delete(f'/api/admin/media/{media_id}', headers=editor_headers)
    assert response.status_code == 403, response.text


def test_media_deactivate_rejects_file_used_by_active_document(client, admin_headers, db):
    upload = client.post(
        '/api/admin/media',
        headers=admin_headers,
        data={'kind': 'pdf'},
        files={'file': _pdf_upload()[1]},
    )
    media_id = upload.json()['id']

    category = GacetaCategory(name=f'Cat {media_id}', is_active=True)
    db.add(category)
    db.flush()
    db.add(
        GacetaDocument(
            category_id=category.id,
            number='MEDIA-001',
            title='Documento que usa el archivo',
            published_at=date(2026, 1, 1),
            pdf_media_id=uuid.UUID(media_id),
            is_published=True,
        )
    )
    db.commit()

    response = client.delete(f'/api/admin/media/{media_id}', headers=admin_headers)
    assert response.status_code == 409, response.text


def test_media_deactivate_rejects_file_used_by_active_mayor(client, admin_headers, db):
    upload = client.post(
        '/api/admin/media',
        headers=admin_headers,
        data={'kind': 'image'},
        files={'file': _jpeg_upload()[1]},
    )
    media_id = upload.json()['id']

    db.add(Mayor(name='Alcalde de prueba', photo_media_id=uuid.UUID(media_id), is_active=True))
    db.commit()

    response = client.delete(f'/api/admin/media/{media_id}', headers=admin_headers)
    assert response.status_code == 409, response.text


def test_media_deactivate_keeps_binary_on_disk(client, admin_headers, storage, db):
    upload = client.post(
        '/api/admin/media',
        headers=admin_headers,
        data={'kind': 'pdf'},
        files={'file': _pdf_upload()[1]},
    )
    media_id = upload.json()['id']
    row = db.get(Media, uuid.UUID(media_id))
    binary_path = storage / row.storage_path
    assert binary_path.exists()

    response = client.delete(f'/api/admin/media/{media_id}', headers=admin_headers)
    assert response.status_code == 200, response.text
    # Baja lógica: el binario se conserva para auditoría.
    assert binary_path.exists()


def test_public_media_stops_serving_deactivated_file(client, admin_headers):
    upload = client.post(
        '/api/admin/media',
        headers=admin_headers,
        data={'kind': 'pdf'},
        files={'file': _pdf_upload()[1]},
    )
    media_id = upload.json()['id']

    assert client.get(f'/api/public/media/{media_id}').status_code == 200

    client.delete(f'/api/admin/media/{media_id}', headers=admin_headers)
    assert client.get(f'/api/public/media/{media_id}').status_code == 404
