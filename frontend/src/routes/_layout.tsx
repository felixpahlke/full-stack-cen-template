import { Outlet, createFileRoute, redirect } from "@tanstack/react-router";

import useAuth, { isLoggedIn } from "../hooks/useAuth";
import { Navbar } from "../components/Common/Navbar";

export const Route = createFileRoute("/_layout")({
  component: Layout,
  beforeLoad: async () => {
    if (!isLoggedIn()) {
      throw redirect({
        to: "/login",
      });
    }
  },
});

function Layout() {
  const { isLoading } = useAuth();

  return (
    <div className="relative">
      <Navbar />
      {isLoading ? (
        <div className="flex h-[calc(100dvh-80px)] w-full items-center justify-center">
          <div className="h-12 w-12 animate-spin rounded-full border-b-2 border-t-2"></div>
        </div>
      ) : (
        <div className="mx-auto flex max-w-screen-xl px-8">
          <Outlet />
        </div>
      )}
    </div>
  );
}
