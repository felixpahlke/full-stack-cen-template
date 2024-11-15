import { Toaster as Sonner } from "sonner";
import { useTheme } from "../Theme/ThemeProvider";

type ToasterProps = React.ComponentProps<typeof Sonner>;

const Toaster = ({ ...props }: ToasterProps) => {
  const { theme = "system" } = useTheme();

  return (
    <Sonner
      // theme={theme as ToasterProps["theme"]}
      className="toaster group"
      toastOptions={{
        classNames: {
          content: "pl-2",
          toast:
            "group border-l-4 rounded-none border-cds-border-subtle border-solid border toast group-[.toaster]:bg-cds-background group-[.toaster]:text-foreground group-[.toaster]:border-border group-[.toaster]:shadow-lg p-4",
          description: "group-[.toast]:text-muted-foreground",
          actionButton:
            "group-[.toast]:bg-primary group-[.toast]:text-primary-foreground",
          cancelButton:
            "group-[.toast]:bg-muted group-[.toast]:text-muted-foreground",
        },
      }}
      richColors
      {...props}
    />
  );
};

export { Toaster };
