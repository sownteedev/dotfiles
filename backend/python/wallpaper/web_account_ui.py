import json
import os
from pathlib import Path
import re

from PySide6.QtCore import QFileSystemWatcher, QTimer, Qt, Signal
from PySide6.QtGui import QColor, QFont, QIcon
from PySide6.QtWidgets import (
    QFrame, QGridLayout, QHBoxLayout, QLabel, QMainWindow, QProgressBar, QPushButton,
    QSizePolicy, QVBoxLayout, QWidget,
)


APP_ID = "sownteeshell-connect"
APP_NAME = "SownteeShell Connect"
ICON_PATH = Path(__file__).resolve().parents[3] / "assets/icons/sownteeshell-connect.svg"

FALLBACK_COLORS = {
    "surface": "#111815",
    "surface_container": "#1d2521",
    "surface_container_high": "#27302b",
    "surface_container_lowest": "#0b100e",
    "on_surface": "#e0e4df",
    "on_surface_variant": "#bfc9c1",
    "primary": "#9ed5b2",
    "on_primary": "#003920",
    "primary_container": "#205135",
    "on_primary_container": "#b9f2cd",
    "outline_variant": "#414942",
}


def themed_icon_path(colors):
    cache_home = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
    icon_path = cache_home / "sownteeshell" / "sownteeshell-connect-themed.svg"
    icon_path.parent.mkdir(parents=True, exist_ok=True)
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <rect x="8" y="8" width="108" height="108" rx="30" fill="{colors["primary_container"]}"/>
  <rect x="9" y="9" width="106" height="106" rx="29" fill="none" stroke="{colors["outline_variant"]}" stroke-width="2"/>
  <g transform="translate(-4 -6) rotate(-40 64 64)" fill="none" stroke="{colors["on_primary_container"]}" stroke-width="10" stroke-linecap="round">
    <rect x="27" y="46" width="48" height="36" rx="18"/>
    <rect x="53" y="46" width="48" height="36" rx="18"/>
    <path d="M53 64h22" stroke="{colors["primary_container"]}" stroke-width="18"/>
    <path d="M53 64h22"/>
  </g>
  <circle cx="102" cy="102" r="22" fill="{colors["primary"]}" stroke="{colors["surface_container_lowest"]}" stroke-width="4"/>
  <path d="M110 94 C107 89 97 89 95 94 C91 103 113 99 109 109 C107 114 97 114 94 110" fill="none" stroke="{colors["on_primary"]}" stroke-width="4.5" stroke-linecap="round"/>
</svg>\n'''
    try:
        if not icon_path.exists() or icon_path.read_text() != svg:
            icon_path.write_text(svg)
        return icon_path
    except OSError:
        return ICON_PATH


def configure_application(app):
    app.setApplicationDisplayName(APP_NAME)
    app.setDesktopFileName(APP_ID)
    colors = read_colors(ICON_PATH.parents[1] / "colors.json") or FALLBACK_COLORS
    app.setWindowIcon(QIcon(str(themed_icon_path(colors))))

def read_colors(path):
    try:
        document = json.loads(path.read_text())
        tokens = document.get("md3", {}) if isinstance(document, dict) else {}
        if not isinstance(tokens, dict):
            return None
        colors = dict(FALLBACK_COLORS)
        colors.update({
            name: value for name, value in tokens.items()
            if name in colors and isinstance(value, str) and re.fullmatch(r"#[0-9a-fA-F]{6}", value)
        })
        return colors
    except (OSError, ValueError):
        return None


def shell_font():
    cache_home = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
    try:
        settings = json.loads((cache_home / "sownteeshell/settings.json").read_text())
        family = settings.get("fontName") if isinstance(settings, dict) else None
        if isinstance(family, str) and family.strip():
            return family[:128]
    except (OSError, ValueError):
        pass
    return "Inter Variable"


def text_label(text, name, parent=None):
    label = QLabel(text, parent)
    label.setObjectName(name)
    label.setTextFormat(Qt.TextFormat.PlainText)
    label.setWordWrap(True)
    label.setSizePolicy(QSizePolicy.Policy.Preferred, QSizePolicy.Policy.Maximum)
    return label


class AccountWindow(QMainWindow):
    closing = Signal()

    def __init__(self, provider, view, theme_path=None):
        super().__init__()
        self.theme_path = theme_path or Path(__file__).resolve().parents[3] / "colors.json"
        self.colors = dict(FALLBACK_COLORS)
        self.view = view
        self.setWindowTitle(APP_NAME + " - " + provider)
        self.setWindowIcon(QIcon(str(themed_icon_path(self.colors))))
        self.setObjectName("accountWindow")
        self.setFont(QFont(shell_font(), 11))
        self.resize(1040, 800)
        self.setMinimumSize(420, 520)

        container = QWidget()
        container.setObjectName("accountSurface")
        layout = QVBoxLayout(container)
        layout.setContentsMargins(24, 20, 24, 20)
        layout.setSpacing(16)
        header = QHBoxLayout()
        header.setSpacing(16)
        badge = text_label("", "brandBadge")
        self.brand_badge = badge
        badge.setPixmap(self.windowIcon().pixmap(48, 48))
        badge.setAccessibleName(APP_NAME)
        badge.setAlignment(Qt.AlignmentFlag.AlignCenter)
        badge.setFixedSize(48, 48)
        header.addWidget(badge, 0, Qt.AlignmentFlag.AlignTop)
        heading = QVBoxLayout()
        heading.setSpacing(4)
        heading.addWidget(text_label("SOWNTEESHELL CONNECT", "eyebrow"))
        heading.addWidget(text_label("Connect " + provider, "title"))
        header.addLayout(heading, 1)
        layout.addLayout(header)
        layout.addWidget(text_label(
            "Sign in on the official website. Complete any security checks yourself.", "intro"
        ))

        browser = QFrame()
        browser.setObjectName("browserFrame")
        browser_layout = QVBoxLayout(browser)
        browser_layout.setContentsMargins(1, 1, 1, 1)
        browser_layout.setSpacing(0)
        address = QWidget()
        address.setObjectName("addressBar")
        address_layout = QHBoxLayout(address)
        address_layout.setContentsMargins(14, 10, 14, 10)
        address_layout.setSpacing(12)
        self.host = text_label("Loading official website...", "host")
        self.host.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
        address_layout.addWidget(self.host, 1)
        self.reload = QPushButton("Reload")
        self.reload.setObjectName("reloadButton")
        self.reload.setCursor(Qt.CursorShape.PointingHandCursor)
        self.reload.setAccessibleName("Reload website")
        self.reload.clicked.connect(view.reload)
        address_layout.addWidget(self.reload)
        browser_layout.addWidget(address)
        self.progress = QProgressBar()
        self.progress.setTextVisible(False)
        self.progress.setFixedHeight(3)
        browser_layout.addWidget(self.progress)
        view.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        browser_layout.addWidget(view, 1)
        layout.addWidget(browser, 1)

        footer = QFrame()
        footer.setObjectName("accountFooter")
        self.footer_layout = QGridLayout(footer)
        self.footer_layout.setContentsMargins(16, 12, 16, 12)
        self.footer_layout.setHorizontalSpacing(20)
        self.footer_layout.setVerticalSpacing(12)
        self.footer_layout.setColumnStretch(0, 1)
        self.footer_info = QWidget()
        information = QVBoxLayout(self.footer_info)
        information.setContentsMargins(0, 0, 0, 0)
        information.setSpacing(4)
        self.status = text_label(
            "Sign in, then select Check sign-in to continue.", "status"
        )
        self.status.setMinimumWidth(0)
        information.addWidget(self.status)
        information.addWidget(text_label(
            "Private session, separate from your browser.", "privacy"
        ))
        self.footer_actions = QWidget()
        actions = QHBoxLayout(self.footer_actions)
        actions.setContentsMargins(0, 0, 0, 0)
        actions.setSpacing(8)
        self.cancel = QPushButton("Cancel")
        self.cancel.setObjectName("cancelButton")
        self.cancel.clicked.connect(self.close)
        self.confirm = QPushButton("Check sign-in")
        self.confirm.setObjectName("primaryButton")
        self.confirm.setEnabled(False)
        for button in (self.cancel, self.confirm):
            button.setMinimumHeight(44)
            button.setCursor(Qt.CursorShape.PointingHandCursor)
        self.cancel.setMinimumWidth(104)
        self.confirm.setMinimumWidth(154)
        actions.addWidget(self.cancel)
        actions.addWidget(self.confirm)
        self.footer_stacked = None
        self.layout_footer()
        layout.addWidget(footer)
        self.setCentralWidget(container)

        view.urlChanged.connect(self.update_address)
        view.loadStarted.connect(lambda: self.progress.setValue(0))
        view.loadProgress.connect(self.progress.setValue)
        view.loadFinished.connect(lambda success: self.progress.setValue(100 if success else 0))
        self.theme_timer = QTimer(self)
        self.theme_timer.setSingleShot(True)
        self.theme_timer.setInterval(120)
        self.theme_timer.timeout.connect(self.reload_theme)
        self.theme_watcher = QFileSystemWatcher(self)
        self.theme_watcher.directoryChanged.connect(lambda _: self.theme_timer.start())
        self.theme_watcher.fileChanged.connect(lambda _: self.theme_timer.start())
        self.reload_theme()

    def layout_footer(self):
        stacked = self.width() < 760
        if stacked == self.footer_stacked:
            return
        self.footer_stacked = stacked
        self.footer_layout.removeWidget(self.footer_info)
        self.footer_layout.removeWidget(self.footer_actions)
        self.footer_layout.addWidget(self.footer_info, 0, 0, 1, 2 if stacked else 1)
        self.footer_layout.addWidget(
            self.footer_actions, 1 if stacked else 0, 0 if stacked else 1,
            1, 2 if stacked else 1, Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter,
        )

    def resizeEvent(self, event):
        super().resizeEvent(event)
        if hasattr(self, "footer_layout"):
            self.layout_footer()

    def update_address(self, url):
        self.host.setText(url.scheme() + "://" + url.host() if url.host() else "Loading official website...")

    def reload_theme(self):
        colors = read_colors(self.theme_path)
        if colors is not None:
            self.colors = colors
        self.setWindowIcon(QIcon(str(themed_icon_path(self.colors))))
        self.brand_badge.setPixmap(self.windowIcon().pixmap(48, 48))
        for path in (self.theme_path.parent, self.theme_path):
            if path.exists() and str(path) not in self.theme_watcher.files() + self.theme_watcher.directories():
                self.theme_watcher.addPath(str(path))
        colors = self.colors
        self.setStyleSheet(f"""
            QMainWindow#accountWindow, QWidget#accountSurface {{ background: {colors['surface']}; }}
            QLabel {{ color: {colors['on_surface']}; background: transparent; }}
            QLabel#eyebrow, QLabel#privacy {{ color: {colors['on_surface_variant']}; font-size: 9pt; }}
            QLabel#title {{ font-size: 20pt; font-weight: 600; }}
            QLabel#intro, QLabel#host {{ color: {colors['on_surface_variant']}; }}
            QFrame#accountFooter {{ background: {colors['surface_container']}; border-radius: 20px; }}
            QLabel#status {{ font-size: 11pt; font-weight: 600; }}
            QLabel#brandBadge {{ background: {colors['primary_container']}; color: {colors['on_primary_container']}; border-radius: 16px; font-size: 22pt; font-weight: 600; }}
            QFrame#browserFrame {{ border: 1px solid {colors['outline_variant']}; border-radius: 12px; }}
            QWidget#addressBar {{ background: {colors['surface_container']}; border-top-left-radius: 11px; border-top-right-radius: 11px; }}
            QPushButton {{ background: {colors['surface_container_high']}; color: {colors['on_surface']}; border: 2px solid transparent; border-radius: 22px; padding: 0 20px; font-weight: 600; }}
            QPushButton:hover {{ background: {colors['primary_container']}; color: {colors['on_primary_container']}; }}
            QPushButton:pressed {{ background: {colors['outline_variant']}; }}
            QPushButton:focus {{ border-color: {colors['primary']}; }}
            QPushButton#cancelButton {{ background: transparent; color: {colors['on_surface_variant']}; }}
            QPushButton#cancelButton:hover, QPushButton#cancelButton:pressed {{ background: {colors['surface_container_high']}; color: {colors['on_surface']}; }}
            QPushButton#primaryButton {{ background: {colors['primary']}; color: {colors['on_primary']}; }}
            QPushButton#primaryButton:hover, QPushButton#primaryButton:pressed {{ background: {colors['primary_container']}; color: {colors['on_primary_container']}; }}
            QPushButton#primaryButton:focus {{ border-color: {colors['on_primary']}; }}
            QPushButton#primaryButton:disabled {{ background: {colors['surface_container_high']}; color: {colors['on_surface_variant']}; }}
            QPushButton#reloadButton {{ min-height: 32px; border-radius: 16px; padding: 0 12px; }}
            QProgressBar {{ background: {colors['surface_container']}; border: none; }}
            QProgressBar::chunk {{ background: {colors['primary']}; }}
        """)
        self.view.page().setBackgroundColor(QColor(colors["surface"]))

    def closeEvent(self, event):
        self.closing.emit()
        event.accept()
