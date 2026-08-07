import { Theme as CarbonTheme } from "@carbon/react";
import { createContext, type ReactNode, useContext, useEffect, useState } from "react";

export type Theme = "dark" | "light" | "system";

type ThemeContextValue = {
  theme: Theme;
  resolvedTheme: "dark" | "light";
  /** @deprecated Use resolvedTheme. */
  actualTheme: "dark" | "light";
  setTheme: (theme: Theme) => void;
};

type ThemeProviderProps = {
  children: ReactNode;
  defaultTheme?: Theme;
  storageKey?: string;
};

const ThemeContext = createContext<ThemeContextValue | null>(null);
const prefersDark = () => window.matchMedia("(prefers-color-scheme: dark)").matches;
const isTheme = (value: string | null): value is Theme =>
  value === "dark" || value === "light" || value === "system";

function initialTheme(storageKey: string, defaultTheme: Theme): Theme {
  const stored = localStorage.getItem(storageKey);
  if (isTheme(stored)) return stored;
  if (storageKey !== "vite-ui-theme") return defaultTheme;

  const legacyTheme = localStorage.getItem("carbon-theme");
  if (!isTheme(legacyTheme)) return defaultTheme;
  localStorage.setItem(storageKey, legacyTheme);
  localStorage.removeItem("carbon-theme");
  return legacyTheme;
}

export function ThemeProvider({
  children,
  defaultTheme = "system",
  storageKey = "vite-ui-theme",
}: ThemeProviderProps) {
  const [theme, setThemeState] = useState<Theme>(() => initialTheme(storageKey, defaultTheme));
  const [systemDark, setSystemDark] = useState(prefersDark);

  useEffect(() => {
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const onChange = () => setSystemDark(media.matches);
    media.addEventListener("change", onChange);
    return () => media.removeEventListener("change", onChange);
  }, []);

  const resolvedTheme = theme === "system" ? (systemDark ? "dark" : "light") : theme;

  useEffect(() => {
    const root = document.documentElement;
    root.classList.toggle("dark", resolvedTheme === "dark");
    root.classList.toggle("cds--g90", resolvedTheme === "dark");
    root.classList.toggle("cds--g10", resolvedTheme === "light");
  }, [resolvedTheme]);

  const setTheme = (next: Theme) => {
    localStorage.setItem(storageKey, next);
    setThemeState(next);
  };

  return (
    <ThemeContext.Provider value={{ theme, resolvedTheme, actualTheme: resolvedTheme, setTheme }}>
      <CarbonTheme theme={resolvedTheme === "dark" ? "g90" : "g10"}>{children}</CarbonTheme>
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) throw new Error("useTheme must be used within ThemeProvider");
  return context;
}
