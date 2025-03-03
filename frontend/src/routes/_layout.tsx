import { Outlet, createFileRoute } from "@tanstack/react-router";

import { Header } from "../components/common/Header";
import useAuth from "../hooks/useAuth";
import { Loading } from "@carbon/react";

export const Route = createFileRoute("/_layout")({
  component: Layout,
});

function Layout() {
  const { isLoading } = useAuth();

  return (
    <div className="relative">
      <Header />
      {isLoading ? (
        <Loading />
      ) : (
        <div className="max-w-screen-xl mx-auto flex px-8 pb-24 pt-[47px]">
          <Outlet />
        </div>
      )}
    </div>
  );
}
