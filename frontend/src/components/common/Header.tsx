import { Link } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import { Menu } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useIsMobile } from "@/hooks/use-mobile";
import type { UserPublic } from "../../client";
import useAuth from "../../hooks/useAuth";
import { ModeToggle } from "../theme/ThemeSwitcher";
import { Separator } from "@/components/ui/separator";
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet";
import UserMenu from "./UserMenu";
import { Logo } from "./Logo";

export function Header() {
  const { logout } = useAuth();
  const queryClient = useQueryClient();
  const currentUser = queryClient.getQueryData<UserPublic>(["currentUser"]);
  const isMobile = useIsMobile();

  const handleLogout = () => {
    logout();
  };

  const navItems: {
    title: string;
    path: string;
    search?: { page: number };
  }[] = [{ title: "Items", path: "/items", search: { page: 1 } }];

  if (currentUser?.is_superuser) {
    navItems.push({ title: "Admin", path: "/admin" });
  }

  return (
    <header className="bg-background sticky top-0 z-50 flex h-12 w-full items-center border-b">
      <div className="flex h-14 w-full items-center gap-2 px-4">
        {isMobile ? (
          <Sheet>
            <SheetTrigger asChild>
              <Button
                variant="ghost"
                size="icon"
                className="text-foreground h-8 w-8"
              >
                <Menu className="h-5 w-5" />
                <span className="sr-only">Toggle menu</span>
              </Button>
            </SheetTrigger>
            <SheetContent side="left" className="sm:w-[300px] w-[240px]">
              <nav className="mt-6 flex flex-col space-y-4">
                {navItems.map((item) => (
                  <Link
                    key={item.title}
                    to={item.path}
                    search={item.search}
                    className="text-foreground/60 hover:text-foreground/80 text-lg font-medium transition-colors"
                  >
                    {item.title}
                  </Link>
                ))}
                <Link
                  to="/settings"
                  className="text-foreground/60 hover:text-foreground/80 text-lg font-medium transition-colors"
                >
                  User Settings
                </Link>
                <button
                  onClick={handleLogout}
                  className="text-left text-lg font-medium text-red-500 hover:text-red-600"
                >
                  Logout
                </button>
              </nav>
            </SheetContent>
          </Sheet>
        ) : (
          <Link to="/" className="mr-6 flex items-center space-x-2">
            <span className="text-sm">
              IBM <span className="font-semibold">Client Engineering</span>
            </span>
          </Link>
        )}

        <Separator
          orientation="vertical"
          className="md:block mr-2 hidden h-4"
        />

        <nav className="md:flex hidden items-center space-x-8 pl-4 text-sm">
          {navItems.map((item) => (
            <Link
              key={item.title}
              to={item.path}
              search={item.search}
              className="text-muted-foreground hover:text-foreground/80 transition-colors"
            >
              {item.title}
            </Link>
          ))}
        </nav>

        <div className="ml-auto flex items-center gap-2">
          <ModeToggle />
          {!isMobile ? <UserMenu /> : null}
        </div>
      </div>
    </header>
  );
}
