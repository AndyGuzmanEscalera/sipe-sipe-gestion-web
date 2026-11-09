"""Reglas de edición de Gaceta: categoría inactiva y reemplazo de archivos."""
import uuid

from app.models import GacetaCategory, GacetaDocument, Media


def _pdf_upload(name='documento.pdf', payload=None):
    body = payload or b'%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF\n'
    return ('pdf', (name, body, 'application/pdf'))


def _jpeg_upload(name='foto.jpg'):
    return ('photo', (name, b'\xff\xd8\xff\xe0' + b'payload' * 16, 'image/jpeg'))


def _create_category(db, name, active=True):
    category = GacetaCategory(name=name, is_active=active)
    db.add(category)
    db.commit()
    db.refresh(category)
    return category


def test_create_document_rejects_inactive_category(client, admin_headers, db):
    category = _create_category(db, 'Inactiva para alta', active=False)

    response = client.post(
        '/api/admin/gaceta',
        headers=admin_headers,
        data={
            'category_id': str(category.id),
            'number': 'CAT-INACTIVE-NEW',
            'title': 'No debe crearse',
            'published_at': '2026-01-01',
            'is_published': 'false',
        },
        files={_pdf_upload()[0]: _pdf_upload()[1]},
    )
    assert response.status_code == 422, response.text


def test_edit_document_keeps_its_own_inactive_category(client, admin_headers, db):
    category = _create_category(db, 'Inactiva pero conservada', active=True)

    created = client.post(
        '/api/admin/gaceta',
        headers=admin_headers,
        data={
            'category_id': str(category.id),
            'number': 'CAT-KEEP',
            'title': 'Documento con categoría que luego se desactiva',
            'published_at': '2026-01-01',
            'is_published': 'false',
        },
        files={_pdf_upload()[0]: _pdf_upload()[1]},
    )
    assert created.status_code == 200, created.text
    document_id = created.json()['id']

    # La categoría se desactiva después de crear el documento.
    category.is_active = False
    db.commit()

    # Editar manteniendo la misma categoría debe funcionar.
    updated = client.put(
        f'/api/admin/gaceta/{document_id}',
        headers=admin_headers,
        data={
            'category_id': str(category.id),
            'number': 'CAT-KEEP',
            'title': 'Documento editado conservando la categoría inactiva',
            'description': 'Edición válida',
            'published_at': '2026-01-02',
            'is_published': 'false',
        },
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()['title'] == 'Documento editado conservando la categoría inactiva'


def test_edit_document_rejects_switching_to_another_inactive_category(client, admin_headers, db):
    active_category = _create_category(db, 'Activa', active=True)
    inactive_category = _create_category(db, 'Inactiva destino', active=False)

    created = client.post(
        '/api/admin/gaceta',
        headers=admin_headers,
        data={
            'category_id': str(active_category.id),
            'number': 'CAT-SWITCH',
            'title': 'Documento origen',
            'published_at': '2026-01-01',
            'is_published': 'false',
        },
        files={_pdf_upload()[0]: _pdf_upload()[1]},
    )
    assert created.status_code == 200, created.text
    document_id = created.json()['id']

    response = client.put(
        f'/api/admin/gaceta/{document_id}',
        headers=admin_headers,
        data={
            'category_id': str(inactive_category.id),
            'number': 'CAT-SWITCH',
            'title': 'Cambio a categoría inactiva',
            'published_at': '2026-01-02',
            'is_published': 'false',
        },
    )
    assert response.status_code == 422, response.text


def test_replacing_pdf_supersedes_previous_media(client, admin_headers, db):
    category = _create_category(db, 'Categoria reemplazo', active=True)

    created = client.post(
        '/api/admin/gaceta',
        headers=admin_headers,
        data={
            'category_id': str(category.id),
            'number': 'REPLACE-001',
            'title': 'Documento con PDF reemplazable',
            'published_at': '2026-01-01',
            'is_published': 'false',
        },
        files={_pdf_upload()[0]: _pdf_upload()[1]},
    )
    assert created.status_code == 200, created.text
    first_media_id = created.json()['pdf']['id']

    replaced = client.put(
        f"/api/admin/gaceta/{created.json()['id']}",
        headers=admin_headers,
        data={
            'category_id': str(category.id),
            'number': 'REPLACE-001',
            'title': 'Documento con PDF reemplazable',
            'published_at': '2026-01-01',
            'is_published': 'false',
        },
        files={_pdf_upload('nuevo.pdf', b'%PDF-1.4 version 2\n%%EOF\n')[0]: _pdf_upload('nuevo.pdf', b'%PDF-1.4 version 2\n%%EOF\n')[1]},
    )
    assert replaced.status_code == 200, replaced.text
    second_media_id = replaced.json()['pdf']['id']
    assert second_media_id != first_media_id

    previous = db.get(Media, uuid.UUID(first_media_id))
    assert previous is not None
    assert previous.is_active is False
    assert previous.superseded_at is not None
    assert previous.deleted_at is None

    current = db.get(Media, uuid.UUID(second_media_id))
    assert current.is_active is True

    document = db.get(GacetaDocument, uuid.UUID(created.json()['id']))
    assert str(document.pdf_media_id) == second_media_id


def test_replacing_mayor_photo_supersedes_previous_media(client, admin_headers, db):
    created = client.post(
        '/api/admin/mayor',
        headers=admin_headers,
        data={
            'name': 'Alcalde de prueba',
            'title': 'Alcalde',
            'welcome_title': 'Bienvenida',
            'message': 'Mensaje',
            'photo_note': 'Nota',
        },
        files={_jpeg_upload()[0]: _jpeg_upload()[1]},
    )
    assert created.status_code == 200, created.text
    first_media_id = created.json()['photo']['id']

    updated = client.put(
        f"/api/admin/mayor/{created.json()['id']}",
        headers=admin_headers,
        data={
            'name': 'Alcalde de prueba',
            'title': 'Alcalde',
            'welcome_title': 'Bienvenida',
            'message': 'Mensaje actualizado',
            'photo_note': 'Nota',
        },
        files={_jpeg_upload('nueva.jpg')[0]: _jpeg_upload('nueva.jpg')[1]},
    )
    assert updated.status_code == 200, updated.text
    second_media_id = updated.json()['photo']['id']
    assert second_media_id != first_media_id

    previous = db.get(Media, uuid.UUID(first_media_id))
    assert previous.is_active is False
    assert previous.superseded_at is not None

    current = db.get(Media, uuid.UUID(second_media_id))
    assert current.is_active is True


def test_edit_document_without_new_pdf_keeps_current_media(client, admin_headers, db):
    category = _create_category(db, 'Categoria conserva pdf', active=True)

    created = client.post(
        '/api/admin/gaceta',
        headers=admin_headers,
        data={
            'category_id': str(category.id),
            'number': 'KEEP-PDF',
            'title': 'Documento que conserva PDF',
            'published_at': '2026-01-01',
            'is_published': 'false',
        },
        files={_pdf_upload()[0]: _pdf_upload()[1]},
    )
    assert created.status_code == 200, created.text
    media_id = created.json()['pdf']['id']

    updated = client.put(
        f"/api/admin/gaceta/{created.json()['id']}",
        headers=admin_headers,
        data={
            'category_id': str(category.id),
            'number': 'KEEP-PDF',
            'title': 'Documento que conserva PDF',
            'published_at': '2026-01-01',
            'is_published': 'false',
        },
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()['pdf']['id'] == media_id
    assert db.get(Media, uuid.UUID(media_id)).is_active is True
