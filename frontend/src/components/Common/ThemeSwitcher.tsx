import { BrightnessContrast, Light, Moon } from "@carbon/icons-react";
import { useTheme } from "../Theme/ThemeProvider";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

interface ThemeSwitcherProps {
  displayAs?: "dropdown" | "sidenav";
}

export function ThemeSwitcher({ displayAs = "dropdown" }: ThemeSwitcherProps) {
  const { theme, setTheme } = useTheme();

  if (displayAs === "sidenav") {
    return (
      <button
        onClick={() => {
          const nextTheme =
            theme === "light" ? "dark" : theme === "dark" ? "system" : "light";
          setTheme(nextTheme);
        }}
        className="flex w-full items-center"
      >
        <span className="mr-2">
          {theme === "light" ? (
            <Light className="h-5 w-5" />
          ) : theme === "dark" ? (
            <Moon className="h-5 w-5" />
          ) : (
            <BrightnessContrast className="h-5 w-5" />
          )}
        </span>
        {`Switch to ${theme === "light" ? "Dark" : theme === "dark" ? "System" : "Light"} Mode`}
      </button>
    );
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger className="hidden lg:flex" asChild>
        <Button
          variant="ghost"
          size="icon"
          className="text-cds-text-primary"
          aria-label="Theme switcher"
        >
          {theme === "light" ? (
            <Light className="h-5 w-5" />
          ) : theme === "dark" ? (
            <Moon className="h-5 w-5" />
          ) : (
            <BrightnessContrast className="h-5 w-5" />
          )}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onClick={() => setTheme("light")}>
          <Light className="mr-2 h-4 w-4" />
          Light Mode
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => setTheme("dark")}>
          <Moon className="mr-2 h-4 w-4" />
          Dark Mode
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => setTheme("system")}>
          <BrightnessContrast className="mr-2 h-4 w-4" />
          System
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

export default ThemeSwitcher;
