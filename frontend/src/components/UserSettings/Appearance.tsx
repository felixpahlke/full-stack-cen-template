import { Label } from "@/components/ui/label";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useTheme } from "../Theme/ThemeProvider";

const Appearance = () => {
  const { theme, setTheme } = useTheme();

  const handleThemeChange = (value: string) => {
    setTheme(value as "light" | "dark" | "system");
  };

  return (
    <Card className="max-w-md">
      <CardHeader>
        <CardTitle>Appearance</CardTitle>
      </CardHeader>
      <CardContent>
        <RadioGroup value={theme} onValueChange={handleThemeChange} className="space-y-4">
          <div className="flex items-center space-x-2">
            <RadioGroupItem value="light" id="light" />
            <Label htmlFor="light">Light Mode</Label>
            {theme === "light" && (
              <span className="bg-primary text-primary-foreground ml-2 rounded-full px-2 py-1 text-xs">
                Default
              </span>
            )}
          </div>
          <div className="flex items-center space-x-2">
            <RadioGroupItem value="dark" id="dark" />
            <Label htmlFor="dark">Dark Mode</Label>
          </div>
          <div className="flex items-center space-x-2">
            <RadioGroupItem value="system" id="system" />
            <Label htmlFor="system">System Default</Label>
          </div>
        </RadioGroup>
      </CardContent>
    </Card>
  );
};

export default Appearance;
