#!/usr/bin/env python3
"""Root-installed bridge used by the Quickshell Security settings page."""

from __future__ import annotations

import configparser
import json
import os
import pwd
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


HOWDY = Path("/usr/bin/howdy")
HOWDY_COMPARE = Path("/usr/lib/howdy/compare.py")
HOWDY_MODULE = Path("/usr/lib/security/pam_howdy.so")
HOWDY_CONFIG = Path("/etc/howdy/config.ini")
HOWDY_MODELS = Path("/etc/howdy/models")
PAM_TARGET = Path("/etc/pam.d/quickshell")
PAM_BACKUP = Path("/etc/pam.d/quickshell.before-face-manager")
PAM_CONTENT = """#%PAM-1.0

# Face authentication is intentionally scoped to the Quickshell lock screen.
auth      sufficient  /usr/lib/security/pam_howdy.so
auth      include     system-auth
"""


class ManagerError(RuntimeError):
    pass


def emit(ok: bool, message: str, **values: object) -> None:
    print(json.dumps({"ok": ok, "message": message, **values}, ensure_ascii=False))


def requesting_account() -> pwd.struct_passwd:
    uid_text = os.environ.get("PKEXEC_UID") if os.geteuid() == 0 else None
    uid = int(uid_text) if uid_text and uid_text.isdigit() else os.getuid()
    account = pwd.getpwuid(uid)
    if account.pw_uid == 0:
        raise ManagerError("Face models must be managed from a normal user session")
    return account


def require_root() -> None:
    if os.geteuid() != 0:
        raise ManagerError("Administrator authorization is required")


def model_path(account: pwd.struct_passwd) -> Path:
    return HOWDY_MODELS / f"{account.pw_name}.dat"


def load_models(account: pwd.struct_passwd) -> list[dict[str, object]]:
    path = model_path(account)
    if not path.exists():
        return []
    try:
        raw_models = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ManagerError(f"Could not read face models: {error}") from error

    models: list[dict[str, object]] = []
    for entry in raw_models if isinstance(raw_models, list) else []:
        if not isinstance(entry, dict):
            continue
        models.append(
            {
                "id": int(entry.get("id", -1)),
                "label": str(entry.get("label", "Face model")),
                "time": int(entry.get("time", 0)),
            }
        )
    return models


def read_camera_path() -> str:
    if not HOWDY_CONFIG.exists():
        return ""
    parser = configparser.ConfigParser()
    parser.read(HOWDY_CONFIG)
    return parser.get("video", "device_path", fallback="")


def status() -> None:
    account = requesting_account()
    installed = HOWDY.exists() and HOWDY_MODULE.exists() and HOWDY_COMPARE.exists()
    managed_pam = False
    if PAM_TARGET.exists():
        try:
            managed_pam = PAM_TARGET.read_text(encoding="utf-8") == PAM_CONTENT
        except OSError:
            managed_pam = False
    models = load_models(account) if installed else []
    emit(
        True,
        "Face authentication is ready" if installed else "Howdy is not installed",
        installed=installed,
        enabled=managed_pam,
        models=models,
        camera=read_camera_path() if installed else "",
        user=account.pw_name,
    )


def run_howdy(*arguments: str) -> subprocess.CompletedProcess[str]:
    process = subprocess.run(
        [str(HOWDY), *arguments],
        check=False,
        capture_output=True,
        text=True,
    )
    if process.returncode != 0:
        detail = process.stderr.strip() or process.stdout.strip() or "Howdy command failed"
        raise ManagerError(detail)
    return process


def is_capture_device(path: Path) -> bool:
    if not path.exists():
        return False
    probe = subprocess.run(
        ["/usr/bin/v4l2-ctl", "-d", str(path), "--all"],
        check=False,
        capture_output=True,
        text=True,
    )
    return probe.returncode == 0 and "Video Capture" in probe.stdout


def detect_camera() -> Path:
    configured = Path(read_camera_path())
    if str(configured) not in ("", ".") and is_capture_device(configured):
        return configured

    candidates = sorted(Path("/dev/v4l/by-id").glob("*-video-index0"))
    candidates.extend(sorted(Path("/dev/v4l/by-path").glob("*-video-index0")))
    candidates.extend(sorted(Path("/dev").glob("video*")))
    for candidate in candidates:
        if is_capture_device(candidate):
            return candidate
    raise ManagerError("No usable capture camera was found")


def configure_howdy() -> Path:
    if not HOWDY.exists() or not HOWDY_MODULE.exists():
        raise ManagerError("Howdy is not installed. Run the dotfiles installer first")
    camera = detect_camera()
    run_howdy("set", "device_path", str(camera))
    run_howdy("set", "detection_notice", "true")
    run_howdy("set", "force_mjpeg", "true")
    run_howdy("set", "save_failed", "false")
    run_howdy("set", "save_successful", "false")
    return camera


def normalize_model_permissions(account: pwd.struct_passwd) -> None:
    path = model_path(account)
    if path.exists():
        os.chown(path, account.pw_uid, account.pw_gid)
        os.chmod(path, 0o600)


def add_model(label: str) -> None:
    require_root()
    account = requesting_account()
    clean_label = label.strip().replace(",", " ")[:24] or f"Face {int(time.time())}"
    camera = configure_howdy()
    run_howdy("-U", account.pw_name, "-y", "add", clean_label)
    normalize_model_permissions(account)
    emit(True, f'Added face model "{clean_label}"', camera=str(camera))


def test_model() -> None:
    require_root()
    account = requesting_account()
    configure_howdy()
    if not load_models(account):
        raise ManagerError("Add a face model before testing")
    process = subprocess.run(
        ["/usr/bin/python", str(HOWDY_COMPARE), account.pw_name],
        check=False,
        capture_output=True,
        text=True,
    )
    if process.returncode != 0:
        raise ManagerError(process.stderr.strip() or "Face was not recognized")
    emit(True, "Face recognized successfully")


def write_managed_pam() -> None:
    PAM_TARGET.parent.mkdir(parents=True, exist_ok=True)
    if PAM_TARGET.exists():
        current = PAM_TARGET.read_text(encoding="utf-8")
        if current != PAM_CONTENT and not PAM_BACKUP.exists():
            shutil.copy2(PAM_TARGET, PAM_BACKUP)

    descriptor, temporary_name = tempfile.mkstemp(prefix=".quickshell.", dir=PAM_TARGET.parent)
    try:
        os.fchmod(descriptor, 0o644)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(PAM_CONTENT)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_name, PAM_TARGET)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)


def remove_managed_pam() -> bool:
    """Remove our PAM stack and restore the configuration it replaced."""
    if not PAM_TARGET.exists():
        return False
    current = PAM_TARGET.read_text(encoding="utf-8")
    if current != PAM_CONTENT:
        raise ManagerError("Refusing to remove an unmanaged PAM configuration")
    if PAM_BACKUP.exists():
        os.replace(PAM_BACKUP, PAM_TARGET)
    else:
        PAM_TARGET.unlink()
    return True


def enable() -> None:
    require_root()
    account = requesting_account()
    configure_howdy()
    if not load_models(account):
        raise ManagerError("Add and test a face model before enabling face unlock")
    write_managed_pam()
    emit(True, "Face unlock enabled; password fallback remains active")


def disable() -> None:
    require_root()
    if not remove_managed_pam():
        emit(True, "Face unlock is already disabled")
        return
    message = "Face unlock disabled; previous PAM configuration restored" if PAM_TARGET.exists() else "Face unlock disabled; password authentication remains active"
    emit(True, message)


def remove_model(model_id: str) -> None:
    require_root()
    account = requesting_account()
    if not model_id.isdigit():
        raise ManagerError("Invalid face model ID")
    run_howdy("-U", account.pw_name, "-y", "remove", model_id)
    remaining = load_models(account)
    if remaining:
        normalize_model_permissions(account)
    elif PAM_TARGET.exists() and PAM_TARGET.read_text(encoding="utf-8") == PAM_CONTENT:
        remove_managed_pam()
    emit(True, "Face model removed" if remaining else "Last face model removed; face unlock disabled")


def main() -> int:
    try:
        command = sys.argv[1] if len(sys.argv) > 1 else "status"
        if command == "status":
            status()
        elif command == "add":
            add_model(sys.argv[2] if len(sys.argv) > 2 else "")
        elif command == "test":
            test_model()
        elif command == "enable":
            enable()
        elif command == "disable":
            disable()
        elif command == "remove":
            remove_model(sys.argv[2] if len(sys.argv) > 2 else "")
        else:
            raise ManagerError(f"Unknown command: {command}")
        return 0
    except Exception as error:
        emit(False, str(error))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
