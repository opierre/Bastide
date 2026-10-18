"""Tests for `tools/package_app.py`'s guard: uninstalling must never delete the user's data.

Velopack installs into %LOCALAPPDATA%\\<pack id> and deletes that whole folder on uninstall,
while the database lives in %LOCALAPPDATA%\\<data dir name>.
"""

import importlib.util
import sys
from pathlib import Path
from types import ModuleType

import pytest

from app.core.config import default_db_path

PACKAGE_APP = Path(__file__).resolve().parents[2] / "tools" / "package_app.py"


@pytest.fixture(scope="module")
def package_app() -> ModuleType:
    spec = importlib.util.spec_from_file_location("package_app", PACKAGE_APP)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_the_build_reads_the_data_dir_the_backend_uses(package_app: ModuleType) -> None:
    assert package_app.data_dir_name() == default_db_path().parent.name


def test_the_install_folder_is_not_the_data_folder(package_app: ModuleType) -> None:
    pack_id = package_app.VELOPACK_PACK_ID

    assert pack_id.casefold() != package_app.data_dir_name().casefold()
    package_app.check_install_root_spares_data(pack_id, package_app.data_dir_name())


@pytest.mark.parametrize("pack_id", ["Bastide", "bastide", "BASTIDE"])
def test_a_pack_id_naming_the_data_folder_is_refused(package_app: ModuleType, pack_id: str) -> None:
    with pytest.raises(SystemExit, match="would delete their database"):
        package_app.check_install_root_spares_data(pack_id, "Bastide")


@pytest.mark.skipif(sys.platform != "win32", reason="the install folder is Windows-only")
def test_the_database_is_outside_the_install_folder(package_app: ModuleType) -> None:
    install_root = default_db_path().parents[1] / package_app.VELOPACK_PACK_ID

    assert not default_db_path().is_relative_to(install_root)
