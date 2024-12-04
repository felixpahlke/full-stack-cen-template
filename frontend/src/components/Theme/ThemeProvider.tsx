import { Theme as CarbonTheme } from "@carbon/react";
import { createContext, useContext, useEffect, useState } from "react";

type Theme = "g10" | "g90" | "g100" | "white" | "system";

type ThemeProviderProps = {
  children: React.ReactNode;
  defaultTheme?: Theme;
  storageKey?: string;
};

type ThemeProviderState = {
  theme: Theme;
  actualTheme: Exclude<Theme, "system">;
  setTheme: (theme: Theme) => void;
};

const initialState: ThemeProviderState = {
  theme: "system",
  actualTheme: "white",
  setTheme: () => null,
};

const ThemeProviderContext = createContext<ThemeProviderState>(initialState);

export function ThemeProvider({
  children,
  defaultTheme = "system",
  storageKey = "carbon-theme",
  ...props
}: ThemeProviderProps) {
  const [theme, setTheme] = useState<Theme>(
    () => (localStorage.getItem(storageKey) as Theme) || defaultTheme,
  );
  const [actualTheme, setActualTheme] =
    useState<Exclude<Theme, "system">>("white");

  useEffect(() => {
    if (theme === "system") {
      const systemTheme = window.matchMedia("(prefers-color-scheme: dark)")
        .matches
        ? "g90"
        : "white";

      setActualTheme(systemTheme);
      return;
    }

    setActualTheme(theme as Exclude<Theme, "system">);
  }, [theme]);

  useEffect(() => {
    document.documentElement.classList.remove(
      "cds--white",
      "cds--g10",
      "cds--g90",
      "cds--g100",
    );
    document.documentElement.classList.add(`cds--${actualTheme}`);
  }, [actualTheme]);

  const value = {
    theme,
    actualTheme,
    setTheme: (theme: Theme) => {
      localStorage.setItem(storageKey, theme);
      setTheme(theme);
    },
  };

  return (
    <ThemeProviderContext.Provider {...props} value={value}>
      <CarbonTheme theme={actualTheme}>{children}</CarbonTheme>
    </ThemeProviderContext.Provider>
  );
}

export const useTheme = () => {
  const context = useContext(ThemeProviderContext);

  if (context === undefined)
    throw new Error("useTheme must be used within a ThemeProvider");

  return context;
};
