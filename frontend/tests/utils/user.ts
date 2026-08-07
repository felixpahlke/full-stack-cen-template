import { expect, type Page } from "@playwright/test";
import { dexTestUserEmail, dexTestUserPassword } from "../config";

export async function logInUser(page: Page) {
  await page.goto("/");
  const login = page.locator('input[name="login"]');
  if (await login.isVisible()) {
    await login.fill(dexTestUserEmail);
    await page.locator('input[name="password"]').fill(dexTestUserPassword);
    await page.getByRole("button", { name: /login/i }).click();
  }
  await expect(page.getByText("Welcome back, nice to see you again!")).toBeVisible();
}

export async function logOutUser(page: Page) {
  const signOut = page.waitForRequest(
    (request) => new URL(request.url()).pathname === "/oauth2/sign_out",
  );
  await page.getByTestId("user-menu").click();
  await page.getByRole("menuitem", { name: "Log out" }).click();
  await signOut;
  await expect(page.locator('input[name="login"]')).toBeVisible();
}
