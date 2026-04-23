import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RouterProvider, createRouter } from "@tanstack/react-router";
import ReactDOM from "react-dom/client";
import { routeTree } from "./routeTree.gen";

import { StrictMode } from "react";
import { client } from "./client/client.gen";

import { ErrorBoundary } from "@/components/common/ErrorBoundary";
import { Toaster } from "@/components/common/Toaster";
import { ThemeProvider } from "./components/theme/ThemeProvider";
import { setupApiLogging } from "./lib/apiLogger";
import { logger } from "./lib/logger";
import { trackFlavor } from "./lib/trackFlavor";
import "./styles/globals.scss";
import "./styles/tailwind.scss";

client.setConfig({
  baseURL: import.meta.env.VITE_API_URL || "",
  throwOnError: true,
  auth: async () => {
    return localStorage.getItem("access_token") || undefined;
  },
});

// Setup API logging interceptors
const axiosInstance = client.instance;
if (axiosInstance) {
  setupApiLogging(axiosInstance);
}

const queryClient = new QueryClient();

const router = createRouter({ routeTree });
declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}

trackFlavor();

// Log application startup
logger.debug("Application starting", "main");

ReactDOM.createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <ErrorBoundary>
      <ThemeProvider>
        <Toaster />
        <QueryClientProvider client={queryClient}>
          <RouterProvider router={router} />
        </QueryClientProvider>
      </ThemeProvider>
    </ErrorBoundary>
  </StrictMode>,
);

// Log when application is mounted
logger.debug("Application mounted successfully", "main");
