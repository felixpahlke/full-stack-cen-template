/**
 * Centralized logging utility for the frontend application.
 *
 * Provides structured logging with:
 * - ISO 8601 timestamp format
 * - Log levels (info, warn, error, debug)
 * - Context information
 * - Stack trace logging for errors
 */

type LogLevel = "info" | "warn" | "error" | "debug";

interface LogEntry {
  timestamp: string;
  level: LogLevel;
  context?: string;
  message: string;
  data?: unknown;
  stack?: string;
}

class Logger {
  private minLogLevel: LogLevel;

  constructor() {
    this.minLogLevel = this.getMinLogLevelFromEnvironment();
    // Log the configured level to console (bypassing our own filtering)
    // This helps debug logging configuration issues
    // @ts-ignore - Vite provides this
    const viteLogLevel = import.meta.env.VITE_LOG_LEVEL || 'not set';
    // @ts-ignore - Vite provides this
    const viteEnvironment = import.meta.env.VITE_ENVIRONMENT || 'not set';
    console.info(
      `[Logger] Configured with log level: ${this.minLogLevel.toUpperCase()}`,
      `(VITE_LOG_LEVEL=${viteLogLevel}, VITE_ENVIRONMENT=${viteEnvironment})`
    );
  }

  /**
   * Determine minimum log level based on VITE_LOG_LEVEL or VITE_ENVIRONMENT variable
   *
   * Priority:
   * 1. VITE_LOG_LEVEL environment variable (if set, overrides everything)
   * 2. VITE_ENVIRONMENT-based defaults (local=debug, staging=info, production=warn)
   */
  private getMinLogLevelFromEnvironment(): LogLevel {
    // @ts-ignore - Vite provides this
    const explicitLogLevel = import.meta.env.VITE_LOG_LEVEL;
    
    // Check for explicit VITE_LOG_LEVEL override first
    if (explicitLogLevel) {
      let levelStr = explicitLogLevel.toLowerCase();
      
      // Map backend log levels to frontend equivalents
      // Backend uses: DEBUG, INFO, WARNING, ERROR, CRITICAL
      // Frontend uses: debug, info, warn, error
      if (levelStr === 'warning') {
        levelStr = 'warn';
      } else if (levelStr === 'critical') {
        levelStr = 'error';
      }
      
      // Validate it's a valid log level
      if (["debug", "info", "warn", "error"].includes(levelStr)) {
        return levelStr as LogLevel;
      }
    }
    
    // Fall back to environment-based defaults
    // @ts-ignore - Vite provides this
    const environment = (import.meta.env.VITE_ENVIRONMENT || "local").toLowerCase();
    
    if (environment === "local") {
      return "debug"; // Verbose logging for development
    } else if (environment === "staging") {
      return "info"; // Standard logging for staging
    } else if (environment === "production") {
      return "warn"; // Only warnings and errors for production
    } else {
      return "info"; // Default to info
    }
  }

  /**
   * Check if a log level should be output based on minimum level
   */
  private shouldLog(level: LogLevel): boolean {
    const levels: LogLevel[] = ["debug", "info", "warn", "error"];
    const minIndex = levels.indexOf(this.minLogLevel);
    const currentIndex = levels.indexOf(level);
    return currentIndex >= minIndex;
  }

  /**
   * Format timestamp in ISO 8601 UTC format
   */
  private getTimestamp(): string {
    return new Date().toISOString();
  }

  /**
   * Format and output log entry
   */
  private log(entry: LogEntry): void {
    const { timestamp, level, context, message, data, stack } = entry;
    
    // Check if this log level should be output
    if (!this.shouldLog(level)) {
      return;
    }

    const contextStr = context ? `[${context}]` : "";
    const prefix = `[${timestamp}] [${level.toUpperCase()}] ${contextStr}`;

    switch (level) {
      case "error":
        console.error(prefix, message, data || "", stack || "");
        break;
      case "warn":
        console.warn(prefix, message, data || "");
        break;
      case "info":
        console.info(prefix, message, data || "");
        break;
      case "debug":
        console.debug(prefix, message, data || "");
        break;
    }
  }

  /**
   * Log informational message
   */
  info(message: string, context?: string, data?: unknown): void {
    this.log({
      timestamp: this.getTimestamp(),
      level: "info",
      context,
      message,
      data,
    });
  }

  /**
   * Log warning message
   */
  warn(message: string, context?: string, data?: unknown): void {
    this.log({
      timestamp: this.getTimestamp(),
      level: "warn",
      context,
      message,
      data,
    });
  }

  /**
   * Log error message with optional stack trace
   */
  error(message: string, context?: string, error?: Error | unknown): void {
    const stack =
      error instanceof Error ? error.stack : undefined;
    const errorData = error instanceof Error ? {
      name: error.name,
      message: error.message,
    } : error;

    this.log({
      timestamp: this.getTimestamp(),
      level: "error",
      context,
      message,
      data: errorData,
      stack,
    });
  }

  /**
   * Log debug message (only in development)
   */
  debug(message: string, context?: string, data?: unknown): void {
    this.log({
      timestamp: this.getTimestamp(),
      level: "debug",
      context,
      message,
      data,
    });
  }

  /**
   * Log exception with full stack trace
   */
  exception(error: Error, context?: string, additionalData?: unknown): void {
    this.log({
      timestamp: this.getTimestamp(),
      level: "error",
      context,
      message: `Exception: ${error.message}`,
      data: {
        name: error.name,
        message: error.message,
        ...(additionalData && typeof additionalData === "object" ? additionalData : {}),
      },
      stack: error.stack,
    });
  }
}

// Export singleton instance
export const logger = new Logger();

