import { Component, ErrorInfo, ReactNode } from "react";
import { logger } from "@/lib/logger";
import {
  Button,
  InlineNotification,
  Layer,
  Stack,
  Accordion,
  AccordionItem,
  Grid,
  Column,
} from "@carbon/react";
import { Renew, WarningAlt } from "@carbon/icons-react";

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

/**
 * Error Boundary component that catches React errors and logs them.
 * Provides a fallback UI when an error occurs.
 * Fully compliant with Carbon Design System for enterprise-grade applications.
 */
export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): State {
    // Update state so the next render will show the fallback UI
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo): void {
    // Log the error with full stack trace
    logger.exception(error, "ErrorBoundary", {
      componentStack: errorInfo.componentStack,
    });
  }

  handleReset = (): void => {
    this.setState({ hasError: false, error: null });
    // Reload the page to reset the application state
    window.location.reload();
  };

  render(): ReactNode {
    if (this.state.hasError) {
      // Custom fallback UI
      if (this.props.fallback) {
        return this.props.fallback;
      }

      // Default fallback UI - Carbon Design System compliant
      return (
        <div className="flex min-h-screen items-center justify-center bg-cds-background">
          <Grid className="w-full max-w-4xl px-4">
            <Column sm={4} md={8} lg={12}>
              <Layer className="p-8 md:p-12">
                <Stack gap={7}>
                  {/* Icon and Title Section */}
                  <div className="flex flex-col items-center text-center">
                    <div className="mb-6 flex h-20 w-20 items-center justify-center rounded-full bg-cds-support-error/10">
                      <WarningAlt
                        size={48}
                        className="text-cds-support-error"
                      />
                    </div>
                    <h1 className="mb-3 text-4xl font-light text-cds-text-primary">
                      Something went wrong
                    </h1>
                    <p className="max-w-xl text-lg text-cds-text-secondary">
                      We apologize for the inconvenience. An unexpected error
                      has occurred in the application.
                    </p>
                  </div>

                  {/* Notification Section */}
                  <InlineNotification
                    kind="error"
                    title="Error Logged"
                    subtitle="Our team has been notified and will investigate this issue. Your session data has been preserved."
                    hideCloseButton
                    lowContrast
                  />

                  {/* Error Details Accordion */}
                  {this.state.error && (
                    <Accordion>
                      <AccordionItem title="Technical details">
                        <Stack gap={4}>
                          <div>
                            <p className="mb-2 text-sm font-semibold text-cds-text-primary">
                              Error Message:
                            </p>
                            <Layer className="p-4">
                              <code className="text-sm text-cds-text-primary">
                                {this.state.error.message}
                              </code>
                            </Layer>
                          </div>
                          {this.state.error.stack && (
                            <div>
                              <p className="mb-2 text-sm font-semibold text-cds-text-primary">
                                Stack Trace:
                              </p>
                              <Layer className="max-h-64 overflow-auto p-4">
                                <pre className="text-xs text-cds-text-secondary">
                                  {this.state.error.stack}
                                </pre>
                              </Layer>
                            </div>
                          )}
                        </Stack>
                      </AccordionItem>
                    </Accordion>
                  )}

                  {/* Action Buttons */}
                  <div className="flex flex-col items-center gap-3 pt-4 sm:flex-row sm:justify-center">
                    <Button
                      onClick={this.handleReset}
                      kind="primary"
                      size="lg"
                      renderIcon={Renew}
                    >
                      Reload Application
                    </Button>
                    <Button
                      onClick={() => window.history.back()}
                      kind="secondary"
                      size="lg"
                    >
                      Go Back
                    </Button>
                  </div>

                  {/* Support Information */}
                  <div className="border-t border-cds-border-subtle pt-6 text-center">
                    <p className="text-sm text-cds-text-secondary">
                      If this problem persists, please contact our support team
                      with the error details above.
                    </p>
                  </div>
                </Stack>
              </Layer>
            </Column>
          </Grid>
        </div>
      );
    }

    return this.props.children;
  }
}