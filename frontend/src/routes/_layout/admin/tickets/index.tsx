import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Loading } from "@carbon/react";
import { TicketsTable } from "@/components/tickets/TicketsTable";
import type { TicketsPublic } from "@/client";

export const Route = createFileRoute("/_layout/admin/tickets/")({
  component: TicketsListPage,
});

function TicketsListPage() {
  const { data, isLoading, error } = useQuery<TicketsPublic>({
    queryKey: ["tickets"],
    queryFn: async () => {
      const response = await fetch("/api/v1/tickets/");
      if (!response.ok) {
        throw new Error("Failed to fetch tickets");
      }
      return response.json();
    },
    refetchInterval: 5000, // Refresh every 5 seconds
  });

  if (isLoading) {
    return (
      <div className="flex h-64 items-center justify-center">
        <Loading description="Loading tickets..." withOverlay={false} />
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-4 text-cds-text-error">
        Error loading tickets: {error.message}
      </div>
    );
  }

  if (!data || data.count === 0) {
    return (
      <div className="p-4">
        <h2 className="mb-4 text-xl font-semibold">All Tickets</h2>
        <p className="text-cds-text-secondary">
          No tickets found. Upload a CSV file to generate tickets.
        </p>
      </div>
    );
  }

  return (
    <div className="p-4">
      <TicketsTable tickets={data.data} />
    </div>
  );
}

// Made with Bob
