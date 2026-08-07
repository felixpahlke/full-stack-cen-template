import { defineConfig } from "@hey-api/openapi-ts";

export default defineConfig({
  input: process.env.OPENAPI_INPUT || "./openapi.json",
  output: process.env.OPENAPI_OUTPUT || "./src/client",
  plugins: [
    "@hey-api/client-axios",
    "@hey-api/typescript",
    "@hey-api/schemas",
    {
      name: "@hey-api/sdk",
      operations: { strategy: "byTags" },
    },
  ],
});
