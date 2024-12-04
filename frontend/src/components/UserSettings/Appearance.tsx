import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Tag } from "@carbon/react";
import { useTheme } from "../Theme/ThemeProvider";

const Appearance = () => {
  const { theme, setTheme } = useTheme();

  const handleThemeChange = (value: string) => {
    setTheme(value as "white" | "g90" | "system");
  };

  return (
    <Card className="max-w-md">
      <CardHeader>
        <CardTitle>Appearance</CardTitle>
      </CardHeader>
      <CardContent>
        <RadioGroup
          value={theme}
          onValueChange={handleThemeChange}
          className="space-y-4"
        >
          <div className="flex items-center space-x-2">
            <RadioGroupItem value="white" id="light" />
            <Label htmlFor="light">Light Mode</Label>
            {theme === "white" && (
              <Tag type="blue" size="sm">
                Default
              </Tag>
            )}
          </div>
          <div className="flex items-center space-x-2">
            <RadioGroupItem value="g90" id="dark" />
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
