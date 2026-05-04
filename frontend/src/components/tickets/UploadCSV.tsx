import { useState } from "react";
import { FileUploader, InlineNotification, Loading } from "@carbon/react";
import { useMutation } from "@tanstack/react-query";

interface UploadResult {
  success: boolean;
  tickets_created: number;
  tickets_failed: number;
  total_rows: number;
  errors: Array<{ row: number; error: string }>;
  ticket_ids: string[];
}

export function UploadCSV() {
  const [uploadResult, setUploadResult] = useState<UploadResult | null>(null);
  const [uploadError, setUploadError] = useState<string | null>(null);

  const uploadMutation = useMutation({
    mutationFn: async (file: File) => {
      console.log("Starting upload for file:", file.name, file.size, "bytes");
      const formData = new FormData();
      formData.append("file", file);

      console.log("Sending POST to /api/v1/tickets/upload-csv");
      const response = await fetch("/api/v1/tickets/upload-csv", {
        method: "POST",
        body: formData,
        credentials: "include",
      });

      console.log("Response status:", response.status, response.statusText);
      console.log(
        "Response headers:",
        Object.fromEntries(response.headers.entries()),
      );

      if (!response.ok) {
        const contentType = response.headers.get("content-type");
        console.log("Error response content-type:", contentType);

        if (contentType?.includes("application/json")) {
          const error = await response.json();
          throw new Error(error.detail || "Upload failed");
        } else {
          const text = await response.text();
          console.log("Error response text:", text);
          throw new Error(
            `Upload failed: ${response.status} ${response.statusText}`,
          );
        }
      }

      const contentType = response.headers.get("content-type");
      if (!contentType?.includes("application/json")) {
        const text = await response.text();
        console.error("Expected JSON but got:", contentType, text);
        throw new Error("Server returned non-JSON response");
      }

      return response.json();
    },
    onSuccess: (data: UploadResult) => {
      setUploadResult(data);
      setUploadError(null);
    },
    onError: (error: Error) => {
      setUploadError(error.message);
      setUploadResult(null);
    },
  });

  const handleFileChange = (event: any) => {
    console.log("File change event:", event);
    console.log("Event type:", typeof event);
    console.log("Event keys:", Object.keys(event || {}));

    // Try different possible event structures
    const file = event?.addedFiles?.[0] || event?.target?.files?.[0];
    console.log("Selected file:", file);

    if (file) {
      setUploadResult(null);
      setUploadError(null);
      console.log("Starting upload mutation for file:", file.name);
      uploadMutation.mutate(file);
    } else {
      console.warn("No file found in event. Event structure:", event);
    }
  };

  return (
    <div className="space-y-4">
      <FileUploader
        labelTitle="Upload CSV File"
        labelDescription="Select an Airtable CSV export file (semicolon-delimited, UTF-8 encoding)"
        buttonLabel="Select file"
        filenameStatus="edit"
        accept={[".csv"]}
        multiple={false}
        disabled={uploadMutation.isPending}
        onChange={handleFileChange}
      />

      {uploadMutation.isPending && (
        <Loading description="Processing CSV file..." withOverlay={false} />
      )}

      {uploadError && (
        <InlineNotification
          kind="error"
          title="Upload Failed"
          subtitle={uploadError}
          lowContrast
        />
      )}

      {uploadResult && (
        <div className="space-y-4">
          <InlineNotification
            kind={uploadResult.tickets_failed > 0 ? "warning" : "success"}
            title="Upload Complete"
            subtitle={`Created ${uploadResult.tickets_created} tickets${
              uploadResult.tickets_failed > 0
                ? `, ${uploadResult.tickets_failed} rows failed validation`
                : ""
            }`}
            lowContrast
          />

          {uploadResult.errors && uploadResult.errors.length > 0 && (
            <div className="rounded bg-cds-layer-01 p-4">
              <h3 className="mb-2 font-semibold text-cds-text-primary">
                Validation Errors
              </h3>
              <ul className="list-inside list-disc space-y-1 text-sm text-cds-text-secondary">
                {uploadResult.errors.map((error, index) => (
                  <li key={index}>
                    Row {error.row}: {error.error}
                  </li>
                ))}
              </ul>
            </div>
          )}

          {uploadResult.tickets_created > 0 && (
            <div className="rounded bg-cds-layer-01 p-4">
              <h3 className="mb-2 font-semibold text-cds-text-primary">
                Success Summary
              </h3>
              <p className="text-sm text-cds-text-secondary">
                {uploadResult.tickets_created} tickets created successfully.
                Emails have been queued for delivery.
              </p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// Made with Bob
