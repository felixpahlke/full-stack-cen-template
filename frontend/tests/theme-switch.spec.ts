import { expect, type Page, test } from "@playwright/test";
import { logInUser, logOutUser } from "./utils/user";

async function selectTheme(page: Page, theme: "Light" | "Dark" | "System") {
  await page.getByRole("button", { name: "Theme Switcher" }).click();
  await page.getByText(theme, { exact: true }).click();
}

test("light, dark, and system themes follow the selected policy", async ({ page }) => {
  await page.goto("/");
  await selectTheme(page, "Dark");
  await expect(page.locator("html")).toHaveClass(/dark/);
  await selectTheme(page, "Light");
  await expect(page.locator("html")).not.toHaveClass(/dark/);
  await page.emulateMedia({ colorScheme: "dark" });
  await selectTheme(page, "System");
  await expect(page.locator("html")).toHaveClass(/dark/);
});

test("selected theme survives proxy sign-out and Dex sign-in", async ({ page }) => {
  await page.goto("/");
  await selectTheme(page, "Dark");
  await logOutUser(page);
  await logInUser(page);
  await expect(page.locator("html")).toHaveClass(/dark/);
});
