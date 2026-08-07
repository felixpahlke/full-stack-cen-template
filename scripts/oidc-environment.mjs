const metadataFields = ["authorization_endpoint", "token_endpoint", "jwks_uri"];

export async function configureOidcEnvironment(environment, fetchMetadata = fetch) {
  const issuer = environment.OAUTH2_PROXY_OIDC_ISSUER_URL?.trim();
  const proxyPort = environment.OAUTH2_PROXY_PORT || "4180";
  const dexPort = environment.DEX_PORT || "5556";

  environment.DEV_OIDC_REDIRECT_URL =
    environment.OAUTH2_PROXY_REDIRECT_URL?.trim() ||
    `http://localhost:${proxyPort}/oauth2/callback`;
  environment.DEV_OIDC_COOKIE_DOMAIN = environment.OAUTH2_PROXY_COOKIE_DOMAIN?.trim() || "";

  if (!issuer) {
    environment.DEV_OIDC_USES_DEX = "true";
    environment.DEV_OIDC_ISSUER_URL = `http://localhost:${dexPort}/dex`;
    environment.DEV_OIDC_SKIP_DISCOVERY = "true";
    environment.DEV_OIDC_LOGIN_URL = `http://localhost:${dexPort}/dex/auth`;
    environment.DEV_OIDC_REDEEM_URL = "http://dex:5556/dex/token";
    environment.DEV_OIDC_JWKS_URL = "http://dex:5556/dex/keys";
    return environment;
  }

  const metadataUrl =
    environment.OAUTH2_PROXY_WELL_KNOWN_URL?.trim() ||
    `${issuer.replace(/\/$/, "")}/.well-known/openid-configuration`;
  let response;
  try {
    response = await fetchMetadata(metadataUrl, { signal: AbortSignal.timeout(10_000) });
  } catch (error) {
    throw failure(`Could not load OIDC metadata from ${metadataUrl}: ${error.message}`);
  }
  if (!response.ok) {
    throw failure(`OIDC metadata request ${metadataUrl} returned HTTP ${response.status}.`);
  }

  let metadata;
  try {
    metadata = await response.json();
  } catch (error) {
    throw failure(`OIDC metadata from ${metadataUrl} is not valid JSON: ${error.message}`);
  }
  for (const field of metadataFields) assertHttpUrl(metadata[field], field, metadataUrl);

  environment.DEV_OIDC_USES_DEX = "false";
  environment.DEV_OIDC_ISSUER_URL = issuer;
  environment.DEV_OIDC_SKIP_DISCOVERY = "true";
  environment.DEV_OIDC_LOGIN_URL = metadata.authorization_endpoint;
  environment.DEV_OIDC_REDEEM_URL = metadata.token_endpoint;
  environment.DEV_OIDC_JWKS_URL = metadata.jwks_uri;
  return environment;
}

function assertHttpUrl(value, field, metadataUrl) {
  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    throw failure(`OIDC metadata ${metadataUrl} has an invalid ${field}.`);
  }
  if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
    throw failure(`OIDC metadata ${metadataUrl} has a non-HTTP ${field}.`);
  }
}

function failure(message) {
  const error = new Error(message);
  error.exitCode = 1;
  return error;
}
