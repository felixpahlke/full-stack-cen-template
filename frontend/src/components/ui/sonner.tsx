import { Toaster as Sonner } from "sonner";

type ToasterProps = React.ComponentProps<typeof Sonner>;

const Toaster = ({ ...props }: ToasterProps) => {
  return (
    <Sonner
      toastOptions={{
        classNames: {
          content: "pl-2",
          toast:
            "border-l-4 text-cds-text-primary rounded-none border-solid border bg-cds-background  border-border shadow-lg p-4",
          success: "dark:text-cds-green-30 text-cds-green-60",
          error: "dark:text-cds-red-30 text-cds-red-60",
          warning: "dark:text-cds-yellow-30 text-cds-yellow-60",
          info: "dark:text-cds-blue-30 text-cds-blue-60",
          loading: "dark:text-cds-text-primary text-cds-text-primary",
        },
      }}
      {...props}
    />
  );
};

export { Toaster };
