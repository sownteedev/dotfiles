use super::SettingsPaths;
use super::parser::*;
use anyhow::{Context, Result};
use serde_json::{Map, Value, json};
use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

const ANIMATION_NAMES: &[&str] = &[
    "workspace-switch",
    "window-open",
    "window-close",
    "horizontal-view-movement",
    "window-movement",
    "window-resize",
    "config-notification-open-close",
    "exit-confirmation-open-close",
    "screenshot-ui-open",
    "overview-open-close",
    "recent-windows-close",
];

const EDITABLE_NIRI_FILES: &[&str] = &[
    "autostart.kdl",
    "environment.kdl",
    "layer-rules.kdl",
    "window-rules.kdl",
    "workspaces.kdl",
];

pub fn build(paths: &SettingsPaths) -> Result<Value> {
    let layout_source = read(&paths.include_dir.join("layout.kdl"))?;
    let input_source = read(&paths.include_dir.join("input.kdl"))?;
    let animation_source = read(&paths.include_dir.join("animations.kdl"))?;
    let behavior_source = read(&paths.include_dir.join("behavior.kdl"))?;
    let cursor_source = read(&paths.include_dir.join("cursor.kdl"))?;
    let switch_events_source = read(&paths.include_dir.join("switch-events.kdl"))?;
    let config_source = read(&paths.config_qml)?;

    let border_block = find_block(&layout_source, "border");
    let focus_ring_block = find_block(&layout_source, "focus-ring");
    let shadow_block = find_block(&layout_source, "shadow");
    let shadow_offset = block_offset(&shadow_block);
    let tab_indicator_block = find_block(&layout_source, "tab-indicator");
    let insert_hint_block = find_block(&layout_source, "insert-hint");
    let default_width_block = find_block(&layout_source, "default-column-width");
    let preset_widths_block = find_any_block(&layout_source, "preset-column-widths");
    let preset_heights_block = find_any_block(&layout_source, "preset-window-heights");
    let struts_block = find_any_block(&layout_source, "struts");
    let overview_block = find_block(&layout_source, "overview");
    let workspace_shadow_block = find_block(&overview_block, "workspace-shadow");
    let workspace_shadow_offset = block_offset(&workspace_shadow_block);
    let blur_block = find_any_block(&layout_source, "blur");
    let recent_windows_block = find_any_block(&layout_source, "recent-windows");
    let recent_highlight_block = find_any_block(&recent_windows_block, "highlight");
    let recent_previews_block = find_any_block(&recent_windows_block, "previews");
    let recent_binds_block = find_any_block(&recent_windows_block, "binds");

    let gaps = number_capture(&layout_source, r"(?m)^\s*gaps\s+([\d.]+)", 0.0);
    let border_width = number_capture(&border_block, r"(?m)^\s*width\s+([\d.]+)", 0.0);
    let center = capture(
        &layout_source,
        r#"(?m)^\s*center-focused-column\s+"([^"]+)""#,
        1,
    )
    .unwrap_or_else(|| "never".into());
    let default_display = capture(
        &layout_source,
        r#"(?m)^\s*default-column-display\s+"([^"]+)""#,
        1,
    )
    .unwrap_or_else(|| "normal".into());
    let default_width_proportion =
        number_optional(&default_width_block, r"(?m)^\s*proportion\s+([\d.]+)");
    let default_width_fixed = number_optional(&default_width_block, r"(?m)^\s*fixed\s+([\d.]+)");
    let overview_zoom = number_capture(&overview_block, r"(?m)^\s*zoom\s+([\d.]+)", 0.4);

    let border_active_gradient = block_raw_setting(
        &border_block,
        "active-gradient",
        r##"from="#80c8ff" to="#c7ff7f" angle=45"##,
    );
    let border_inactive_gradient = block_raw_setting(
        &border_block,
        "inactive-gradient",
        r##"from="#505050" to="#808080" angle=45"##,
    );
    let border_urgent_gradient = block_raw_setting(
        &border_block,
        "urgent-gradient",
        r##"from="#800" to="#a33" angle=45"##,
    );
    let focus_active_gradient = block_raw_setting(
        &focus_ring_block,
        "active-gradient",
        r##"from="#80c8ff" to="#bbddff" angle=45"##,
    );
    let focus_inactive_gradient = block_raw_setting(
        &focus_ring_block,
        "inactive-gradient",
        r##"from="#505050" to="#808080" angle=45"##,
    );
    let focus_urgent_gradient = block_raw_setting(
        &focus_ring_block,
        "urgent-gradient",
        r##"from="#800" to="#a33" angle=45"##,
    );
    let tab_active_gradient = block_raw_setting(
        &tab_indicator_block,
        "active-gradient",
        r##"from="#80c8ff" to="#bbddff" angle=45"##,
    );
    let tab_inactive_gradient = block_raw_setting(
        &tab_indicator_block,
        "inactive-gradient",
        r##"from="#505050" to="#808080" angle=45"##,
    );
    let tab_urgent_gradient = block_raw_setting(
        &tab_indicator_block,
        "urgent-gradient",
        r##"from="#800" to="#a33" angle=45"##,
    );
    let insert_gradient = block_raw_setting(
        &insert_hint_block,
        "gradient",
        r##"from="#ffbb6680" to="#ffc88080" angle=45"##,
    );

    let default_width_mode = if default_width_fixed.is_some() {
        "fixed"
    } else if default_width_proportion.is_some() {
        "proportion"
    } else {
        "auto"
    };
    let default_width = default_width_fixed
        .or(default_width_proportion)
        .unwrap_or(1.0);

    let layout = json!({
        "gaps": gaps,
        "borderWidth": border_width,
        "shadow": explicit_state_enabled(&shadow_block, false),
        "centerFocused": center,
        "alwaysCenterSingle": regex(r"(?m)^\s*always-center-single-column\s*$").is_match(&layout_source),
        "emptyWorkspaceAboveFirst": flag_enabled(&layout_source, "empty-workspace-above-first"),
        "defaultColumnDisplay": default_display,
        "backgroundColor": block_string(&find_block(&layout_source, "layout"), "background-color", "transparent"),
        "defaultColumnWidthMode": default_width_mode,
        "defaultColumnWidth": default_width,
        "presetColumnWidthsEnabled": block_enabled(&layout_source, "preset-column-widths"),
        "presetColumnWidths": fallback_string(dimension_entries(&preset_widths_block), "proportion 0.33333, proportion 0.5, proportion 0.66667"),
        "presetWindowHeightsEnabled": block_enabled(&layout_source, "preset-window-heights"),
        "presetWindowHeights": fallback_string(dimension_entries(&preset_heights_block), "proportion 0.33333, proportion 0.5, proportion 0.66667"),
        "strutsEnabled": block_enabled(&layout_source, "struts"),
        "strutLeft": block_number_any(&struts_block, "left", 0.0),
        "strutRight": block_number_any(&struts_block, "right", 0.0),
        "strutTop": block_number_any(&struts_block, "top", 0.0),
        "strutBottom": block_number_any(&struts_block, "bottom", 0.0),
        "overviewZoom": overview_zoom,
        "overviewBackdropColor": block_string(&overview_block, "backdrop-color", "#0a0a0a"),
        "workspaceShadowEnabled": explicit_state_enabled(&workspace_shadow_block, true),
        "workspaceShadowSoftness": block_number(&workspace_shadow_block, "softness", 30.0),
        "workspaceShadowSpread": block_number(&workspace_shadow_block, "spread", 5.0),
        "workspaceShadowOffsetX": workspace_shadow_offset.0,
        "workspaceShadowOffsetY": workspace_shadow_offset.1,
        "workspaceShadowColor": block_string(&workspace_shadow_block, "color", "#000000"),
        "borderEnabled": explicit_state_enabled(&border_block, false),
        "borderActiveColor": block_string(&border_block, "active-color", "#222222"),
        "borderInactiveColor": block_string(&border_block, "inactive-color", "#222222"),
        "borderUrgentColor": block_string(&border_block, "urgent-color", "#9b0000"),
        "borderGradientEnabled": border_active_gradient.0 || border_inactive_gradient.0 || border_urgent_gradient.0,
        "borderActiveGradient": border_active_gradient.1,
        "borderInactiveGradient": border_inactive_gradient.1,
        "borderUrgentGradient": border_urgent_gradient.1,
        "focusRingEnabled": explicit_state_enabled(&focus_ring_block, true),
        "focusRingWidth": block_number_any(&focus_ring_block, "width", 4.0),
        "focusRingActiveColor": block_string(&focus_ring_block, "active-color", "#7fc8ff"),
        "focusRingInactiveColor": block_string(&focus_ring_block, "inactive-color", "#505050"),
        "focusRingUrgentColor": block_string(&focus_ring_block, "urgent-color", "#9b0000"),
        "focusRingGradientEnabled": focus_active_gradient.0 || focus_inactive_gradient.0 || focus_urgent_gradient.0,
        "focusRingActiveGradient": focus_active_gradient.1,
        "focusRingInactiveGradient": focus_inactive_gradient.1,
        "focusRingUrgentGradient": focus_urgent_gradient.1,
        "tabIndicatorEnabled": explicit_state_enabled(&tab_indicator_block, true),
        "tabHideSingle": flag_enabled(&tab_indicator_block, "hide-when-single-tab"),
        "tabPlaceWithinColumn": flag_enabled(&tab_indicator_block, "place-within-column"),
        "tabGap": block_number_any(&tab_indicator_block, "gap", 5.0),
        "tabWidth": block_number_any(&tab_indicator_block, "width", 4.0),
        "tabLength": block_attribute_number(&tab_indicator_block, "length", "total-proportion", 1.0),
        "tabPosition": block_string(&tab_indicator_block, "position", "right"),
        "tabGapsBetween": block_number_any(&tab_indicator_block, "gaps-between-tabs", 2.0),
        "tabCornerRadius": block_number_any(&tab_indicator_block, "corner-radius", 8.0),
        "tabActiveColor": block_string(&tab_indicator_block, "active-color", "#7fc8ff"),
        "tabInactiveColor": block_string(&tab_indicator_block, "inactive-color", "#505050"),
        "tabUrgentColor": block_string(&tab_indicator_block, "urgent-color", "#9b0000"),
        "tabGradientEnabled": tab_active_gradient.0 || tab_inactive_gradient.0 || tab_urgent_gradient.0,
        "tabActiveGradient": tab_active_gradient.1,
        "tabInactiveGradient": tab_inactive_gradient.1,
        "tabUrgentGradient": tab_urgent_gradient.1,
        "insertHintEnabled": explicit_state_enabled(&insert_hint_block, true),
        "insertHintColor": block_string(&insert_hint_block, "color", "#7fc8ff80"),
        "insertHintGradientEnabled": insert_gradient.0,
        "insertHintGradient": insert_gradient.1,
        "shadowSoftness": block_number_any(&shadow_block, "softness", 20.0),
        "shadowSpread": block_number_any(&shadow_block, "spread", 5.0),
        "shadowOffsetX": shadow_offset.0,
        "shadowOffsetY": shadow_offset.1,
        "shadowDrawBehind": block_bool(&shadow_block, "draw-behind-window", true),
        "shadowColor": block_string(&shadow_block, "color", "#000000"),
        "shadowInactiveColor": block_string(&shadow_block, "inactive-color", "#00000054"),
        "blurEnabled": !(block_enabled(&layout_source, "blur") && flag_enabled(&blur_block, "off")),
        "blurPasses": block_number(&blur_block, "passes", 3.0) as i64,
        "blurOffset": block_number(&blur_block, "offset", 3.0),
        "blurNoise": block_number(&blur_block, "noise", 0.02),
        "blurSaturation": block_number(&blur_block, "saturation", 1.5),
        "recentWindows": !(block_enabled(&layout_source, "recent-windows") && flag_enabled(&recent_windows_block, "off")),
        "recentDebounceMs": block_number(&recent_windows_block, "debounce-ms", 750.0) as i64,
        "recentOpenDelayMs": block_number(&recent_windows_block, "open-delay-ms", 150.0) as i64,
        "recentHighlightActiveColor": block_string(&recent_highlight_block, "active-color", "#999999ff"),
        "recentHighlightUrgentColor": block_string(&recent_highlight_block, "urgent-color", "#ff9999ff"),
        "recentHighlightPadding": block_number(&recent_highlight_block, "padding", 30.0) as i64,
        "recentHighlightCornerRadius": block_number(&recent_highlight_block, "corner-radius", 0.0) as i64,
        "recentPreviewHeight": block_number(&recent_previews_block, "max-height", 480.0) as i64,
        "recentPreviewScale": block_number(&recent_previews_block, "max-scale", 0.5),
        "recentBinds": parse_recent_binds(&recent_binds_block),
    });

    let mut files = Map::new();
    for name in EDITABLE_NIRI_FILES {
        files.insert(
            (*name).into(),
            Value::String(read(&paths.include_dir.join(name))?),
        );
    }

    Ok(json!({
        "niri": {
            "keybindGroups": parse_binds(&read(&paths.include_dir.join("keybinds.kdl"))?),
            "layout": layout,
            "input": {
                "Keyboard": input_lines(&find_block(&input_source, "keyboard")),
                "Touchpad": input_lines(&find_block(&input_source, "touchpad")),
                "Mouse": input_lines(&find_block(&input_source, "mouse")),
                "Trackpoint": input_lines(&find_block(&input_source, "trackpoint")),
                "Trackball": input_lines(&find_block(&input_source, "trackball")),
                "Tablet": input_lines(&find_block(&input_source, "tablet")),
                "Touch": input_lines(&find_block(&input_source, "touch")),
            },
            "inputEnabled": {
                "Touchpad": !flag_enabled(&find_block(&input_source, "touchpad"), "off"),
                "Mouse": !flag_enabled(&find_block(&input_source, "mouse"), "off"),
                "Trackpoint": !flag_enabled(&find_block(&input_source, "trackpoint"), "off"),
                "Trackball": !flag_enabled(&find_block(&input_source, "trackball"), "off"),
                "Tablet": !flag_enabled(&find_block(&input_source, "tablet"), "off"),
                "Touch": !flag_enabled(&find_block(&input_source, "touch"), "off"),
            },
            "animations": animation_snapshot(&animation_source),
            "behavior": behavior_snapshot(&behavior_source, &cursor_source, &input_source, &switch_events_source),
            "files": Value::Object(files),
        },
        "gtk": gtk_snapshot(),
        "quickshell": quickshell_snapshot(paths, &config_source),
    }))
}

fn gtk_snapshot() -> Value {
    let gtk_fb = gtk_defaults();
    let qt_fb = qt_defaults();
    let fb_str = |map: &Map<String, Value>, key: &str, default: &str| {
        map.get(key)
            .and_then(Value::as_str)
            .unwrap_or(default)
            .to_string()
    };
    let fb_i64 = |map: &Map<String, Value>, key: &str, default: i64| {
        map.get(key).and_then(Value::as_i64).unwrap_or(default)
    };

    let gtk_theme = gsettings_string("gtk-theme", &fb_str(&gtk_fb, "gtkTheme", "adw-gtk3-dark"));
    let icon_theme = gsettings_string("icon-theme", &fb_str(&gtk_fb, "iconTheme", "WhiteSur"));
    let cursor_theme = gsettings_string("cursor-theme", &fb_str(&gtk_fb, "cursorTheme", "Dark_Cursor"));
    let cursor_size = gsettings_int("cursor-size", fb_i64(&gtk_fb, "cursorSize", 24));
    let font_name = gsettings_string("font-name", &fb_str(&gtk_fb, "fontName", "SF Pro Text 10.5"));
    let (qt_style, qt_color_scheme, qt_dialogs) = qt_snapshot(
        &fb_str(&qt_fb, "qtStyle", "kvantum"),
        &fb_str(&qt_fb, "qtColorScheme", "matugen"),
        &fb_str(&qt_fb, "qtDialogs", "gtk3"),
    );

    json!({
        "gtkTheme": gtk_theme,
        "iconTheme": icon_theme,
        "cursorTheme": cursor_theme,
        "cursorSize": cursor_size,
        "fontName": font_name,
        "qtStyle": qt_style,
        "qtColorScheme": qt_color_scheme,
        "qtDialogs": qt_dialogs,
        "gtkThemes": installed_gtk_themes(&gtk_theme),
        "iconThemes": installed_icon_themes(&icon_theme),
        "cursorThemes": installed_cursor_themes(&cursor_theme),
        "qtStyles": installed_qt_styles(&qt_style),
        "qtColorSchemes": installed_qt_color_schemes(&qt_color_scheme),
        "qtDialogOptions": installed_qt_dialogs(),
    })
}

fn gsettings_string(key: &str, fallback: &str) -> String {
    let Ok(output) = Command::new("gsettings")
        .args(["get", "org.gnome.desktop.interface", key])
        .output()
    else {
        return fallback.into();
    };
    if !output.status.success() {
        return fallback.into();
    }

    let value = decode_gvariant_string(&String::from_utf8_lossy(&output.stdout));
    if value.is_empty() {
        fallback.into()
    } else {
        value
    }
}

fn gsettings_int(key: &str, fallback: i64) -> i64 {
    let Ok(output) = Command::new("gsettings")
        .args(["get", "org.gnome.desktop.interface", key])
        .output()
    else {
        return fallback;
    };
    if !output.status.success() {
        return fallback;
    }

    let text = String::from_utf8_lossy(&output.stdout);
    text.trim().parse::<i64>().unwrap_or(fallback)
}

fn decode_gvariant_string(raw: &str) -> String {
    let value = raw.trim();
    if value.len() < 2 || !value.starts_with('\'') || !value.ends_with('\'') {
        return value.to_string();
    }

    let mut decoded = String::new();
    let mut escaped = false;
    for character in value[1..value.len() - 1].chars() {
        if escaped {
            decoded.push(character);
            escaped = false;
        } else if character == '\\' {
            escaped = true;
        } else {
            decoded.push(character);
        }
    }
    if escaped {
        decoded.push('\\');
    }
    decoded
}

fn data_roots(subdirectory: &str, legacy_home_directory: &str) -> Vec<PathBuf> {
    let mut roots = Vec::new();
    if let Some(home) = env::var_os("HOME").map(PathBuf::from) {
        roots.push(home.join(legacy_home_directory));
        roots.push(
            env::var_os("XDG_DATA_HOME")
                .map(PathBuf::from)
                .unwrap_or_else(|| home.join(".local/share"))
                .join(subdirectory),
        );
    } else if let Some(data_home) = env::var_os("XDG_DATA_HOME") {
        roots.push(PathBuf::from(data_home).join(subdirectory));
    }
    let data_dirs =
        env::var("XDG_DATA_DIRS").unwrap_or_else(|_| "/usr/local/share:/usr/share".into());
    roots.extend(
        data_dirs
            .split(':')
            .filter(|directory| !directory.is_empty())
            .map(|directory| PathBuf::from(directory).join(subdirectory)),
    );
    roots
}

fn installed_names<F>(roots: Vec<PathBuf>, current: &str, is_valid: F) -> Vec<String>
where
    F: Fn(&Path, &str) -> bool,
{
    let mut names = Vec::new();
    for root in roots {
        let Ok(entries) = fs::read_dir(root) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if !path.is_dir() {
                continue;
            }
            let Some(name) = entry.file_name().to_str().map(str::to_string) else {
                continue;
            };
            if !name.starts_with('.') && is_valid(&path, &name) {
                names.push(name);
            }
        }
    }
    if !current.is_empty() {
        names.push(current.into());
    }
    names.sort_by_key(|name| name.to_lowercase());
    names.dedup();
    names
}

fn installed_gtk_themes(current: &str) -> Vec<String> {
    installed_names(data_roots("themes", ".themes"), current, |path, _name| {
        path.join("gtk-3.0/gtk.css").is_file()
            || path.join("gtk-4.0/gtk.css").is_file()
            || path.join("gtk-2.0/gtkrc").is_file()
    })
}

fn is_excluded_icon_or_cursor_theme(name: &str) -> bool {
    let lower = name.to_ascii_lowercase();
    lower == "default" || lower == "hicolor" || lower == "locolor"
}

fn has_icon_directories(path: &Path) -> bool {
    let index_path = path.join("index.theme");
    let Ok(content) = fs::read_to_string(&index_path) else {
        return false;
    };
    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("Directories=")
            || trimmed.starts_with("Directories =")
            || trimmed.starts_with("ScaledDirectories=")
            || trimmed.starts_with("ScaledDirectories =")
        {
            return true;
        }
    }
    false
}

fn installed_icon_themes(current: &str) -> Vec<String> {
    let current_clean = if is_excluded_icon_or_cursor_theme(current) {
        ""
    } else {
        current
    };
    installed_names(data_roots("icons", ".icons"), current_clean, |path, name| {
        !is_excluded_icon_or_cursor_theme(name) && has_icon_directories(path)
    })
}

fn installed_cursor_themes(current: &str) -> Vec<String> {
    let current_clean = if is_excluded_icon_or_cursor_theme(current) {
        ""
    } else {
        current
    };
    installed_names(data_roots("icons", ".icons"), current_clean, |path, name| {
        !is_excluded_icon_or_cursor_theme(name) && path.join("cursors").is_dir()
    })
}

fn qt_snapshot(
    default_style: &str,
    default_color: &str,
    default_dialogs: &str,
) -> (String, String, String) {
    let config_dir = env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".config")));
    let Some(config_dir) = config_dir else {
        return (default_style.into(), default_color.into(), default_dialogs.into());
    };

    let conf_path = config_dir.join("qt6ct/qt6ct.conf");
    let target = if conf_path.is_file() {
        conf_path
    } else {
        config_dir.join("qt5ct/qt5ct.conf")
    };

    let Ok(content) = fs::read_to_string(&target) else {
        return (default_style.into(), default_color.into(), default_dialogs.into());
    };

    let mut style = default_style.to_string();
    let mut color_scheme = default_color.to_string();
    let mut dialogs = default_dialogs.to_string();
    let mut custom_palette = true;

    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("style=") || trimmed.starts_with("style =") {
            if let Some(val) = trimmed.split('=').nth(1) {
                let v = val.trim();
                if !v.is_empty() {
                    style = v.to_string();
                }
            }
        } else if trimmed.starts_with("custom_palette=") || trimmed.starts_with("custom_palette =") {
            if let Some(val) = trimmed.split('=').nth(1) {
                custom_palette = val.trim().eq_ignore_ascii_case("true") || val.trim() == "1";
            }
        } else if trimmed.starts_with("color_scheme_path=") || trimmed.starts_with("color_scheme_path =") {
            if let Some(val) = trimmed.split('=').nth(1) {
                let v = val.trim();
                if !v.is_empty() {
                    if v.contains("style-colors") {
                        color_scheme = "style".to_string();
                    } else {
                        let path = Path::new(v);
                        if let Some(stem) = path.file_stem().and_then(|s| s.to_str()) {
                            color_scheme = stem.to_string();
                        }
                    }
                }
            }
        } else if trimmed.starts_with("standard_dialogs=") || trimmed.starts_with("standard_dialogs =") {
            if let Some(val) = trimmed.split('=').nth(1) {
                let v = val.trim();
                if !v.is_empty() {
                    dialogs = v.to_string();
                }
            }
        }
    }

    if !custom_palette {
        color_scheme = "system".to_string();
    }

    (style, color_scheme, dialogs)
}

fn installed_qt_styles(current: &str) -> Vec<String> {
    let mut styles = Vec::new();
    let mut found_kvantum = false;
    for dir in &["/usr/lib/qt6/plugins/styles", "/usr/lib/qt/plugins/styles"] {
        let Ok(entries) = fs::read_dir(dir) else { continue };
        for entry in entries.flatten() {
            let Some(name) = entry.file_name().to_str().map(str::to_string) else { continue };
            if name == "libkvantum.so" {
                found_kvantum = true;
            } else if name.ends_with(".so") && !name.ends_with("-style.so") {
                let mut base = name.trim_end_matches(".so");
                if base.starts_with("lib") {
                    base = &base[3..];
                }
                styles.push(base.to_string());
            }
        }
    }
    if found_kvantum {
        styles.push("kvantum-dark".to_string());
        styles.push("kvantum".to_string());
    }
    styles.push("Windows".to_string());
    styles.push("Fusion".to_string());
    if !current.is_empty() {
        styles.push(current.to_string());
    }

    let mut ordered = Vec::new();
    for preferred in ["kvantum-dark", "kvantum", "Windows", "Fusion"] {
        if styles.iter().any(|s| s.eq_ignore_ascii_case(preferred)) && !ordered.iter().any(|s: &String| s.eq_ignore_ascii_case(preferred)) {
            ordered.push(preferred.to_string());
        }
    }
    for s in styles {
        if !ordered.iter().any(|o: &String| o.eq_ignore_ascii_case(&s)) {
            ordered.push(s);
        }
    }
    ordered
}

fn installed_qt_dialogs() -> Vec<Value> {
    let mut options = vec![json!({"label": "Default", "value": "default"})];
    let has_gtk3 = Path::new("/usr/lib/qt6/plugins/platformthemes/libqgtk3.so").is_file()
        || Path::new("/usr/lib/qt/plugins/platformthemes/libqgtk3.so").is_file();
    let has_portal = Path::new("/usr/lib/qt6/plugins/platformthemes/libqxdgdesktopportal.so").is_file()
        || Path::new("/usr/lib/qt/plugins/platformthemes/libqxdgdesktopportal.so").is_file();
    let has_kde = Path::new("/usr/lib/qt6/plugins/platformthemes/KDEPlatformTheme6.so").is_file()
        || Path::new("/usr/lib/qt6/plugins/platformthemes/libkded.so").is_file();
    let has_gtk2 = Path::new("/usr/lib/qt6/plugins/platformthemes/libqgtk2.so").is_file()
        || Path::new("/usr/lib/qt/plugins/platformthemes/libqgtk2.so").is_file();

    if has_gtk3 {
        options.push(json!({"label": "GTK3", "value": "gtk3"}));
    } else if has_gtk2 {
        options.push(json!({"label": "GTK2", "value": "gtk2"}));
    }
    if has_kde {
        options.push(json!({"label": "KDE", "value": "kde"}));
    }
    if has_portal {
        options.push(json!({"label": "XDG Desktop Portal", "value": "xdgdesktopportal"}));
    }
    options
}

fn installed_qt_color_schemes(current: &str) -> Vec<Value> {
    let mut schemes = Vec::new();
    schemes.push(json!({"label": "Default", "value": "system"}));
    schemes.push(json!({"label": "Style's colors", "value": "style"}));

    let home = env::var_os("HOME").map(PathBuf::from);
    let mut conf_dirs = vec![
        PathBuf::from("/usr/share/qt6ct/colors"),
        PathBuf::from("/usr/share/qt5ct/colors"),
    ];
    if let Some(h) = &home {
        conf_dirs.insert(0, h.join(".config/qt5ct/colors"));
        conf_dirs.insert(0, h.join(".config/qt6ct/colors"));
    }

    let mut conf_stems = Vec::new();
    for dir in conf_dirs {
        let Ok(entries) = fs::read_dir(dir) else { continue };
        for entry in entries.flatten() {
            let Some(name) = entry.file_name().to_str().map(str::to_string) else { continue };
            if name.ends_with(".conf") {
                let stem = name.trim_end_matches(".conf").to_string();
                if !conf_stems.contains(&stem) {
                    conf_stems.push(stem);
                }
            }
        }
    }
    if conf_stems.contains(&"matugen".to_string()) {
        schemes.push(json!({"label": "matugen", "value": "matugen"}));
    }
    conf_stems.sort_by_key(|s| s.to_lowercase());
    for stem in conf_stems {
        if stem != "matugen" {
            schemes.push(json!({"label": stem, "value": stem}));
        }
    }

    let mut kcolor_dirs = vec![PathBuf::from("/usr/share/color-schemes")];
    if let Some(h) = &home {
        kcolor_dirs.insert(0, h.join(".local/share/color-schemes"));
    }
    let mut kcolors = Vec::new();
    for dir in kcolor_dirs {
        let Ok(entries) = fs::read_dir(dir) else { continue };
        for entry in entries.flatten() {
            let path = entry.path();
            let Some(file_name) = entry.file_name().to_str().map(str::to_string) else { continue };
            if file_name.ends_with(".colors") {
                let stem = file_name.trim_end_matches(".colors").to_string();
                if kcolors.iter().any(|(s, _): &(String, String)| s == &stem) {
                    continue;
                }
                let mut display_name = stem.clone();
                if let Ok(content) = fs::read_to_string(&path) {
                    for line in content.lines() {
                        let trimmed = line.trim();
                        if trimmed.starts_with("Name=") {
                            display_name = trimmed[5..].trim().to_string();
                            break;
                        }
                    }
                }
                let full_label = format!("{display_name} (KColorScheme)");
                kcolors.push((stem, full_label));
            }
        }
    }
    kcolors.sort_by_key(|(stem, _)| stem.to_lowercase());
    for (stem, label) in kcolors {
        schemes.push(json!({"label": label, "value": stem}));
    }

    if !current.is_empty()
        && current != "system"
        && current != "style"
        && !schemes.iter().any(|val| val.get("value").and_then(Value::as_str) == Some(current))
    {
        schemes.push(json!({"label": current, "value": current}));
    }

    schemes
}

fn read(path: &Path) -> Result<String> {
    fs::read_to_string(path).with_context(|| format!("read {}", path.display()))
}

fn number_optional(source: &str, pattern: &str) -> Option<f64> {
    capture(source, pattern, 1).and_then(|value| value.parse().ok())
}

fn number_capture(source: &str, pattern: &str, fallback: f64) -> f64 {
    number_optional(source, pattern).unwrap_or(fallback)
}

fn fallback_string(value: String, fallback: &str) -> String {
    if value.is_empty() {
        fallback.into()
    } else {
        value
    }
}

fn animation_snapshot(source: &str) -> Value {
    let slowdown = number_capture(source, r"(?m)^\s*(?://\s*)?slowdown\s+([\d.]+)", 1.0);
    let entries = ANIMATION_NAMES
        .iter()
        .map(|name| {
            let block = find_any_block(source, name);
            let spec = block
                .lines()
                .map(str::trim)
                .find(|line| !line.is_empty() && !line.starts_with("//"))
                .unwrap_or_default()
                .trim_end_matches(';');
            json!({
                "name": name,
                "enabled": block_enabled(source, name),
                "spec": spec,
            })
        })
        .collect::<Vec<_>>();
    json!({
        "enabled": !flag_enabled(source, "off"),
        "slowdown": slowdown,
        "entries": entries,
    })
}

fn behavior_snapshot(
    behavior_source: &str,
    cursor_source: &str,
    input_source: &str,
    switch_events_source: &str,
) -> Value {
    let screenshot_pattern = regex(r#"(?m)^\s*screenshot-path\s+(null|"(?:\\.|[^"])*")"#);
    let screenshot = screenshot_pattern.captures(behavior_source);
    let screenshot_value = screenshot.as_ref().map(|value| &value[1]);
    let screenshot_saving_enabled = screenshot_value.is_some_and(|value| value != "null");
    let screenshot_path = screenshot_value
        .filter(|value| *value != "null")
        .map(|value| {
            serde_json::from_str::<String>(value)
                .unwrap_or_else(|_| value.trim_matches('"').to_string())
        })
        .unwrap_or_default();
    let hotkey_overlay = find_block(behavior_source, "hotkey-overlay");
    let xwayland = find_any_block(behavior_source, "xwayland-satellite");
    let cursor = find_block(cursor_source, "cursor");
    let input_block = find_block(input_source, "input");
    let gestures = find_block(behavior_source, "gestures");
    let dnd_view = find_block(&gestures, "dnd-edge-view-scroll");
    let dnd_workspace = find_block(&gestures, "dnd-edge-workspace-switch");
    let hot_corners = find_block(&gestures, "hot-corners");
    let hot_corners_enabled = !flag_enabled(&hot_corners, "off");
    let mut corner_states = HashMap::from([
        ("top-left", flag_enabled(&hot_corners, "top-left")),
        ("top-right", flag_enabled(&hot_corners, "top-right")),
        ("bottom-left", flag_enabled(&hot_corners, "bottom-left")),
        ("bottom-right", flag_enabled(&hot_corners, "bottom-right")),
    ]);
    if hot_corners_enabled && !corner_states.values().any(|value| *value) {
        corner_states.insert("top-left", true);
    }
    let warp =
        regex(r#"(?m)^\s*warp-mouse-to-focus(?:\s+mode="([^"]+)")?\s*$"#).captures(&input_block);
    let focus_follows =
        regex(r#"(?m)^\s*focus-follows-mouse(?:\s+max-scroll-amount="([^"]+)")?\s*$"#)
            .captures(&input_block);
    let cursor_timeout = capture(
        &cursor,
        r"(?m)^\s*(?://\s*)?hide-after-inactive-ms\s+(\d+)",
        1,
    )
    .and_then(|value| value.parse::<i64>().ok())
    .unwrap_or(1000);
    let cursor_theme =
        capture(&cursor, r#"(?m)^\s*xcursor-theme\s+"([^"]+)""#, 1).unwrap_or_default();
    let cursor_size = capture(&cursor, r"(?m)^\s*xcursor-size\s+(\d+)", 1)
        .and_then(|value| value.parse::<i64>().ok())
        .unwrap_or(24);

    json!({
        "showHotkeyOverlayAtStartup": !flag_enabled(&hotkey_overlay, "skip-at-startup"),
        "preferNoCsd": flag_enabled(behavior_source, "prefer-no-csd"),
        "screenshotSavingEnabled": screenshot_saving_enabled,
        "screenshotPath": screenshot_path,
        "hideUnboundHotkeys": flag_enabled(behavior_source, "hide-not-bound"),
        "disablePrimaryClipboard": block_enabled(behavior_source, "clipboard"),
        "disableConfigError": block_enabled(behavior_source, "config-notification"),
        "xwaylandEnabled": block_enabled(behavior_source, "xwayland-satellite"),
        "xwaylandPath": block_string(&xwayland, "path", "xwayland-satellite"),
        "switchEvents": block_enabled(switch_events_source, "switch-events"),
        "hideCursorWhileTyping": flag_enabled(&cursor, "hide-when-typing"),
        "cursorTimeoutEnabled": regex(r"(?m)^\s*hide-after-inactive-ms\s+\d+").is_match(&cursor),
        "cursorTimeoutMs": cursor_timeout,
        "cursorTheme": cursor_theme,
        "cursorSize": cursor_size,
        "disablePowerKeyHandling": flag_enabled(&input_block, "disable-power-key-handling"),
        "warpMouseToFocus": warp.is_some(),
        "warpMouseMode": warp.as_ref().and_then(|value| value.get(1)).map(|value| value.as_str()).unwrap_or("separate"),
        "focusFollowsMouse": focus_follows.is_some(),
        "focusFollowsMaxScrollAmount": focus_follows.as_ref().and_then(|value| value.get(1)).map(|value| value.as_str()).unwrap_or("0%"),
        "workspaceAutoBackAndForth": flag_enabled(&input_block, "workspace-auto-back-and-forth"),
        "modKey": capture(&input_block, r#"(?m)^\s*mod-key\s+"([^"]+)"\s*$"#, 1).unwrap_or_default(),
        "modKeyNested": capture(&input_block, r#"(?m)^\s*mod-key-nested\s+"([^"]+)"\s*$"#, 1).unwrap_or_default(),
        "dndViewTriggerWidth": block_number(&dnd_view, "trigger-width", 30.0) as i64,
        "dndViewDelayMs": block_number(&dnd_view, "delay-ms", 100.0) as i64,
        "dndViewMaxSpeed": block_number(&dnd_view, "max-speed", 1500.0) as i64,
        "dndWorkspaceTriggerHeight": block_number(&dnd_workspace, "trigger-height", 50.0) as i64,
        "dndWorkspaceDelayMs": block_number(&dnd_workspace, "delay-ms", 100.0) as i64,
        "dndWorkspaceMaxSpeed": block_number(&dnd_workspace, "max-speed", 1500.0) as i64,
        "hotCornersEnabled": hot_corners_enabled,
        "hotCornerTopLeft": corner_states["top-left"],
        "hotCornerTopRight": corner_states["top-right"],
        "hotCornerBottomLeft": corner_states["bottom-left"],
        "hotCornerBottomRight": corner_states["bottom-right"],
        "lidCloseAction": event_action(switch_events_source, "lid-close"),
        "lidOpenAction": event_action(switch_events_source, "lid-open"),
        "tabletModeOnAction": event_action(switch_events_source, "tablet-mode-on"),
        "tabletModeOffAction": event_action(switch_events_source, "tablet-mode-off"),
    })
}

fn event_action(source: &str, name: &str) -> String {
    let block = find_any_block(source, name);
    capture(&block, r"(?m)^\s*(spawn(?:-sh)?\s+.+?)\s*;?\s*$", 1)
        .map(|value| value.trim().to_string())
        .unwrap_or_default()
}

fn quickshell_snapshot(paths: &SettingsPaths, config_source: &str) -> Value {
    let mut settings = defaults();
    settings.remove("clock24h");
    set_qml_string(&mut settings, config_source, "fontName", "Inter Variable");
    set_qml_string(
        &mut settings,
        config_source,
        "greeterDefaultSession",
        "niri",
    );
    set_qml_bool(
        &mut settings,
        config_source,
        "greeterRememberLastSession",
        false,
    );
    set_qml_int(&mut settings, config_source, "lockFaceMaxAttempts", 3);
    set_qml_bool(&mut settings, config_source, "lockFaceRetryOnWake", true);
    set_qml_string(
        &mut settings,
        config_source,
        "launcherCalculatorAngleMode",
        "rad",
    );
    for name in [
        "launcherKlipyApiKey",
        "profileImagePath",
        "latLon",
        "apiWeather",
        "steamUsername",
        "steamWebApiKey",
        "wallhavenUsername",
        "wallhavenApiKey",
        "wallFolderPath",
        "liveWallFolderPath",
        "captureScreenshotDirPath",
        "captureRecordingDirPath",
        "wallpaperEngineAssetsDirPath",
        "wallpaperEngineWorkshopDirPath",
    ] {
        let fallback = settings
            .get(name)
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_string();
        set_qml_string(&mut settings, config_source, name, &fallback);
    }
    set_qml_string(
        &mut settings,
        config_source,
        "notificationLockscreenPrivacy",
        "hidden",
    );
    for (name, fallback) in [
        ("wallhavenShowNsfw", false),
        ("wallpaperWorkshopShowNsfw", false),
        ("wallpaperPauseOnFullscreen", true),
        ("wallpaperPauseOnLock", true),
        ("matugenEnabled", true),
        ("matugenAnimateColors", true),
        ("captureAutoCopyScreenshot", true),
        ("captureAutoCopyRecording", true),
        ("captureRecordingCursor", true),
        ("captureRecordingMicrophone", false),
    ] {
        set_qml_bool(&mut settings, config_source, name, fallback);
    }
    for (name, fallback) in [
        ("wallpaperBatteryFps", 20),
        ("wallpaperEngineFps", 30),
        ("wallpaperTransitionDuration", 360),
        ("matugenTransitionDuration", 300),
        ("captureRecordingFps", 60),
        ("captureRecordingCountdown", 0),
        ("captureScreenshotQuality", 90),
        ("captureEditorWidth", 6),
    ] {
        set_qml_int(&mut settings, config_source, name, fallback);
    }
    for (name, fallback) in [
        ("wallpaperScalingMode", "fill"),
        ("captureRecordingCodec", "hevc"),
        ("captureRecordingQuality", "high"),
        ("captureRecordingMicrophoneSource", "default_input"),
        ("captureRecordingMode", "region"),
        ("captureScreenshotAction", "notification"),
        ("captureScreenshotFilenameTemplate", "{date}_{time}-edited"),
        ("captureScreenshotFormat", "png"),
        ("captureEditorTool", "pen"),
        ("captureEditorColor", "#ff3b30"),
        ("temperatureUnit", "celsius"),
    ] {
        set_qml_string(&mut settings, config_source, name, fallback);
    }

    if let Ok(source) = fs::read_to_string(&paths.runtime_settings)
        && let Ok(Value::Object(runtime)) = serde_json::from_str::<Value>(&source)
    {
        let legacy_timeout = runtime
            .get("notificationPopupDuration")
            .cloned()
            .unwrap_or_else(|| json!(5000));
        if !runtime.contains_key("notificationLowTimeout") {
            settings.insert("notificationLowTimeout".into(), legacy_timeout.clone());
        }
        if !runtime.contains_key("notificationNormalTimeout") {
            settings.insert("notificationNormalTimeout".into(), legacy_timeout);
        }
        let legacy_blur = runtime
            .get("shellBlurEnabled")
            .map(json_truthy)
            .unwrap_or(true);
        for key in blur_keys() {
            if !runtime.contains_key(*key) {
                settings.insert((*key).into(), Value::Bool(legacy_blur));
            }
        }
        for (key, value) in runtime {
            if settings.contains_key(&key) {
                settings.insert(key, value);
            }
        }
    }
    let privacy = settings
        .get("notificationLockscreenPrivacy")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_ascii_lowercase();
    if !matches!(privacy.as_str(), "hidden" | "icons" | "full") {
        let show = settings
            .get("notificationShowOnLock")
            .map(json_truthy)
            .unwrap_or(false);
        settings.insert(
            "notificationLockscreenPrivacy".into(),
            Value::String(if show { "full" } else { "hidden" }.into()),
        );
    }
    Value::Object(settings)
}

pub fn defaults() -> Map<String, Value> {
    let mut map = serde_json::from_str::<Value>(include_str!("defaults.json"))
        .expect("settings defaults are valid JSON")
        .as_object()
        .expect("settings defaults are an object")
        .clone();
    map.remove("gtk");
    map.remove("qt");
    map
}

pub fn gtk_defaults() -> Map<String, Value> {
    serde_json::from_str::<Value>(include_str!("defaults.json"))
        .ok()
        .and_then(|mut val| val.get_mut("gtk").map(Value::take))
        .and_then(|val| match val {
            Value::Object(map) => Some(map),
            _ => None,
        })
        .unwrap_or_default()
}

pub fn qt_defaults() -> Map<String, Value> {
    serde_json::from_str::<Value>(include_str!("defaults.json"))
        .ok()
        .and_then(|mut val| val.get_mut("qt").map(Value::take))
        .and_then(|val| match val {
            Value::Object(map) => Some(map),
            _ => None,
        })
        .unwrap_or_default()
}

pub fn blur_keys() -> &'static [&'static str] {
    &[
        "shellBlurBarEnabled",
        "shellBlurControlLeftEnabled",
        "shellBlurControlRightEnabled",
        "shellBlurDockEnabled",
        "shellBlurLauncherEnabled",
        "shellBlurNotificationEnabled",
        "shellBlurOsdEnabled",
        "shellBlurSettingsEnabled",
    ]
}

pub fn json_truthy(value: &Value) -> bool {
    match value {
        Value::Null => false,
        Value::Bool(value) => *value,
        Value::Number(value) => value.as_f64().unwrap_or_default() != 0.0,
        Value::String(value) => !value.is_empty(),
        Value::Array(value) => !value.is_empty(),
        Value::Object(value) => !value.is_empty(),
    }
}

fn set_qml_string(settings: &mut Map<String, Value>, source: &str, name: &str, fallback: &str) {
    settings.insert(
        name.into(),
        Value::String(qml_string(source, name, fallback)),
    );
}

fn set_qml_int(settings: &mut Map<String, Value>, source: &str, name: &str, fallback: i64) {
    settings.insert(
        name.into(),
        Value::Number(qml_int(source, name, fallback).into()),
    );
}

fn set_qml_bool(settings: &mut Map<String, Value>, source: &str, name: &str, fallback: bool) {
    settings.insert(name.into(), Value::Bool(qml_bool(source, name, fallback)));
}

fn pretty_key(raw: &str) -> String {
    let key = regex(r"\s+(?:repeat|cooldown-ms|allow-when-locked)=[^\s]+")
        .replace_all(raw, "")
        .trim()
        .to_string();
    key.split('+')
        .map(|part| match part {
            "Mod" => "Super",
            "XF86AudioRaiseVolume" => "Volume +",
            "XF86AudioLowerVolume" => "Volume −",
            "XF86AudioMute" => "Mute",
            "XF86AudioMicMute" => "Mic mute",
            "XF86MonBrightnessUp" => "Brightness +",
            "XF86MonBrightnessDown" => "Brightness −",
            "Return" => "Enter",
            "Equal" => "=",
            "Minus" => "−",
            value => value,
        })
        .collect::<Vec<_>>()
        .join(" + ")
}

fn unquote_command(body: &str) -> Option<(&str, String)> {
    let captures = regex(r"^(spawn-sh|spawn)\s+(.+)$").captures(body)?;
    let encoded = &captures[2];
    let args = shell_split(encoded).unwrap_or_else(|| vec![encoded.trim_matches('"').into()]);
    Some((captures.get(1)?.as_str(), args.join(" ")))
}

fn action_description(body: &str) -> String {
    let clean = body.trim().trim_end_matches(';');
    if let Some((_command_type, command)) = unquote_command(clean) {
        let lower = command.to_ascii_lowercase();
        for (needle, label) in [
            ("blackbox-terminal", "Open terminal"),
            ("launcher toggle", "Open application launcher"),
            ("lockscreen", "Lock screen"),
            ("wallpaper toggle", "Open wallpaper selector"),
            ("killall quickshell", "Reload SownteeShell"),
            ("nautilus", "Open file manager"),
            ("missioncenter", "Open system monitor"),
            ("hyprpicker", "Pick screen color"),
            ("gnome-control-center", "Open system settings"),
            ("screenshot", "Capture screenshot"),
            ("togglerecording", "Toggle screen recording"),
            ("set-sink-volume", "Change output volume"),
            ("set-source-volume", "Change microphone volume"),
            ("set-sink-mute", "Toggle output mute"),
            ("set-mute @default_audio_source@", "Toggle microphone mute"),
            ("brightnessctl", "Change screen brightness"),
            ("focus-app", "Focus app workspace"),
            (
                "toogle-floating-workspace",
                "Toggle workspace floating layout",
            ),
        ] {
            if lower.contains(needle) {
                return label.into();
            }
        }
        let first = command
            .split_whitespace()
            .next()
            .and_then(|value| Path::new(value).file_name())
            .and_then(|value| value.to_str())
            .unwrap_or("command");
        return format!("Run {first}");
    }
    let action = clean.split_whitespace().next().unwrap_or_default();
    let known = HashMap::from([
        ("show-hotkey-overlay", "Show Niri hotkey overlay"),
        ("focus-column-left", "Focus column left"),
        ("focus-column-right", "Focus column right"),
        ("focus-window-up", "Focus window above"),
        ("focus-window-down", "Focus window below"),
        ("move-column-left", "Move column left"),
        ("move-column-right", "Move column right"),
        ("move-window-up", "Move window up"),
        ("move-window-down", "Move window down"),
        (
            "focus-window-or-workspace-down",
            "Focus window or workspace below",
        ),
        (
            "focus-window-or-workspace-up",
            "Focus window or workspace above",
        ),
        (
            "move-window-down-or-to-workspace-down",
            "Move window or workspace down",
        ),
        (
            "move-window-up-or-to-workspace-up",
            "Move window or workspace up",
        ),
        ("toggle-column-tabbed-display", "Toggle tabbed columns"),
        ("focus-monitor-left", "Focus monitor left"),
        ("focus-monitor-right", "Focus monitor right"),
        ("focus-monitor-up", "Focus monitor above"),
        ("focus-monitor-down", "Focus monitor below"),
        ("move-column-to-monitor-left", "Move column to monitor left"),
        (
            "move-column-to-monitor-right",
            "Move column to monitor right",
        ),
        ("move-column-to-monitor-up", "Move column to monitor above"),
        (
            "move-column-to-monitor-down",
            "Move column to monitor below",
        ),
        ("toggle-overview", "Toggle overview"),
        ("focus-workspace-previous", "Focus previous workspace"),
        ("move-workspace-up", "Move workspace up"),
        ("move-workspace-down", "Move workspace down"),
        ("maximize-window-to-edges", "Maximize window"),
        ("fullscreen-window", "Toggle fullscreen"),
        ("toggle-window-floating", "Toggle window floating"),
        (
            "switch-focus-between-floating-and-tiling",
            "Switch floating / tiled focus",
        ),
        ("center-column", "Center focused column"),
        ("center-visible-columns", "Center visible columns"),
        ("quit", "Exit Niri"),
    ]);
    if let Some(label) = known.get(action) {
        return (*label).into();
    }
    let last = clean.split_whitespace().last().unwrap_or_default();
    match action {
        "focus-workspace" => format!("Focus workspace {last}"),
        "move-column-to-workspace" => format!("Move column to workspace {last}"),
        "set-column-width" => format!("Change column width {}", last.trim_matches('"')),
        "set-window-height" => format!("Change window height {}", last.trim_matches('"')),
        "" => "Niri action".into(),
        _ => {
            let mut value = action.replace('-', " ");
            if let Some(first) = value.get_mut(0..1) {
                first.make_ascii_uppercase();
            }
            value
        }
    }
}

fn category_for(key: &str, body: &str, description: &str) -> &'static str {
    let text = format!("{key} {body} {description}").to_ascii_lowercase();
    if text.contains("audio") || text.contains("volume") || text.contains("mic mute") {
        "Media"
    } else if text.contains("brightness") {
        "Backlight"
    } else if text.contains("screenshot") || text.contains("recording") {
        "Capture"
    } else if text.contains("monitor") {
        "Monitor"
    } else if text.contains("workspace") || text.contains("overview") || text.contains("focus-app")
    {
        "Workspace"
    } else if [
        "launcher",
        "terminal",
        "file manager",
        "system monitor",
        "system settings",
        "pick screen color",
    ]
    .iter()
    .any(|word| text.contains(word))
    {
        "Applications"
    } else if [
        "quickshell",
        "lock screen",
        "wallpaper",
        "exit niri",
        "hotkey overlay",
    ]
    .iter()
    .any(|word| text.contains(word))
    {
        "Shell"
    } else if [
        "window",
        "column",
        "floating",
        "fullscreen",
        "width",
        "height",
    ]
    .iter()
    .any(|word| text.contains(word))
    {
        "Window"
    } else {
        "Other"
    }
}

fn parse_binds(source: &str) -> Vec<Value> {
    let pattern = regex(r"^\s*([^/\{][^\{]*?)\s*\{\s*(.*?)\s*;\s*\}\s*$");
    let mut groups: HashMap<&str, Vec<Value>> = HashMap::new();
    for raw in source.lines() {
        let line = raw.trim();
        if line.is_empty() || line.starts_with("//") {
            continue;
        }
        let Some(captures) = pattern.captures(raw) else {
            continue;
        };
        let key = captures[1].trim();
        let body = captures[2].trim();
        let raw_key = key.split_whitespace().next().unwrap_or_default();
        let description = action_description(body);
        let category = category_for(key, body, &description);
        groups.entry(category).or_default().push(json!({
            "key": pretty_key(key),
            "rawKey": raw_key,
            "rawHeader": key,
            "description": description,
        }));
    }
    let order = [
        "Window",
        "Applications",
        "Workspace",
        "Shell",
        "Capture",
        "Monitor",
        "Media",
        "Backlight",
        "Other",
    ];
    let icons = HashMap::from([
        ("Window", "window-new-symbolic"),
        ("Applications", "view-app-grid-symbolic"),
        ("Workspace", "view-grid-symbolic"),
        ("Shell", "utilities-terminal-symbolic"),
        ("Capture", "camera-photo-symbolic"),
        ("Monitor", "video-display-symbolic"),
        ("Media", "audio-volume-high-symbolic"),
        ("Backlight", "display-brightness-symbolic"),
        ("Other", "applications-system-symbolic"),
    ]);
    let mut column_sizes = [0_usize, 0_usize];
    let mut result = Vec::new();
    for name in order {
        let Some(items) = groups.remove(name) else {
            continue;
        };
        let column = if column_sizes[0] <= column_sizes[1] {
            0
        } else {
            1
        };
        column_sizes[column] += items.len() + 2;
        result.push(json!({
            "name": name,
            "icon": icons[name],
            "column": column,
            "items": items,
        }));
    }
    result
}
