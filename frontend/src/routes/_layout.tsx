import { Outlet, createFileRoute, redirect } from "@tanstack/react-router";

import useAuth, { isLoggedIn } from "../hooks/useAuth";
import { Header } from "../components/Common/Header";

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
      <Header />
      {isLoading ? (
        <div className="mt-[47px] flex h-[calc(100dvh-47px)] w-full items-center justify-center">
          <div className="h-12 w-12 animate-spin rounded-full border-b-2 border-t-2"></div>
        </div>
      ) : (
        <div className="max-w-screen-xl mx-auto mt-[47px] flex px-8">
          <Outlet />
        </div>
      )}
    </div>
  );
}
