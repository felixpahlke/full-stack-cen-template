import { useTheme } from "@/components/theme/ThemeProvider";
import { cn } from "@/lib/utils";

interface LogoProps {
  className?: string;
  logoOnly?: boolean;
  logoSize?: "sm" | "md" | "lg";
}

export const Logo = ({ className, logoSize = "md", logoOnly = false }: LogoProps) => {
  const { resolvedTheme } = useTheme();

  return (
    <div className={cn("flex items-center justify-center", className)}>
      <img
        className={cn({
          "w-8": logoSize === "sm",
          "w-12": logoSize === "md",
          "w-16": logoSize === "lg",
        })}
        src={
          resolvedTheme === "dark"
            ? "/assets/images/logo-light.png"
            : "/assets/images/logo-dark.png"
        }
        alt="IBM-Client-Engineering"
      />
      {!logoOnly && (
        <p className="pl-2">
          IBM <strong>Client Engineering</strong>
        </p>
      )}
    </div>
  );
};
