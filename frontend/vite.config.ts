import path from "node:path";
import { tanstackRouter } from "@tanstack/router-plugin/vite";
import react from "@vitejs/plugin-react-swc";
import { defineConfig, loadEnv } from "vite";

export default defineConfig(({ mode }) => {
  const root = path.resolve(import.meta.dirname, "..");
  const env = loadEnv(mode, root, "");
  const apiPort = env.API_PORT || "8000";

  return {
    envDir: root,
    plugins: [react(), tanstackRouter({ target: "react", autoCodeSplitting: true })],
    css: {
      preprocessorOptions: { scss: { silenceDeprecations: ["mixed-decls"] } },
    },
    resolve: { alias: { "@": path.resolve(import.meta.dirname, "./src") } },
    server: {
      host: true,
      port: Number(env.WEB_PORT) || 5173,
      strictPort: true,
      proxy: { "/api": `http://127.0.0.1:${apiPort}` },
      watch: { usePolling: true, interval: 300 },
    },
  };
});
