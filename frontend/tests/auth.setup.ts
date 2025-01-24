import { test as setup } from "@playwright/test";
import { playwrightTestUserEmail, playwrightTestUserPassword } from "./config";

const authFile = "playwright/.auth/user.json";

setup("authenticate", async ({ page }) => {
  await page.goto("/");
  await page.getByLabel("Email", { exact: true }).fill(playwrightTestUserEmail);
  await page
    .getByLabel("Password", { exact: true })
    .fill(playwrightTestUserPassword);
  await page.click("#cd_login_button");
  await page.waitForURL("/");
  await page.context().storageState({ path: authFile });
  await page.getByText("Welcome back, nice to see you again!").waitFor();
});
