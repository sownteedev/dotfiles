use anyhow::{Context, Result, bail};
use std::cmp::Ordering;
use x11rb::connection::Connection;
use x11rb::protocol::xproto::{AtomEnum, ConnectionExt as _, PropMode};
use x11rb::wrapper::ConnectionExt as _;

const INTEGER: u8 = 0;
const STRING: u8 = 1;
const COLOR: u8 = 2;
const LITTLE_ENDIAN: u8 = 0;
const BIG_ENDIAN: u8 = 1;
const MAX_PROPERTY_LONGS: u32 = 1024 * 1024;
const MAX_SETTINGS: usize = 4096;

#[derive(Debug, Clone, PartialEq, Eq)]
enum Value {
    Integer(i32),
    String(Vec<u8>),
    Color([u16; 4]),
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct Setting {
    name: Vec<u8>,
    last_change_serial: u32,
    value: Value,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct Settings {
    byte_order: u8,
    serial: u32,
    entries: Vec<Setting>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ApplyReport {
    pub owner: u32,
    pub serial: u32,
    pub setting_count: usize,
}

pub fn apply(
    theme_name: &str,
    icon_theme_name: &str,
    cursor_theme_name: &str,
    cursor_theme_size: i32,
) -> Result<ApplyReport> {
    validate_name("theme", theme_name)?;
    validate_name("icon theme", icon_theme_name)?;
    validate_name("cursor theme", cursor_theme_name)?;
    if !(1..=1024).contains(&cursor_theme_size) {
        bail!("cursor theme size must be between 1 and 1024");
    }

    let (connection, screen_number) = x11rb::connect(None).context("connect to X display")?;
    let selection_name = format!("_XSETTINGS_S{screen_number}");
    let selection = intern_atom(&connection, selection_name.as_bytes())?;
    let property = intern_atom(&connection, b"_XSETTINGS_SETTINGS")?;
    let owner = connection
        .get_selection_owner(selection)
        .context("request XSETTINGS owner")?
        .reply()
        .context("read XSETTINGS owner")?
        .owner;
    if owner == x11rb::NONE {
        bail!("X display has no XSETTINGS manager");
    }

    let reply = connection
        .get_property(false, owner, property, AtomEnum::ANY, 0, MAX_PROPERTY_LONGS)
        .context("request current XSETTINGS property")?
        .reply()
        .context("read current XSETTINGS property")?;
    if reply.bytes_after != 0 {
        bail!("XSETTINGS property exceeds the supported size");
    }
    if reply.format != 0 && reply.format != 8 {
        bail!("XSETTINGS property has unsupported format {}", reply.format);
    }
    if reply.format == 8 && reply.type_ != property {
        bail!("XSETTINGS property has an unexpected atom type");
    }

    let mut settings = if reply.format == 0 || reply.value.is_empty() {
        Settings::empty()
    } else {
        Settings::decode(&reply.value).context("decode current XSETTINGS property")?
    };
    settings.serial = settings.serial.wrapping_add(1);
    let serial = settings.serial;
    settings.merge_string("Net/ThemeName", theme_name, serial);
    settings.merge_string("Net/IconThemeName", icon_theme_name, serial);
    settings.merge_string("Gtk/CursorThemeName", cursor_theme_name, serial);
    settings.merge_integer("Gtk/CursorThemeSize", cursor_theme_size, serial);
    settings.merge_string("Gtk/DecorationLayout", ":minimize,maximize,close", serial);
    settings.merge_integer("Net/EnableEventSounds", 1, serial);
    settings.merge_integer("Net/EnableInputFeedbackSounds", 0, serial);
    settings.merge_integer("Xft/Antialias", 1, serial);
    settings.merge_integer("Xft/Hinting", 1, serial);
    settings.merge_string("Xft/HintStyle", "hintslight", serial);
    settings.merge_string("Xft/RGBA", "rgb", serial);
    settings
        .entries
        .sort_by(|left, right| left.name.cmp(&right.name));

    let setting_count = settings.entries.len();
    let encoded = settings.encode()?;
    connection
        .change_property8(PropMode::REPLACE, owner, property, property, &encoded)
        .context("replace XSETTINGS property")?
        .check()
        .context("apply XSETTINGS property")?;
    connection.flush().context("flush XSETTINGS update")?;

    Ok(ApplyReport {
        owner,
        serial,
        setting_count,
    })
}

fn validate_name(label: &str, value: &str) -> Result<()> {
    if value.is_empty() {
        bail!("{label} name must not be empty");
    }
    if value.as_bytes().contains(&0) {
        bail!("{label} name must not contain NUL bytes");
    }
    Ok(())
}

fn intern_atom<C: Connection>(connection: &C, name: &[u8]) -> Result<u32> {
    Ok(connection
        .intern_atom(false, name)
        .with_context(|| format!("request X atom {}", String::from_utf8_lossy(name)))?
        .reply()
        .with_context(|| format!("read X atom {}", String::from_utf8_lossy(name)))?
        .atom)
}

impl Settings {
    fn empty() -> Self {
        Self {
            byte_order: if cfg!(target_endian = "little") {
                LITTLE_ENDIAN
            } else {
                BIG_ENDIAN
            },
            serial: 0,
            entries: Vec::new(),
        }
    }

    fn decode(bytes: &[u8]) -> Result<Self> {
        if bytes.len() < 12 {
            bail!("property is shorter than the XSETTINGS header");
        }
        let byte_order = bytes[0];
        if byte_order != LITTLE_ENDIAN && byte_order != BIG_ENDIAN {
            bail!("property uses unknown byte order {byte_order}");
        }

        let mut reader = Reader::new(bytes, byte_order);
        reader.take(4)?;
        let serial = reader.u32()?;
        let count = reader.u32()? as usize;
        if count > MAX_SETTINGS {
            bail!("property contains too many settings ({count})");
        }

        let mut entries = Vec::with_capacity(count);
        for _ in 0..count {
            let value_type = reader.u8()?;
            reader.take(1)?;
            let name_length = reader.u16()? as usize;
            let name = reader.take(name_length)?.to_vec();
            reader.padding(name_length)?;
            let last_change_serial = reader.u32()?;
            let value = match value_type {
                INTEGER => Value::Integer(reader.i32()?),
                STRING => {
                    let length = reader.u32()? as usize;
                    let value = reader.take(length)?.to_vec();
                    reader.padding(length)?;
                    Value::String(value)
                }
                COLOR => Value::Color([reader.u16()?, reader.u16()?, reader.u16()?, reader.u16()?]),
                _ => bail!("property contains unknown setting type {value_type}"),
            };
            entries.push(Setting {
                name,
                last_change_serial,
                value,
            });
        }
        if !reader.is_finished() {
            bail!("property contains trailing bytes");
        }

        Ok(Self {
            byte_order,
            serial,
            entries,
        })
    }

    fn encode(&self) -> Result<Vec<u8>> {
        let count = u32::try_from(self.entries.len()).context("too many XSETTINGS entries")?;
        let mut output = Vec::new();
        output.push(self.byte_order);
        output.extend_from_slice(&[0; 3]);
        write_u32(&mut output, self.serial, self.byte_order);
        write_u32(&mut output, count, self.byte_order);

        for entry in &self.entries {
            let name_length = u16::try_from(entry.name.len())
                .with_context(|| format!("XSETTING name is too long: {:?}", entry.name))?;
            output.push(match entry.value {
                Value::Integer(_) => INTEGER,
                Value::String(_) => STRING,
                Value::Color(_) => COLOR,
            });
            output.push(0);
            write_u16(&mut output, name_length, self.byte_order);
            output.extend_from_slice(&entry.name);
            write_padding(&mut output, entry.name.len());
            write_u32(&mut output, entry.last_change_serial, self.byte_order);
            match &entry.value {
                Value::Integer(value) => write_i32(&mut output, *value, self.byte_order),
                Value::String(value) => {
                    let length = u32::try_from(value.len()).with_context(|| {
                        format!("XSETTING string is too long: {:?}", entry.name)
                    })?;
                    write_u32(&mut output, length, self.byte_order);
                    output.extend_from_slice(value);
                    write_padding(&mut output, value.len());
                }
                Value::Color(value) => {
                    for channel in value {
                        write_u16(&mut output, *channel, self.byte_order);
                    }
                }
            }
        }
        Ok(output)
    }

    fn merge_integer(&mut self, name: &str, value: i32, serial: u32) {
        self.merge(name, Value::Integer(value), serial);
    }

    fn merge_string(&mut self, name: &str, value: &str, serial: u32) {
        self.merge(name, Value::String(value.as_bytes().to_vec()), serial);
    }

    fn merge(&mut self, name: &str, value: Value, serial: u32) {
        let name = name.as_bytes();
        let mut first_match = None;
        self.entries.retain(|entry| {
            if entry.name != name {
                return true;
            }
            if first_match.is_none() {
                first_match = Some(entry.clone());
            }
            false
        });

        let last_change_serial = first_match
            .filter(|setting| setting.value == value)
            .map_or(serial, |setting| setting.last_change_serial);
        self.entries.push(Setting {
            name: name.to_vec(),
            last_change_serial,
            value,
        });
    }
}

struct Reader<'a> {
    bytes: &'a [u8],
    offset: usize,
    byte_order: u8,
}

impl<'a> Reader<'a> {
    fn new(bytes: &'a [u8], byte_order: u8) -> Self {
        Self {
            bytes,
            offset: 0,
            byte_order,
        }
    }

    fn is_finished(&self) -> bool {
        self.offset == self.bytes.len()
    }

    fn take(&mut self, length: usize) -> Result<&'a [u8]> {
        let end = self
            .offset
            .checked_add(length)
            .context("XSETTINGS property length overflow")?;
        if end > self.bytes.len() {
            bail!("XSETTINGS property ends unexpectedly");
        }
        let value = &self.bytes[self.offset..end];
        self.offset = end;
        Ok(value)
    }

    fn padding(&mut self, length: usize) -> Result<()> {
        self.take(padding_length(length)).map(|_| ())
    }

    fn u8(&mut self) -> Result<u8> {
        Ok(self.take(1)?[0])
    }

    fn u16(&mut self) -> Result<u16> {
        let bytes: [u8; 2] = self.take(2)?.try_into().expect("two bytes");
        Ok(if self.byte_order == LITTLE_ENDIAN {
            u16::from_le_bytes(bytes)
        } else {
            u16::from_be_bytes(bytes)
        })
    }

    fn u32(&mut self) -> Result<u32> {
        let bytes: [u8; 4] = self.take(4)?.try_into().expect("four bytes");
        Ok(if self.byte_order == LITTLE_ENDIAN {
            u32::from_le_bytes(bytes)
        } else {
            u32::from_be_bytes(bytes)
        })
    }

    fn i32(&mut self) -> Result<i32> {
        let bytes: [u8; 4] = self.take(4)?.try_into().expect("four bytes");
        Ok(if self.byte_order == LITTLE_ENDIAN {
            i32::from_le_bytes(bytes)
        } else {
            i32::from_be_bytes(bytes)
        })
    }
}

fn padding_length(length: usize) -> usize {
    (4 - length % 4) % 4
}

fn write_padding(output: &mut Vec<u8>, length: usize) {
    output.resize(output.len() + padding_length(length), 0);
}

fn write_u16(output: &mut Vec<u8>, value: u16, byte_order: u8) {
    match byte_order.cmp(&LITTLE_ENDIAN) {
        Ordering::Equal => output.extend_from_slice(&value.to_le_bytes()),
        _ => output.extend_from_slice(&value.to_be_bytes()),
    }
}

fn write_u32(output: &mut Vec<u8>, value: u32, byte_order: u8) {
    match byte_order.cmp(&LITTLE_ENDIAN) {
        Ordering::Equal => output.extend_from_slice(&value.to_le_bytes()),
        _ => output.extend_from_slice(&value.to_be_bytes()),
    }
}

fn write_i32(output: &mut Vec<u8>, value: i32, byte_order: u8) {
    match byte_order.cmp(&LITTLE_ENDIAN) {
        Ordering::Equal => output.extend_from_slice(&value.to_le_bytes()),
        _ => output.extend_from_slice(&value.to_be_bytes()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_settings(byte_order: u8) -> Settings {
        Settings {
            byte_order,
            serial: 7,
            entries: vec![
                Setting {
                    name: b"Gdk/WindowScalingFactor".to_vec(),
                    last_change_serial: 1,
                    value: Value::Integer(1),
                },
                Setting {
                    name: b"Gdk/UnscaledDPI".to_vec(),
                    last_change_serial: 1,
                    value: Value::Integer(98_304),
                },
                Setting {
                    name: b"Xft/DPI".to_vec(),
                    last_change_serial: 1,
                    value: Value::Integer(98_304),
                },
                Setting {
                    name: b"Net/SoundThemeName".to_vec(),
                    last_change_serial: 3,
                    value: Value::String(b"freedesktop".to_vec()),
                },
                Setting {
                    name: b"Gtk/AccentColor".to_vec(),
                    last_change_serial: 6,
                    value: Value::Color([0x1111, 0x2222, 0x3333, 0xffff]),
                },
            ],
        }
    }

    #[test]
    fn round_trips_little_endian_settings() {
        let settings = sample_settings(LITTLE_ENDIAN);
        let encoded = settings.encode().unwrap();
        assert_eq!(Settings::decode(&encoded).unwrap(), settings);
    }

    #[test]
    fn round_trips_big_endian_settings() {
        let settings = sample_settings(BIG_ENDIAN);
        let encoded = settings.encode().unwrap();
        assert_eq!(Settings::decode(&encoded).unwrap(), settings);
    }

    #[test]
    fn merge_preserves_scale_settings() {
        let mut settings = sample_settings(LITTLE_ENDIAN);
        settings.serial = settings.serial.wrapping_add(1);
        let serial = settings.serial;
        settings.merge_string("Net/ThemeName", "SownteeShell-A", serial);
        settings.merge_integer("Gtk/CursorThemeSize", 24, serial);

        assert_eq!(settings.entries.len(), 7);
        assert!(settings.entries.iter().any(|setting| {
            setting.name == b"Gdk/WindowScalingFactor" && setting.value == Value::Integer(1)
        }));
        assert!(settings.entries.iter().any(|setting| {
            setting.name == b"Xft/DPI" && setting.value == Value::Integer(98_304)
        }));
        assert!(settings.entries.iter().any(|setting| {
            setting.name == b"Net/ThemeName"
                && setting.last_change_serial == serial
                && setting.value == Value::String(b"SownteeShell-A".to_vec())
        }));
        assert!(settings.entries.iter().any(|setting| {
            setting.name == b"Gtk/AccentColor"
                && setting.value == Value::Color([0x1111, 0x2222, 0x3333, 0xffff])
        }));
    }

    #[test]
    fn unchanged_value_keeps_its_change_serial() {
        let mut settings = Settings {
            byte_order: LITTLE_ENDIAN,
            serial: 4,
            entries: vec![Setting {
                name: b"Net/IconThemeName".to_vec(),
                last_change_serial: 2,
                value: Value::String(b"WhiteSur".to_vec()),
            }],
        };
        settings.merge_string("Net/IconThemeName", "WhiteSur", 5);
        assert_eq!(settings.entries[0].last_change_serial, 2);
    }

    #[test]
    fn rejects_truncated_property() {
        let encoded = sample_settings(LITTLE_ENDIAN).encode().unwrap();
        assert!(Settings::decode(&encoded[..encoded.len() - 1]).is_err());
    }
}
