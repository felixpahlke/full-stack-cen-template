import { expect, type Page, test } from "@playwright/test";

async function selectTheme(page: Page, theme: "Light" | "Dark" | "System") {
  await page.getByRole("button", { name: "Toggle theme" }).click();
  await page.getByText(theme, { exact: true }).click();
}

test("light, dark, and system themes switch and persist", async ({ page }) => {
  await page.emulateMedia({ colorScheme: "light" });
  await page.goto("/");
  await page.getByText("Welcome back, nice to see you again!").waitFor();

  await selectTheme(page, "Dark");
  await expect(page.locator("html")).toHaveClass(/dark/);
  await expect.poll(() => page.evaluate(() => localStorage.getItem("vite-ui-theme"))).toBe("dark");

  await page.reload();
  await expect(page.locator("html")).toHaveClass(/dark/);

  await selectTheme(page, "Light");
  await expect(page.locator("html")).not.toHaveClass(/dark/);
  await expect.poll(() => page.evaluate(() => localStorage.getItem("vite-ui-theme"))).toBe("light");

  await page.emulateMedia({ colorScheme: "dark" });
  await selectTheme(page, "System");
  await expect(page.locator("html")).toHaveClass(/dark/);
  await expect
    .poll(() => page.evaluate(() => localStorage.getItem("vite-ui-theme")))
    .toBe("system");

  await page.emulateMedia({ colorScheme: "light" });
  await expect(page.locator("html")).not.toHaveClass(/dark/);

  await page.reload();
  await expect(page.locator("html")).not.toHaveClass(/dark/);
  await expect
    .poll(() => page.evaluate(() => localStorage.getItem("vite-ui-theme")))
    .toBe("system");
});
