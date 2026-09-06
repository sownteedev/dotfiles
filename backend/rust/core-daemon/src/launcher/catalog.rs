use anyhow::{Context, Result, bail};
use regex::Regex;
use serde::Deserialize;
use serde_json::{Map, Value, json};
use std::collections::HashSet;
use std::fs;
use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, OnceLock};
use tokio::sync::Mutex as AsyncMutex;
use tokio::task;

const DEFAULT_LIMIT: usize = 24;
const MAX_CATALOG_BYTES: u64 = 16 * 1024 * 1024;
const MAX_LINE_BYTES: usize = 64 * 1024;
const MAX_QUERY_LENGTH: usize = 160;
const MAX_RESULTS: usize = 100;

#[derive(Clone, Default)]
pub struct CatalogBackend {
    catalog: Arc<Mutex<Option<CachedCatalog>>>,
    load_lock: Arc<AsyncMutex<()>>,
}

#[derive(Clone)]
struct CachedCatalog {
    paths: CatalogPaths,
    value: Arc<Catalog>,
}

#[derive(Clone, Eq, PartialEq)]
struct CatalogPaths {
    emoji: PathBuf,
    unicode: PathBuf,
}

struct Catalog {
    emoji: Vec<PreparedEntry>,
    unicode: Vec<PreparedEntry>,
}

struct PreparedEntry {
    category: String,
    data: Map<String, Value>,
    glyph: String,
    keyword_words: HashSet<String>,
    keywords: String,
    kind: &'static str,
    name: String,
    name_words: HashSet<String>,
    order: usize,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SearchParams {
    emoji_path: PathBuf,
    #[serde(default)]
    limit: Option<usize>,
    #[serde(default)]
    query: String,
    #[serde(default = "default_request_id")]
    request_id: i64,
    unicode_path: PathBuf,
}

fn default_request_id() -> i64 {
    -1
}

impl CatalogBackend {
    pub async fn search(&self, params: Value) -> Result<Value> {
        let params: SearchParams =
            serde_json::from_value(params).context("decode catalog search")?;
        let paths = CatalogPaths {
            emoji: params.emoji_path,
            unicode: params.unicode_path,
        };
        let catalog = self.catalog(&paths).await?;
        let query = params.query;
        let limit = params.limit.unwrap_or(DEFAULT_LIMIT).clamp(1, MAX_RESULTS);
        let results = task::spawn_blocking(move || catalog.search(&query, limit))
            .await
            .context("join launcher catalog search")?;
        Ok(json!({
            "requestId": params.request_id,
            "results": results,
        }))
    }

    pub fn release(&self) -> Value {
        let released = self
            .catalog
            .lock()
            .ok()
            .and_then(|mut catalog| catalog.take())
            .is_some();
        json!({"ok": true, "released": released})
    }

    async fn catalog(&self, paths: &CatalogPaths) -> Result<Arc<Catalog>> {
        if let Some(catalog) = self.cached(paths) {
            return Ok(catalog);
        }

        let _load_guard = self.load_lock.lock().await;
        if let Some(catalog) = self.cached(paths) {
            return Ok(catalog);
        }

        let load_paths = paths.clone();
        let loaded = task::spawn_blocking(move || Catalog::load(&load_paths))
            .await
            .context("join launcher catalog loader")??;
        let loaded = Arc::new(loaded);
        if let Ok(mut catalog) = self.catalog.lock() {
            *catalog = Some(CachedCatalog {
                paths: paths.clone(),
                value: loaded.clone(),
            });
        }
        Ok(loaded)
    }

    fn cached(&self, paths: &CatalogPaths) -> Option<Arc<Catalog>> {
        self.catalog.lock().ok().and_then(|catalog| {
            catalog
                .as_ref()
                .filter(|cached| cached.paths == *paths)
                .map(|cached| cached.value.clone())
        })
    }
}

impl Catalog {
    fn load(paths: &CatalogPaths) -> Result<Self> {
        let emoji_entries = load_entries(&paths.emoji)?;
        let emoji_glyphs = emoji_entries
            .iter()
            .filter_map(|entry| entry.get("glyph").and_then(Value::as_str))
            .map(str::to_string)
            .collect::<HashSet<_>>();
        let emoji = emoji_entries
            .into_iter()
            .enumerate()
            .map(|(order, entry)| PreparedEntry::new(entry, "emoji", order))
            .collect::<Vec<_>>();

        let mut unicode = Vec::new();
        let mut order = emoji.len();
        for entry in load_entries(&paths.unicode)? {
            let glyph = entry
                .get("glyph")
                .and_then(Value::as_str)
                .unwrap_or_default();
            if emoji_glyphs.contains(glyph) {
                continue;
            }
            unicode.push(PreparedEntry::new(entry, "unicode", order));
            order += 1;
        }
        Ok(Self { emoji, unicode })
    }

    fn search(&self, query: &str, limit: usize) -> Vec<Value> {
        let term = query
            .trim()
            .to_lowercase()
            .chars()
            .take(MAX_QUERY_LENGTH)
            .collect::<String>();
        if term.is_empty() {
            return self
                .emoji
                .iter()
                .take(limit)
                .map(|entry| entry.result(None))
                .collect();
        }

        let tokens = term.split_whitespace().collect::<Vec<_>>();
        let mut matches = self
            .emoji
            .iter()
            .chain(self.unicode.iter())
            .filter_map(|entry| {
                entry
                    .score(&term, &tokens)
                    .map(|score| (score, entry.order, entry))
            })
            .collect::<Vec<_>>();
        matches.sort_by_key(|(score, order, _)| (*score, *order));
        matches
            .into_iter()
            .take(limit)
            .map(|(score, _, entry)| entry.result(Some(score)))
            .collect()
    }
}

impl PreparedEntry {
    fn new(data: Map<String, Value>, kind: &'static str, order: usize) -> Self {
        let glyph = text(&data, "glyph").to_lowercase();
        let name = text(&data, "name").to_lowercase();
        let keywords = text(&data, "keywords").to_lowercase();
        let category = text(&data, "category").to_lowercase();
        Self {
            name_words: name_word_regex()
                .split(&name)
                .filter(|word| !word.is_empty())
                .map(str::to_string)
                .collect(),
            keyword_words: keywords.split_whitespace().map(str::to_string).collect(),
            category,
            data,
            glyph,
            keywords,
            kind,
            name,
            order,
        }
    }

    fn score(&self, term: &str, tokens: &[&str]) -> Option<usize> {
        let term_is_word = term.chars().count() > 1;
        if self.glyph == term {
            return Some(0);
        }
        if self.name == term {
            return Some(1);
        }
        if self.category == term {
            return Some(2);
        }
        if self.keyword_words.contains(term) {
            return Some(3);
        }
        if term_is_word && self.name.starts_with(term) {
            return Some(4);
        }
        if term_is_word
            && (self.name.contains(term)
                || self.keywords.contains(term)
                || self.category.contains(term))
        {
            return Some(8);
        }

        let mut score = 20;
        for token in tokens {
            if self.glyph == *token {
                continue;
            }
            if self.name_words.contains(*token) {
                score += 1;
            } else if self.keyword_words.contains(*token) || self.category == *token {
                score += 2;
            } else if token.chars().count() > 1 && self.name.contains(token) {
                score += 4;
            } else if token.chars().count() > 1
                && (self.keywords.contains(token) || self.category.contains(token))
            {
                score += 5;
            } else {
                return None;
            }
        }
        Some(score)
    }

    fn result(&self, score: Option<usize>) -> Value {
        let mut result = json!({
            "type": "emoji",
            "characterKind": self.kind,
            "data": self.data,
        });
        if let Some(score) = score
            && let Some(object) = result.as_object_mut()
        {
            object.insert("score".into(), score.into());
            object.insert("order".into(), self.order.into());
        }
        result
    }
}

fn load_entries(path: &Path) -> Result<Vec<Map<String, Value>>> {
    let metadata = fs::metadata(path)
        .with_context(|| format!("inspect launcher catalog {}", path.display()))?;
    if !metadata.is_file() || metadata.len() > MAX_CATALOG_BYTES {
        bail!(
            "launcher catalog is missing or too large: {}",
            path.display()
        );
    }

    let file = fs::File::open(path)
        .with_context(|| format!("open launcher catalog {}", path.display()))?;
    let mut entries = Vec::new();
    for (line_number, line) in BufReader::new(file).lines().enumerate() {
        let line =
            line.with_context(|| format!("read {} line {}", path.display(), line_number + 1))?;
        if line.len() > MAX_LINE_BYTES {
            bail!(
                "launcher catalog line is too large at {}:{}",
                path.display(),
                line_number + 1
            );
        }
        let raw = line.trim();
        if raw.is_empty() {
            continue;
        }
        let Value::Object(entry) = serde_json::from_str(raw)
            .with_context(|| format!("parse {} line {}", path.display(), line_number + 1))?
        else {
            continue;
        };
        if entry
            .get("glyph")
            .and_then(Value::as_str)
            .is_some_and(|glyph| !glyph.is_empty())
        {
            entries.push(entry);
        }
    }
    Ok(entries)
}

fn text<'a>(entry: &'a Map<String, Value>, key: &str) -> &'a str {
    entry.get(key).and_then(Value::as_str).unwrap_or_default()
}

fn name_word_regex() -> &'static Regex {
    static WORDS: OnceLock<Regex> = OnceLock::new();
    WORDS.get_or_init(|| Regex::new(r"[^a-z0-9+]+").expect("valid launcher word regex"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use uuid::Uuid;

    #[test]
    fn preserves_scoring_and_removes_duplicate_unicode_glyphs() {
        let root = std::env::temp_dir().join(format!("catalog-test-{}", Uuid::new_v4()));
        fs::create_dir_all(&root).expect("create test directory");
        let emoji = root.join("emoji.jsonl");
        let unicode = root.join("unicode.jsonl");
        write_lines(
            &emoji,
            &[r#"{"glyph":"😀","name":"Grinning face","keywords":"smile happy"}"#],
        );
        write_lines(
            &unicode,
            &[
                r#"{"glyph":"😀","name":"Duplicate","keywords":"duplicate"}"#,
                r#"{"glyph":"λ","name":"Greek Small Letter Lambda","keywords":"lambda greek","category":"Greek"}"#,
            ],
        );
        let catalog = Catalog::load(&CatalogPaths { emoji, unicode }).expect("load catalog");
        assert_eq!(catalog.unicode.len(), 1);
        let result = catalog.search("lambda", 10);
        assert_eq!(result[0]["data"]["glyph"], "λ");
        assert_eq!(result[0]["score"], 3);
        fs::remove_dir_all(root).ok();
    }

    fn write_lines(path: &Path, lines: &[&str]) {
        let mut file = fs::File::create(path).expect("create catalog");
        for line in lines {
            writeln!(file, "{line}").expect("write catalog line");
        }
    }
}
