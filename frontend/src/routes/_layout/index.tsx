import { createFileRoute } from "@tanstack/react-router";

import useAuth from "../../hooks/useAuth";

export const Route = createFileRoute("/_layout/")({
  component: Dashboard,
});

function Dashboard() {
  const { user: currentUser } = useAuth();

  return (
    <div className="flex flex-col py-12">
      <h2 className="text-2xl">
        Hi, {currentUser?.name || currentUser?.email} 👋🏼
      </h2>
      <p>Welcome back, nice to see you again!</p>
    </div>
  );
}
