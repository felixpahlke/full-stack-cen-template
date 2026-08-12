import { createFileRoute, Outlet } from "@tanstack/react-router";
import { Loader2 } from "lucide-react";
import { Header } from "@/components/common/Header";
import useAuth from "@/hooks/useAuth";

export const Route = createFileRoute("/_layout")({
  component: Layout,
});

function Layout() {
  const { error, isLoading } = useAuth();

  return (
    <div className="relative">
      <Header />
      {isLoading ? (
        <div className="flex h-screen items-center justify-center">
          <Loader2 className="h-10 w-10 animate-spin" />
        </div>
      ) : error ? (
        <div
          className="mx-auto mt-24 max-w-3xl rounded-lg border border-destructive/50 bg-destructive/10 p-4"
          role="alert"
        >
          <h2 className="font-semibold">Application temporarily unavailable</h2>
          <p className="text-sm text-muted-foreground">
            The backend did not respond. Please try again shortly.
          </p>
        </div>
      ) : (
        <div className="mx-auto flex px-8 pb-24 pt-[47px]">
          <Outlet />
        </div>
      )}
    </div>
  );
}
