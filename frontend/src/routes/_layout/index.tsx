import { createFileRoute } from "@tanstack/react-router";

import useAuth from "../../hooks/useAuth";

export const Route = createFileRoute("/_layout/")({
  component: Dashboard,
});

function Dashboard() {
  const { user: currentUser } = useAuth();

  return (
    <div className="flex flex-col gap-6 py-12">
      <div>
        <h2 className="text-2xl">
          Hi, {currentUser?.full_name || currentUser?.email} 👋🏼
        </h2>
        <p>Welcome back, nice to see you again!</p>
      </div>
    </div>
  );
}
