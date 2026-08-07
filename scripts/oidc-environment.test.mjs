import assert from "node:assert/strict";
import test from "node:test";

import { configureOidcEnvironment } from "./oidc-environment.mjs";

test("Dex remains the zero-configuration OIDC default", async () => {
  const environment = await configureOidcEnvironment({
    DEX_PORT: "5557",
    OAUTH2_PROXY_PORT: "4181",
  });

  assert.equal(environment.DEV_OIDC_USES_DEX, "true");
  assert.equal(environment.DEV_OIDC_ISSUER_URL, "http://localhost:5557/dex");
  assert.equal(environment.DEV_OIDC_REDEEM_URL, "http://dex:5556/dex/token");
  assert.equal(environment.DEV_OIDC_REDIRECT_URL, "http://localhost:4181/oauth2/callback");
});

test("an external issuer uses its standard discovery document", async () => {
  const requests = [];
  const environment = await configureOidcEnvironment(
    {
      OAUTH2_PROXY_OIDC_ISSUER_URL: "https://idp.example/oidc",
      OAUTH2_PROXY_REDIRECT_URL: "http://localhost:9000/oauth2/callback",
      OAUTH2_PROXY_COOKIE_DOMAIN: ".example.test",
    },
    async (url) => {
      requests.push(url);
      return metadataResponse("https://idp.example");
    },
  );

  assert.deepEqual(requests, ["https://idp.example/oidc/.well-known/openid-configuration"]);
  assert.equal(environment.DEV_OIDC_USES_DEX, "false");
  assert.equal(environment.DEV_OIDC_ISSUER_URL, "https://idp.example/oidc");
  assert.equal(environment.DEV_OIDC_LOGIN_URL, "https://idp.example/authorize");
  assert.equal(environment.DEV_OIDC_REDIRECT_URL, "http://localhost:9000/oauth2/callback");
  assert.equal(environment.DEV_OIDC_COOKIE_DOMAIN, ".example.test");
});

test("an explicit well-known URL overrides the standard discovery location", async () => {
  const requests = [];
  const environment = await configureOidcEnvironment(
    {
      OAUTH2_PROXY_OIDC_ISSUER_URL: "https://issuer.example",
      OAUTH2_PROXY_WELL_KNOWN_URL: "https://config.example/custom-openid.json",
    },
    async (url) => {
      requests.push(url);
      return metadataResponse("https://config.example");
    },
  );

  assert.deepEqual(requests, ["https://config.example/custom-openid.json"]);
  assert.equal(environment.DEV_OIDC_REDEEM_URL, "https://config.example/token");
  assert.equal(environment.DEV_OIDC_JWKS_URL, "https://config.example/keys");
});

function metadataResponse(origin) {
  return new Response(
    JSON.stringify({
      authorization_endpoint: `${origin}/authorize`,
      token_endpoint: `${origin}/token`,
      jwks_uri: `${origin}/keys`,
    }),
    { status: 200, headers: { "content-type": "application/json" } },
  );
}
