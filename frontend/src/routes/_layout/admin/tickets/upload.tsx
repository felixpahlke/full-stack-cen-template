import { createFileRoute } from "@tanstack/react-router";
import { UploadCSV } from "@/components/tickets/UploadCSV";

export const Route = createFileRoute("/_layout/admin/tickets/upload")({
  component: UploadTicketsPage,
});

function UploadTicketsPage() {
  return (
    <div className="mx-auto max-w-4xl p-6">
      <div className="mb-6">
        <h1 className="mb-2 text-3xl font-semibold text-cds-text-primary">
          Upload Tickets
        </h1>
        <p className="text-cds-text-secondary">
          Upload an Airtable CSV export to generate tickets for all guests.
        </p>
      </div>

      <div className="rounded-lg bg-cds-layer-01 p-6">
        <h2 className="mb-4 text-xl font-semibold text-cds-text-primary">
          CSV File Requirements
        </h2>
        <ul className="mb-6 list-inside list-disc space-y-2 text-cds-text-secondary">
          <li>File must be in CSV format with .csv extension</li>
          <li>Semicolon (;) delimiter required</li>
          <li>UTF-8 encoding (with or without BOM)</li>
          <li>
            Required columns: Vorname, Nachname, E-Mail, Rolle, Age Guest,
            E-mail Host Gast
          </li>
          <li>First row must contain column headers</li>
        </ul>

        <UploadCSV />
      </div>

      <div className="mt-6 rounded-lg bg-cds-layer-01 p-6">
        <h2 className="mb-4 text-xl font-semibold text-cds-text-primary">
          What Happens After Upload?
        </h2>
        <ol className="list-inside list-decimal space-y-2 text-cds-text-secondary">
          <li>
            Each valid row in the CSV generates a unique ticket with QR code
          </li>
          <li>Tickets are stored in the database with guest information</li>
          <li>Email notifications are queued for delivery to guests</li>
          <li>Invalid rows are reported without stopping the process</li>
          <li>You can download individual tickets from the tickets list</li>
        </ol>
      </div>
    </div>
  );
}

// Made with Bob
