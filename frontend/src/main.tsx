import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { createRouter, RouterProvider } from "@tanstack/react-router";
import { StrictMode } from "react";
import ReactDOM from "react-dom/client";
import { Toaster } from "@/components/common/Toaster";
import { client } from "./client/client.gen";
import { ThemeProvider } from "./components/theme/ThemeProvider";
import { trackFlavor } from "./lib/trackFlavor";
import { routeTree } from "./routeTree.gen";
import "./styles/carbon.scss";
import "./styles/index.css";

client.setConfig({
  baseURL: import.meta.env.VITE_API_URL || "",
  throwOnError: true,
});

const queryClient = new QueryClient();

const router = createRouter({ routeTree });
declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}

trackFlavor();

ReactDOM.createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <ThemeProvider>
      <Toaster />
      <QueryClientProvider client={queryClient}>
        <RouterProvider router={router} />
      </QueryClientProvider>
    </ThemeProvider>
  </StrictMode>,
);
