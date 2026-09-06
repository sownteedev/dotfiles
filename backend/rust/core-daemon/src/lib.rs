//! Shared backend implementation used by the SownteeShell core daemon.

#![recursion_limit = "512"]

#[cfg(feature = "daemon")]
pub mod application;
#[cfg(feature = "daemon")]
pub mod clipboard;
#[cfg(feature = "daemon")]
pub mod command;
#[cfg(feature = "daemon")]
pub mod diagnostics;
#[cfg(feature = "daemon")]
pub mod display;
#[cfg(feature = "daemon")]
pub mod greeter;
#[cfg(feature = "daemon")]
pub mod job;
#[cfg(feature = "daemon")]
pub mod launcher;
#[cfg(feature = "daemon")]
pub mod network;
#[cfg(feature = "daemon")]
pub mod productivity;
#[cfg(feature = "daemon")]
pub mod settings;
pub mod system;
#[cfg(feature = "daemon")]
pub mod theme;
#[cfg(feature = "daemon")]
pub mod updates;
#[cfg(feature = "daemon")]
pub mod wallpaper;
#[cfg(feature = "daemon")]
pub mod weather;
#[cfg(feature = "daemon")]
pub mod wifi;
