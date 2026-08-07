import { useTheme } from "../theme/ThemeProvider";

interface LogoProps {
  className?: string;
  logoOnly?: boolean;
  logoSize?: "sm" | "md" | "lg";
}

export const Logo = ({ className, logoSize = "md", logoOnly = false }: LogoProps) => {
  const { resolvedTheme } = useTheme();
  const sizeClass = logoSize === "sm" ? "w-8" : logoSize === "lg" ? "w-16" : "w-12";

  return (
    <div className={`flex items-center justify-center text-xl ${className ?? ""}`}>
      <img
        className={sizeClass}
        src={
          resolvedTheme === "dark"
            ? "/assets/images/ibm-bee-white.png"
            : "/assets/images/ibm-bee-black.png"
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
