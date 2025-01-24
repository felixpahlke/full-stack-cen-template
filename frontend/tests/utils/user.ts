import { type Page } from "@playwright/test";

export async function logInUser(page: Page, email: string, password: string) {
  await page.goto("/");
  await page.getByLabel("Email", { exact: true }).fill(email);
  await page.getByLabel("Password", { exact: true }).fill(password);
  await page.click("#cd_login_button");
  await page.waitForURL("/");
  await page.getByText("Welcome back, nice to see you again!").waitFor();
}

export async function logOutUser(page: Page) {
  await page.getByLabel("User menu").click();
  await page.getByText("Log out", { exact: true }).click();
  await page.goto("/");
}
