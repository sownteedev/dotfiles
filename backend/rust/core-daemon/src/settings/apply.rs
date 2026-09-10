use super::SettingsPaths;
use super::parser::*;
use super::snapshot;
use super::transaction::{NiriUpdate, apply_niri_changes, atomic_write};
use anyhow::{Context, Result, bail};
use regex::Regex;
use serde_json::{Map, Value, json};
use std::collections::HashSet;
use std::fs;
use tokio::process::Command;
use tokio_util::sync::CancellationToken;

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

const INPUT_SECTIONS: &[(&str, &str)] = &[
    ("Keyboard", "keyboard"),
    ("Touchpad", "touchpad"),
    ("Mouse", "mouse"),
    ("Trackpoint", "trackpoint"),
    ("Trackball", "trackball"),
    ("Tablet", "tablet"),
    ("Touch", "touch"),
];

pub async fn layout(
    paths: &SettingsPaths,
    payload: &Value,
    cancellation: CancellationToken,
) -> Value {
    let update = match prepare_layout(paths, payload) {
        Ok(update) => update,
        Err(error) => return failure(error),
    };
    apply_niri_changes(paths, vec![update], "Niri layout applied", cancellation).await
}

fn prepare_layout(paths: &SettingsPaths, payload: &Value) -> Result<NiriUpdate> {
    let path = paths.include_dir.join("layout.kdl");
    let original = read_file(&path)?;
    let gaps = value_f64(payload, "gaps", 10.0).clamp(0.0, 64.0);
    let border_width = value_f64(payload, "borderWidth", 1.0).clamp(0.0, 64.0);
    let shadow = value_bool(payload, "shadow", true);
    let center_focused = allowed_string(
        payload,
        "centerFocused",
        "on-overflow",
        &["never", "always", "on-overflow"],
    );
    let default_display = allowed_string(
        payload,
        "defaultColumnDisplay",
        "normal",
        &["normal", "tabbed"],
    );
    let default_width_mode = allowed_string(
        payload,
        "defaultColumnWidthMode",
        "proportion",
        &["auto", "proportion", "fixed"],
    );
    let mut default_width = value_f64(payload, "defaultColumnWidth", 1.0);
    if default_width_mode == "proportion" {
        default_width = default_width.clamp(0.01, 1.0);
    } else if default_width_mode == "fixed" {
        default_width = default_width.clamp(1.0, 16384.0);
    }
    let preset_widths_enabled = value_bool(payload, "presetColumnWidthsEnabled", false);
    let preset_widths = value_string(
        payload,
        "presetColumnWidths",
        "proportion 0.33333, proportion 0.5, proportion 0.66667",
    );
    let preset_heights_enabled = value_bool(payload, "presetWindowHeightsEnabled", false);
    let preset_heights = value_string(
        payload,
        "presetWindowHeights",
        "proportion 0.33333, proportion 0.5, proportion 0.66667",
    );
    let struts_enabled = value_bool(payload, "strutsEnabled", false);
    let strut_left = value_f64(payload, "strutLeft", 0.0).clamp(-4096.0, 4096.0);
    let strut_right = value_f64(payload, "strutRight", 0.0).clamp(-4096.0, 4096.0);
    let strut_top = value_f64(payload, "strutTop", 0.0).clamp(-4096.0, 4096.0);
    let strut_bottom = value_f64(payload, "strutBottom", 0.0).clamp(-4096.0, 4096.0);
    let overview_zoom = value_f64(payload, "overviewZoom", 0.4).clamp(0.1, 1.0);
    let overview_backdrop = clean_color(payload, "overviewBackdropColor", "#0a0a0a");
    let workspace_shadow_enabled = value_bool(payload, "workspaceShadowEnabled", true);
    let workspace_shadow_softness =
        value_f64(payload, "workspaceShadowSoftness", 30.0).clamp(0.0, 100.0);
    let workspace_shadow_spread =
        value_f64(payload, "workspaceShadowSpread", 5.0).clamp(0.0, 100.0);
    let workspace_shadow_offset_x =
        value_f64(payload, "workspaceShadowOffsetX", 0.0).clamp(-100.0, 100.0);
    let workspace_shadow_offset_y =
        value_f64(payload, "workspaceShadowOffsetY", 0.0).clamp(-100.0, 100.0);
    let workspace_shadow_color = clean_color(payload, "workspaceShadowColor", "#000000");
    let background_color = clean_color(payload, "backgroundColor", "transparent");
    let border_active_color = clean_color(payload, "borderActiveColor", "#222222");
    let border_inactive_color = clean_color(payload, "borderInactiveColor", "#222222");
    let border_urgent_color = clean_color(payload, "borderUrgentColor", "#9b0000");
    let border_gradient_enabled = value_bool(payload, "borderGradientEnabled", false);
    let border_active_gradient = value_string(
        payload,
        "borderActiveGradient",
        r##"from="#80c8ff" to="#c7ff7f" angle=45"##,
    );
    let border_inactive_gradient = value_string(
        payload,
        "borderInactiveGradient",
        r##"from="#505050" to="#808080" angle=45"##,
    );
    let border_urgent_gradient = value_string(
        payload,
        "borderUrgentGradient",
        r##"from="#800" to="#a33" angle=45"##,
    );
    let focus_ring_width = value_f64(payload, "focusRingWidth", 4.0).clamp(0.0, 64.0);
    let focus_ring_active_color = clean_color(payload, "focusRingActiveColor", "#7fc8ff");
    let focus_ring_inactive_color = clean_color(payload, "focusRingInactiveColor", "#505050");
    let focus_ring_urgent_color = clean_color(payload, "focusRingUrgentColor", "#9b0000");
    let focus_gradient_enabled = value_bool(payload, "focusRingGradientEnabled", false);
    let focus_active_gradient = value_string(
        payload,
        "focusRingActiveGradient",
        r##"from="#80c8ff" to="#bbddff" angle=45"##,
    );
    let focus_inactive_gradient = value_string(
        payload,
        "focusRingInactiveGradient",
        r##"from="#505050" to="#808080" angle=45"##,
    );
    let focus_urgent_gradient = value_string(
        payload,
        "focusRingUrgentGradient",
        r##"from="#800" to="#a33" angle=45"##,
    );
    let shadow_softness = value_f64(payload, "shadowSoftness", 20.0).clamp(0.0, 100.0);
    let shadow_spread = value_f64(payload, "shadowSpread", 5.0).clamp(0.0, 100.0);
    let shadow_offset_x = value_f64(payload, "shadowOffsetX", 0.0).clamp(-100.0, 100.0);
    let shadow_offset_y = value_f64(payload, "shadowOffsetY", 0.0).clamp(-100.0, 100.0);
    let shadow_draw_behind = value_bool(payload, "shadowDrawBehind", true);
    let shadow_color = clean_color(payload, "shadowColor", "#000000");
    let shadow_inactive_color = clean_color(payload, "shadowInactiveColor", "#00000054");
    let tab_gap = value_f64(payload, "tabGap", 5.0).clamp(-64.0, 64.0);
    let tab_width = value_f64(payload, "tabWidth", 4.0).clamp(0.1, 64.0);
    let tab_length = value_f64(payload, "tabLength", 1.0).clamp(0.05, 1.0);
    let tab_position = allowed_string(
        payload,
        "tabPosition",
        "right",
        &["left", "right", "top", "bottom"],
    );
    let tab_gaps_between = value_f64(payload, "tabGapsBetween", 2.0).clamp(0.0, 64.0);
    let tab_corner_radius = value_f64(payload, "tabCornerRadius", 8.0).clamp(0.0, 256.0);
    let tab_active_color = clean_color(payload, "tabActiveColor", "#7fc8ff");
    let tab_inactive_color = clean_color(payload, "tabInactiveColor", "#505050");
    let tab_urgent_color = clean_color(payload, "tabUrgentColor", "#9b0000");
    let tab_gradient_enabled = value_bool(payload, "tabGradientEnabled", false);
    let tab_active_gradient = value_string(
        payload,
        "tabActiveGradient",
        r##"from="#80c8ff" to="#bbddff" angle=45"##,
    );
    let tab_inactive_gradient = value_string(
        payload,
        "tabInactiveGradient",
        r##"from="#505050" to="#808080" angle=45"##,
    );
    let tab_urgent_gradient = value_string(
        payload,
        "tabUrgentGradient",
        r##"from="#800" to="#a33" angle=45"##,
    );
    let insert_hint_color = clean_color(payload, "insertHintColor", "#7fc8ff80");
    let insert_gradient_enabled = value_bool(payload, "insertHintGradientEnabled", false);
    let insert_gradient = value_string(
        payload,
        "insertHintGradient",
        r##"from="#ffbb6680" to="#ffc88080" angle=45"##,
    );
    let blur_values = [
        (
            "passes",
            value_i64(payload, "blurPasses", 3).clamp(1, 8) as f64,
        ),
        (
            "offset",
            value_f64(payload, "blurOffset", 3.0).clamp(0.1, 10.0),
        ),
        (
            "noise",
            value_f64(payload, "blurNoise", 0.02).clamp(0.0, 1.0),
        ),
        (
            "saturation",
            value_f64(payload, "blurSaturation", 1.5).clamp(0.0, 5.0),
        ),
    ];

    let mut updated = replace_once_with(
        &original,
        r"(?m)^(\s*gaps\s+)[\d.]+",
        "layout gaps",
        |captures| format!("{}{}", &captures[1], kdl_float(gaps)),
    )?;
    updated = replace_once_with(
        &updated,
        r"(?ms)(\bborder\s*\{.*?^\s*width\s+)[\d.]+",
        "border width",
        |captures| format!("{}{}", &captures[1], kdl_float(border_width)),
    )?;
    updated = set_explicit_block_state(&updated, "shadow", shadow)?;
    updated = replace_once_with(
        &updated,
        r#"(?m)^(\s*center-focused-column\s+)"[^"]+""#,
        "focused column mode",
        |captures| format!(r#"{}"{}""#, &captures[1], center_focused),
    )?;
    updated = set_flag(
        &updated,
        "always-center-single-column",
        value_bool(payload, "alwaysCenterSingle", true),
    )?;
    updated = set_flag(
        &updated,
        "empty-workspace-above-first",
        value_bool(payload, "emptyWorkspaceAboveFirst", false),
    )?;
    updated = replace_once_with(
        &updated,
        r#"(?m)^(\s*background-color\s+)"[^"]*""#,
        "layout background color",
        |captures| format!("{}{}", &captures[1], json_quote(&background_color)),
    )?;
    updated = replace_once_with(
        &updated,
        r#"(?m)^(\s*)(?://\s*)?default-column-display\s+"[^"]+"\s*$"#,
        "default column display",
        |captures| {
            format!(
                "{}{}default-column-display \"tabbed\"",
                &captures[1],
                if default_display == "tabbed" {
                    ""
                } else {
                    "// "
                }
            )
        },
    )?;
    updated = update_block(&updated, "default-column-width", |_| {
        Ok(match default_width_mode.as_str() {
            "auto" => String::new(),
            "fixed" => format!(" fixed {}; ", default_width.round() as i64),
            _ => format!(" proportion {}; ", kdl_float(default_width)),
        })
    })?;
    updated = toggle_block(&updated, "preset-column-widths", preset_widths_enabled)?;
    updated = update_block(&updated, "preset-column-widths", |_| {
        render_dimension_entries(&preset_widths, "preset column widths")
    })?;
    updated = toggle_block(&updated, "preset-window-heights", preset_heights_enabled)?;
    updated = update_block(&updated, "preset-window-heights", |_| {
        render_dimension_entries(&preset_heights, "preset window heights")
    })?;
    updated = toggle_block(&updated, "struts", struts_enabled)?;
    updated = update_block(&updated, "struts", |block| {
        let block = set_number_line(block, "left", strut_left, "left strut")?;
        let block = set_number_line(&block, "right", strut_right, "right strut")?;
        let block = set_number_line(&block, "top", strut_top, "top strut")?;
        set_number_line(&block, "bottom", strut_bottom, "bottom strut")
    })?;
    updated = replace_once_with(
        &updated,
        r"(?ms)(\boverview\s*\{.*?^\s*zoom\s+)[\d.]+",
        "overview zoom",
        |captures| format!("{}{}", &captures[1], kdl_float(overview_zoom)),
    )?;
    updated = replace_once_with(
        &updated,
        r#"(?ms)(\boverview\s*\{.*?^\s*backdrop-color\s+)"[^"]*""#,
        "overview backdrop color",
        |captures| format!("{}{}", &captures[1], json_quote(&overview_backdrop)),
    )?;
    updated = set_explicit_block_state(&updated, "workspace-shadow", workspace_shadow_enabled)?;
    updated = update_block(&updated, "workspace-shadow", |block| {
        let block = set_number_line(
            block,
            "softness",
            workspace_shadow_softness,
            "workspace shadow softness",
        )?;
        let block = set_number_line(
            &block,
            "spread",
            workspace_shadow_spread,
            "workspace shadow spread",
        )?;
        let block = replace_once_with(
            &block,
            r"(?m)^(\s*offset\s+)x=[-\d.]+\s+y=[-\d.]+",
            "workspace shadow offset",
            |captures| {
                format!(
                    "{}x={} y={}",
                    &captures[1],
                    kdl_float(workspace_shadow_offset_x),
                    kdl_float(workspace_shadow_offset_y)
                )
            },
        )?;
        set_string_line(
            &block,
            "color",
            &workspace_shadow_color,
            "workspace shadow color",
        )
    })?;
    updated = set_explicit_block_state(
        &updated,
        "border",
        value_bool(payload, "borderEnabled", true),
    )?;
    updated = set_explicit_block_state(
        &updated,
        "focus-ring",
        value_bool(payload, "focusRingEnabled", false),
    )?;
    updated = set_explicit_block_state(
        &updated,
        "tab-indicator",
        value_bool(payload, "tabIndicatorEnabled", false),
    )?;
    updated = set_explicit_block_state(
        &updated,
        "insert-hint",
        value_bool(payload, "insertHintEnabled", false),
    )?;
    updated = toggle_block(&updated, "blur", true)?;
    updated = set_block_flag(
        &updated,
        "blur",
        "off",
        !value_bool(payload, "blurEnabled", true),
    )?;
    for (name, value) in blur_values {
        let encoded = if name == "passes" {
            (value as i64).to_string()
        } else {
            kdl_float(value)
        };
        updated = replace_once_with(
            &updated,
            &format!(
                r"(?ms)((?:/-)?blur\s*\{{.*?^\s*{}\s+)[\d.]+",
                regex::escape(name)
            ),
            &format!("blur {name}"),
            |captures| format!("{}{}", &captures[1], encoded),
        )?;
    }
    updated = update_block(&updated, "border", |block| {
        let block = set_string_line(
            block,
            "active-color",
            &border_active_color,
            "border active color",
        )?;
        let block = set_string_line(
            &block,
            "inactive-color",
            &border_inactive_color,
            "border inactive color",
        )?;
        let block = set_string_line(
            &block,
            "urgent-color",
            &border_urgent_color,
            "border urgent color",
        )?;
        let block = set_optional_raw_line(
            &block,
            "active-gradient",
            &border_active_gradient,
            border_gradient_enabled,
            "border active gradient",
        )?;
        let block = set_optional_raw_line(
            &block,
            "inactive-gradient",
            &border_inactive_gradient,
            border_gradient_enabled,
            "border inactive gradient",
        )?;
        set_optional_raw_line(
            &block,
            "urgent-gradient",
            &border_urgent_gradient,
            border_gradient_enabled,
            "border urgent gradient",
        )
    })?;
    updated = update_block(&updated, "focus-ring", |block| {
        let block = set_number_line(block, "width", focus_ring_width, "focus ring width")?;
        let block = set_string_line(
            &block,
            "active-color",
            &focus_ring_active_color,
            "focus ring active color",
        )?;
        let block = set_string_line(
            &block,
            "inactive-color",
            &focus_ring_inactive_color,
            "focus ring inactive color",
        )?;
        let block = set_string_line(
            &block,
            "urgent-color",
            &focus_ring_urgent_color,
            "focus ring urgent color",
        )?;
        let block = set_optional_raw_line(
            &block,
            "active-gradient",
            &focus_active_gradient,
            focus_gradient_enabled,
            "focus ring active gradient",
        )?;
        let block = set_optional_raw_line(
            &block,
            "inactive-gradient",
            &focus_inactive_gradient,
            focus_gradient_enabled,
            "focus ring inactive gradient",
        )?;
        set_optional_raw_line(
            &block,
            "urgent-gradient",
            &focus_urgent_gradient,
            focus_gradient_enabled,
            "focus ring urgent gradient",
        )
    })?;
    updated = update_block(&updated, "shadow", |block| {
        let block = set_number_line(block, "softness", shadow_softness, "shadow softness")?;
        let block = set_number_line(&block, "spread", shadow_spread, "shadow spread")?;
        let block = replace_once_with(
            &block,
            r"(?m)^([ \t]*)(?://[ \t]*)?offset\s+x=[-\d.]+\s+y=[-\d.]+",
            "shadow offset",
            |captures| {
                format!(
                    "{}offset x={} y={}",
                    &captures[1],
                    kdl_float(shadow_offset_x),
                    kdl_float(shadow_offset_y)
                )
            },
        )?;
        let block = set_bool_line(
            &block,
            "draw-behind-window",
            shadow_draw_behind,
            "shadow draw behind",
        )?;
        let block = set_string_line(&block, "color", &shadow_color, "shadow color")?;
        set_string_line(
            &block,
            "inactive-color",
            &shadow_inactive_color,
            "shadow inactive color",
        )
    })?;
    updated = update_block(&updated, "tab-indicator", |block| {
        let block = set_flag(
            block,
            "hide-when-single-tab",
            value_bool(payload, "tabHideSingle", true),
        )?;
        let block = set_flag(
            &block,
            "place-within-column",
            value_bool(payload, "tabPlaceWithinColumn", true),
        )?;
        let block = set_number_line(&block, "gap", tab_gap, "tab indicator gap")?;
        let block = set_number_line(&block, "width", tab_width, "tab indicator width")?;
        let block = set_attribute_number_line(
            &block,
            "length",
            "total-proportion",
            tab_length,
            "tab indicator length",
        )?;
        let block = set_string_line(&block, "position", &tab_position, "tab indicator position")?;
        let block = set_number_line(&block, "gaps-between-tabs", tab_gaps_between, "tab gaps")?;
        let block = set_number_line(
            &block,
            "corner-radius",
            tab_corner_radius,
            "tab corner radius",
        )?;
        let block = set_string_line(
            &block,
            "active-color",
            &tab_active_color,
            "tab active color",
        )?;
        let block = set_string_line(
            &block,
            "inactive-color",
            &tab_inactive_color,
            "tab inactive color",
        )?;
        let block = set_string_line(
            &block,
            "urgent-color",
            &tab_urgent_color,
            "tab urgent color",
        )?;
        let block = set_optional_raw_line(
            &block,
            "active-gradient",
            &tab_active_gradient,
            tab_gradient_enabled,
            "tab active gradient",
        )?;
        let block = set_optional_raw_line(
            &block,
            "inactive-gradient",
            &tab_inactive_gradient,
            tab_gradient_enabled,
            "tab inactive gradient",
        )?;
        set_optional_raw_line(
            &block,
            "urgent-gradient",
            &tab_urgent_gradient,
            tab_gradient_enabled,
            "tab urgent gradient",
        )
    })?;
    updated = update_block(&updated, "insert-hint", |block| {
        let block = set_string_line(block, "color", &insert_hint_color, "insert hint color")?;
        set_optional_raw_line(
            &block,
            "gradient",
            &insert_gradient,
            insert_gradient_enabled,
            "insert hint gradient",
        )
    })?;

    let recent_windows_enabled = value_bool(payload, "recentWindows", true);
    updated = toggle_block(&updated, "recent-windows", true)?;
    updated = set_block_flag(&updated, "recent-windows", "off", !recent_windows_enabled)?;
    let recent_debounce = value_i64(payload, "recentDebounceMs", 750).clamp(0, 5000);
    let recent_open_delay = value_i64(payload, "recentOpenDelayMs", 150).clamp(0, 5000);
    let recent_active_color = clean_color(payload, "recentHighlightActiveColor", "#999999ff");
    let recent_urgent_color = clean_color(payload, "recentHighlightUrgentColor", "#ff9999ff");
    let recent_padding = value_i64(payload, "recentHighlightPadding", 30).clamp(0, 256);
    let recent_corner_radius = value_i64(payload, "recentHighlightCornerRadius", 0).clamp(0, 256);
    let recent_preview_height = value_i64(payload, "recentPreviewHeight", 480).clamp(64, 2160);
    let recent_preview_scale = value_f64(payload, "recentPreviewScale", 0.5).clamp(0.05, 1.0);
    let recent_binds = payload
        .get("recentBinds")
        .and_then(Value::as_array)
        .context("Recent windows binds must be a list")?;
    let rendered_binds = render_recent_binds(recent_binds)?;
    updated = update_block(&updated, "recent-windows", |block| {
        let block = set_integer_line(
            block,
            "debounce-ms",
            recent_debounce,
            "recent windows debounce",
        )?;
        let block = set_integer_line(
            &block,
            "open-delay-ms",
            recent_open_delay,
            "recent windows open delay",
        )?;
        let block = update_block(&block, "highlight", |inner| {
            let inner = set_string_line(
                inner,
                "active-color",
                &recent_active_color,
                "recent windows active highlight color",
            )?;
            let inner = set_string_line(
                &inner,
                "urgent-color",
                &recent_urgent_color,
                "recent windows urgent highlight color",
            )?;
            let inner = set_integer_line(
                &inner,
                "padding",
                recent_padding,
                "recent windows highlight padding",
            )?;
            set_integer_line(
                &inner,
                "corner-radius",
                recent_corner_radius,
                "recent windows highlight corner radius",
            )
        })?;
        let block = update_block(&block, "previews", |inner| {
            let inner = set_integer_line(
                inner,
                "max-height",
                recent_preview_height,
                "recent windows preview height",
            )?;
            set_number_line(
                &inner,
                "max-scale",
                recent_preview_scale,
                "recent windows preview scale",
            )
        })?;
        update_block(&block, "binds", |_| Ok(rendered_binds.clone()))
    })?;

    Ok(NiriUpdate {
        path,
        content: updated,
    })
}

fn render_recent_binds(bindings: &[Value]) -> Result<String> {
    let mut rendered = Vec::new();
    for binding in bindings {
        let object = binding
            .as_object()
            .context("Invalid recent windows binding")?;
        let key = object
            .get("key")
            .map(json_text)
            .unwrap_or_default()
            .trim()
            .to_string();
        if key.is_empty() || key.chars().any(|character| "{};\n\r".contains(character)) {
            bail!("Invalid recent windows key: {key:?}");
        }
        let direction = match object
            .get("direction")
            .map(json_text)
            .unwrap_or_else(|| "next-window".into())
            .as_str()
        {
            "previous-window" => "previous-window",
            _ => "next-window",
        };
        let filter = match object
            .get("filter")
            .map(json_text)
            .unwrap_or_default()
            .as_str()
        {
            "app-id" => "app-id",
            _ => "",
        };
        let scope = match object
            .get("scope")
            .map(json_text)
            .unwrap_or_default()
            .as_str()
        {
            "all" => "all",
            "output" => "output",
            "workspace" => "workspace",
            _ => "",
        };
        let mut attributes = String::new();
        if !scope.is_empty() {
            attributes.push_str(&format!(" scope=\"{scope}\""));
        }
        if !filter.is_empty() {
            attributes.push_str(&format!(" filter=\"{filter}\""));
        }
        rendered.push(format!("        {key} {{ {direction}{attributes}; }}"));
    }
    Ok(format!("\n{}\n    ", rendered.join("\n")))
}

pub async fn animation_global(
    paths: &SettingsPaths,
    payload: &Value,
    cancellation: CancellationToken,
) -> Value {
    let path = paths.include_dir.join("animations.kdl");
    let result = (|| -> Result<String> {
        let original = read_file(&path)?;
        let enabled = value_bool(payload, "enabled", true);
        let slowdown = value_f64(payload, "slowdown", 1.0).clamp(0.05, 10.0);
        let updated = set_flag(&original, "off", !enabled)?;
        replace_once_with(
            &updated,
            r"(?m)^(\s*)(?://\s*)?slowdown\s+[\d.]+\s*$",
            "animation slowdown",
            |captures| format!("{}slowdown {}", &captures[1], compact_float(slowdown)),
        )
    })();
    let updated = match result {
        Ok(updated) => updated,
        Err(error) => return failure(error),
    };
    apply_niri_changes(
        paths,
        vec![NiriUpdate {
            path,
            content: updated,
        }],
        "Animation settings applied",
        cancellation,
    )
    .await
}

pub async fn animation_entry(
    paths: &SettingsPaths,
    payload: &Value,
    cancellation: CancellationToken,
) -> Value {
    let name = value_string(payload, "name", "").trim().to_string();
    if !ANIMATION_NAMES.contains(&name.as_str()) {
        return json!({"ok": false, "message": "Unknown animation"});
    }
    let path = paths.include_dir.join("animations.kdl");
    let updated = match read_file(&path)
        .and_then(|source| toggle_block(&source, &name, value_bool(payload, "enabled", false)))
    {
        Ok(updated) => updated,
        Err(error) => return failure(error),
    };
    apply_niri_changes(
        paths,
        vec![NiriUpdate {
            path,
            content: updated,
        }],
        &format!("{name} animation updated"),
        cancellation,
    )
    .await
}

pub async fn behavior(
    paths: &SettingsPaths,
    payload: &Value,
    cancellation: CancellationToken,
) -> Value {
    let updates = match prepare_behavior(paths, payload) {
        Ok(updates) => updates,
        Err(error) => return failure(error),
    };
    let cursor_theme = non_empty_string(payload, "cursorTheme", "");
    let cursor_size = value_i64(payload, "cursorSize", 24).clamp(12, 128);
    if !cursor_theme.is_empty() {
        let _ = set_gsettings_value("cursor-theme", &cursor_theme, &cancellation).await;
        let _ = set_gsettings_value("cursor-size", &cursor_size.to_string(), &cancellation).await;
    }
    apply_niri_changes(paths, updates, "Niri behavior applied", cancellation).await
}

fn prepare_behavior(paths: &SettingsPaths, payload: &Value) -> Result<Vec<NiriUpdate>> {
    let behavior_path = paths.include_dir.join("behavior.kdl");
    let cursor_path = paths.include_dir.join("cursor.kdl");
    let input_path = paths.include_dir.join("input.kdl");
    let switch_events_path = paths.include_dir.join("switch-events.kdl");
    let mut behavior = read_file(&behavior_path)?;
    let mut cursor = read_file(&cursor_path)?;
    let mut input = read_file(&input_path)?;
    let mut switch_events = read_file(&switch_events_path)?;

    behavior = set_flag(
        &behavior,
        "skip-at-startup",
        !value_bool(payload, "showHotkeyOverlayAtStartup", false),
    )?;
    behavior = set_flag(
        &behavior,
        "prefer-no-csd",
        value_bool(payload, "preferNoCsd", true),
    )?;
    behavior = set_flag(
        &behavior,
        "hide-not-bound",
        value_bool(payload, "hideUnboundHotkeys", false),
    )?;
    behavior = toggle_block(
        &behavior,
        "clipboard",
        value_bool(payload, "disablePrimaryClipboard", false),
    )?;
    behavior = toggle_block(
        &behavior,
        "config-notification",
        value_bool(payload, "disableConfigError", false),
    )?;
    behavior = toggle_block(
        &behavior,
        "xwayland-satellite",
        value_bool(payload, "xwaylandEnabled", false),
    )?;
    let xwayland_path = non_empty_string(payload, "xwaylandPath", "xwayland-satellite");
    behavior = update_block(&behavior, "xwayland-satellite", |block| {
        set_string_line(block, "path", &xwayland_path, "Xwayland path")
    })?;
    switch_events = toggle_block(
        &switch_events,
        "switch-events",
        value_bool(payload, "switchEvents", false),
    )?;

    let mut screenshot_path = value_string(payload, "screenshotPath", "")
        .trim()
        .to_string();
    let screenshot_enabled = value_bool(payload, "screenshotSavingEnabled", true);
    if screenshot_enabled && screenshot_path.is_empty() {
        screenshot_path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png".into();
    }
    let screenshot_value = if screenshot_enabled {
        json_quote(&screenshot_path)
    } else {
        "null".into()
    };
    behavior = replace_once_with(
        &behavior,
        r#"(?m)^(\s*)screenshot-path\s+(?:null|"(?:\\.|[^"])*")\s*$"#,
        "screenshot path",
        |captures| format!("{}screenshot-path {screenshot_value}", &captures[1]),
    )?;

    cursor = set_flag(
        &cursor,
        "hide-when-typing",
        value_bool(payload, "hideCursorWhileTyping", false),
    )?;
    let timeout = value_i64(payload, "cursorTimeoutMs", 1000).clamp(100, 600_000);
    let timeout_enabled = value_bool(payload, "cursorTimeoutEnabled", false);
    cursor = replace_once_with(
        &cursor,
        r"(?m)^(\s*)(?://\s*)?hide-after-inactive-ms\s+\d+\s*$",
        "cursor inactivity timeout",
        |captures| {
            format!(
                "{}{}hide-after-inactive-ms {timeout}",
                &captures[1],
                if timeout_enabled { "" } else { "// " }
            )
        },
    )?;
    let cursor_theme = non_empty_string(payload, "cursorTheme", "default");
    let cursor_size = value_i64(payload, "cursorSize", 24).clamp(8, 128);
    cursor = replace_once_with(
        &cursor,
        r#"(?m)^(\s*xcursor-theme\s+)"[^"]+""#,
        "cursor theme",
        |captures| format!("{}{}", &captures[1], json_quote(&cursor_theme)),
    )?;
    cursor = replace_once_with(
        &cursor,
        r"(?m)^(\s*xcursor-size\s+)\d+",
        "cursor size",
        |captures| format!("{}{cursor_size}", &captures[1]),
    )?;

    input = set_flag(
        &input,
        "disable-power-key-handling",
        value_bool(payload, "disablePowerKeyHandling", false),
    )?;
    let warp_mode = allowed_string(
        payload,
        "warpMouseMode",
        "separate",
        &["separate", "center-xy", "center-xy-always"],
    );
    let warp_suffix = if warp_mode == "separate" {
        String::new()
    } else {
        format!("mode=\"{warp_mode}\"")
    };
    input = set_unique_option_line(
        &input,
        "warp-mouse-to-focus",
        value_bool(payload, "warpMouseToFocus", false),
        &warp_suffix,
    )?;
    let max_scroll_raw = value_string(payload, "focusFollowsMaxScrollAmount", "0%");
    let max_scroll_pattern = Regex::new(r"^(\d+(?:\.\d+)?)%$")?;
    let max_scroll = max_scroll_pattern
        .captures(max_scroll_raw.trim())
        .and_then(|captures| captures[1].parse::<f64>().ok())
        .unwrap_or(0.0)
        .clamp(0.0, 100.0);
    let max_scroll_text = format!("{}%", compact_float(max_scroll));
    input = set_unique_option_line(
        &input,
        "focus-follows-mouse",
        value_bool(payload, "focusFollowsMouse", false),
        &format!("max-scroll-amount=\"{max_scroll_text}\""),
    )?;
    input = set_flag(
        &input,
        "workspace-auto-back-and-forth",
        value_bool(payload, "workspaceAutoBackAndForth", false),
    )?;
    let valid_modifiers = ["", "Super", "Alt", "Mod3", "Mod5", "Ctrl", "Shift"];
    let mod_key = value_string(payload, "modKey", "").trim().to_string();
    let mod_key_nested = value_string(payload, "modKeyNested", "").trim().to_string();
    if !valid_modifiers.contains(&mod_key.as_str())
        || !valid_modifiers.contains(&mod_key_nested.as_str())
    {
        bail!("Invalid Niri modifier");
    }
    let mod_key_value = if mod_key.is_empty() {
        "\"Super\"".to_string()
    } else {
        json_quote(&mod_key)
    };
    input = set_unique_option_line(&input, "mod-key", !mod_key.is_empty(), &mod_key_value)?;
    let mod_key_nested_value = if mod_key_nested.is_empty() {
        "\"Alt\"".to_string()
    } else {
        json_quote(&mod_key_nested)
    };
    input = set_unique_option_line(
        &input,
        "mod-key-nested",
        !mod_key_nested.is_empty(),
        &mod_key_nested_value,
    )?;

    let dnd_view_trigger_width = value_i64(payload, "dndViewTriggerWidth", 30).clamp(1, 1000);
    let dnd_view_delay = value_i64(payload, "dndViewDelayMs", 100).clamp(0, 60_000);
    let dnd_view_max_speed = value_i64(payload, "dndViewMaxSpeed", 1500).clamp(1, 100_000);
    let dnd_workspace_trigger_height =
        value_i64(payload, "dndWorkspaceTriggerHeight", 50).clamp(1, 1000);
    let dnd_workspace_delay = value_i64(payload, "dndWorkspaceDelayMs", 100).clamp(0, 60_000);
    let dnd_workspace_max_speed =
        value_i64(payload, "dndWorkspaceMaxSpeed", 1500).clamp(1, 100_000);
    let hot_corners_enabled = value_bool(payload, "hotCornersEnabled", true);
    let mut hot_corner_top_left = value_bool(payload, "hotCornerTopLeft", true);
    let hot_corner_top_right = value_bool(payload, "hotCornerTopRight", false);
    let hot_corner_bottom_left = value_bool(payload, "hotCornerBottomLeft", false);
    let hot_corner_bottom_right = value_bool(payload, "hotCornerBottomRight", false);
    if hot_corners_enabled
        && ![
            hot_corner_top_left,
            hot_corner_top_right,
            hot_corner_bottom_left,
            hot_corner_bottom_right,
        ]
        .into_iter()
        .any(|value| value)
    {
        hot_corner_top_left = true;
    }
    behavior = update_block(&behavior, "gestures", |block| {
        let block = update_block(block, "dnd-edge-view-scroll", |inner| {
            let inner = set_integer_line(
                inner,
                "trigger-width",
                dnd_view_trigger_width,
                "DnD view trigger width",
            )?;
            let inner = set_integer_line(&inner, "delay-ms", dnd_view_delay, "DnD view delay")?;
            set_integer_line(
                &inner,
                "max-speed",
                dnd_view_max_speed,
                "DnD view maximum speed",
            )
        })?;
        let block = update_block(&block, "dnd-edge-workspace-switch", |inner| {
            let inner = set_integer_line(
                inner,
                "trigger-height",
                dnd_workspace_trigger_height,
                "DnD workspace trigger height",
            )?;
            let inner = set_integer_line(
                &inner,
                "delay-ms",
                dnd_workspace_delay,
                "DnD workspace delay",
            )?;
            set_integer_line(
                &inner,
                "max-speed",
                dnd_workspace_max_speed,
                "DnD workspace maximum speed",
            )
        })?;
        update_block(&block, "hot-corners", |inner| {
            let inner = set_flag(inner, "off", !hot_corners_enabled)?;
            let inner = set_flag(&inner, "top-left", hot_corner_top_left)?;
            let inner = set_flag(&inner, "top-right", hot_corner_top_right)?;
            let inner = set_flag(&inner, "bottom-left", hot_corner_bottom_left)?;
            set_flag(&inner, "bottom-right", hot_corner_bottom_right)
        })
    })?;

    switch_events = set_event_action(
        &switch_events,
        "lid-close",
        &value_string(payload, "lidCloseAction", ""),
    )?;
    switch_events = set_event_action(
        &switch_events,
        "lid-open",
        &value_string(payload, "lidOpenAction", ""),
    )?;
    switch_events = set_event_action(
        &switch_events,
        "tablet-mode-on",
        &value_string(payload, "tabletModeOnAction", ""),
    )?;
    switch_events = set_event_action(
        &switch_events,
        "tablet-mode-off",
        &value_string(payload, "tabletModeOffAction", ""),
    )?;

    Ok(vec![
        NiriUpdate {
            path: behavior_path,
            content: behavior,
        },
        NiriUpdate {
            path: cursor_path,
            content: cursor,
        },
        NiriUpdate {
            path: input_path,
            content: input,
        },
        NiriUpdate {
            path: switch_events_path,
            content: switch_events,
        },
    ])
}

fn set_event_action(source: &str, name: &str, action: &str) -> Result<String> {
    let clean = action.trim().trim_end_matches(';');
    if !(clean.starts_with("spawn ") || clean.starts_with("spawn-sh ")) {
        bail!("{name} action must start with spawn or spawn-sh");
    }
    if clean.chars().any(|character| "{}\n\r".contains(character)) {
        bail!("{name} action must be one KDL line");
    }
    update_block(source, name, |block| {
        replace_once_with(
            block,
            r"(?m)^([ \t]*)spawn(?:-sh)?[ \t]+.+?[ \t]*;?[ \t]*$",
            &format!("{name} action"),
            |captures| format!("{}{clean}", &captures[1]),
        )
    })
}

pub async fn niri_file(
    paths: &SettingsPaths,
    payload: &Value,
    cancellation: CancellationToken,
) -> Value {
    let name = value_string(payload, "fileName", "").trim().to_string();
    if !EDITABLE_NIRI_FILES.contains(&name.as_str()) {
        return json!({"ok": false, "message": "This Niri file is not editable here"});
    }
    let mut content = value_string(payload, "content", "");
    if content.trim().is_empty() {
        return json!({"ok": false, "message": "Config file cannot be empty"});
    }
    if !content.ends_with('\n') {
        content.push('\n');
    }
    apply_niri_changes(
        paths,
        vec![NiriUpdate {
            path: paths.include_dir.join(&name),
            content,
        }],
        &format!("{name} applied"),
        cancellation,
    )
    .await
}

pub async fn keybind(
    paths: &SettingsPaths,
    payload: &Value,
    cancellation: CancellationToken,
) -> Value {
    let path = paths.include_dir.join("keybinds.kdl");
    let old_header = value_string(payload, "oldHeader", "").trim().to_string();
    let new_key = value_string(payload, "newKey", "").trim().to_string();
    if old_header.is_empty() || new_key.is_empty() {
        return json!({"ok": false, "message": "A key combination is required"});
    }
    let valid_key = Regex::new(r"^[A-Za-z0-9_+\-]+$").expect("static key regex");
    if !valid_key.is_match(&new_key) {
        return json!({"ok": false, "message": "The captured key combination is not valid for Niri"});
    }
    let original = match read_file(&path) {
        Ok(value) => value,
        Err(error) => return failure(error),
    };
    let binding_pattern = Regex::new(r"^\s*([^/{][^{]*?)\s*\{").expect("static binding regex");
    for raw in original.lines() {
        let Some(captures) = binding_pattern.captures(raw) else {
            continue;
        };
        let header = captures[1].trim();
        if header != old_header && header.split_whitespace().next().unwrap_or_default() == new_key {
            return json!({
                "ok": false,
                "message": format!("{} is already assigned", pretty_key(&new_key)),
            });
        }
    }

    let old_key = old_header.split_whitespace().next().unwrap_or_default();
    let option_suffix = old_header.strip_prefix(old_key).unwrap_or_default();
    let mut replaced = false;
    let mut updated = String::with_capacity(original.len());
    for raw in original.split_inclusive('\n') {
        if !replaced
            && let Some(captures) = binding_pattern.captures(raw)
            && captures[1].trim() == old_header
        {
            let header = captures.get(1).expect("binding header");
            updated.push_str(&raw[..header.start()]);
            updated.push_str(&new_key);
            updated.push_str(option_suffix);
            updated.push_str(&raw[header.end()..]);
            replaced = true;
        } else {
            updated.push_str(raw);
        }
    }
    if !replaced {
        return json!({
            "ok": false,
            "message": "The keybind changed on disk; refresh and try again",
        });
    }
    apply_niri_changes(
        paths,
        vec![NiriUpdate {
            path,
            content: updated,
        }],
        &format!("Keybind changed to {}", pretty_key(&new_key)),
        cancellation,
    )
    .await
}

pub async fn input(
    paths: &SettingsPaths,
    payload: &Value,
    cancellation: CancellationToken,
) -> Value {
    let path = paths.include_dir.join("input.kdl");
    let section = value_string(payload, "section", "").trim().to_string();
    let entry_index = value_i64(payload, "entryIndex", -1);
    let new_line = value_string(payload, "value", "")
        .trim()
        .trim_end_matches(';')
        .to_string();
    let Some(block_name) = input_block_name(&section) else {
        return json!({"ok": false, "message": "Unknown input setting"});
    };
    if entry_index < 0 {
        return json!({"ok": false, "message": "Unknown input setting"});
    }
    if new_line.is_empty()
        || new_line.contains('\n')
        || new_line
            .chars()
            .any(|character| matches!(character, '{' | '}'))
    {
        return json!({
            "ok": false,
            "message": "Input values must be a single KDL setting",
        });
    }
    let original = match read_file(&path) {
        Ok(value) => value,
        Err(error) => return failure(error),
    };
    let updated = match update_input_entry(
        &original,
        block_name,
        entry_index as usize,
        |raw, parsed| {
            let indent_length = raw.len() - raw.trim_start().len();
            let ending = if raw.ends_with('\n') { "\n" } else { "" };
            Ok(format!(
                "{}{}{}{}",
                &raw[..indent_length],
                if parsed.1 { "" } else { "// " },
                new_line,
                ending
            ))
        },
    ) {
        Ok(value) => value,
        Err(error) => return failure(error),
    };
    apply_niri_changes(
        paths,
        vec![NiriUpdate {
            path,
            content: updated,
        }],
        &format!("{section} setting updated"),
        cancellation,
    )
    .await
}

pub async fn input_enabled(
    paths: &SettingsPaths,
    payload: &Value,
    cancellation: CancellationToken,
) -> Value {
    let path = paths.include_dir.join("input.kdl");
    let section = value_string(payload, "section", "").trim().to_string();
    let Some(block_name) = input_block_name(&section).filter(|name| *name != "keyboard") else {
        return json!({"ok": false, "message": "This input section cannot be disabled"});
    };
    let updated = match read_file(&path).and_then(|source| {
        set_block_flag(
            &source,
            block_name,
            "off",
            !value_bool(payload, "enabled", true),
        )
    }) {
        Ok(value) => value,
        Err(error) => return failure(error),
    };
    apply_niri_changes(
        paths,
        vec![NiriUpdate {
            path,
            content: updated,
        }],
        &format!("{section} state updated"),
        cancellation,
    )
    .await
}

pub async fn input_entry_enabled(
    paths: &SettingsPaths,
    payload: &Value,
    cancellation: CancellationToken,
) -> Value {
    let path = paths.include_dir.join("input.kdl");
    let section = value_string(payload, "section", "").trim().to_string();
    let entry_index = value_i64(payload, "entryIndex", -1);
    let enabled = value_bool(payload, "enabled", true);
    let Some(block_name) = input_block_name(&section) else {
        return json!({"ok": false, "message": "Unknown input setting"});
    };
    if entry_index < 0 {
        return json!({"ok": false, "message": "Unknown input setting"});
    }
    let original = match read_file(&path) {
        Ok(value) => value,
        Err(error) => return failure(error),
    };
    let updated = match update_input_entry(
        &original,
        block_name,
        entry_index as usize,
        |raw, parsed| {
            let indent_length = raw.len() - raw.trim_start().len();
            let ending = if raw.ends_with('\n') { "\n" } else { "" };
            Ok(format!(
                "{}{}{}{}",
                &raw[..indent_length],
                if enabled { "" } else { "// " },
                parsed.0,
                ending
            ))
        },
    ) {
        Ok(value) => value,
        Err(error) => return failure(error),
    };
    apply_niri_changes(
        paths,
        vec![NiriUpdate {
            path,
            content: updated,
        }],
        &format!("{section} option updated"),
        cancellation,
    )
    .await
}

fn input_block_name(section: &str) -> Option<&'static str> {
    INPUT_SECTIONS
        .iter()
        .find_map(|(name, block)| (*name == section).then_some(*block))
}

fn update_input_entry<F>(
    original: &str,
    block_name: &str,
    entry_index: usize,
    updater: F,
) -> Result<String>
where
    F: FnOnce(&str, (String, bool)) -> Result<String>,
{
    let mut updater = Some(updater);
    update_block(original, block_name, |block| {
        let mut current_index = 0_usize;
        let mut replaced = false;
        let mut updated = String::with_capacity(block.len());
        for raw in block.split_inclusive('\n') {
            if !replaced && let Some(parsed) = parse_input_line(raw) {
                if current_index == entry_index {
                    updated.push_str(&updater.take().expect("input updater is called once")(
                        raw, parsed,
                    )?);
                    replaced = true;
                } else {
                    updated.push_str(raw);
                }
                current_index += 1;
            } else {
                updated.push_str(raw);
            }
        }
        if !replaced {
            bail!("The input setting changed on disk; refresh and try again");
        }
        Ok(updated)
    })
}

fn pretty_key(raw: &str) -> String {
    let option_pattern = Regex::new(r"\s+(?:repeat|cooldown-ms|allow-when-locked)=[^\s]+")
        .expect("static key option regex");
    let key = option_pattern.replace_all(raw, "");
    key.trim()
        .split('+')
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

pub async fn quickshell(
    paths: &SettingsPaths,
    payload: &Value,
    cancellation: CancellationToken,
) -> Value {
    let settings = match sanitize_quickshell(paths, payload) {
        Ok(settings) => settings,
        Err(error) => return failure(error),
    };
    let behavior_path = paths.include_dir.join("behavior.kdl");
    let behavior_original = match read_file(&behavior_path) {
        Ok(value) => value,
        Err(error) => return failure(error),
    };
    let screenshot_dir = settings
        .get("captureScreenshotDirPath")
        .map(json_text)
        .unwrap_or_default()
        .trim_end_matches('/')
        .to_string();
    let screenshot_dir = if screenshot_dir.is_empty() {
        "~/Pictures/Screenshots".to_string()
    } else {
        screenshot_dir
    };
    let screenshot_pattern = format!("{screenshot_dir}/Screenshot from %Y-%m-%d %H-%M-%S.png");
    let behavior_updated = match replace_once_with(
        &behavior_original,
        r#"(?m)^(\s*screenshot-path\s+)"[^"]*"\s*$"#,
        "Niri screenshot path",
        |captures| format!("{}{}", &captures[1], json_quote(&screenshot_pattern)),
    ) {
        Ok(value) => value,
        Err(error) => return failure(error),
    };
    if behavior_updated != behavior_original {
        let response = apply_niri_changes(
            paths,
            vec![NiriUpdate {
                path: behavior_path,
                content: behavior_updated,
            }],
            "SownteeShell Settings and Niri screenshot path saved",
            cancellation,
        )
        .await;
        if response.get("ok").and_then(Value::as_bool) != Some(true) {
            return response;
        }
    }

    let mut encoded = match serde_json::to_string_pretty(&Value::Object(settings)) {
        Ok(value) => value,
        Err(error) => return failure(error),
    };
    encoded.push('\n');
    match atomic_write(&paths.runtime_settings, &encoded, Some(0o600)) {
        Ok(()) => json!({"ok": true, "message": "SownteeShell Settings applied"}),
        Err(error) => failure(error),
    }
}

pub async fn gtk(
    paths: &SettingsPaths,
    payload: &Value,
    cancellation: CancellationToken,
) -> Value {
    let gtk_fb = snapshot::gtk_defaults();
    let qt_fb = snapshot::qt_defaults();
    let fb_str = |map: &serde_json::Map<String, Value>, key: &str, default: &str| {
        map.get(key)
            .and_then(Value::as_str)
            .unwrap_or(default)
            .to_string()
    };
    let fb_i64 = |map: &serde_json::Map<String, Value>, key: &str, default: i64| {
        map.get(key).and_then(Value::as_i64).unwrap_or(default)
    };

    let gtk_theme = match required_setting(payload, "gtkTheme", "GTK theme") {
        Ok(val) => val,
        Err(_) => fb_str(&gtk_fb, "gtkTheme", "adw-gtk3-dark"),
    };
    let icon_theme = match required_setting(payload, "iconTheme", "icon theme") {
        Ok(val) => val,
        Err(_) => fb_str(&gtk_fb, "iconTheme", "WhiteSur"),
    };
    let cursor_theme = match required_setting(payload, "cursorTheme", "cursor theme") {
        Ok(val) => val,
        Err(_) => fb_str(&gtk_fb, "cursorTheme", "Dark_Cursor"),
    };
    let font_name = match required_setting(payload, "fontName", "interface font") {
        Ok(val) => val,
        Err(_) => fb_str(&gtk_fb, "fontName", "SF Pro Text 10.5"),
    };
    let cursor_size = value_i64(payload, "cursorSize", fb_i64(&gtk_fb, "cursorSize", 24)).clamp(12, 128);
    let cursor_size_str = cursor_size.to_string();

    let values = [
        ("gtk-theme", &gtk_theme),
        ("icon-theme", &icon_theme),
        ("cursor-theme", &cursor_theme),
        ("cursor-size", &cursor_size_str),
        ("font-name", &font_name),
    ];

    for (key, value) in values {
        if let Err(error) = set_gsettings_value(key, value, &cancellation).await {
            return failure(error);
        }
    }

    // Synchronize cursor in Niri include/cursor.kdl
    let cursor_path = paths.include_dir.join("cursor.kdl");
    if cursor_path.is_file() {
        if let Ok(mut cursor) = read_file(&cursor_path) {
            let mut changed = false;
            if let Ok(updated) = replace_once_with(
                &cursor,
                r#"(?m)^(\s*xcursor-theme\s+)"[^"]+""#,
                "cursor theme",
                |captures| format!("{}{}", &captures[1], json_quote(&cursor_theme)),
            ) {
                cursor = updated;
                changed = true;
            }
            if let Ok(updated) = replace_once_with(
                &cursor,
                r"(?m)^(\s*xcursor-size\s+)\d+",
                "cursor size",
                |captures| format!("{}{cursor_size}", &captures[1]),
            ) {
                cursor = updated;
                changed = true;
            }
            if changed {
                let _ = apply_niri_changes(
                    paths,
                    vec![NiriUpdate {
                        path: cursor_path,
                        content: cursor,
                    }],
                    "Niri cursor updated",
                    cancellation.clone(),
                )
                .await;
            }
        }
    }

    let qt_style = non_empty_string(payload, "qtStyle", &fb_str(&qt_fb, "qtStyle", "kvantum"));
    let qt_color_scheme = non_empty_string(payload, "qtColorScheme", &fb_str(&qt_fb, "qtColorScheme", "matugen"));
    let qt_dialogs = allowed_string(
        payload,
        "qtDialogs",
        &fb_str(&qt_fb, "qtDialogs", "gtk3"),
        &["gtk3", "default", "xdgdesktopportal"],
    );

    // Synchronize Qt5 and Qt6 configuration (qt5ct / qt6ct)
    if let Err(error) = sync_qt_settings(&icon_theme, &font_name, &qt_style, &qt_color_scheme, &qt_dialogs) {
        eprintln!("Warning: failed to synchronize Qt settings: {error}");
    }

    // Synchronize GTK 3 and GTK 4 settings.ini
    if let Err(error) = sync_gtk_ini_settings(&gtk_theme, &icon_theme, &cursor_theme, cursor_size, &font_name) {
        eprintln!("Warning: failed to synchronize GTK settings.ini: {error}");
    }

    // Broadcast XSettings for XWayland applications
    let _ = crate::theme::xsettings::apply(&gtk_theme, &icon_theme, &cursor_theme, cursor_size as i32);

    json!({"ok": true, "message": "GTK and Qt appearance applied"})
}

pub async fn general(
    paths: &SettingsPaths,
    payload: &Value,
    cancellation: CancellationToken,
) -> Value {
    let quickshell_payload = payload.get("quickshell").unwrap_or(&Value::Null);
    let gtk_payload = payload.get("gtk").unwrap_or(&Value::Null);

    let quickshell_result = quickshell(paths, quickshell_payload, cancellation.clone()).await;
    if quickshell_result.get("ok").and_then(Value::as_bool) != Some(true) {
        return quickshell_result;
    }

    let gtk_result = gtk(paths, gtk_payload, cancellation).await;
    if gtk_result.get("ok").and_then(Value::as_bool) != Some(true) {
        return gtk_result;
    }

    json!({"ok": true, "message": "General, GTK and Qt settings applied"})
}

fn sync_qt_settings(
    icon_theme: &str,
    font_name: &str,
    style: &str,
    color_scheme: &str,
    dialogs: &str,
) -> Result<()> {
    let (family, size) = parse_font_name(font_name);
    let qt5_font = format!("\"{family},{size},-1,5,50,0,0,0,0,0\"");
    let qt6_font = format!("\"{family},{size},-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0\"");

    let config_dir = std::env::var_os("XDG_CONFIG_HOME")
        .map(std::path::PathBuf::from)
        .or_else(|| {
            std::env::var_os("HOME").map(|home| std::path::PathBuf::from(home).join(".config"))
        })
        .context("could not determine user configuration directory")?;

    let qt5_path = config_dir.join("qt5ct/qt5ct.conf");
    let qt6_path = config_dir.join("qt6ct/qt6ct.conf");

    sync_single_qt_conf(&qt5_path, "qt5ct", &config_dir, icon_theme, &qt5_font, style, color_scheme, dialogs)?;
    sync_single_qt_conf(&qt6_path, "qt6ct", &config_dir, icon_theme, &qt6_font, style, color_scheme, dialogs)?;

    Ok(())
}

fn parse_font_name(font_name: &str) -> (String, String) {
    let text = font_name.trim();
    if let Ok(re) = Regex::new(r"^(.+?)\s+([0-9]+(?:\.[0-9]+)?)$") {
        if let Some(captures) = re.captures(text) {
            let family = captures
                .get(1)
                .map(|m| m.as_str().trim().to_string())
                .unwrap_or_else(|| "SF Pro Text".into());
            let size = captures
                .get(2)
                .map(|m| m.as_str().trim().to_string())
                .unwrap_or_else(|| "10.5".into());
            return (family, size);
        }
    }
    (text.to_string(), "10.5".into())
}

fn sync_single_qt_conf(
    path: &std::path::Path,
    ct_name: &str,
    config_dir: &std::path::Path,
    icon_theme: &str,
    font_value: &str,
    style: &str,
    color_scheme: &str,
    dialogs: &str,
) -> Result<()> {
    let target = fs::canonicalize(path).unwrap_or_else(|_| path.to_path_buf());
    let original = fs::read_to_string(&target).unwrap_or_default();

    let (custom_palette_val, resolved_color_path) = match color_scheme {
        "system" => (false, String::new()),
        "style" => (true, format!("~/.config/{ct_name}/colors/style-colors.conf")),
        val => {
            let kcolor_path = format!("/usr/share/color-schemes/{val}.colors");
            let local_kcolor = config_dir
                .parent()
                .unwrap_or(config_dir)
                .join(format!(".local/share/color-schemes/{val}.colors"));
            if local_kcolor.is_file() {
                (true, local_kcolor.to_string_lossy().to_string())
            } else if std::path::Path::new(&kcolor_path).is_file() {
                (true, kcolor_path)
            } else {
                let user_color = format!("~/.config/{ct_name}/colors/{val}.conf");
                let expanded_user_color = config_dir.join(format!("{ct_name}/colors/{val}.conf"));
                let system_color = format!("/usr/share/{ct_name}/colors/{val}.conf");
                if expanded_user_color.is_file() {
                    (true, user_color)
                } else if std::path::Path::new(&system_color).is_file() {
                    (true, system_color)
                } else {
                    (true, user_color)
                }
            }
        }
    };

    let updated = update_qt_conf_content(
        &original,
        icon_theme,
        font_value,
        style,
        &resolved_color_path,
        custom_palette_val,
        dialogs,
    );

    if let Some(parent) = target.parent() {
        let _ = fs::create_dir_all(parent);
    }
    fs::write(&target, updated.as_bytes())
        .with_context(|| format!("write {}", target.display()))?;
    Ok(())
}

fn update_qt_conf_content(
    original: &str,
    icon_theme: &str,
    font_value: &str,
    style: &str,
    color_scheme_path: &str,
    custom_palette: bool,
    dialogs: &str,
) -> String {
    if original.trim().is_empty() {
        return format!(
            "[Appearance]\ncolor_scheme_path={color_scheme_path}\ncustom_palette={custom_palette}\nicon_theme={icon_theme}\nstandard_dialogs={dialogs}\nstyle={style}\n\n[Fonts]\nfixed={font_value}\ngeneral={font_value}\n\n[Interface]\nactivate_item_on_single_click=1\nbuttonbox_layout=0\ncursor_flash_time=1000\ndialog_buttons_have_icons=1\ndouble_click_interval=400\ngui_effects=@Invalid()\nkeyboard_scheme=2\nmenus_have_icons=true\nshow_shortcuts_in_context_menus=true\nstylesheets=@Invalid()\ntoolbutton_style=4\nunderline_shortcut=1\nwheel_scroll_lines=3\n\n[Troubleshooting]\nforce_raster_widgets=1\nignored_applications=@Invalid()\n"
        );
    }

    let mut lines: Vec<String> = Vec::new();
    let mut in_appearance = false;
    let mut in_fonts = false;
    let mut found_style = false;
    let mut found_palette = false;
    let mut found_color = false;
    let mut found_icon = false;
    let mut found_dialogs = false;
    let mut found_fixed = false;
    let mut found_general = false;
    let mut has_appearance_header = false;
    let mut has_fonts_header = false;

    for line in original.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with('[') && trimmed.ends_with(']') {
            if in_appearance {
                if !found_color { lines.push(format!("color_scheme_path={color_scheme_path}")); }
                if !found_palette { lines.push(format!("custom_palette={custom_palette}")); }
                if !found_icon { lines.push(format!("icon_theme={icon_theme}")); }
                if !found_dialogs { lines.push(format!("standard_dialogs={dialogs}")); }
                if !found_style { lines.push(format!("style={style}")); }
            } else if in_fonts {
                if !found_fixed { lines.push(format!("fixed={font_value}")); }
                if !found_general { lines.push(format!("general={font_value}")); }
            }

            if trimmed == "[Appearance]" {
                in_appearance = true;
                in_fonts = false;
                has_appearance_header = true;
            } else if trimmed == "[Fonts]" {
                in_appearance = false;
                in_fonts = true;
                has_fonts_header = true;
            } else {
                in_appearance = false;
                in_fonts = false;
            }
            lines.push(line.to_string());
            continue;
        }

        if in_appearance {
            if trimmed.starts_with("style=") || trimmed.starts_with("style =") {
                lines.push(format!("style={style}"));
                found_style = true;
                continue;
            }
            if trimmed.starts_with("custom_palette=") || trimmed.starts_with("custom_palette =") {
                lines.push(format!("custom_palette={custom_palette}"));
                found_palette = true;
                continue;
            }
            if trimmed.starts_with("color_scheme_path=") || trimmed.starts_with("color_scheme_path =") {
                lines.push(format!("color_scheme_path={color_scheme_path}"));
                found_color = true;
                continue;
            }
            if trimmed.starts_with("icon_theme=") || trimmed.starts_with("icon_theme =") {
                lines.push(format!("icon_theme={icon_theme}"));
                found_icon = true;
                continue;
            }
            if trimmed.starts_with("standard_dialogs=") || trimmed.starts_with("standard_dialogs =") {
                lines.push(format!("standard_dialogs={dialogs}"));
                found_dialogs = true;
                continue;
            }
        }

        if in_fonts {
            if trimmed.starts_with("fixed=") || trimmed.starts_with("fixed =") {
                lines.push(format!("fixed={font_value}"));
                found_fixed = true;
                continue;
            }
            if trimmed.starts_with("general=") || trimmed.starts_with("general =") {
                lines.push(format!("general={font_value}"));
                found_general = true;
                continue;
            }
        }

        lines.push(line.to_string());
    }

    if in_appearance {
        if !found_color { lines.push(format!("color_scheme_path={color_scheme_path}")); }
        if !found_palette { lines.push(format!("custom_palette={custom_palette}")); }
        if !found_icon { lines.push(format!("icon_theme={icon_theme}")); }
        if !found_dialogs { lines.push(format!("standard_dialogs={dialogs}")); }
        if !found_style { lines.push(format!("style={style}")); }
    } else if in_fonts {
        if !found_fixed { lines.push(format!("fixed={font_value}")); }
        if !found_general { lines.push(format!("general={font_value}")); }
    }

    if !has_appearance_header {
        lines.push(String::new());
        lines.push("[Appearance]".to_string());
        lines.push(format!("color_scheme_path={color_scheme_path}"));
        lines.push(format!("custom_palette={custom_palette}"));
        lines.push(format!("icon_theme={icon_theme}"));
        lines.push(format!("standard_dialogs={dialogs}"));
        lines.push(format!("style={style}"));
    }
    if !has_fonts_header {
        lines.push(String::new());
        lines.push("[Fonts]".to_string());
        lines.push(format!("fixed={font_value}"));
        lines.push(format!("general={font_value}"));
    }

    let mut result = lines.join("\n");
    result.push('\n');
    result
}

fn sync_gtk_ini_settings(
    gtk_theme: &str,
    icon_theme: &str,
    cursor_theme: &str,
    cursor_size: i64,
    font_name: &str,
) -> Result<()> {
    let config_dir = std::env::var_os("XDG_CONFIG_HOME")
        .map(std::path::PathBuf::from)
        .or_else(|| {
            std::env::var_os("HOME").map(|home| std::path::PathBuf::from(home).join(".config"))
        })
        .context("could not determine user configuration directory")?;

    for version in &["gtk-3.0", "gtk-4.0"] {
        let ini_path = config_dir.join(version).join("settings.ini");
        if ini_path.is_file() {
            let _ = update_gtk_ini_file(&ini_path, gtk_theme, icon_theme, cursor_theme, cursor_size, font_name);
        }
    }
    Ok(())
}

fn update_gtk_ini_file(
    path: &std::path::Path,
    gtk_theme: &str,
    icon_theme: &str,
    cursor_theme: &str,
    cursor_size: i64,
    font_name: &str,
) -> Result<()> {
    let target = fs::canonicalize(path).unwrap_or_else(|_| path.to_path_buf());
    let original = fs::read_to_string(&target)?;
    let updated = update_gtk_ini_content(&original, gtk_theme, icon_theme, cursor_theme, cursor_size, font_name);
    atomic_write(&target, &updated, Some(0o644))?;
    Ok(())
}

fn update_gtk_ini_content(
    original: &str,
    gtk_theme: &str,
    icon_theme: &str,
    cursor_theme: &str,
    cursor_size: i64,
    font_name: &str,
) -> String {
    let mut lines: Vec<String> = original.lines().map(str::to_string).collect();
    let mut found_theme = false;
    let mut found_icon = false;
    let mut found_cursor_theme = false;
    let mut found_cursor_size = false;
    let mut found_font = false;

    for line in &mut lines {
        let trimmed = line.trim();
        if trimmed.starts_with("gtk-theme-name=") || trimmed.starts_with("gtk-theme-name =") {
            *line = format!("gtk-theme-name={gtk_theme}");
            found_theme = true;
        } else if trimmed.starts_with("gtk-icon-theme-name=") || trimmed.starts_with("gtk-icon-theme-name =") {
            *line = format!("gtk-icon-theme-name={icon_theme}");
            found_icon = true;
        } else if trimmed.starts_with("gtk-cursor-theme-name=") || trimmed.starts_with("gtk-cursor-theme-name =") {
            *line = format!("gtk-cursor-theme-name={cursor_theme}");
            found_cursor_theme = true;
        } else if trimmed.starts_with("gtk-cursor-theme-size=") || trimmed.starts_with("gtk-cursor-theme-size =") {
            *line = format!("gtk-cursor-theme-size={cursor_size}");
            found_cursor_size = true;
        } else if trimmed.starts_with("gtk-font-name=") || trimmed.starts_with("gtk-font-name =") {
            *line = format!("gtk-font-name={font_name}");
            found_font = true;
        }
    }

    if !found_theme {
        lines.push(format!("gtk-theme-name={gtk_theme}"));
    }
    if !found_icon {
        lines.push(format!("gtk-icon-theme-name={icon_theme}"));
    }
    if !found_cursor_theme {
        lines.push(format!("gtk-cursor-theme-name={cursor_theme}"));
    }
    if !found_cursor_size {
        lines.push(format!("gtk-cursor-theme-size={cursor_size}"));
    }
    if !found_font {
        lines.push(format!("gtk-font-name={font_name}"));
    }

    let mut result = lines.join("\n");
    result.push('\n');
    result
}

fn required_setting(payload: &Value, key: &str, label: &str) -> Result<String> {
    let value = payload
        .get(key)
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .with_context(|| format!("{label} is required"))?;
    if value.len() > 256 || value.chars().any(char::is_control) {
        bail!("{label} contains invalid characters");
    }
    Ok(value.into())
}

async fn set_gsettings_value(
    key: &str,
    value: &str,
    cancellation: &CancellationToken,
) -> Result<()> {
    if cancellation.is_cancelled() {
        bail!("GTK appearance update cancelled");
    }

    let mut command = Command::new("gsettings");
    command
        .args(["set", "org.gnome.desktop.interface", key, value])
        .kill_on_drop(true);
    let output = tokio::select! {
        result = command.output() => result.with_context(|| format!("run gsettings for {key}"))?,
        _ = cancellation.cancelled() => bail!("GTK appearance update cancelled"),
    };
    if !output.status.success() {
        let message = String::from_utf8_lossy(&output.stderr).trim().to_string();
        bail!(
            "could not set {key}: {}",
            if message.is_empty() {
                "gsettings failed"
            } else {
                &message
            }
        );
    }
    Ok(())
}

fn sanitize_quickshell(paths: &SettingsPaths, payload: &Value) -> Result<Map<String, Value>> {
    let defaults = snapshot::defaults();
    let mut stored = fs::read_to_string(&paths.runtime_settings)
        .ok()
        .and_then(|source| serde_json::from_str::<Value>(&source).ok())
        .and_then(|value| value.as_object().cloned())
        .unwrap_or_default();
    let legacy_timeout = stored
        .get("notificationPopupDuration")
        .cloned()
        .or_else(|| defaults.get("notificationPopupDuration").cloned())
        .unwrap_or_else(|| json!(5000));
    stored
        .entry("notificationLowTimeout")
        .or_insert_with(|| legacy_timeout.clone());
    stored
        .entry("notificationNormalTimeout")
        .or_insert(legacy_timeout);
    if !valid_privacy(stored.get("notificationLockscreenPrivacy")) {
        let show = stored
            .get("notificationShowOnLock")
            .map(snapshot::json_truthy)
            .unwrap_or(false);
        stored.insert(
            "notificationLockscreenPrivacy".into(),
            Value::String(if show { "full" } else { "hidden" }.into()),
        );
    }
    let mut supplied = payload.as_object().cloned().unwrap_or_default();
    if !valid_privacy(supplied.get("notificationLockscreenPrivacy"))
        && supplied.contains_key("notificationShowOnLock")
    {
        let show = supplied
            .get("notificationShowOnLock")
            .map(snapshot::json_truthy)
            .unwrap_or(false);
        supplied.insert(
            "notificationLockscreenPrivacy".into(),
            Value::String(if show { "full" } else { "hidden" }.into()),
        );
    }
    let legacy_blur = stored
        .get("shellBlurEnabled")
        .map(snapshot::json_truthy)
        .unwrap_or(true);
    for key in snapshot::blur_keys() {
        stored.entry(*key).or_insert(Value::Bool(legacy_blur));
    }

    let mut merged = defaults.clone();
    for (key, value) in stored.into_iter().chain(supplied) {
        if defaults.contains_key(&key) {
            merged.insert(key, value);
        }
    }
    let mut settings = merged.clone();
    for name in [
        "fontName",
        "greeterDefaultSession",
        "profileImagePath",
        "latLon",
        "apiWeather",
        "steamUsername",
        "steamWebApiKey",
        "launcherKlipyApiKey",
        "wallhavenUsername",
        "wallhavenApiKey",
        "wallFolderPath",
        "liveWallFolderPath",
        "wallpaperScalingMode",
        "captureScreenshotDirPath",
        "captureRecordingDirPath",
        "captureRecordingCodec",
        "captureRecordingQuality",
        "captureRecordingMicrophoneSource",
        "captureRecordingMode",
        "captureScreenshotAction",
        "captureScreenshotFilenameTemplate",
        "captureScreenshotFormat",
        "captureEditorTool",
        "captureEditorColor",
        "wallpaperEngineAssetsDirPath",
        "wallpaperEngineWorkshopDirPath",
        "notificationBlockedApps",
        "notificationHistoryExcludedApps",
        "notificationLockscreenPrivacy",
    ] {
        let fallback = defaults.get(name).map(json_text).unwrap_or_default();
        settings.insert(
            name.into(),
            Value::String(
                merged
                    .get(name)
                    .map(json_text)
                    .unwrap_or(fallback)
                    .trim()
                    .to_string(),
            ),
        );
    }
    if settings
        .get("fontName")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .is_empty()
    {
        settings.insert("fontName".into(), Value::String("Inter Variable".into()));
    }
    let greeter_session = settings
        .get("greeterDefaultSession")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .chars()
        .take(80)
        .filter(|character| {
            character.is_ascii_alphanumeric() || matches!(character, '.' | '_' | '+' | '-')
        })
        .collect::<String>();
    settings.insert(
        "greeterDefaultSession".into(),
        Value::String(if greeter_session.is_empty() {
            "niri".into()
        } else {
            greeter_session
        }),
    );

    let prefix_defaults = [
        ("launcherClipboardPrefix", "c"),
        ("launcherFilesPrefix", "f"),
        ("launcherCalculatorPrefix", "="),
        ("launcherEmojiPrefix", "e"),
        ("launcherGifPrefix", "g"),
        ("launcherStickerPrefix", "s"),
    ];
    let available_fallbacks = prefix_defaults.map(|(_, fallback)| fallback);
    let mut used_prefixes = HashSet::new();
    for (name, fallback) in prefix_defaults {
        let prefix = merged
            .get(name)
            .map(json_text)
            .unwrap_or_else(|| fallback.into())
            .chars()
            .filter(|character| !character.is_whitespace())
            .collect::<String>();
        let mut candidate = if prefix.is_empty() {
            fallback.to_string()
        } else {
            prefix.chars().take(3).collect()
        };
        if used_prefixes.contains(&candidate.to_lowercase()) {
            candidate = available_fallbacks
                .iter()
                .find(|value| !used_prefixes.contains(&value.to_lowercase()))
                .copied()
                .unwrap_or(fallback)
                .to_string();
        }
        used_prefixes.insert(candidate.to_lowercase());
        settings.insert(name.into(), Value::String(candidate));
    }

    let time_pattern = Regex::new(r"^(?:[01]\d|2[0-3]):[0-5]\d$")?;
    for (name, fallback) in [
        ("notificationDndStart", "23:00"),
        ("notificationDndEnd", "07:00"),
    ] {
        let value = merged
            .get(name)
            .map(json_text)
            .unwrap_or_else(|| fallback.into())
            .trim()
            .to_string();
        settings.insert(
            name.into(),
            Value::String(if time_pattern.is_match(&value) {
                value
            } else {
                fallback.into()
            }),
        );
    }
    set_enum(
        &mut settings,
        &merged,
        "barDensity",
        "comfortable",
        &["compact", "comfortable", "spacious"],
        false,
    );
    set_enum(
        &mut settings,
        &merged,
        "launcherCalculatorAngleMode",
        "rad",
        &["deg", "rad"],
        true,
    );
    set_enum(
        &mut settings,
        &merged,
        "temperatureUnit",
        "celsius",
        &["celsius", "fahrenheit"],
        true,
    );
    set_enum(
        &mut settings,
        &merged,
        "wallpaperScalingMode",
        "fill",
        &["fill", "fit", "stretch"],
        true,
    );
    for name in ["idleSleepAction", "idleBatterySleepAction"] {
        set_enum(
            &mut settings,
            &merged,
            name,
            "suspend",
            &["none", "suspend", "suspend-then-hibernate", "hibernate"],
            true,
        );
    }
    set_enum(
        &mut settings,
        &merged,
        "notificationPosition",
        "top",
        &["top", "top-right", "bottom-right"],
        false,
    );
    set_enum(
        &mut settings,
        &merged,
        "notificationLockscreenPrivacy",
        "hidden",
        &["hidden", "icons", "full"],
        true,
    );
    let show_on_lock = settings
        .get("notificationLockscreenPrivacy")
        .and_then(Value::as_str)
        != Some("hidden");
    settings.insert("notificationShowOnLock".into(), Value::Bool(show_on_lock));
    set_enum(
        &mut settings,
        &merged,
        "osdPosition",
        "bottom",
        &["top", "bottom"],
        false,
    );
    normalize_existing_enum(
        &mut settings,
        "captureRecordingCodec",
        "hevc",
        &["h264", "hevc"],
    );
    normalize_existing_enum(
        &mut settings,
        "captureRecordingQuality",
        "high",
        &["medium", "high", "very_high"],
    );
    normalize_existing_enum(
        &mut settings,
        "captureRecordingMode",
        "region",
        &["region", "screen"],
    );
    normalize_existing_enum(
        &mut settings,
        "captureScreenshotAction",
        "notification",
        &["notification", "editor", "copy", "save"],
    );
    normalize_existing_enum(
        &mut settings,
        "captureScreenshotFormat",
        "png",
        &["png", "jpeg", "webp"],
    );
    let microphone_source = settings
        .get("captureRecordingMicrophoneSource")
        .map(json_text)
        .unwrap_or_default()
        .replace('\0', "")
        .trim()
        .chars()
        .take(512)
        .collect::<String>();
    settings.insert(
        "captureRecordingMicrophoneSource".into(),
        Value::String(if microphone_source.is_empty() {
            "default_input".into()
        } else {
            microphone_source
        }),
    );
    let filename_template = settings
        .get("captureScreenshotFilenameTemplate")
        .map(json_text)
        .unwrap_or_default()
        .replace('\0', "")
        .trim()
        .replace(['/', '\\'], "-")
        .chars()
        .take(128)
        .collect::<String>();
    settings.insert(
        "captureScreenshotFilenameTemplate".into(),
        Value::String(if filename_template.is_empty() {
            "{date}_{time}-edited".into()
        } else {
            filename_template
        }),
    );
    normalize_existing_enum(
        &mut settings,
        "captureEditorTool",
        "pen",
        &[
            "select",
            "pen",
            "line",
            "rectangle",
            "ellipse",
            "arrow",
            "highlight",
            "blur",
            "pixelate",
            "text",
            "number",
            "callout",
            "loupe",
            "crop",
            "ocr",
            "eraser",
        ],
    );
    let recording_countdown = python_i64(merged.get("captureRecordingCountdown"), 0);
    settings.insert(
        "captureRecordingCountdown".into(),
        json!(if [0, 3, 5, 10].contains(&recording_countdown) {
            recording_countdown
        } else {
            0
        }),
    );

    for (name, minimum, maximum, fallback) in [
        ("barHeight", 40, 72, 50),
        ("caffeineAutoDisableMinutes", 0, 720, 0),
        ("idleBatteryDisplayTimeout", 0, 86400, 300),
        ("idleBatteryLockTimeout", 0, 86400, 300),
        ("idleBatterySuspendTimeout", 0, 86400, 900),
        ("idleDimDuration", 0, 30, 5),
        ("idleDisplayTimeout", 0, 86400, 600),
        ("idleLockedDisplayTimeout", 0, 86400, 60),
        ("idleLockTimeout", 0, 86400, 600),
        ("idleSuspendTimeout", 0, 86400, 0),
        ("lockFaceMaxAttempts", 1, 3, 3),
        ("launcherMaxResults", 5, 50, 20),
        ("notificationCriticalTimeout", 0, 60000, 0),
        ("notificationHistoryLimit", 0, 500, 100),
        ("notificationLowTimeout", 0, 60000, 5000),
        ("notificationMaxVisible", 1, 6, 3),
        ("notificationNormalTimeout", 0, 60000, 5000),
        ("notificationPopupDuration", 1000, 30000, 5000),
        ("osdDuration", 500, 10000, 2000),
        ("wallpaperBatteryFps", 5, 60, 20),
        ("wallpaperEngineFps", 5, 165, 30),
        ("wallpaperTransitionDuration", 0, 2000, 360),
        ("matugenTransitionDuration", 0, 2000, 300),
        ("captureRecordingFps", 5, 165, 60),
        ("captureScreenshotQuality", 1, 100, 90),
        ("captureEditorWidth", 1, 96, 6),
    ] {
        let value = python_i64(merged.get(name), fallback).clamp(minimum, maximum);
        settings.insert(name.into(), json!(value));
    }
    for (name, minimum, maximum, fallback) in [
        ("audioMaxVolume", 0.5, 1.5, 1.0),
        ("idleDimOpacity", 0.2, 0.9, 0.55),
        ("shellAnimationScale", 0.0, 2.0, 1.0),
        ("shellBlurBarOpacityDark", 0.0, 1.0, 0.24),
        ("shellBlurBarOpacityLight", 0.0, 1.0, 0.86),
        ("shellBlurPanelOpacityDark", 0.0, 1.0, 0.76),
        ("shellBlurPanelOpacityLight", 0.0, 1.0, 0.88),
        ("shellComponentShadowBlur", 0.0, 64.0, 10.0),
        ("shellComponentShadowOffsetX", -32.0, 32.0, 0.0),
        ("shellComponentShadowOffsetY", -32.0, 32.0, 2.0),
        ("shellComponentShadowOpacity", 0.0, 1.0, 0.18),
        ("shellComponentShadowSpread", -32.0, 32.0, 0.0),
        ("shellShadowBlur", 0.0, 64.0, 18.0),
        ("shellShadowOffsetX", -32.0, 32.0, 0.0),
        ("shellShadowOffsetY", -32.0, 32.0, 3.0),
        ("shellShadowOpacity", 0.0, 1.0, 0.28),
        ("shellShadowSpread", -32.0, 32.0, 1.0),
    ] {
        let value = python_f64(merged.get(name), fallback).clamp(minimum, maximum);
        settings.insert(name.into(), json!(value));
    }
    for (name, fallback) in [
        ("barShowActiveClient", true),
        ("barShowBattery", true),
        ("barShowBluetooth", true),
        ("barShowClock", true),
        ("barShowMedia", true),
        ("barShowMicrophone", true),
        ("barShowNetwork", true),
        ("barShowNotifications", true),
        ("barShowRecording", true),
        ("barShowSysTray", true),
        ("barShowWeather", true),
        ("barShowWorkspaces", true),
        ("cavaEnabled", true),
        ("idleEnabled", true),
        ("idleLockBeforeSleep", true),
        ("idleRespectInhibitors", true),
        ("idleSeparatePowerProfiles", false),
        ("lockFaceRetryOnWake", true),
        ("launcherCalculatorEnabled", true),
        ("launcherClipboardAutoPaste", true),
        ("launcherClipboardEnabled", true),
        ("launcherEmojiEnabled", true),
        ("launcherFilesEnabled", true),
        ("launcherFuzzySearch", true),
        ("launcherGifEnabled", true),
        ("launcherStickerEnabled", true),
        ("notificationDndScheduleEnabled", false),
        ("notificationShowInFullscreen", true),
        ("osdEnabled", true),
        ("osdShowBrightness", true),
        ("osdShowMicrophone", true),
        ("osdShowVolume", true),
        ("shellBlurBarEnabled", true),
        ("shellBlurControlLeftEnabled", true),
        ("shellBlurControlRightEnabled", true),
        ("shellBlurDockEnabled", true),
        ("shellBlurLauncherEnabled", true),
        ("shellBlurNotificationEnabled", true),
        ("shellBlurOsdEnabled", true),
        ("shellBlurSettingsEnabled", true),
        ("shellComponentShadowEnabled", true),
        ("shellLowPowerMode", false),
        ("shellReducedMotion", false),
        ("shellShadowEnabled", true),
        ("wallpaperPauseOnFullscreen", true),
        ("wallpaperPauseOnLock", true),
        ("matugenEnabled", true),
        ("matugenAnimateColors", true),
        ("captureAutoCopyScreenshot", true),
        ("captureAutoCopyRecording", true),
        ("captureRecordingMicrophone", false),
        ("captureRecordingCursor", true),
        ("clock24h", true),
        ("wallhavenShowNsfw", false),
        ("wallpaperWorkshopShowNsfw", false),
        ("greeterRememberLastSession", false),
    ] {
        let value = merged
            .get(name)
            .map(snapshot::json_truthy)
            .unwrap_or(fallback);
        settings.insert(name.into(), Value::Bool(value));
    }
    let privacy = settings
        .get("notificationLockscreenPrivacy")
        .and_then(Value::as_str)
        .unwrap_or_default();
    settings.insert(
        "notificationShowOnLock".into(),
        Value::Bool(privacy != "hidden"),
    );
    Ok(settings)
}

fn valid_privacy(value: Option<&Value>) -> bool {
    value
        .map(json_text)
        .map(|value| {
            matches!(
                value.to_ascii_lowercase().as_str(),
                "hidden" | "icons" | "full"
            )
        })
        .unwrap_or(false)
}

fn set_enum(
    settings: &mut Map<String, Value>,
    merged: &Map<String, Value>,
    name: &str,
    fallback: &str,
    allowed: &[&str],
    lowercase: bool,
) {
    let mut value = merged
        .get(name)
        .map(json_text)
        .unwrap_or_else(|| fallback.into());
    if lowercase {
        value = value.to_ascii_lowercase();
    }
    if !allowed.contains(&value.as_str()) {
        value = fallback.into();
    }
    settings.insert(name.into(), Value::String(value));
}

fn normalize_existing_enum(
    settings: &mut Map<String, Value>,
    name: &str,
    fallback: &str,
    allowed: &[&str],
) {
    let value = settings.get(name).map(json_text).unwrap_or_default();
    if !allowed.contains(&value.as_str()) {
        settings.insert(name.into(), Value::String(fallback.into()));
    }
}

fn python_i64(value: Option<&Value>, fallback: i64) -> i64 {
    match value {
        Some(Value::Bool(value)) => i64::from(*value),
        Some(Value::Number(value)) => value
            .as_i64()
            .or_else(|| value.as_f64().map(|value| value as i64))
            .unwrap_or(fallback),
        Some(Value::String(value)) => value.trim().parse().unwrap_or(fallback),
        _ => fallback,
    }
}

fn python_f64(value: Option<&Value>, fallback: f64) -> f64 {
    match value {
        Some(Value::Bool(value)) => f64::from(u8::from(*value)),
        Some(Value::Number(value)) => value.as_f64().unwrap_or(fallback),
        Some(Value::String(value)) => value.trim().parse().unwrap_or(fallback),
        _ => fallback,
    }
}

fn read_file(path: &std::path::Path) -> Result<String> {
    fs::read_to_string(path).with_context(|| format!("read {}", path.display()))
}

fn clean_color(payload: &Value, name: &str, fallback: &str) -> String {
    let value = value_string(payload, name, fallback)
        .replace('"', "")
        .trim()
        .to_string();
    if value.is_empty() {
        fallback.to_string()
    } else {
        value
    }
}

fn non_empty_string(payload: &Value, name: &str, fallback: &str) -> String {
    let value = value_string(payload, name, fallback).trim().to_string();
    if value.is_empty() {
        fallback.to_string()
    } else {
        value
    }
}

fn allowed_string(payload: &Value, name: &str, fallback: &str, allowed: &[&str]) -> String {
    let value = value_string(payload, name, fallback);
    if allowed.contains(&value.as_str()) {
        value
    } else {
        fallback.to_string()
    }
}

fn compact_float(value: f64) -> String {
    let mut text = format!("{value:.6}");
    while text.ends_with('0') {
        text.pop();
    }
    if text.ends_with('.') {
        text.pop();
    }
    if text.is_empty() || text == "-0" {
        "0".into()
    } else {
        text
    }
}

fn json_text(value: &Value) -> String {
    match value {
        Value::String(value) => value.clone(),
        Value::Bool(value) => {
            if *value {
                "True".into()
            } else {
                "False".into()
            }
        }
        Value::Null => "None".into(),
        Value::Number(value) => value.to_string(),
        value => value.to_string(),
    }
}

fn failure(error: impl std::fmt::Display) -> Value {
    json!({"ok": false, "message": error.to_string()})
}

#[cfg(test)]
mod tests {
    #[test]
    fn updates_gtk_ini_settings() {
        let sample = "[Settings]\ngtk-theme-name=OldTheme\ngtk-cursor-theme-size=24\n";
        let updated = update_gtk_ini_content(sample, "NewTheme", "NewIcons", "NewCursor", 32, "Inter 11");
        assert!(updated.contains("gtk-theme-name=NewTheme"));
        assert!(updated.contains("gtk-icon-theme-name=NewIcons"));
        assert!(updated.contains("gtk-cursor-theme-name=NewCursor"));
        assert!(updated.contains("gtk-cursor-theme-size=32"));
        assert!(updated.contains("gtk-font-name=Inter 11"));
    }

    use super::*;

    #[test]
    fn parses_font_names_with_sizes() {
        let (family, size) = parse_font_name("SF Pro Text 10.5");
        assert_eq!(family, "SF Pro Text");
        assert_eq!(size, "10.5");

        let (family, size) = parse_font_name("Inter Variable 11");
        assert_eq!(family, "Inter Variable");
        assert_eq!(size, "11");

        let (family, size) = parse_font_name("Noto Sans");
        assert_eq!(family, "Noto Sans");
        assert_eq!(size, "10.5");
    }

    #[test]
    fn updates_qt_conf_in_memory() {
        let sample = "[Appearance]\nicon_theme=OldTheme\nstyle=kvantum\n\n[Fonts]\nfixed=\"OldFont,10,-1,5,50,0,0,0,0,0\"\ngeneral=\"OldFont,10,-1,5,50,0,0,0,0,0\"\n";
        let temp_dir = std::env::temp_dir().join(format!("qt_test_{}", std::process::id()));
        let _ = fs::create_dir_all(&temp_dir);
        let file_path = temp_dir.join("qt5ct.conf");
        fs::write(&file_path, sample).unwrap();

        sync_single_qt_conf(
            &file_path,
            "qt5ct",
            &temp_dir,
            "WhiteSur",
            "\"SF Pro Text,10.5,-1,5,50,0,0,0,0,0\"",
            "kvantum",
            "matugen",
            "gtk3",
        )
        .unwrap();
        let content = fs::read_to_string(&file_path).unwrap();
        assert!(content.contains("icon_theme=WhiteSur"));
        assert!(content.contains("style=kvantum"));
        assert!(content.contains("standard_dialogs=gtk3"));
        assert!(content.contains("color_scheme_path="));
        assert!(content.contains("matugen.conf"));
        assert!(content.contains("general=\"SF Pro Text,10.5,-1,5,50,0,0,0,0,0\""));
        assert!(content.contains("fixed=\"SF Pro Text,10.5,-1,5,50,0,0,0,0,0\""));
        let _ = fs::remove_file(&file_path);
        let _ = fs::remove_dir(&temp_dir);
    }
}
