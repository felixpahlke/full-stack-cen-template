import { createFileRoute } from "@tanstack/react-router";
import { Button } from "@carbon/react";
import { WarningAlt } from "@carbon/icons-react";
import { useState } from "react";

import useAuth from "../../hooks/useAuth";

export const Route = createFileRoute("/_layout/")({
  component: Dashboard,
});

function Dashboard() {
  const { user: currentUser } = useAuth();
  const [shouldError, setShouldError] = useState(false);

  // Trigger error when button is clicked
  if (shouldError) {
    throw new Error("Test error to demonstrate ErrorBoundary");
  }

  return (
    <div className="flex flex-col gap-6 py-12">
      <div>
        <h2 className="text-2xl">
          Hi, {currentUser?.full_name || currentUser?.email} 👋🏼
        </h2>
        <p>Welcome back, nice to see you again!</p>
      </div>

      {/* Test ErrorBoundary Button */}
      <div className="rounded-lg border border-cds-border-subtle bg-cds-layer p-6">
        <h3 className="mb-2 text-lg font-semibold text-cds-text-primary">
          Test Error Boundary
        </h3>
        <p className="mb-4 text-sm text-cds-text-secondary">
          Click the button below to trigger an error and see the beautiful
          Carbon Design System error page.
        </p>
        <Button
          kind="danger"
          renderIcon={WarningAlt}
          onClick={() => setShouldError(true)}
        >
          Trigger Error Boundary
        </Button>
      </div>
    </div>
  );
}
