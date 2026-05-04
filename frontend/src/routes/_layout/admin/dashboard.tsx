import { createFileRoute } from "@tanstack/react-router";
import { DashboardStats } from "@/components/tickets/DashboardStats";
import { RecentScansTable } from "@/components/tickets/RecentScansTable";
import { Renew } from "@carbon/icons-react";

export const Route = createFileRoute("/_layout/admin/dashboard")({
  component: DashboardPage,
});

function DashboardPage() {
  return (
    <div className="container mx-auto space-y-6 p-6">
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="mb-2 text-3xl font-semibold text-cds-text-primary">
            Ticket Dashboard
          </h1>
          <p className="text-cds-text-secondary">
            Real-time monitoring of ticket validation activity
          </p>
        </div>
        <div className="flex items-center gap-2 text-sm text-cds-text-secondary">
          <Renew className="animate-spin" size={16} />
          <span>Auto-refreshing every 2 seconds</span>
        </div>
      </div>

      <DashboardStats />

      <div className="mt-8">
        <h2 className="mb-4 text-xl font-semibold text-cds-text-primary">
          Recent Scan Activity
        </h2>
        <RecentScansTable />
      </div>
    </div>
  );
}

// Made with Bob
