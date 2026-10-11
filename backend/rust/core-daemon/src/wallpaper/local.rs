use super::util::{failure, local_path};
use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::{Value, json};
use std::fs;

#[derive(Default, Deserialize)]
struct RemoveParams {
    path: String,
    current_path: String,
    roots: Vec<String>,
}

pub async fn remove(params: Value) -> Result<Value> {
    let params: RemoveParams = serde_json::from_value(params).unwrap_or_default();
    tokio::task::spawn_blocking(move || remove_blocking(params))
        .await
        .context("join local wallpaper removal")
}

fn remove_blocking(params: RemoveParams) -> Value {
    let target = local_path(&params.path);
    if target
        .symlink_metadata()
        .is_ok_and(|metadata| metadata.file_type().is_symlink())
    {
        return failure("unsafe_path", "Refusing to delete a symbolic link");
    }
    let Ok(resolved) = target.canonicalize() else {
        return failure("not_found", "Wallpaper was not found");
    };
    let extension = resolved
        .extension()
        .and_then(|value| value.to_str())
        .unwrap_or_default()
        .to_ascii_lowercase();
    let allowed_extension = matches!(
        extension.as_str(),
        "jpg"
            | "jpeg"
            | "png"
            | "webp"
            | "bmp"
            | "mp4"
            | "webm"
            | "mkv"
            | "mov"
            | "m4v"
            | "avi"
            | "gif"
    );
    let allowed_root = params.roots.iter().any(|root| {
        !root.is_empty()
            && local_path(root)
                .canonicalize()
                .is_ok_and(|folder| resolved.parent() == Some(folder.as_path()))
    });
    if !resolved.is_file() || !allowed_extension || !allowed_root {
        return failure(
            "unsafe_path",
            "Refusing to delete a file outside the wallpaper library",
        );
    }
    if !params.current_path.is_empty()
        && local_path(&params.current_path)
            .canonicalize()
            .is_ok_and(|current| current == resolved)
    {
        return failure(
            "in_use",
            "Choose another wallpaper before deleting this one",
        );
    }
    if fs::remove_file(&resolved).is_err() {
        return failure(
            "remove_failed",
            "Could not delete the wallpaper permanently",
        );
    }
    json!({ "ok": true, "path": resolved })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    struct Library(PathBuf);

    impl Library {
        fn new() -> Self {
            let path =
                std::env::temp_dir().join(format!("wallpaper-remove-{}", uuid::Uuid::new_v4()));
            fs::create_dir_all(path.join("library")).unwrap();
            Self(path)
        }

        fn remove(&self, path: &std::path::Path, current: &str) -> Value {
            remove_blocking(RemoveParams {
                path: path.to_string_lossy().into_owned(),
                current_path: current.into(),
                roots: vec![self.0.join("library").to_string_lossy().into_owned()],
            })
        }
    }

    impl Drop for Library {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn removes_static_and_live_files() {
        let library = Library::new();
        for name in ["photo.JPG", "video.mp4", "image with spaces.png"] {
            let path = library.0.join("library").join(name);
            fs::write(&path, b"test").unwrap();
            assert_eq!(library.remove(&path, "")["ok"], true);
            assert!(!path.exists());
        }
    }

    #[test]
    fn rejects_active_file_and_alias() {
        let library = Library::new();
        let path = library.0.join("library/photo.png");
        let alias = library.0.join("active.png");
        fs::write(&path, b"test").unwrap();
        std::os::unix::fs::symlink(&path, &alias).unwrap();
        assert_eq!(
            library.remove(&path, &path.to_string_lossy())["code"],
            "in_use"
        );
        assert_eq!(
            library.remove(&path, &alias.to_string_lossy())["code"],
            "in_use"
        );
        assert!(path.exists());
    }

    #[test]
    fn rejects_outside_files_directories_and_symlinks() {
        let library = Library::new();
        let outside = library.0.join("outside.png");
        let directory = library.0.join("library/folder.png");
        let link = library.0.join("library/link.png");
        let unsupported = library.0.join("library/settings.json");
        fs::write(&outside, b"test").unwrap();
        fs::write(&unsupported, b"test").unwrap();
        fs::create_dir(&directory).unwrap();
        std::os::unix::fs::symlink(&outside, &link).unwrap();
        for path in [&outside, &directory, &link, &unsupported] {
            assert_eq!(library.remove(path, "")["code"], "unsafe_path");
            assert!(path.exists());
        }
        assert_eq!(
            library.remove(&library.0.join("missing.png"), "")["code"],
            "not_found"
        );
    }
}
