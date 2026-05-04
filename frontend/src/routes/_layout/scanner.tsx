import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useRef, useState } from "react";
import { Html5Qrcode } from "html5-qrcode";
import { Button, InlineNotification, Loading, Tile } from "@carbon/react";
import { Checkmark, Close, WarningAlt } from "@carbon/icons-react";
import { useMutation } from "@tanstack/react-query";
import { Tickets } from "@/client";

export const Route = createFileRoute("/_layout/scanner")({
  component: ScannerPage,
});

interface ValidationResult {
  valid: boolean;
  result: "granted" | "already_scanned" | "invalid" | "network_error";
  message: string;
  ticket?: {
    first_name: string;
    last_name: string;
  };
  scanned_at?: string;
}

function ScannerPage() {
  const [isScanning, setIsScanning] = useState(false);
  const [lastResult, setLastResult] = useState<ValidationResult | null>(null);
  // Generate or retrieve device ID from localStorage (initialized once)
  const [deviceId] = useState<string>(() => {
    let storedDeviceId = localStorage.getItem("scanner_device_id");
    if (!storedDeviceId) {
      storedDeviceId = `scanner-${Date.now()}-${Math.random().toString(36).substring(7)}`;
      localStorage.setItem("scanner_device_id", storedDeviceId);
    }
    return storedDeviceId;
  });
  const [isOnline, setIsOnline] = useState(navigator.onLine);
  const scannerRef = useRef<Html5Qrcode | null>(null);
  const [cameraError, setCameraError] = useState<string | null>(null);

  // Monitor network connectivity
  useEffect(() => {
    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);

    window.addEventListener("online", handleOnline);
    window.addEventListener("offline", handleOffline);

    return () => {
      window.removeEventListener("online", handleOnline);
      window.removeEventListener("offline", handleOffline);
    };
  }, []);

  // Validation mutation
  const validateMutation = useMutation({
    mutationFn: async (ticketId: string) => {
      const response = await Tickets.ticketsValidateTicket({
        path: { ticket_id: ticketId },
        query: {
          scanner_device_id: deviceId,
          scanner_user_id: "current-user", // TODO: Get from auth context
        },
      });
      return response.data as unknown as ValidationResult;
    },
    onSuccess: (data) => {
      setLastResult(data);
      // Play audio feedback
      playFeedbackSound(data.valid);
      // Vibrate on mobile devices
      if (navigator.vibrate) {
        navigator.vibrate(data.valid ? 200 : [100, 50, 100]);
      }
      // Clear result after 5 seconds
      setTimeout(() => setLastResult(null), 5000);
    },
    onError: (error) => {
      setLastResult({
        valid: false,
        result: "network_error",
        message: `Network error: ${error.message}`,
      });
      playFeedbackSound(false);
      setTimeout(() => setLastResult(null), 5000);
    },
  });

  const playFeedbackSound = (success: boolean) => {
    const audioContext = new (
      window.AudioContext || (window as any).webkitAudioContext
    )();
    const oscillator = audioContext.createOscillator();
    const gainNode = audioContext.createGain();

    oscillator.connect(gainNode);
    gainNode.connect(audioContext.destination);

    oscillator.frequency.value = success ? 800 : 400;
    oscillator.type = "sine";
    gainNode.gain.value = 0.3;

    oscillator.start();
    oscillator.stop(audioContext.currentTime + 0.2);
  };

  const startScanning = async () => {
    try {
      setCameraError(null);
      const html5QrCode = new Html5Qrcode("qr-reader");
      scannerRef.current = html5QrCode;

      await html5QrCode.start(
        { facingMode: "environment" },
        {
          fps: 10,
          qrbox: { width: 250, height: 250 },
        },
        (decodedText) => {
          // QR code successfully scanned
          console.log("QR Code scanned:", decodedText);
          validateMutation.mutate(decodedText);
        },
        (errorMessage) => {
          // Scanning error (can be ignored for continuous scanning)
          console.debug("QR scan error:", errorMessage);
        },
      );

      setIsScanning(true);
    } catch (error) {
      console.error("Failed to start scanner:", error);
      setCameraError(
        error instanceof Error
          ? error.message
          : "Failed to access camera. Please grant camera permissions.",
      );
    }
  };

  const stopScanning = async () => {
    if (scannerRef.current) {
      try {
        await scannerRef.current.stop();
        scannerRef.current.clear();
        scannerRef.current = null;
        setIsScanning(false);
      } catch (error) {
        console.error("Failed to stop scanner:", error);
      }
    }
  };

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (scannerRef.current) {
        scannerRef.current.stop().catch(console.error);
      }
    };
  }, []);

  const getResultColor = (result: ValidationResult) => {
    if (result.valid) return "bg-cds-support-success text-white";
    if (result.result === "network_error")
      return "bg-cds-support-warning text-black";
    return "bg-cds-support-error text-white";
  };

  const getResultIcon = (result: ValidationResult) => {
    if (result.valid) return <Checkmark size={48} />;
    if (result.result === "network_error") return <WarningAlt size={48} />;
    return <Close size={48} />;
  };

  return (
    <div className="flex min-h-screen flex-col items-center justify-start bg-cds-layer p-4">
      <div className="w-full max-w-2xl space-y-4">
        {/* Header */}
        <Tile className="text-center">
          <h1 className="text-2xl font-bold text-cds-text-primary">
            QR Code Scanner
          </h1>
          <p className="mt-2 text-sm text-cds-text-secondary">
            Scan ticket QR codes for event entry validation
          </p>
        </Tile>

        {/* Network Status */}
        {!isOnline && (
          <InlineNotification
            kind="error"
            title="No Network Connection"
            subtitle="Scanner requires network connectivity for real-time validation"
            lowContrast
          />
        )}

        {/* Device ID */}
        <Tile>
          <p className="text-xs text-cds-text-secondary">
            Device ID: {deviceId}
          </p>
        </Tile>

        {/* Camera Error */}
        {cameraError && (
          <InlineNotification
            kind="error"
            title="Camera Error"
            subtitle={cameraError}
            lowContrast
          />
        )}

        {/* Scanner Controls */}
        <div className="flex justify-center gap-4">
          {!isScanning ? (
            <Button
              size="lg"
              onClick={startScanning}
              disabled={!isOnline || !deviceId}
            >
              Start Scanning
            </Button>
          ) : (
            <Button size="lg" kind="danger" onClick={stopScanning}>
              Stop Scanning
            </Button>
          )}
        </div>

        {/* QR Reader Container */}
        <Tile>
          <div
            id="qr-reader"
            className="mx-auto w-full max-w-md overflow-hidden rounded-lg"
          />
          {!isScanning && (
            <div className="flex min-h-[300px] items-center justify-center text-cds-text-secondary">
              <p>Camera preview will appear here when scanning starts</p>
            </div>
          )}
        </Tile>

        {/* Validation Result */}
        {validateMutation.isPending && (
          <Tile className="text-center">
            <Loading description="Validating ticket..." withOverlay={false} />
          </Tile>
        )}

        {lastResult && !validateMutation.isPending && (
          <Tile
            className={`${getResultColor(lastResult)} p-8 text-center duration-300 animate-in fade-in zoom-in`}
          >
            <div className="flex flex-col items-center gap-4">
              {getResultIcon(lastResult)}
              <h2 className="text-3xl font-bold">{lastResult.message}</h2>
              {lastResult.ticket && (
                <p className="text-xl">
                  {lastResult.ticket.first_name} {lastResult.ticket.last_name}
                </p>
              )}
              {lastResult.scanned_at && (
                <p className="text-sm opacity-80">
                  Previously scanned at:{" "}
                  {new Date(lastResult.scanned_at).toLocaleString()}
                </p>
              )}
            </div>
          </Tile>
        )}

        {/* Instructions */}
        <Tile>
          <h3 className="mb-2 font-semibold text-cds-text-primary">
            Instructions:
          </h3>
          <ul className="list-inside list-disc space-y-1 text-sm text-cds-text-secondary">
            <li>Ensure network connectivity is active</li>
            <li>Grant camera permissions when prompted</li>
            <li>Point camera at ticket QR code</li>
            <li>Wait for automatic validation</li>
            <li>Green = Entry Granted</li>
            <li>Red = Entry Denied (already scanned or invalid)</li>
            <li>Yellow = Network Error (retry)</li>
          </ul>
        </Tile>
      </div>
    </div>
  );
}

// Made with Bob
