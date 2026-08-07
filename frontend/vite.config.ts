import path from "node:path";
import tailwindcss from "@tailwindcss/vite";
import { tanstackRouter } from "@tanstack/router-plugin/vite";
import react from "@vitejs/plugin-react-swc";
import { defineConfig, loadEnv } from "vite";

export default defineConfig(({ mode }) => {
  const root = path.resolve(import.meta.dirname, "..");
  const env = loadEnv(mode, root, "");
  const apiPort = env.API_PORT || "8000";

  return {
    envDir: root,
    plugins: [
      tanstackRouter({
        target: "react",
        autoCodeSplitting: true,
      }),
      react(),
      tailwindcss(),
    ],
    resolve: {
      alias: {
        "@": path.resolve(import.meta.dirname, "./src"),
      },
    },
    server: {
      host: true,
      allowedHosts: ["host.docker.internal"],
      port: Number(env.WEB_PORT) || 5173,
      strictPort: true,
      proxy: { "/api": `http://127.0.0.1:${apiPort}` },
      watch: {
        usePolling: true,
        interval: 300,
      },
    },
  };
});
