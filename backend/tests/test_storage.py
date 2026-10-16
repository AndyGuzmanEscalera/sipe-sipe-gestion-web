from pathlib import Path
import pytest
from app.core.storage.local_filesystem_storage import LocalFilesystemStorage

def test_storage_round_trip(tmp_path: Path):
    storage = LocalFilesystemStorage(tmp_path)
    storage.put('gaceta/2026/file.pdf', b'%PDF-test')
    assert storage.read('gaceta/2026/file.pdf') == b'%PDF-test'
    assert storage.exists('gaceta/2026/file.pdf')

def test_storage_rejects_path_traversal(tmp_path: Path):
    storage = LocalFilesystemStorage(tmp_path)
    with pytest.raises(ValueError):
        storage.put('../outside.pdf', b'bad')
