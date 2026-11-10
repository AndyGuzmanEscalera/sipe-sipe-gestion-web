"""Ciclo de vida del contenido público sin despliegue del sitio Astro."""


def test_public_mayor_changes_immediately(client, admin_headers):
    before = client.get('/api/public/mayor')
    assert before.status_code == 200

    create = client.post(
        '/api/admin/mayor',
        headers=admin_headers,
        data={
            'name': 'Alcalde E2E Runtime',
            'title': 'Alcalde Municipal',
            'welcome_title': 'Saludo de prueba',
            'message': 'Mensaje inicial',
            'photo_note': '',
        },
    )
    assert create.status_code == 200
    mayor_id = create.json()['id']

    public = client.get('/api/public/mayor')
    assert public.status_code == 200
    assert public.json()['name'] == 'Alcalde E2E Runtime'
    assert public.headers.get('cache-control') == 'public, max-age=30'

    client.put(
        f'/api/admin/mayor/{mayor_id}',
        headers=admin_headers,
        data={
            'name': 'Alcalde E2E Actualizado',
            'title': 'Alcalde Municipal',
            'welcome_title': 'Saludo de prueba',
            'message': 'Mensaje actualizado',
            'photo_note': '',
        },
    )
    public2 = client.get('/api/public/mayor')
    assert public2.json()['name'] == 'Alcalde E2E Actualizado'


def test_public_institutional_changes_immediately(client, admin_headers):
    client.put(
        '/api/admin/institutional',
        headers=admin_headers,
        json={'mission': 'Misión E2E', 'vision': 'Visión E2E'},
    )
    response = client.get('/api/public/institutional')
    assert response.status_code == 200
    payload = response.json()
    assert payload['mission'] == 'Misión E2E'
    assert payload['vision'] == 'Visión E2E'


def test_authorities_publish_lifecycle(client, admin_headers):
    assert client.get('/api/public/authorities').json() == []

    create = client.post(
        '/api/admin/authorities',
        headers=admin_headers,
        data={
            'name': 'Autoridad E2E',
            'professional_title': 'Lic.',
            'position': 'Secretaría',
            'description': 'Descripción',
            'display_order': 1,
            'is_published': False,
        },
    )
    assert create.status_code == 200
    authority_id = create.json()['id']
    assert client.get('/api/public/authorities').json() == []

    client.post(f'/api/admin/authorities/{authority_id}/publish', headers=admin_headers)
    published = client.get('/api/public/authorities').json()
    assert len(published) == 1
    assert published[0]['name'] == 'Autoridad E2E'

    client.put(
        f'/api/admin/authorities/{authority_id}',
        headers=admin_headers,
        data={
            'name': 'Autoridad Editada',
            'professional_title': 'Lic.',
            'position': 'Secretaría',
            'description': 'Descripción',
            'display_order': 1,
            'is_published': True,
        },
    )
    assert client.get('/api/public/authorities').json()[0]['name'] == 'Autoridad Editada'

    client.post(f'/api/admin/authorities/{authority_id}/unpublish', headers=admin_headers)
    assert client.get('/api/public/authorities').json() == []


def test_public_endpoints_do_not_require_auth(client):
    for path in (
        '/api/public/mayor',
        '/api/public/institutional',
        '/api/public/authorities',
        '/api/public/gaceta?page=1&page_size=1',
    ):
        response = client.get(path)
        assert response.status_code in {200, 404}
        assert 'authorization' not in {k.lower() for k in response.headers}
