use super::{
    AuthorizedAccount, LoopbackFlow, OAuthToken, RedirectHost, TokenResponse, decode_error_response,
};
use anyhow::{Context, Result, bail};
use reqwest::Client;
use serde::Deserialize;
use std::collections::HashMap;
use url::Url;

const AUTHORIZATION_ENDPOINT: &str = "https://accounts.google.com/o/oauth2/v2/auth";
const TOKEN_ENDPOINT: &str = "https://oauth2.googleapis.com/token";
const USERINFO_ENDPOINT: &str = "https://www.googleapis.com/oauth2/v2/userinfo";
const SCOPES: &str = "openid email profile \
https://www.googleapis.com/auth/calendar.events \
https://www.googleapis.com/auth/calendar.calendarlist.readonly";

#[derive(Debug, Deserialize)]
struct GoogleUser {
    id: String,
    #[serde(default)]
    email: String,
    #[serde(default)]
    name: String,
}

pub async fn authorize(
    http: &Client,
    client_id: &str,
    client_secret: Option<&str>,
) -> Result<AuthorizedAccount> {
    if client_id.trim().is_empty() {
        bail!("Google OAuth client ID is required");
    }

    let flow = LoopbackFlow::bind(RedirectHost::LoopbackIp).await?;
    let mut authorization_url = Url::parse(AUTHORIZATION_ENDPOINT)?;
    authorization_url
        .query_pairs_mut()
        .append_pair("client_id", client_id)
        .append_pair("redirect_uri", &flow.redirect_uri)
        .append_pair("response_type", "code")
        .append_pair("scope", SCOPES)
        .append_pair("access_type", "offline")
        .append_pair("prompt", "consent")
        .append_pair("include_granted_scopes", "true")
        .append_pair("state", &flow.state)
        .append_pair("code_challenge", &flow.challenge)
        .append_pair("code_challenge_method", "S256");

    let redirect_uri = flow.redirect_uri.clone();
    let verifier = flow.verifier.clone();
    let code = flow.open_and_wait(authorization_url).await?;
    let token = exchange_code(
        http,
        client_id,
        client_secret,
        &redirect_uri,
        &verifier,
        &code,
    )
    .await?;
    let user = http
        .get(USERINFO_ENDPOINT)
        .bearer_auth(&token.access_token)
        .send()
        .await
        .context("fetch Google account profile")?
        .error_for_status()
        .context("Google account profile request failed")?
        .json::<GoogleUser>()
        .await
        .context("decode Google account profile")?;

    Ok(AuthorizedAccount {
        remote_id: user.id,
        display_name: if user.name.is_empty() {
            user.email.clone()
        } else {
            user.name
        },
        email: user.email,
        token,
    })
}

pub async fn refresh(
    http: &Client,
    client_id: &str,
    client_secret: Option<&str>,
    token: &OAuthToken,
) -> Result<OAuthToken> {
    if token.refresh_token.is_empty() {
        bail!("Google account has no refresh token");
    }
    let mut form = HashMap::from([
        ("client_id", client_id),
        ("refresh_token", token.refresh_token.as_str()),
        ("grant_type", "refresh_token"),
    ]);
    if let Some(secret) = client_secret.filter(|value| !value.is_empty()) {
        form.insert("client_secret", secret);
    }
    let response = http.post(TOKEN_ENDPOINT).form(&form).send().await?;
    if !response.status().is_success() {
        return Err(decode_error_response(response).await);
    }
    Ok(response
        .json::<TokenResponse>()
        .await?
        .into_token(Some(token)))
}

async fn exchange_code(
    http: &Client,
    client_id: &str,
    client_secret: Option<&str>,
    redirect_uri: &str,
    verifier: &str,
    code: &str,
) -> Result<OAuthToken> {
    let mut form = HashMap::from([
        ("client_id", client_id),
        ("code", code),
        ("code_verifier", verifier),
        ("grant_type", "authorization_code"),
        ("redirect_uri", redirect_uri),
    ]);
    if let Some(secret) = client_secret.filter(|value| !value.is_empty()) {
        form.insert("client_secret", secret);
    }
    let response = http.post(TOKEN_ENDPOINT).form(&form).send().await?;
    if !response.status().is_success() {
        return Err(decode_error_response(response).await);
    }
    Ok(response.json::<TokenResponse>().await?.into_token(None))
}
