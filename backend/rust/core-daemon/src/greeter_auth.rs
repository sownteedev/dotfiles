use anyhow::{Context, Result, bail, ensure};
use serde_json::{Value, json};
use std::collections::HashMap;
use std::fs;
use std::io::Read;
use std::os::unix::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, PartialEq)]
struct Policy {
    deny: u64,
    interval: u64,
    unlock: u64,
    directory: PathBuf,
}

pub fn lockout_status(user: &str) -> Value {
    match read_status(user) {
        Ok(status) => status,
        Err(_) => json!({"known": false}),
    }
}

fn read_status(user: &str) -> Result<Value> {
    ensure!(!user.is_empty() && !user.contains('/') && user != "." && user != "..");
    let passwd = fs::read_to_string("/etc/passwd")?;
    let account = passwd
        .lines()
        .find(|line| line.split(':').next() == Some(user))
        .context("not a local account")?;
    let fields: Vec<_> = account.split(':').collect();
    let uid: u32 = fields.get(2).context("missing uid")?.parse()?;
    let gid: u32 = fields.get(3).context("missing gid")?.parse()?;
    let mut rules = Vec::new();
    collect_rules(Path::new("/etc/pam.d"), "greetd", 0, &mut rules)?;
    ensure!(!rules.is_empty(), "no faillock policy");
    let mut policies = Vec::new();
    for rule in rules {
        let arguments = parse_options(&rule);
        let config = arguments
            .get("conf")
            .map(String::as_str)
            .unwrap_or("/etc/security/faillock.conf");
        let mut options = parse_options(&fs::read_to_string(config)?);
        options.extend(arguments);
        let mut admin = uid == 0;
        if let Some(group) = options.get("admin_group") {
            let groups = fs::read_to_string("/etc/group")?;
            for entry in groups.lines() {
                let parts: Vec<_> = entry.split(':').collect();
                if parts.len() == 4 && parts[0] == group {
                    admin |= parts[2].parse::<u32>()? == gid
                        || parts[3].split(',').any(|name| name == user);
                }
            }
        }
        policies.push(policy_from_options(&options, admin)?);
    }
    let policy = &policies[0];
    ensure!(
        policies.iter().all(|item| item == policy),
        "conflicting faillock policies"
    );
    let path = policy.directory.join(user);
    let records = match fs::OpenOptions::new()
        .read(true)
        .custom_flags(nix::libc::O_NOFOLLOW | nix::libc::O_NONBLOCK)
        .open(path)
    {
        Ok(file) => {
            ensure!(file.metadata()?.is_file(), "not a regular tally file");
            let mut data = Vec::new();
            file.take(1024 * 1024 + 1).read_to_end(&mut data)?;
            ensure!(data.len() <= 1024 * 1024, "tally too large");
            data
        }
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Vec::new(),
        Err(error) => return Err(error.into()),
    };
    let now = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs();
    evaluate(&records, policy, now)
}

fn collect_rules(base: &Path, service: &str, depth: usize, rules: &mut Vec<String>) -> Result<()> {
    ensure!(depth < 12 && !service.contains('/') && service != "." && service != "..");
    let text = fs::read_to_string(base.join(service))?.replace("\\\n", " ");
    for line in text.lines() {
        let line = line.split('#').next().unwrap_or("").trim();
        let mut fields = line.split_whitespace();
        if !matches!(fields.next(), Some("auth" | "-auth")) {
            continue;
        }
        let control = fields.next().context("missing PAM control")?;
        if matches!(control, "include" | "substack") {
            collect_rules(
                base,
                fields.next().context("missing PAM include")?,
                depth + 1,
                rules,
            )?;
        } else {
            if control.starts_with('[') && !control.ends_with(']') {
                ensure!(
                    fields.by_ref().any(|part| part.ends_with(']')),
                    "invalid PAM control"
                );
            }
            let module = fields.next().context("missing PAM module")?;
            if Path::new(module).file_name().and_then(|name| name.to_str())
                == Some("pam_faillock.so")
            {
                rules.push(fields.collect::<Vec<_>>().join("\n"));
            }
        }
    }
    Ok(())
}

fn parse_options(text: &str) -> HashMap<String, String> {
    text.lines()
        .filter_map(|line| {
            let line = line.split('#').next().unwrap_or("").trim();
            if line.is_empty() {
                return None;
            }
            let (key, value) = line.split_once('=').unwrap_or((line, ""));
            Some((key.trim().into(), value.trim().into()))
        })
        .collect()
}

fn policy_from_options(options: &HashMap<String, String>, admin: bool) -> Result<Policy> {
    let number = |key: &str, default: u64| -> Result<u64> {
        match options.get(key).map(String::as_str) {
            None => Ok(default),
            Some("never") if key.ends_with("unlock_time") => Ok(0),
            Some(value) => Ok(value.parse()?),
        }
    };
    let unlock = number("unlock_time", 600)?;
    let deny_root =
        options.contains_key("even_deny_root") || options.contains_key("root_unlock_time");
    let policy = Policy {
        deny: if admin && !deny_root {
            0
        } else {
            number("deny", 3)?
        },
        interval: number("fail_interval", 900)?,
        unlock: if admin {
            number("root_unlock_time", unlock)?
        } else {
            unlock
        },
        directory: options
            .get("dir")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("/var/run/faillock")),
    };
    ensure!(policy.directory.is_absolute(), "relative tally directory");
    Ok(policy)
}

fn evaluate(records: &[u8], policy: &Policy, now: u64) -> Result<Value> {
    ensure!(records.len() % 64 == 0, "invalid tally size");
    let mut times = Vec::new();
    for record in records.chunks_exact(64) {
        ensure!(record[52..54] == [0, 0], "unknown tally format");
        let status = u16::from_ne_bytes(record[54..56].try_into()?);
        ensure!(status & !7 == 0, "unknown tally flags");
        if status & 1 != 0 {
            let time = u64::from_ne_bytes(record[56..64].try_into()?);
            ensure!(time <= now, "future tally timestamp");
            times.push(time);
        }
    }
    let latest = times.iter().copied().max().unwrap_or(0);
    let failures = times
        .iter()
        .filter(|time| latest - **time < policy.interval)
        .count() as u64;
    let unlock_at = latest
        .checked_add(policy.unlock)
        .and_then(|time| time.checked_add(1))
        .context("invalid unlock deadline")?;
    let locked =
        policy.deny > 0 && failures >= policy.deny && (policy.unlock == 0 || now < unlock_at);
    if unlock_at > 8_640_000_000_000 {
        bail!("unlock deadline out of range");
    }
    Ok(
        json!({"known": true, "locked": locked, "failures": failures,
        "unlockAt": if policy.unlock == 0 { 0 } else { unlock_at * 1000 }}),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn records(times: &[(u64, u16)]) -> Vec<u8> {
        times
            .iter()
            .flat_map(|(time, status)| {
                let mut record = [0_u8; 64];
                record[54..56].copy_from_slice(&status.to_ne_bytes());
                record[56..64].copy_from_slice(&time.to_ne_bytes());
                record
            })
            .collect()
    }

    #[test]
    fn locks_on_third_failure_with_fixed_deadline() {
        let policy = policy_from_options(&HashMap::new(), false).unwrap();
        assert_eq!(
            evaluate(&records(&[(1000, 1), (1010, 1)]), &policy, 1020).unwrap()["locked"],
            false
        );
        let data = records(&[(1000, 1), (1010, 1), (1020, 1)]);
        let initial = evaluate(&data, &policy, 1020).unwrap();
        assert_eq!(initial["locked"], true);
        assert_eq!(initial["unlockAt"], 1621000);
        assert_eq!(
            evaluate(&data, &policy, 1500).unwrap()["unlockAt"],
            initial["unlockAt"]
        );
        assert_eq!(evaluate(&data, &policy, 1620).unwrap()["locked"], true);
        assert_eq!(evaluate(&data, &policy, 1621).unwrap()["locked"], false);
    }

    #[test]
    fn ignores_invalid_and_out_of_window_records() {
        let policy = policy_from_options(&HashMap::new(), false).unwrap();
        let data = records(&[(100, 1), (1000, 1), (1005, 0), (1010, 1)]);
        assert_eq!(evaluate(&data, &policy, 1010).unwrap()["failures"], 2);
    }

    #[test]
    fn honors_policy_and_admin_exemption() {
        let options = parse_options("deny = 2\nunlock_time = 120\nfail_interval = 30\n");
        let data = records(&[(1000, 1), (1010, 1)]);
        let policy = policy_from_options(&options, false).unwrap();
        assert_eq!(evaluate(&data, &policy, 1010).unwrap()["unlockAt"], 1131000);
        assert_eq!(evaluate(&data, &policy, 1010).unwrap()["locked"], true);
        let policy = policy_from_options(&options, true).unwrap();
        assert_eq!(evaluate(&data, &policy, 1010).unwrap()["locked"], false);
        let options = parse_options("deny=2\nroot_unlock_time=60\n");
        let policy = policy_from_options(&options, true).unwrap();
        assert_eq!(evaluate(&data, &policy, 1010).unwrap()["unlockAt"], 1071000);
    }

    #[test]
    fn handles_permanent_and_disabled_lockout() {
        let data = records(&[(1000, 1), (1010, 1), (1020, 1)]);
        let policy = policy_from_options(&parse_options("unlock_time=never"), false).unwrap();
        let status = evaluate(&data, &policy, 50000).unwrap();
        assert_eq!(status["locked"], true);
        assert_eq!(status["unlockAt"], 0);
        let policy = policy_from_options(&parse_options("deny=0"), false).unwrap();
        assert_eq!(evaluate(&data, &policy, 1020).unwrap()["locked"], false);
    }

    #[test]
    fn rejects_unusable_tallies_and_options() {
        let policy = policy_from_options(&HashMap::new(), false).unwrap();
        assert!(evaluate(&[0; 63], &policy, 1020).is_err());
        assert!(evaluate(&records(&[(2000, 1)]), &policy, 1020).is_err());
        assert!(evaluate(&records(&[(1000, 8)]), &policy, 1020).is_err());
        assert!(policy_from_options(&parse_options("deny=bad"), false).is_err());
    }

    #[test]
    fn reads_nested_pam_includes_and_module_overrides() {
        let base =
            std::env::temp_dir().join(format!("sowntee-pam-policy-{}", uuid::Uuid::new_v4()));
        fs::create_dir(&base).unwrap();
        fs::write(
            base.join("greetd"),
            "auth required pam_securetty.so\nauth include shared\n",
        )
        .unwrap();
        fs::write(base.join("shared"), "auth required pam_faillock.so preauth deny=5\nauth [default=die] pam_faillock.so authfail deny=5\n").unwrap();
        let mut rules = Vec::new();
        collect_rules(&base, "greetd", 0, &mut rules).unwrap();
        assert_eq!(rules.len(), 2);
        assert_eq!(
            policy_from_options(&parse_options(&rules[0]), false)
                .unwrap()
                .deny,
            5
        );
        fs::write(base.join("shared"), "auth include greetd\n").unwrap();
        assert!(collect_rules(&base, "greetd", 0, &mut Vec::new()).is_err());
        fs::remove_dir_all(base).unwrap();
    }
}
