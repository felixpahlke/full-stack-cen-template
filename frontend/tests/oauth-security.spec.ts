import http from "node:http";
import { expect, request, test } from "@playwright/test";
import { proxyUrl } from "./config";

test("real proxy rejects unauthenticated identity and authorization spoofing", async ({ page }) => {
  const anonymous = await request.newContext({ baseURL: proxyUrl });
  const probes: Array<Record<string, string>> = [
    {},
    { "X-Forwarded-User": "forged", "X-Forwarded-Email": "forged@example.com" },
    { X_Forwarded_User: "forged", X_Forwarded_Email: "forged@example.com" },
    { Authorization: "Bearer client-supplied-token" },
  ];
  for (const headers of probes) {
    const response = await anonymous.get("/api/v1/users/me", {
      headers,
      maxRedirects: 0,
    });
    expect(response.status()).toBe(302);
    expect(response.headers().location).toContain("/oauth2/");
  }
  await anonymous.dispose();

  const duplicate = await rawRequest([
    "X-Forwarded-User",
    "first",
    "X-Forwarded-User",
    "second",
    "X-Forwarded-Email",
    "forged@example.com",
  ]);
  expect(duplicate.status).toBe(302);
  expect(duplicate.location).toContain("/oauth2/");

  const genuine = await page.request.get("/api/v1/users/me", { maxRedirects: 0 });
  expect(genuine.status()).toBe(200);
});

function rawRequest(headers: string[]): Promise<{ status: number; location: string }> {
  const target = new URL("/api/v1/users/me", proxyUrl);
  return new Promise((resolve, reject) => {
    const req = http.request(target, { method: "GET", headers }, (response) => {
      response.resume();
      response.once("end", () =>
        resolve({
          status: response.statusCode || 0,
          location: response.headers.location || "",
        }),
      );
    });
    req.once("error", reject);
    req.end();
  });
}
