import { expect, test as setup } from "@playwright/test";
import { dexTestUserEmail, dexTestUserPassword } from "./config";

const authFile = "playwright/.auth/user.json";

setup("authenticate through bundled Dex", async ({ page }) => {
  await page.goto("/");
  await page.locator('input[name="login"]').fill(dexTestUserEmail);
  await page.locator('input[name="password"]').fill(dexTestUserPassword);
  await page.getByRole("button", { name: /login/i }).click();
  await expect(page.getByText("Welcome back, nice to see you again!")).toBeVisible();

  const me = await page.request.get("/api/v1/users/me");
  expect(me.status()).toBe(200);
  const principal = await me.json();
  expect(principal).toMatchObject({
    email: dexTestUserEmail,
    name: dexTestUserEmail,
  });
  expect(principal.id).not.toMatch(/^[0-9a-f-]{36}$/i);
  await page.context().storageState({ path: authFile });
});
