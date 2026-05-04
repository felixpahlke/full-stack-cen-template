import {
  DataTable,
  Table,
  TableHead,
  TableRow,
  TableHeader,
  TableBody,
  TableCell,
  Tag,
} from "@carbon/react";
import { useQuery } from "@tanstack/react-query";

interface ScanEvent {
  id: string;
  ticket_id: string;
  timestamp: string;
  scanner_device_id: string;
  scanner_user_id: string;
  scan_result: "granted" | "already_scanned" | "invalid" | "network_error";
  error_message?: string;
  network_latency_ms?: number;
}

interface ScanEventsResponse {
  data: ScanEvent[];
  count: number;
}

const headers = [
  { key: "timestamp", header: "Time" },
  { key: "ticket_id", header: "Ticket ID" },
  { key: "scan_result", header: "Result" },
  { key: "scanner_device_id", header: "Device" },
  { key: "scanner_user_id", header: "User" },
];

function getScanResultTag(result: string) {
  switch (result) {
    case "granted":
      return <Tag type="green">Granted</Tag>;
    case "already_scanned":
      return <Tag type="red">Already Scanned</Tag>;
    case "invalid":
      return <Tag type="red">Invalid</Tag>;
    case "network_error":
      return <Tag type="warm-gray">Network Error</Tag>;
    default:
      return <Tag type="gray">{result}</Tag>;
  }
}

function formatTimestamp(timestamp: string) {
  const date = new Date(timestamp);
  return date.toLocaleTimeString("en-US", {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

export function RecentScansTable() {
  const { data, isLoading } = useQuery({
    queryKey: ["recent-scans"],
    queryFn: async (): Promise<ScanEventsResponse> => {
      const response = await fetch("/api/v1/tickets/recent-scans?limit=50");
      if (!response.ok) {
        throw new Error("Failed to fetch recent scans");
      }
      return response.json();
    },
    refetchInterval: 2000, // Poll every 2 seconds for real-time updates
  });

  const rows =
    data?.data.map((event) => ({
      id: event.id,
      timestamp: formatTimestamp(event.timestamp),
      ticket_id: event.ticket_id.substring(0, 8) + "...",
      scan_result: event.scan_result,
      scanner_device_id: event.scanner_device_id.substring(0, 12) + "...",
      scanner_user_id: event.scanner_user_id,
    })) || [];

  if (isLoading) {
    return (
      <div className="animate-pulse">
        <div className="h-64 rounded bg-cds-layer-02" />
      </div>
    );
  }

  return (
    <DataTable rows={rows} headers={headers}>
      {({ rows, headers, getTableProps, getHeaderProps, getRowProps }) => (
        <Table {...getTableProps()} className="bg-cds-layer-01">
          <TableHead>
            <TableRow>
              {headers.map((header) => (
                <TableHeader {...getHeaderProps({ header })} key={header.key}>
                  {header.header}
                </TableHeader>
              ))}
            </TableRow>
          </TableHead>
          <TableBody>
            {rows.map((row) => (
              <TableRow {...getRowProps({ row })} key={row.id}>
                {row.cells.map((cell) => (
                  <TableCell key={cell.id}>
                    {cell.info.header === "scan_result"
                      ? getScanResultTag(cell.value as string)
                      : cell.value}
                  </TableCell>
                ))}
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
    </DataTable>
  );
}

// Made with Bob
