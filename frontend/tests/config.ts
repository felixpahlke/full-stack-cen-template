import path from "node:path";
import { fileURLToPath } from "node:url";
import dotenv from "dotenv";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.join(__dirname, "../../.env") });

const { PLAYWRIGHT_TEST_USER_EMAIL, PLAYWRIGHT_TEST_USER_PASSWORD } =
  process.env;

if (typeof PLAYWRIGHT_TEST_USER_EMAIL !== "string") {
  throw new Error(
    "Environment variable PLAYWRIGHT_TEST_USER_EMAIL is undefined",
  );
}

if (typeof PLAYWRIGHT_TEST_USER_PASSWORD !== "string") {
  throw new Error(
    "Environment variable PLAYWRIGHT_TEST_USER_PASSWORD is undefined",
  );
}

export const playwrightTestUserEmail = PLAYWRIGHT_TEST_USER_EMAIL as string;
export const playwrightTestUserPassword =
  PLAYWRIGHT_TEST_USER_PASSWORD as string;
