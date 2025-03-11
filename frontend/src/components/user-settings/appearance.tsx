import { Card, CardContent } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Badge } from "@/components/ui/badge";
import { useTheme } from "../theme/theme-provider";

const Appearance = () => {
  const { theme, setTheme } = useTheme();

  const handleThemeChange = (value: string) => {
    setTheme(value as "light" | "dark" | "system");
  };

  return (
    <Card className="max-w-md">
      <CardContent className="pt-6">
        <h3 className="mb-4 text-lg font-medium">Appearance</h3>
        <RadioGroup
          className="mt-4 space-y-3"
          value={theme}
          onValueChange={handleThemeChange}
        >
          <div className="flex items-center space-x-2">
            <RadioGroupItem value="light" id="light" />
            <Label htmlFor="light" className="flex items-center">
              <span className="mr-2">Light Mode</span>
              {theme === "light" && (
                <Badge variant="secondary" className="ml-2">
                  Default
                </Badge>
              )}
            </Label>
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
