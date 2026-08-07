import { Loading } from "@carbon/react";
import { createFileRoute, Outlet } from "@tanstack/react-router";
import { Header } from "../components/common/Header";
import useAuth from "../hooks/useAuth";

export const Route = createFileRoute("/_layout")({
  component: Layout,
});

export function Layout() {
  const { isLoading } = useAuth();

  return (
    <div className="relative">
      <Header />
      {isLoading ? (
        <Loading />
      ) : (
        <div className="mx-auto flex max-w-7xl px-8 pb-24 pt-[47px]">
          <Outlet />
        </div>
      )}
    </div>
  );
}
