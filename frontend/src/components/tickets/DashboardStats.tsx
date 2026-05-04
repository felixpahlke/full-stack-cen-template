import { Tile } from "@carbon/react";
import { useQuery } from "@tanstack/react-query";

interface DashboardStats {
  total_tickets: number;
  scanned_tickets: number;
  remaining_tickets: number;
  scan_rate_per_minute: number;
}

export function DashboardStats() {
  const { data: stats, isLoading } = useQuery({
    queryKey: ["dashboard-stats"],
    queryFn: async (): Promise<DashboardStats> => {
      const response = await fetch("/api/v1/tickets/dashboard");
      if (!response.ok) {
        throw new Error("Failed to fetch dashboard stats");
      }
      return response.json();
    },
    refetchInterval: 2000, // Poll every 2 seconds for real-time updates
  });

  if (isLoading) {
    return (
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
        {[...Array(4)].map((_, i) => (
          <Tile key={i} className="animate-pulse">
            <div className="h-20 rounded bg-cds-layer-02" />
          </Tile>
        ))}
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
      <Tile className="bg-cds-layer-01">
        <div className="flex flex-col">
          <span className="mb-2 text-sm text-cds-text-secondary">
            Total Tickets
          </span>
          <span className="text-4xl font-semibold text-cds-text-primary">
            {stats?.total_tickets ?? 0}
          </span>
        </div>
      </Tile>

      <Tile className="bg-cds-layer-01">
        <div className="flex flex-col">
          <span className="mb-2 text-sm text-cds-text-secondary">Scanned</span>
          <span className="text-4xl font-semibold text-cds-support-success">
            {stats?.scanned_tickets ?? 0}
          </span>
        </div>
      </Tile>

      <Tile className="bg-cds-layer-01">
        <div className="flex flex-col">
          <span className="mb-2 text-sm text-cds-text-secondary">
            Remaining
          </span>
          <span className="text-4xl font-semibold text-cds-support-info">
            {stats?.remaining_tickets ?? 0}
          </span>
        </div>
      </Tile>

      <Tile className="bg-cds-layer-01">
        <div className="flex flex-col">
          <span className="mb-2 text-sm text-cds-text-secondary">
            Scan Rate
          </span>
          <span className="text-4xl font-semibold text-cds-text-primary">
            {stats?.scan_rate_per_minute ?? 0}
          </span>
          <span className="mt-1 text-xs text-cds-text-secondary">
            per minute
          </span>
        </div>
      </Tile>
    </div>
  );
}

// Made with Bob
