import { Outlet, createFileRoute } from "@tanstack/react-router";

import { Header } from "@/components/common/Header";
import useAuth from "@/hooks/useAuth";
import { Loader2 } from "lucide-react";

export const Route = createFileRoute("/_layout")({
  component: Layout,
});

function Layout() {
  const { isLoading } = useAuth();

  return (
    <div className="relative">
      <Header />
      {isLoading ? (
        <div className="flex h-screen items-center justify-center">
          <Loader2 className="h-10 w-10 animate-spin" />
        </div>
      ) : (
        <div className="mx-auto flex px-8 pb-24 pt-[47px]">
          <Outlet />
        </div>
      )}
    </div>
  );
}
