use super::{
    AuthorizedAccount, LoopbackFlow, OAuthToken, RedirectHost, TokenResponse, decode_error_response,
};
use anyhow::{Context, Result, bail};
use reqwest::Client;
use serde::Deserialize;
use std::collections::HashMap;
use url::Url;

const GRAPH_PROFILE_ENDPOINT: &str =
    "https://graph.microsoft.com/v1.0/me?$select=id,displayName,mail,userPrincipalName";
const SCOPES: &str = "openid profile email offline_access \
https://graph.microsoft.com/User.Read https://graph.microsoft.com/Calendars.ReadWrite";

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct MicrosoftUser {
    id: String,
    #[serde(default)]
    display_name: String,
    #[serde(default)]
    mail: String,
    #[serde(default)]
    user_principal_name: String,
}

pub async fn authorize(http: &Client, client_id: &str, tenant: &str) -> Result<AuthorizedAccount> {
    if client_id.trim().is_empty() {
        bail!("Microsoft OAuth client ID is required");
    }
    let tenant = normalized_tenant(tenant);
    let authorization_endpoint =
        format!("https://login.microsoftonline.com/{tenant}/oauth2/v2.0/authorize");
    let flow = LoopbackFlow::bind(RedirectHost::Localhost).await?;
    let mut authorization_url = Url::parse(&authorization_endpoint)?;
    authorization_url
        .query_pairs_mut()
        .append_pair("client_id", client_id)
        .append_pair("redirect_uri", &flow.redirect_uri)
        .append_pair("response_type", "code")
        .append_pair("response_mode", "query")
        .append_pair("scope", SCOPES)
        .append_pair("state", &flow.state)
        .append_pair("code_challenge", &flow.challenge)
        .append_pair("code_challenge_method", "S256");

    let redirect_uri = flow.redirect_uri.clone();
    let verifier = flow.verifier.clone();
    let code = flow.open_and_wait(authorization_url).await?;
    let token = exchange_code(http, client_id, &tenant, &redirect_uri, &verifier, &code).await?;
    let user = http
        .get(GRAPH_PROFILE_ENDPOINT)
        .bearer_auth(&token.access_token)
        .send()
        .await
        .context("fetch Microsoft account profile")?
        .error_for_status()
        .context("Microsoft account profile request failed")?
        .json::<MicrosoftUser>()
        .await
        .context("decode Microsoft account profile")?;
    let email = if user.mail.is_empty() {
        user.user_principal_name
    } else {
        user.mail
    };

    Ok(AuthorizedAccount {
        remote_id: user.id,
        display_name: if user.display_name.is_empty() {
            email.clone()
        } else {
            user.display_name
        },
        email,
        token,
    })
}

pub async fn refresh(
    http: &Client,
    client_id: &str,
    tenant: &str,
    token: &OAuthToken,
) -> Result<OAuthToken> {
    if token.refresh_token.is_empty() {
        bail!("Microsoft account has no refresh token");
    }
    let endpoint = format!(
        "https://login.microsoftonline.com/{}/oauth2/v2.0/token",
        normalized_tenant(tenant)
    );
    let form = HashMap::from([
        ("client_id", client_id),
        ("refresh_token", token.refresh_token.as_str()),
        ("grant_type", "refresh_token"),
        ("scope", SCOPES),
    ]);
    let response = http.post(endpoint).form(&form).send().await?;
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
    tenant: &str,
    redirect_uri: &str,
    verifier: &str,
    code: &str,
) -> Result<OAuthToken> {
    let endpoint = format!("https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token");
    let form = HashMap::from([
        ("client_id", client_id),
        ("code", code),
        ("code_verifier", verifier),
        ("grant_type", "authorization_code"),
        ("redirect_uri", redirect_uri),
        ("scope", SCOPES),
    ]);
    let response = http.post(endpoint).form(&form).send().await?;
    if !response.status().is_success() {
        return Err(decode_error_response(response).await);
    }
    Ok(response.json::<TokenResponse>().await?.into_token(None))
}

fn normalized_tenant(tenant: &str) -> String {
    let tenant = tenant.trim();
    if tenant.is_empty() {
        "common".to_string()
    } else {
        tenant.to_string()
    }
}
