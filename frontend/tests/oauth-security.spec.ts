import http from "node:http";
import { expect, test } from "@playwright/test";
import { proxyUrl } from "./config";

test("real proxy rejects unauthenticated identity and authorization spoofing", async ({ page }) => {
  const probes = [
    [],
    ["X-Forwarded-User", "forged", "X-Forwarded-Email", "forged@example.com"],
    ["X_Forwarded_User", "forged", "X_Forwarded_Email", "forged@example.com"],
    ["Authorization", "Bearer client-supplied-token"],
  ];
  for (const headers of probes) {
    const response = await rawRequest(headers);
    expect(response.status).toBe(302);
    expect(response.location).toContain("/dex/auth");
  }

  const duplicate = await rawRequest([
    "X-Forwarded-User",
    "first",
    "X-Forwarded-User",
    "second",
    "X-Forwarded-Email",
    "forged@example.com",
  ]);
  expect(duplicate.status).toBe(302);
  expect(duplicate.location).toContain("/dex/auth");

  const genuine = await page.request.get("/api/v1/users/me", { maxRedirects: 0 });
  expect(genuine.status()).toBe(200);
});

function rawRequest(headers: string[]): Promise<{ status: number; location: string }> {
  const target = new URL("/api/v1/users/me", proxyUrl);
  return new Promise((resolve, reject) => {
    const req = http.request(
      target,
      { method: "GET", headers: ["Host", target.host, ...headers] },
      (response) => {
        response.resume();
        response.once("end", () =>
          resolve({
            status: response.statusCode || 0,
            location: response.headers.location || "",
          }),
        );
      },
    );
    req.once("error", reject);
    req.end();
  });
}
