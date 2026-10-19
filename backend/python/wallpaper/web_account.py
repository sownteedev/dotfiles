#!/usr/bin/env python3
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import signal
import sys
from urllib.parse import urlsplit


PROVIDERS = {
    "wallhaven": {
        "origin": "https://wallhaven.cc",
        "home": "https://wallhaven.cc/favorites",
        "hosts": {"wallhaven.cc"},
    },
    "steam": {
        "origin": "https://steamcommunity.com",
        "home": "https://steamcommunity.com/my/",
        "hosts": {"steamcommunity.com", "store.steampowered.com", "login.steampowered.com", "help.steampowered.com"},
    },
}


class RequestError(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code


def validate_request(request):
    if not isinstance(request, dict) or request.get("provider") not in PROVIDERS:
        raise RequestError("invalid_request", "Choose Wallhaven or Steam.")
    provider = request["provider"]
    action = request.get("action")
    allowed = {"restore", "status", "connect", "disconnect"}
    allowed.update({"collections", "collect", "uncollect"} if provider == "wallhaven" else {"subscriptions", "subscribe", "unsubscribe"})
    if action not in allowed:
        raise RequestError("invalid_request", "Unsupported account action.")
    result = {"provider": provider, "action": action}
    if action == "subscriptions":
        page = request.get("page", 1)
        if type(page) is not int or not 1 <= page <= 10000:
            raise RequestError("invalid_request", "Invalid subscriptions page.")
        result["page"] = page
    if action in {"collect", "uncollect", "subscribe", "unsubscribe"}:
        item_id = str(request.get("item_id", ""))
        pattern = r"[a-z0-9]{6}" if provider == "wallhaven" else r"[1-9][0-9]{0,19}"
        if not re.fullmatch(pattern, item_id):
            raise RequestError("invalid_request", "Invalid wallpaper identifier.")
        result["item_id"] = item_id
    if action == "collect":
        collection_id = str(request.get("collection_id", ""))
        if not re.fullmatch(r"[1-9][0-9]{0,19}", collection_id):
            raise RequestError("invalid_request", "Invalid collection identifier.")
        result["collection_id"] = collection_id
    return result


def private_directory(path):
    if path.is_symlink():
        raise RequestError("unsafe_storage", "Account storage must not be a symbolic link.")
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    if path.stat().st_uid != os.getuid():
        raise RequestError("unsafe_storage", "Account storage belongs to another user.")
    path.chmod(0o700)
    return path


def prepare_account_cache(directory, provider):
    cache_home = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
    cache_path = cache_home / "sownteeshell" / "web-accounts"
    if not cache_home.is_absolute() or cache_path.resolve().is_relative_to(Path(__file__).resolve().parents[3]):
        raise RequestError("unsafe_storage", "Account caches must use an absolute XDG cache directory outside the shell repository.")
    cache_directory = private_directory(cache_path / provider)
    legacy_connect_cache = cache_home / "sownteeshell" / "connect"
    if legacy_connect_cache.exists():
        shutil.rmtree(legacy_connect_cache, ignore_errors=True)
    legacy_cache = directory / "cache"
    if legacy_cache.is_symlink():
        raise RequestError("unsafe_storage", "Account cache must not be a symbolic link.")
    if legacy_cache.is_dir():
        if cache_directory.exists() and any(cache_directory.iterdir()):
            shutil.rmtree(legacy_cache, ignore_errors=True)
        else:
            if cache_directory.exists():
                shutil.rmtree(cache_directory, ignore_errors=True)
            shutil.move(str(legacy_cache), str(cache_directory))
    return private_directory(cache_directory)

def create_application():
    from PySide6.QtCore import QCoreApplication
    from PySide6.QtWidgets import QApplication

    QCoreApplication.setOrganizationName("")
    QCoreApplication.setApplicationName("sownteeshell")
    app = QApplication([sys.argv[0]])
    app.setQuitOnLastWindowClosed(False)
    return app

def read_account(directory):
    path = directory / "account.json"
    if path.is_symlink():
        raise RequestError("unsafe_storage", "Account metadata must not be a symbolic link.")
    try:
        data = json.loads(path.read_text())
    except (OSError, ValueError):
        return None
    if not isinstance(data, dict) or not isinstance(data.get("id"), str) or not data["id"]:
        return None
    return {"id": data["id"][:128], "label": str(data.get("label", data["id"]))[:128]}


def save_account(directory, account):
    temporary = directory / ("account-" + secrets.token_hex(12) + ".tmp")
    with temporary.open("x") as stream:
        os.chmod(temporary, 0o600)
        json.dump(account, stream)
    temporary.replace(directory / "account.json")


def allowed_navigation(provider, url):
    try:
        parsed = urlsplit(url)
        return parsed.scheme == "https" and parsed.hostname in PROVIDERS[provider]["hosts"] and not parsed.username and not parsed.password and parsed.port in {None, 443}
    except ValueError:
        return False


def emit(response):
    try:
        print(json.dumps(response, ensure_ascii=True), flush=True)
    except BrokenPipeError:
        with open(os.devnull, "w") as sink:
            os.dup2(sink.fileno(), sys.stdout.fileno())


def run(request, watch_stdin=False):
    os.umask(0o077)
    provider = request["provider"]
    action = request["action"]
    data_home = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
    base_path = data_home / "sownteeshell" / "web-accounts"
    if not data_home.is_absolute() or base_path.resolve().is_relative_to(Path(__file__).resolve().parents[3]):
        raise RequestError("unsafe_storage", "Account sessions must be stored outside the shell repository in an absolute XDG data directory.")
    base = private_directory(base_path)
    directory = private_directory(base / provider)
    if action == "restore":
        account = read_account(directory)
        emit({"ok": True, "connected": bool(account), "account": account})
        return 0

    from PySide6.QtCore import QLockFile, QSocketNotifier, QTimer, QUrl

    lock = QLockFile(str(base / (provider + ".lock")))
    lock.setStaleLockTime(0)
    if not lock.tryLock(0):
        raise RequestError("busy", "This account is already in use. Finish the current action first.")
    cache_directory = prepare_account_cache(directory, provider)
    account = read_account(directory)
    if action == "disconnect":
        shutil.rmtree(directory, ignore_errors=True)
        shutil.rmtree(cache_directory, ignore_errors=True)
        shutil.rmtree(data_home / "sownteeshell" / "QtWebEngine" / ("sowntee-" + provider), ignore_errors=True)
        emit({"ok": True, "connected": False, "message": "Disconnected from this shell."})
        return 0
    if action != "connect" and not account:
        emit({"ok": action == "status", "connected": False, "code": "authentication_required", "message": "Connect your account in Settings > Integrations first."})
        return 0

    from PySide6.QtWebEngineCore import QWebEnginePage, QWebEngineProfile, QWebEngineSettings, QWebEngineUrlRequestInfo, QWebEngineUrlRequestInterceptor
    from PySide6.QtWebEngineWidgets import QWebEngineView

    class BackgroundRequests(QWebEngineUrlRequestInterceptor):
        def interceptRequest(self, info):
            if info.resourceType() == QWebEngineUrlRequestInfo.ResourceType.ResourceTypeMainFrame:
                info.setHttpHeader(b"Cache-Control", b"no-cache")
            if info.resourceType() in {
                QWebEngineUrlRequestInfo.ResourceType.ResourceTypeImage,
                QWebEngineUrlRequestInfo.ResourceType.ResourceTypeFontResource,
                QWebEngineUrlRequestInfo.ResourceType.ResourceTypeMedia,
            }:
                info.block(True)

    class Page(QWebEnginePage):
        def acceptNavigationRequest(self, url, navigation_type, is_main_frame):
            if not is_main_frame:
                return True
            return allowed_navigation(provider, url.toString())

        def javaScriptConsoleMessage(self, level, message, line, source):
            pass

    class Controller:
        def __init__(self):
            self.done = False
            self.executing = False
            self.generation = 0
            self.identity = None
            self.result_key = "__sowntee_" + secrets.token_hex(16)
            self.profile = QWebEngineProfile("sowntee-" + provider, app)
            self.profile.setPersistentStoragePath(str(private_directory(directory / "profile")))
            self.profile.setCachePath(str(cache_directory))
            self.profile.setHttpCacheType(QWebEngineProfile.HttpCacheType.MemoryHttpCache)
            if provider == "steam" and action in {"subscriptions", "subscribe", "unsubscribe"}:
                self.profile.setHttpCacheType(QWebEngineProfile.HttpCacheType.DiskHttpCache)
                self.background_requests = BackgroundRequests(self.profile)
                self.profile.setUrlRequestInterceptor(self.background_requests)
            self.profile.setPersistentCookiesPolicy(QWebEngineProfile.PersistentCookiesPolicy.ForcePersistentCookies)
            self.profile.downloadRequested.connect(lambda download: download.cancel())
            self.page = Page(self.profile, app)
            self.page.settings().setAttribute(QWebEngineSettings.WebAttribute.JavascriptCanOpenWindows, False)
            self.page.settings().setAttribute(QWebEngineSettings.WebAttribute.LocalContentCanAccessFileUrls, False)
            self.page.permissionRequested.connect(lambda permission: permission.deny())
            self.page.certificateError.connect(lambda error: error.rejectCertificate())
            self.page.loadStarted.connect(self.loading)
            self.page.loadFinished.connect(self.loaded)
            self.timeout = QTimer()
            self.timeout.setSingleShot(True)
            self.timeout.timeout.connect(self.timed_out)
            self.timeout.start(600000 if action == "connect" else 60000)
            self.failed_load_timeout = QTimer()
            self.failed_load_timeout.setSingleShot(True)
            self.failed_load_timeout.timeout.connect(self.failed_load)
            self.poll = QTimer()
            self.poll.setInterval(150)
            self.poll.timeout.connect(self.poll_result)
            self.window = None
            self.owner_notifier = None
            if watch_stdin:
                self.owner_notifier = QSocketNotifier(sys.stdin.fileno(), QSocketNotifier.Type.Read, app)
                self.owner_notifier.activated.connect(self.owner_disconnected)
            if action == "connect":
                from web_account_ui import AccountWindow

                self.view = QWebEngineView()
                self.view.setPage(self.page)
                self.window = AccountWindow("Steam" if provider == "steam" else "Wallhaven", self.view)
                self.window.closing.connect(lambda: self.finish({"ok": False, "code": "cancelled", "message": "Account connection cancelled."}))
                self.label = self.window.status
                self.confirm = self.window.confirm
                self.confirm.clicked.connect(self.confirm_account)
                self.window.show()
            target = PROVIDERS[provider]["home"]
            if action in {"subscribe", "unsubscribe"}:
                target = PROVIDERS[provider]["origin"] + "/sharedfiles/filedetails/?id=" + request["item_id"]
            elif action == "subscriptions":
                target = PROVIDERS[provider]["origin"] + "/profiles/" + account["id"] + "/myworkshopfiles/?appid=431960&browsefilter=mysubscriptions&numperpage=30&p=" + str(request["page"]) + "&l=english"
            self.page.setUrl(QUrl(target))

        def loading(self):
            self.failed_load_timeout.stop()
            self.generation += 1
            self.poll.stop()
            if self.executing and not self.window:
                self.finish({"ok": False, "code": "navigation_changed", "message": "The website navigated during the request. Check the website before retrying."})
                return
            self.executing = False
            if self.window:
                self.identity = None
                self.confirm.setEnabled(False)
                self.confirm.setText("Check sign-in")
                self.label.setText("Loading website. Please wait...")

        def timed_out(self):
            self.finish({"ok": False, "code": "timeout", "message": "Account request timed out. Recheck the website before retrying a save or subscription."})

        def failed_load(self):
            if self.done or self.executing:
                return
            self.finish({"ok": False, "code": "network_error", "message": "Could not load the account website. Check your connection."})

        def loaded(self, success):
            if self.done or self.executing:
                return
            if not success:
                if self.window:
                    self.label.setText("Waiting for the website security check or network response...")
                    self.confirm.setEnabled(True)
                self.failed_load_timeout.start(20000)
                return
            self.failed_load_timeout.stop()
            if self.page.url().host() != urlsplit(PROVIDERS[provider]["origin"]).hostname:
                if self.window:
                    self.confirm.setEnabled(True)
                    self.label.setText("Complete sign-in and security checks on the official website, then select Check sign-in.")
                else:
                    self.finish({"ok": False, "connected": False, "code": "authentication_required", "message": "The website redirected to sign-in. Reconnect your account."})
                return
            self.executing = True
            script_request = dict(request)
            script_request["action"] = "identity" if self.window else action
            script_request["expected_account"] = account["id"] if account and not self.window else ""
            source = (Path(__file__).with_name("web_account.js")).read_text()
            script = "globalThis[" + json.dumps(self.result_key) + "] = null;\n" + source
            script += "\nsownteeAccountAction(" + json.dumps(script_request) + ").then(result => { globalThis[" + json.dumps(self.result_key) + "] = JSON.stringify(result); });"
            self.page.runJavaScript(script)
            self.poll.start()

        def poll_result(self):
            if not self.done:
                generation = self.generation
                self.page.runJavaScript("globalThis[" + json.dumps(self.result_key) + "] || ''", lambda raw: self.received(raw) if generation == self.generation else None)

        def received(self, raw):
            if self.done or not raw:
                return
            self.poll.stop()
            self.executing = False
            try:
                response = json.loads(raw)
                if not isinstance(response, dict):
                    raise ValueError()
            except (TypeError, ValueError):
                self.finish({"ok": False, "code": "invalid_response", "message": "The account website returned an unexpected response."})
                return
            if self.window:
                identity = response.get("account")
                self.identity = identity if response.get("ok") and isinstance(identity, dict) else None
                self.confirm.setEnabled(True)
                self.confirm.setText("Use this account" if self.identity else "Check sign-in")
                self.label.setText("Use account: " + self.identity["label"] if self.identity else "Sign in, then open your Favorites or profile page to connect. Steam Guard / CAPTCHA must be completed by you.")
                return
            if response.get("code") == "authentication_required":
                response["connected"] = False
            elif response.get("code") == "account_changed":
                response["connected"] = False
            elif response.get("ok"):
                response["connected"] = True
                response["account"] = account
            self.finish(response)

        def confirm_account(self):
            if self.identity:
                save_account(directory, self.identity)
                self.finish({"ok": True, "connected": True, "account": self.identity, "message": "Account connected."})
            else:
                self.page.setUrl(QUrl(PROVIDERS[provider]["home"]))

        def owner_disconnected(self):
            try:
                if os.read(sys.stdin.fileno(), 4096):
                    return
            except OSError:
                pass
            self.finish(None)

        def finish(self, response):
            if self.done:
                return
            self.done = True
            self.timeout.stop()
            self.poll.stop()
            self.failed_load_timeout.stop()
            if self.owner_notifier:
                self.owner_notifier.setEnabled(False)
            termination_notifier.setEnabled(False)
            try:
                if response is not None:
                    emit(response)
            finally:
                if self.window:
                    self.window.hide()
                self.page.deleteLater()
                QTimer.singleShot(0, self.dispose_profile)

        def dispose_profile(self):
            self.profile.deleteLater()
            QTimer.singleShot(100, app.quit)

    app = create_application()
    if action == "connect":
        from web_account_ui import configure_application

        configure_application(app)
    controller = Controller()
    termination_read, termination_write = os.pipe2(os.O_NONBLOCK | os.O_CLOEXEC)
    previous_wakeup = signal.set_wakeup_fd(termination_write)
    previous_handler = signal.signal(signal.SIGTERM, lambda *_args: None)
    termination_notifier = QSocketNotifier(termination_read, QSocketNotifier.Type.Read, app)
    termination_notifier.activated.connect(lambda: controller.finish(None))
    try:
        return app.exec()
    finally:
        termination_notifier.setEnabled(False)
        signal.signal(signal.SIGTERM, previous_handler)
        signal.set_wakeup_fd(previous_wakeup)
        os.close(termination_read)
        os.close(termination_write)


def main():
    try:
        raw = sys.stdin.readline(8193)
        if len(raw) > 8192:
            raise RequestError("invalid_request", "Account request is too large.")
        request = validate_request(json.loads(raw))
        return run(request, watch_stdin="--watch-stdin" in sys.argv[1:])
    except RequestError as error:
        emit({"ok": False, "code": error.code, "message": str(error)})
    except ImportError:
        emit({"ok": False, "code": "dependency_missing", "message": "Install pyside6 and qt6-webengine to connect wallpaper accounts."})
    except (ValueError, TypeError):
        emit({"ok": False, "code": "invalid_request", "message": "Invalid account request."})
    except Exception:
        emit({"ok": False, "code": "account_error", "message": "Could not open the private account session. Check storage permissions and dependencies."})
    return 1


if __name__ == "__main__":
    sys.exit(main())
