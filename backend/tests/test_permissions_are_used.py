"""Garantiza que ningún permiso seed quede sin uso real.

El test escanea el código de los endpoints: todo permiso declarado en el
seed debe estar respaldado por al menos una comprobación `require_permission`
o `ensure_permission`.
"""
import re
from pathlib import Path

from app.scripts.seed import PERMISSIONS

BACKEND_ROOT = Path(__file__).resolve().parents[1]


def _declared_permission_codes() -> set[str]:
    source = (BACKEND_ROOT / 'app' / 'main.py').read_text(encoding='utf-8')
    source += (BACKEND_ROOT / 'app' / 'auth.py').read_text(encoding='utf-8')
    return set(re.findall(r"require_permission\(\s*'([^']+)'\s*\)", source)) | set(
        re.findall(r"ensure_permission\([^,]+,\s*user,\s*'([^']+)'\s*\)", source)
    )


def test_every_seeded_permission_is_used_by_an_endpoint():
    used = _declared_permission_codes()
    unused = sorted(code for code in PERMISSIONS if code not in used)
    assert not unused, f'Permisos seed sin uso: {unused}'


def test_no_endpoint_uses_an_undeclared_permission():
    declared = set(PERMISSIONS)
    used = _declared_permission_codes()
    undeclared = sorted(code for code in used if code not in declared)
    assert not undeclared, f'Permisos usados sin declarar en el seed: {undeclared}'
