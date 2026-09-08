use crate::database::Database;
use crate::model::{Account, DaemonEvent, ProviderKind};
use crate::providers::{ProviderRegistry, google::GoogleProvider};
use anyhow::{Context, Result, bail};
use chrono::{NaiveDate, Utc};
use reqwest::{Client, Method, RequestBuilder};
use rusqlite::params;
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value, json};
use std::collections::HashSet;
use std::sync::Arc;
use tokio::sync::{Mutex, broadcast};
use url::Url;

const API_ROOT: &str = "https://tasks.googleapis.com/tasks/v1/";
const MAX_TASKS: usize = 10_000;
const MAX_LISTS: usize = 100;
const MAX_RESPONSE_BYTES: usize = 8 * 1024 * 1024;

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TaskSnapshot {
    pub account_id: String,
    pub visible: bool,
    pub tasks: Vec<Value>,
    pub lists: Vec<Value>,
    pub default_list_id: String,
    pub error: String,
    pub updated_at: Option<String>,
}

#[derive(Clone)]
pub struct GoogleTasks {
    database: Database,
    http: Client,
    google: Arc<GoogleProvider>,
    gate: Arc<Mutex<()>>,
    events: broadcast::Sender<DaemonEvent>,
}

impl GoogleTasks {
    pub fn new(
        database: Database,
        providers: &ProviderRegistry,
        events: broadcast::Sender<DaemonEvent>,
    ) -> Self {
        Self {
            database,
            http: providers.http(),
            google: providers.google(),
            gate: Default::default(),
            events,
        }
    }

    pub async fn snapshots(&self) -> Result<Vec<TaskSnapshot>> {
        self.database.run_blocking(Database::task_snapshots).await
    }

    pub async fn account(&self, account_id: &str) -> Result<Account> {
        if account_id.trim().is_empty() {
            bail!("Select a Google account for this task");
        }
        let wanted = account_id.to_owned();
        self.database.run_blocking(move |db| {
            let accounts = db.list_accounts(true)?;
            accounts.into_iter().find(|account| account.provider == ProviderKind::Google
                && account.id == wanted)
                .context("Google account is not connected in Calendar. Connect or reconnect it with Tasks permission.")
        }).await
    }

    pub async fn set_visible(&self, account_id: String, visible: bool) -> Result<()> {
        let account = self.account(&account_id).await?;
        self.database
            .run_blocking(move |db| db.set_tasks_visible(&account_id, visible))
            .await?;
        self.publish(&account.id);
        Ok(())
    }

    pub async fn refresh(&self, account: &Account) -> Result<Vec<Value>> {
        let _guard = self.gate.lock().await;
        let result = tokio::time::timeout(
            std::time::Duration::from_secs(120),
            self.fetch_snapshot(account),
        )
        .await
        .context("Google Tasks sync timed out; the previous snapshot was kept")
        .and_then(|result| result);
        let account_id = account.id.clone();
        match result {
            Ok((default_list_id, lists, tasks)) => {
                let snapshot = tasks.clone();
                self.database
                    .run_blocking(move |db| {
                        db.store_tasks(&account_id, &default_list_id, &lists, &snapshot)
                    })
                    .await?;
                self.publish(&account.id);
                Ok(tasks)
            }
            Err(error) => {
                let message = format!("{error:#}");
                // Keep the previous complete snapshot on network, permission or pagination failure.
                self.database
                    .run_blocking(move |db| db.set_tasks_error(&account_id, &message))
                    .await?;
                self.publish(&account.id);
                Err(error)
            }
        }
    }

    async fn fetch_snapshot(&self, account: &Account) -> Result<(String, Vec<Value>, Vec<Value>)> {
        let token = self.google.access_token(account).await?;
        let lists = self
            .pages(
                api_url(&["users", "@me", "lists"])?,
                &token,
                MAX_LISTS,
                false,
            )
            .await?;
        let default_id = lists
            .first()
            .and_then(|list| list["id"].as_str())
            .unwrap_or_default()
            .to_owned();
        let mut tasks = Vec::new();
        for list in &lists {
            let id = list["id"].as_str().context("Google task list has no ID")?;
            let page = self
                .pages(api_url(&["lists", id, "tasks"])?, &token, MAX_TASKS, true)
                .await?;
            if tasks.len() + page.len() > MAX_TASKS {
                bail!("Google Tasks exceeds {MAX_TASKS} tasks; the previous snapshot was kept");
            }
            for mut task in page {
                let object = task.as_object_mut().context("Invalid Google task")?;
                object.insert("accountId".into(), json!(account.id));
                object.insert("taskListId".into(), json!(id));
                object.insert("taskListName".into(), list["title"].clone());
                tasks.push(task);
            }
        }
        Ok((default_id, lists, tasks))
    }

    async fn pages(&self, url: Url, token: &str, limit: usize, tasks: bool) -> Result<Vec<Value>> {
        let mut items = Vec::new();
        let mut page_token = String::new();
        let mut seen = HashSet::new();
        loop {
            let mut request = self
                .http
                .get(url.clone())
                .bearer_auth(token)
                .query(&[("maxResults", "100")]);
            if tasks {
                request = request.query(&[
                    ("showCompleted", "true"),
                    ("showHidden", "true"),
                    ("showDeleted", "false"),
                    ("showAssigned", "true"),
                ]);
            }
            if !page_token.is_empty() {
                request = request.query(&[("pageToken", &page_token)]);
            }
            let response = decode(request).await?;
            if let Some(page) = response.get("items") {
                items.extend(
                    page.as_array()
                        .context("Invalid Google Tasks items")?
                        .iter()
                        .cloned(),
                );
            }
            page_token = response["nextPageToken"]
                .as_str()
                .unwrap_or_default()
                .to_owned();
            if items.len() > limit || (!page_token.is_empty() && !seen.insert(page_token.clone())) {
                bail!("Google Tasks pagination limit reached; the previous snapshot was kept");
            }
            if page_token.is_empty() {
                break;
            }
            if seen.len() >= limit {
                bail!("Too many Google Tasks pages");
            }
        }
        Ok(items)
    }

    pub async fn mutate(&self, operation: &str, params: Value) -> Result<Value> {
        let account_id = params["accountId"]
            .as_str()
            .filter(|id| !id.is_empty())
            .context("Select a Google account for this task")?;
        let list_id = params["listId"]
            .as_str()
            .filter(|v| !v.is_empty() && *v != "@default")
            .context("Select a Google task list")?;
        let task_id = params["taskId"].as_str().unwrap_or_default();
        let mut segments = vec!["lists", list_id, "tasks"];
        if operation != "create" {
            if task_id.is_empty() {
                bail!("Google Task ID is required");
            }
            segments.push(task_id);
        }
        let method = match operation {
            "create" => Method::POST,
            "update" => Method::PATCH,
            "delete" => Method::DELETE,
            _ => bail!("Unknown Google Tasks operation"),
        };
        let payload = if operation == "delete" {
            None
        } else {
            Some(mutation_payload(operation, &params)?)
        };
        let account = self.account(account_id).await?;
        let _guard = self.gate.lock().await;
        let token = self.google.access_token(&account).await?;
        let mut request = self
            .http
            .request(method, api_url(&segments)?)
            .bearer_auth(token);
        if let Some(payload) = payload {
            request = request.json(&payload);
        }
        let task = decode(request).await?;
        let account_id = account.id.clone();
        let list_id = list_id.to_owned();
        let deleted_id = task_id.to_owned();
        let deleting = operation == "delete";
        // Apply the confirmed mutation locally; do not repeat a POST if a later sync fails.
        let remote_id = task["id"].as_str().unwrap_or(task_id).to_owned();
        self.database
            .run_blocking(move |db| {
                db.apply_task_mutation(&account_id, &list_id, &deleted_id, deleting, task)
            })
            .await?;
        self.publish(&account.id);
        Ok(json!({"success": true, "id": remote_id}))
    }

    fn publish(&self, account_id: &str) {
        let _ = self
            .events
            .send(DaemonEvent::changed("tasks", Some(account_id), None));
    }
}

impl Database {
    fn set_tasks_visible(&self, account_id: &str, visible: bool) -> Result<()> {
        self.connection()?.execute(
            "INSERT INTO google_tasks(account_id, visible) VALUES (?1, ?2) ON CONFLICT(account_id) DO UPDATE SET visible=excluded.visible",
            params![account_id, visible],
        )?;
        Ok(())
    }

    fn store_tasks(
        &self,
        account_id: &str,
        default_list_id: &str,
        lists: &[Value],
        tasks: &[Value],
    ) -> Result<()> {
        self.connection()?.execute(
            "INSERT INTO google_tasks(account_id, snapshot_json, default_list_id, updated_at, lists_json) VALUES (?1, ?2, ?3, ?4, ?5) \
             ON CONFLICT(account_id) DO UPDATE SET snapshot_json=excluded.snapshot_json, lists_json=excluded.lists_json, default_list_id=excluded.default_list_id, last_error='', updated_at=excluded.updated_at",
            params![account_id, serde_json::to_string(tasks)?, default_list_id, Utc::now().to_rfc3339(), serde_json::to_string(lists)?],
        )?;
        Ok(())
    }

    fn set_tasks_error(&self, account_id: &str, message: &str) -> Result<()> {
        self.connection()?.execute(
            "INSERT INTO google_tasks(account_id, last_error) VALUES (?1, ?2) ON CONFLICT(account_id) DO UPDATE SET last_error=excluded.last_error",
            params![account_id, message],
        )?;
        Ok(())
    }

    fn apply_task_mutation(
        &self,
        account_id: &str,
        list_id: &str,
        task_id: &str,
        deleting: bool,
        mut task: Value,
    ) -> Result<()> {
        let mut snapshot = self
            .task_snapshots()?
            .into_iter()
            .find(|s| s.account_id == account_id)
            .context("Google Tasks account was removed")?;
        if deleting {
            snapshot
                .tasks
                .retain(|t| !(t["id"] == task_id && t["taskListId"] == list_id));
        } else {
            let id = task["id"]
                .as_str()
                .context("Google Tasks mutation returned no ID")?
                .to_owned();
            let list_name = snapshot
                .lists
                .iter()
                .find(|list| list["id"] == list_id)
                .map(|list| list["title"].clone())
                .unwrap_or(json!("Tasks"));
            task["accountId"] = json!(account_id);
            task["taskListId"] = json!(list_id);
            task["taskListName"] = list_name;
            snapshot
                .tasks
                .retain(|t| !(t["id"] == id && t["taskListId"] == list_id));
            snapshot.tasks.push(task);
        }
        self.connection()?.execute(
            "INSERT INTO google_tasks(account_id, snapshot_json, updated_at) VALUES (?1, ?2, ?3) \
             ON CONFLICT(account_id) DO UPDATE SET snapshot_json=excluded.snapshot_json, updated_at=excluded.updated_at",
            params![account_id, serde_json::to_string(&snapshot.tasks)?, Utc::now().to_rfc3339()],
        )?;
        Ok(())
    }

    pub fn task_snapshots(&self) -> Result<Vec<TaskSnapshot>> {
        let connection = self.connection()?;
        let mut statement = connection.prepare(
            "SELECT a.id, COALESCE(t.visible,1), COALESCE(t.snapshot_json,'[]'), COALESCE(t.default_list_id,''), \
             COALESCE(t.last_error,''), t.updated_at, COALESCE(t.lists_json,'[]') FROM accounts a LEFT JOIN google_tasks t ON t.account_id=a.id \
             WHERE a.provider='google' AND a.enabled=1 ORDER BY a.created_at"
        )?;
        let rows = statement.query_map([], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get(1)?,
                row.get::<_, String>(2)?,
                row.get(3)?,
                row.get(4)?,
                row.get(5)?,
                row.get::<_, String>(6)?,
            ))
        })?;
        rows.map(|row| {
            let (account_id, visible, raw, default_list_id, error, updated_at, lists) = row?;
            Ok(TaskSnapshot {
                account_id,
                visible,
                tasks: serde_json::from_str(&raw)?,
                lists: serde_json::from_str(&lists)?,
                default_list_id,
                error,
                updated_at,
            })
        })
        .collect()
    }
}

fn api_url(segments: &[&str]) -> Result<Url> {
    let mut url = Url::parse(API_ROOT)?;
    url.path_segments_mut()
        .map_err(|_| anyhow::anyhow!("Invalid Google Tasks URL"))?
        .pop_if_empty()
        .extend(segments);
    Ok(url)
}

fn mutation_payload(operation: &str, params: &Value) -> Result<Value> {
    let mut payload = Map::new();
    for key in ["title", "notes", "status"] {
        if let Some(value) = params.get(key) {
            let text = value.as_str().context("Task fields must be strings")?;
            if key == "title" && text.trim().is_empty() {
                bail!("Google Task title is required");
            }
            if key == "status" && !matches!(text, "completed" | "needsAction") {
                bail!("Invalid task status");
            }
            payload.insert(key.into(), json!(text));
        }
    }
    if operation == "create" && !payload.contains_key("title") {
        bail!("Google Task title is required");
    }
    if let Some(due) = params.get("due") {
        let due = due.as_str().context("Task due date must be a string")?;
        payload.insert(
            "due".into(),
            if due.is_empty() {
                Value::Null
            } else {
                let date = due.get(..10).context("Invalid task due date")?;
                NaiveDate::parse_from_str(date, "%Y-%m-%d").context("Invalid task due date")?;
                json!(format!("{date}T00:00:00.000Z"))
            },
        );
    }
    if payload.is_empty() {
        bail!("Google Task update has no fields");
    }
    Ok(Value::Object(payload))
}

async fn decode(request: RequestBuilder) -> Result<Value> {
    let mut response = request
        .send()
        .await
        .context("Google Tasks request failed")?;
    let status = response.status();
    let mut body = Vec::new();
    while let Some(chunk) = response.chunk().await? {
        if body.len() + chunk.len() > MAX_RESPONSE_BYTES {
            bail!("Google Tasks response is too large");
        }
        body.extend_from_slice(&chunk);
    }
    let payload: Value = if body.is_empty() {
        json!({})
    } else {
        serde_json::from_slice(&body).context("Invalid Google Tasks response")?
    };
    if !status.is_success() {
        let message = payload["error"]["message"]
            .as_str()
            .unwrap_or("Google Tasks request failed");
        if status.as_u16() == 403 {
            bail!(
                "Google Tasks: {message}. Enable Google Tasks API in Google Cloud and reconnect the Google account in Calendar to grant Tasks access."
            );
        }
        bail!("Google Tasks ({status}): {message}");
    }
    Ok(payload)
}

#[cfg(test)]
mod tests {
    use super::*;

    struct TestDirectory(std::path::PathBuf);

    impl Drop for TestDirectory {
        fn drop(&mut self) {
            std::fs::remove_dir_all(&self.0).expect("remove isolated task database");
        }
    }

    fn database() -> (TestDirectory, Database) {
        let directory = TestDirectory(
            std::env::temp_dir().join(format!("calendar-tasks-{}", uuid::Uuid::new_v4())),
        );
        let database = Database::open(&directory.0.join("calendar.db")).unwrap();
        (directory, database)
    }

    fn add_account(database: &Database, id: &str, provider: ProviderKind, enabled: bool) {
        let now = Utc::now();
        database
            .upsert_account(&Account {
                id: id.into(),
                provider,
                enabled,
                display_name: id.into(),
                email: format!("{id}@example.com"),
                config: json!({}),
                needs_reauth: false,
                last_error: String::new(),
                last_sync_at: None,
                created_at: now,
                updated_at: now,
            })
            .unwrap();
    }

    #[test]
    fn snapshots_include_every_enabled_google_account_before_first_sync() {
        let (_directory, database) = database();
        add_account(&database, "first", ProviderKind::Google, true);
        add_account(&database, "second", ProviderKind::Google, true);
        add_account(&database, "disabled", ProviderKind::Google, false);
        add_account(&database, "work", ProviderKind::Microsoft, true);
        let snapshots = database.task_snapshots().unwrap();
        assert_eq!(snapshots.len(), 2);
        assert!(snapshots.iter().all(|s| s.visible
            && s.tasks.is_empty()
            && s.lists.is_empty()
            && s.updated_at.is_none()));
    }

    #[test]
    fn failed_sync_and_visibility_changes_preserve_complete_snapshot() {
        let (_directory, database) = database();
        add_account(&database, "first", ProviderKind::Google, true);
        database.set_tasks_visible("first", false).unwrap();
        let lists = vec![json!({"id":"inbox", "title":"Inbox"})];
        let tasks = vec![json!({"id":"same-id", "taskListId":"inbox", "title":"Keep this task"})];
        database
            .store_tasks("first", "inbox", &lists, &tasks)
            .unwrap();
        let updated_at = database.task_snapshots().unwrap()[0].updated_at.clone();
        database.set_tasks_error("first", "Offline").unwrap();
        let snapshot = database.task_snapshots().unwrap().remove(0);
        assert_eq!(snapshot.tasks, tasks);
        assert_eq!(snapshot.lists, lists);
        assert_eq!(snapshot.updated_at, updated_at);
        assert_eq!(snapshot.error, "Offline");
        assert!(!snapshot.visible);
        database.store_tasks("first", "inbox", &lists, &[]).unwrap();
        let snapshot = database.task_snapshots().unwrap().remove(0);
        assert!(
            snapshot.tasks.is_empty(),
            "a successful empty sync must remove stale tasks"
        );
        assert!(snapshot.error.is_empty());
        assert!(!snapshot.visible, "sync must not turn hidden tasks back on");
    }

    #[test]
    fn confirmed_mutations_are_isolated_by_account_list_and_task() {
        let (_directory, database) = database();
        let lists = vec![
            json!({"id":"inbox", "title":"Inbox"}),
            json!({"id":"work", "title":"Work"}),
        ];
        let tasks = vec![
            json!({"id":"same-id", "taskListId":"inbox", "title":"Original"}),
            json!({"id":"same-id", "taskListId":"work", "title":"Do not change"}),
        ];
        for account in ["first", "second"] {
            add_account(&database, account, ProviderKind::Google, true);
            database
                .store_tasks(account, "inbox", &lists, &tasks)
                .unwrap();
        }
        database.set_tasks_visible("first", false).unwrap();
        database
            .apply_task_mutation(
                "first",
                "inbox",
                "same-id",
                false,
                json!({"id":"same-id", "title":"Changed"}),
            )
            .unwrap();
        let snapshots = database.task_snapshots().unwrap();
        let first = snapshots.iter().find(|s| s.account_id == "first").unwrap();
        assert!(!first.visible);
        assert_eq!(first.tasks.len(), 2);
        let changed = first
            .tasks
            .iter()
            .find(|t| t["taskListId"] == "inbox")
            .unwrap();
        assert_eq!(changed["title"], "Changed");
        assert_eq!(changed["accountId"], "first");
        assert_eq!(changed["taskListName"], "Inbox");
        assert_eq!(
            snapshots
                .iter()
                .find(|s| s.account_id == "second")
                .unwrap()
                .tasks,
            tasks
        );
        database
            .apply_task_mutation("first", "inbox", "same-id", true, json!({}))
            .unwrap();
        database
            .apply_task_mutation(
                "first",
                "work",
                "new",
                false,
                json!({"id":"new", "title":"New task"}),
            )
            .unwrap();
        let first = database
            .task_snapshots()
            .unwrap()
            .into_iter()
            .find(|s| s.account_id == "first")
            .unwrap();
        assert_eq!(first.tasks.len(), 2);
        assert!(first.tasks.iter().all(|t| t["taskListId"] == "work"));
        assert_eq!(
            first.tasks.iter().find(|t| t["id"] == "new").unwrap()["taskListName"],
            "Work"
        );
    }

    #[test]
    fn cache_survives_restart_and_account_deletion_cascades() {
        let (directory, database) = database();
        add_account(&database, "first", ProviderKind::Google, true);
        database
            .store_tasks("first", "inbox", &[], &[json!({"id":"cached"})])
            .unwrap();
        database.set_tasks_visible("first", false).unwrap();
        drop(database);
        let database = Database::open(&directory.0.join("calendar.db")).unwrap();
        let snapshot = database.task_snapshots().unwrap().remove(0);
        assert_eq!(snapshot.tasks[0]["id"], "cached");
        assert!(!snapshot.visible);
        database.delete_account("first").unwrap();
        assert!(database.task_snapshots().unwrap().is_empty());
        let count: i64 = database
            .connection()
            .unwrap()
            .query_row("SELECT COUNT(*) FROM google_tasks", [], |row| row.get(0))
            .unwrap();
        assert_eq!(count, 0);
    }

    #[test]
    fn task_dates_are_date_only_and_invalid_values_are_rejected() {
        assert_eq!(
            mutation_payload("update", &json!({"due":"2026-09-08T23:30:00-07:00"})).unwrap()["due"],
            "2026-09-08T00:00:00.000Z"
        );
        assert!(mutation_payload("update", &json!({"due":"2026-02-30"})).is_err());
        assert!(mutation_payload("update", &json!({"due":""})).unwrap()["due"].is_null());
    }
    #[test]
    fn task_mutations_validate_status_title_and_fields() {
        assert!(mutation_payload("create", &json!({"title":" "})).is_err());
        assert!(mutation_payload("update", &json!({"status":"deleted"})).is_err());
        assert!(mutation_payload("update", &json!({})).is_err());
        assert_eq!(
            mutation_payload("update", &json!({"status":"completed"})).unwrap()["status"],
            "completed"
        );
    }
    #[test]
    fn task_ids_are_url_encoded_once() {
        assert_eq!(
            api_url(&["lists", "a/b", "tasks", "c/d"]).unwrap().as_str(),
            "https://tasks.googleapis.com/tasks/v1/lists/a%2Fb/tasks/c%2Fd"
        );
    }
}
