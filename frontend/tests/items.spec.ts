import { expect, test } from "@playwright/test";

test("authenticated OIDC subject can create, list, read, update, and delete an item", async ({
  page,
}) => {
  const diagnostics: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error" || message.type() === "warning") {
      diagnostics.push(`${message.type()}: ${message.text()}`);
    }
  });
  page.on("pageerror", (error) => diagnostics.push(`pageerror: ${error.message}`));

  const title = `OAuth item ${Date.now()}`;
  const updatedTitle = `${title} updated`;
  await page.goto("/");
  await expect(page.getByText("Welcome back, nice to see you again!")).toBeVisible();
  await page.goto("/items");
  await page.getByRole("button", { name: "Add Item" }).click();
  await page.getByLabel("Title").fill(title);
  await page.getByLabel("Description").fill("Created through oauth2-proxy");
  await page.getByRole("button", { name: "Save" }).click();
  const row = page.getByRole("row").filter({ hasText: title });
  await expect(row).toBeVisible();

  await row.getByRole("button", { name: `Actions for ${title}` }).click();
  await page.getByRole("menuitem", { name: "Edit Item" }).click();
  await page.getByLabel("Title").fill(updatedTitle);
  await page.getByRole("button", { name: "Save" }).click();
  const updatedRow = page.getByRole("row").filter({ hasText: updatedTitle });
  await expect(updatedRow).toBeVisible();

  await updatedRow.getByRole("button", { name: `Actions for ${updatedTitle}` }).click();
  await page.getByRole("menuitem", { name: "Delete Item" }).click();
  await page.getByRole("button", { name: "Delete", exact: true }).click();
  await expect(updatedRow).not.toBeVisible();
  expect(diagnostics).toEqual([]);
});
