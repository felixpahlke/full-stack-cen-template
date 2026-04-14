/**
 * API Error Handler
 * 
 * Provides centralized error handling and logging for API requests.
 */

import { AxiosError } from "axios";
import { logger } from "./logger";
import { toast } from "@/components/common/Toaster";

interface ApiErrorDetails {
  status?: number;
  statusText?: string;
  url?: string;
  method?: string;
  data?: unknown;
}

/**
 * Handle API errors with logging and user notifications
 */
export function handleApiError(error: unknown, context?: string): void {
  if (error instanceof AxiosError) {
    const details: ApiErrorDetails = {
      status: error.response?.status,
      statusText: error.response?.statusText,
      url: error.config?.url,
      method: error.config?.method?.toUpperCase(),
      data: error.response?.data,
    };

    // Log the error with full details
    logger.error(
      `API Error: ${details.method} ${details.url} - ${details.status} ${details.statusText}`,
      context || "API",
      error
    );

    // Show user-friendly error message
    const errorMessage = getErrorMessage(error);
    
    // Don't show toast for authentication errors (handled by useAuth)
    if (details.status !== 401 && details.status !== 403) {
      toast.error("Request failed", {
        caption: errorMessage,
      });
    }
  } else if (error instanceof Error) {
    // Handle non-Axios errors
    logger.exception(error, context || "API");
    toast.error("An unexpected error occurred", {
      caption: error.message,
    });
  } else {
    // Handle unknown errors
    logger.error("Unknown error occurred", context || "API", error);
    toast.error("An unexpected error occurred");
  }
}

/**
 * Extract user-friendly error message from API error
 */
function getErrorMessage(error: AxiosError): string {
  const responseData = error.response?.data as any;
  
  if (responseData?.detail) {
    if (Array.isArray(responseData.detail)) {
      return responseData.detail.map((e: any) => e.msg || e).join(", ");
    } else if (typeof responseData.detail === "string") {
      return responseData.detail;
    }
  }
  
  if (error.message) {
    return error.message;
  }
  
  return "An error occurred while processing your request";
}

/**
 * Log successful API requests (for debugging)
 */
export function logApiSuccess(
  method: string,
  url: string,
  status: number,
  context?: string
): void {
  logger.info(
    `API Success: ${method.toUpperCase()} ${url} - ${status}`,
    context || "API"
  );
}

// Made with Bob
