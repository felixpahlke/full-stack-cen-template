import { expect, type Page, test } from "@playwright/test";
import { logInUser, logOutUser } from "./utils/user";

async function selectTheme(page: Page, theme: "Light Mode" | "Dark Mode" | "System") {
  await page.getByRole("button", { name: "Theme Switcher" }).click();
  await page.getByText(theme, { exact: true }).click();
}

async function expectCarbonTheme(page: Page, theme: "g10" | "g90") {
  const root = page.locator("html");
  await expect(root).toHaveClass(new RegExp(`cds--${theme}`));
  await expect(root).not.toHaveClass(new RegExp(`cds--${theme === "g10" ? "g90" : "g10"}`));
}

test("light, dark, and system Carbon themes switch and persist", async ({ page }) => {
  await page.emulateMedia({ colorScheme: "light" });
  await page.goto("/");
  await page.getByText("Welcome back, nice to see you again!").waitFor();

  await selectTheme(page, "Dark Mode");
  await expect(page.locator("html")).toHaveClass(/dark/);
  await expectCarbonTheme(page, "g90");
  await expect.poll(() => page.evaluate(() => localStorage.getItem("vite-ui-theme"))).toBe("dark");

  await page.reload();
  await expect(page.locator("html")).toHaveClass(/dark/);
  await expectCarbonTheme(page, "g90");

  await selectTheme(page, "Light Mode");
  await expect(page.locator("html")).not.toHaveClass(/dark/);
  await expectCarbonTheme(page, "g10");
  await expect.poll(() => page.evaluate(() => localStorage.getItem("vite-ui-theme"))).toBe("light");

  await page.emulateMedia({ colorScheme: "dark" });
  await selectTheme(page, "System");
  await expect(page.locator("html")).toHaveClass(/dark/);
  await expectCarbonTheme(page, "g90");
  await expect
    .poll(() => page.evaluate(() => localStorage.getItem("vite-ui-theme")))
    .toBe("system");

  await page.emulateMedia({ colorScheme: "light" });
  await expect(page.locator("html")).not.toHaveClass(/dark/);
  await expectCarbonTheme(page, "g10");

  await page.reload();
  await expectCarbonTheme(page, "g10");
  await expect
    .poll(() => page.evaluate(() => localStorage.getItem("vite-ui-theme")))
    .toBe("system");
});

test("legacy Carbon preference migrates to the current storage key", async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.removeItem("vite-ui-theme");
    localStorage.setItem("carbon-theme", "dark");
  });

  await page.goto("/");

  await expect(page.locator("html")).toHaveClass(/dark/);
  await expect.poll(() => page.evaluate(() => localStorage.getItem("vite-ui-theme"))).toBe("dark");
  await expect.poll(() => page.evaluate(() => localStorage.getItem("carbon-theme"))).toBeNull();
});

test("selected Carbon theme survives proxy sign-out and Dex sign-in", async ({ page }) => {
  await page.goto("/");
  await selectTheme(page, "Dark Mode");
  await logOutUser(page);
  await logInUser(page);
  await expect(page.locator("html")).toHaveClass(/dark/);
  await expectCarbonTheme(page, "g90");
});
