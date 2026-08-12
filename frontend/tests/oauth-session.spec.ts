import { expect, test } from "@playwright/test";
import { logOutUser } from "./utils/user";

test("proxy sign-out clears the session and requires Dex authentication", async ({ page }) => {
  await page.goto("/");
  await logOutUser(page);
  expect((await page.context().cookies()).map((cookie) => cookie.name)).not.toContain(
    "_oauth2_proxy",
  );
  await page.goto("/");
  await expect(page.locator('input[name="login"]')).toBeVisible();
});

test("an invalid or expired-looking session cookie is redirected to authentication", async ({
  browser,
  baseURL,
}) => {
  const context = await browser.newContext();
  await context.addCookies([
    {
      name: "_oauth2_proxy",
      value: "invalid-session-value",
      url: baseURL,
    },
  ]);
  const page = await context.newPage();
  await page.goto("/");
  await expect(page.locator('input[name="login"]')).toBeVisible();
  await context.close();
});

test("a backend failure shows an error without starting a logout loop", async ({ page }) => {
  const signOutRequests: string[] = [];
  page.on("request", (request) => {
    if (new URL(request.url()).pathname === "/oauth2/sign_out") {
      signOutRequests.push(request.url());
    }
  });
  await page.route("**/api/v1/users/me", (route) =>
    route.fulfill({ status: 503, contentType: "application/json", body: "{}" }),
  );

  await page.goto("/");

  await expect(page.getByText("Application temporarily unavailable")).toBeVisible();
  await page.waitForTimeout(500);
  expect(signOutRequests).toHaveLength(0);
});
