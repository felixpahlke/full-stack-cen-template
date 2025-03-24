import { expect, test } from "@playwright/test";
import { playwrightTestUserPassword } from "./config";
import { logInUser } from "./utils/user";
import { logOutUser } from "./utils/user";
import { playwrightTestUserEmail } from "./config";

test("User can switch from light mode to dark mode", async ({ page }) => {
  await page.goto("/");
  await page.getByText("Welcome back, nice to see you again!").waitFor();
  await page
    .getByRole("button", { name: "Theme Switcher" })
    .waitFor({ state: "visible" });
  await page.getByRole("button", { name: "Theme Switcher" }).click();
  await page.getByText("Dark", { exact: true }).click();
  const isDarkMode = await page.evaluate(() =>
    document.documentElement.classList.contains("dark"),
  );
  expect(isDarkMode).toBe(true);
});

test("User can switch from dark mode to light mode", async ({ page }) => {
  await page.goto("/");
  await page.getByText("Welcome back, nice to see you again!").waitFor();
  await page
    .getByRole("button", { name: "Theme Switcher" })
    .waitFor({ state: "visible" });
  await page.getByRole("button", { name: "Theme Switcher" }).click();
  await page.getByText("Light", { exact: true }).click();
  const isLightMode = await page.evaluate(() =>
    document.documentElement.classList.contains("light"),
  );
  expect(isLightMode).toBe(true);
});

test("Selected mode is preserved across sessions", async ({ page }) => {
  await page.goto("/");
  await page.getByText("Welcome back, nice to see you again!").waitFor();
  await page
    .getByRole("button", { name: "Theme Switcher" })
    .waitFor({ state: "visible" });
  await page.getByRole("button", { name: "Theme Switcher" }).click();
  await page.getByText("Dark", { exact: true }).click();

  await logOutUser(page);

  await logInUser(page, playwrightTestUserEmail, playwrightTestUserPassword);

  const isDarkMode = await page.evaluate(() =>
    document.documentElement.classList.contains("dark"),
  );
  expect(isDarkMode).toBe(true);
});
