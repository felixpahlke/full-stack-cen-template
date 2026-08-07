import path from "node:path";
import { tanstackRouter } from "@tanstack/router-plugin/vite";
import react from "@vitejs/plugin-react-swc";
import { defineConfig } from "vite";

// https://vitejs.dev/config/
export default defineConfig({
  build: {
    // Carbon's compiled SCSS contains a legacy media-query expression that Lightning CSS rejects.
    cssMinify: "esbuild",
  },
  plugins: [
    react(),
    tanstackRouter({
      target: "react",
      autoCodeSplitting: true,
    }),
  ],
  css: {
    preprocessorOptions: {
      scss: {
        silenceDeprecations: ["mixed-decls"],
      },
    },
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
      "~@ibm": path.resolve(__dirname, "node_modules/@ibm"),
    },
  },
  server: {
    watch: {
      usePolling: true,
      interval: 300,
    },
  },
});
