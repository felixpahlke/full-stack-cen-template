import { useState } from "react";
import {
  DataTable,
  TableContainer,
  Table,
  TableHead,
  TableRow,
  TableHeader,
  TableBody,
  TableCell,
  Modal,
  Button,
  Tag,
  InlineNotification,
} from "@carbon/react";
import {
  View,
  Download,
  Checkmark,
  Close,
  TrashCan,
} from "@carbon/icons-react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import type { TicketPublic } from "@/client";

interface TicketsTableProps {
  tickets: TicketPublic[];
}

export function TicketsTable({ tickets }: TicketsTableProps) {
  const [selectedTicket, setSelectedTicket] = useState<TicketPublic | null>(
    null,
  );
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const queryClient = useQueryClient();

  const deleteMutation = useMutation({
    mutationFn: async (ticketId: string) => {
      const response = await fetch(`/api/v1/tickets/${ticketId}`, {
        method: "DELETE",
      });
      if (!response.ok) {
        throw new Error("Failed to delete ticket");
      }
    },
    onSuccess: () => {
      // Invalidate and refetch tickets
      queryClient.invalidateQueries({ queryKey: ["tickets"] });
      setDeleteError(null);
    },
    onError: (error: Error) => {
      setDeleteError(error.message);
    },
  });

  const handleDelete = (ticketId: string, guestName: string) => {
    if (
      confirm(`Are you sure you want to delete the ticket for ${guestName}?`)
    ) {
      deleteMutation.mutate(ticketId);
    }
  };

  const headers = [
    { key: "guest_name", header: "Guest Name" },
    { key: "guest_email", header: "Guest Email" },
    { key: "host_email", header: "Host Email" },
    { key: "role", header: "Role" },
    { key: "status", header: "Status" },
    { key: "actions", header: "Actions" },
  ];

  const rows = tickets.map((ticket) => ({
    id: ticket.id,
    guest_name: `${ticket.first_name} ${ticket.last_name}`,
    guest_email: ticket.guest_email,
    host_email: ticket.host_email,
    role: ticket.role || "Guest",
    status: ticket.is_scanned ? (
      <Tag type="green" size="sm">
        <Checkmark size={16} /> Scanned
      </Tag>
    ) : (
      <Tag type="blue" size="sm">
        <Close size={16} /> Not Scanned
      </Tag>
    ),
    actions: (
      <div className="flex gap-2">
        <Button
          kind="ghost"
          size="sm"
          renderIcon={View}
          iconDescription="View QR Code"
          hasIconOnly
          onClick={() => {
            setSelectedTicket(ticket);
            setIsModalOpen(true);
          }}
        />
        <Button
          kind="ghost"
          size="sm"
          renderIcon={Download}
          iconDescription="Download QR Code"
          hasIconOnly
          onClick={() => downloadQRCode(ticket)}
        />
        <Button
          kind="danger--ghost"
          size="sm"
          renderIcon={TrashCan}
          iconDescription="Delete Ticket"
          hasIconOnly
          onClick={() =>
            handleDelete(ticket.id, `${ticket.first_name} ${ticket.last_name}`)
          }
        />
      </div>
    ),
  }));

  const downloadQRCode = (ticket: TicketPublic) => {
    // Create a temporary link to download the QR code
    const link = document.createElement("a");
    link.href = ticket.qr_code_data;
    link.download = `ticket-${ticket.first_name}-${ticket.last_name}-${ticket.id}.png`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <>
      {deleteError && (
        <InlineNotification
          kind="error"
          title="Delete Failed"
          subtitle={deleteError}
          onClose={() => setDeleteError(null)}
          className="mb-4"
        />
      )}
      <DataTable rows={rows} headers={headers}>
        {({ rows, headers, getTableProps, getHeaderProps, getRowProps }) => (
          <TableContainer
            title="All Tickets"
            description="View and manage event tickets"
          >
            <Table {...getTableProps()}>
              <TableHead>
                <TableRow>
                  {headers.map((header) => (
                    <TableHeader
                      {...getHeaderProps({ header })}
                      key={header.key}
                    >
                      {header.header}
                    </TableHeader>
                  ))}
                </TableRow>
              </TableHead>
              <TableBody>
                {rows.map((row) => (
                  <TableRow {...getRowProps({ row })} key={row.id}>
                    {row.cells.map((cell) => (
                      <TableCell key={cell.id}>{cell.value}</TableCell>
                    ))}
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        )}
      </DataTable>

      {/* QR Code Modal */}
      <Modal
        open={isModalOpen}
        onRequestClose={() => setIsModalOpen(false)}
        modalHeading={
          selectedTicket
            ? `QR Code - ${selectedTicket.first_name} ${selectedTicket.last_name}`
            : "QR Code"
        }
        passiveModal
        size="sm"
      >
        {selectedTicket && (
          <div className="flex flex-col items-center gap-4 p-4">
            <img
              src={selectedTicket.qr_code_data}
              alt="Ticket QR Code"
              className="h-64 w-64 border-2 border-cds-border-subtle"
            />
            <div className="text-center">
              <p className="text-sm text-cds-text-secondary">
                <strong>Guest:</strong> {selectedTicket.first_name}{" "}
                {selectedTicket.last_name}
              </p>
              <p className="text-sm text-cds-text-secondary">
                <strong>Email:</strong> {selectedTicket.guest_email}
              </p>
              <p className="text-sm text-cds-text-secondary">
                <strong>Host:</strong> {selectedTicket.host_email}
              </p>
              <p className="text-sm text-cds-text-secondary">
                <strong>Ticket ID:</strong> {selectedTicket.id}
              </p>
            </div>
            <Button
              kind="primary"
              size="sm"
              renderIcon={Download}
              onClick={() => {
                downloadQRCode(selectedTicket);
                setIsModalOpen(false);
              }}
            >
              Download QR Code
            </Button>
          </div>
        )}
      </Modal>
    </>
  );
}

// Made with Bob
