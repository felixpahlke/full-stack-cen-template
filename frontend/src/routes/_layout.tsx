import { InlineNotification, Loading } from "@carbon/react";
import { createFileRoute, Outlet } from "@tanstack/react-router";
import { Header } from "../components/common/Header";
import useAuth from "../hooks/useAuth";

export const Route = createFileRoute("/_layout")({
  component: Layout,
});

function Layout() {
  const { error, isLoading } = useAuth();

  return (
    <div className="relative">
      <Header />
      {isLoading ? (
        <Loading />
      ) : error ? (
        <div className="mx-auto max-w-3xl px-8 pt-24">
          <InlineNotification
            hideCloseButton
            kind="error"
            lowContrast
            subtitle="The backend did not respond. Please try again shortly."
            title="Application temporarily unavailable"
          />
        </div>
      ) : (
        <div className="mx-auto flex max-w-7xl px-8 pb-24 pt-[47px]">
          <Outlet />
        </div>
      )}
    </div>
  );
}
