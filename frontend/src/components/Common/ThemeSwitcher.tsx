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
            theme === "white" ? "g90" : theme === "g90" ? "system" : "white";
          setTheme(nextTheme);
        }}
        className="flex w-full items-center"
      >
        <span className="mr-2">
          {theme === "white" ? (
            <Light className="h-5 w-5" />
          ) : theme === "g90" ? (
            <Moon className="h-5 w-5" />
          ) : (
            <BrightnessContrast className="h-5 w-5" />
          )}
        </span>
        {`Switch to ${theme === "white" ? "Dark" : theme === "g90" ? "System" : "Light"} Mode`}
      </button>
    );
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          variant="ghost"
          size="icon"
          className="text-cds-text-primary"
          aria-label="Theme switcher"
        >
          {theme === "white" ? (
            <Light className="h-5 w-5" />
          ) : theme === "g90" ? (
            <Moon className="h-5 w-5" />
          ) : (
            <BrightnessContrast className="h-5 w-5" />
          )}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onClick={() => setTheme("white")}>
          <Light className="mr-2 h-4 w-4" />
          Light Mode
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => setTheme("g90")}>
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
