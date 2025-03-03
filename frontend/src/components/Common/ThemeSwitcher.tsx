import { BrightnessContrast, Light, Moon } from "@carbon/icons-react";
import { Theme, useTheme } from "../theme/ThemeProvider";
import { Button } from "@carbon/react";
import { Menu, MenuItemRadioGroup } from "@carbon/react";
import { useRef, useState } from "react";

interface ThemeSwitcherProps {
  displayAs?: "dropdown" | "sidenav";
}

export function ThemeSwitcher({ displayAs = "dropdown" }: ThemeSwitcherProps) {
  const { theme, setTheme } = useTheme();
  const [isOpen, setIsOpen] = useState(false);
  const buttonRef = useRef<HTMLButtonElement>(null);

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

  const themeItems = ["Light Mode", "Dark Mode", "System"];
  const themeValues = ["light", "dark", "system"];

  const handleThemeChange = (selectedItem: string) => {
    const index = themeItems.indexOf(selectedItem);
    if (index !== -1) {
      setTheme(themeValues[index] as Theme);
    }
    setIsOpen(false);
  };

  const getSelectedThemeLabel = () => {
    const index = themeValues.indexOf(theme);
    return themeItems[index];
  };

  // Calculate position for the menu when button is clicked
  const getMenuPosition = () => {
    if (!buttonRef.current) return { x: 0, y: 0 };

    const rect = buttonRef.current.getBoundingClientRect();

    return {
      x: rect.left + 20,
      y: rect.bottom,
    };
  };

  return (
    <>
      <div className="h-full">
        <Button
          ref={buttonRef}
          kind="ghost"
          onClick={() => setIsOpen(!isOpen)}
          className="flex h-12 items-center"
        >
          {theme === "light" ? (
            <Light className="h-5 w-5" />
          ) : theme === "dark" ? (
            <Moon className="h-5 w-5" />
          ) : (
            <BrightnessContrast className="h-5 w-5" />
          )}
        </Button>
        {isOpen && buttonRef.current && (
          <Menu
            label="Theme"
            open={isOpen}
            onClose={() => setIsOpen(false)}
            {...getMenuPosition()}
          >
            <MenuItemRadioGroup
              label="Theme"
              items={themeItems}
              selectedItem={getSelectedThemeLabel()}
              // @ts-ignore
              onChange={(item) => handleThemeChange(item)}
            />
          </Menu>
        )}
      </div>
    </>
  );
}

export default ThemeSwitcher;
