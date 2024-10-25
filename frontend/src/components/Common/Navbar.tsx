import { Sheet, SheetTrigger, SheetContent } from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Link } from "@tanstack/react-router";
import { useState } from "react";
import UserMenu from "./UserMenu";
import useAuth from "../../hooks/useAuth";
import { useQueryClient } from "@tanstack/react-query";
import type { UserPublic } from "../../client";
import { Logo } from "./Logo";

export function Navbar() {
  const [isOpen, setIsOpen] = useState(false);
  const { logout } = useAuth();
  const queryClient = useQueryClient();
  const currentUser = queryClient.getQueryData<UserPublic>(["currentUser"]);

  const handleLinkClick = () => {
    setIsOpen(false);
  };

  const handleLogout = () => {
    logout();
    setIsOpen(false);
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
    <header className="bg-background flex h-12 w-full shrink-0 items-center justify-center">
      <Sheet open={isOpen} onOpenChange={setIsOpen}>
        <SheetTrigger asChild>
          <Button variant="outline" size="icon" className="sm:hidden">
            <MenuIcon className="h-6 w-6" />
            <span className="sr-only">Toggle navigation menu</span>
          </Button>
        </SheetTrigger>
        <SheetContent side="left">
          <Link to="/" onClick={handleLinkClick}>
            <Logo className="!text-base" />
            <span className="sr-only">IBM Client Engineering</span>
          </Link>
          <div className="grid gap-2 py-6">
            {navItems.map((item) => (
              <Link
                key={item.title}
                to={item.path}
                search={item.search}
                className="text-foreground flex w-full items-center py-2 text-lg font-semibold"
                onClick={handleLinkClick}
              >
                {item.title}
              </Link>
            ))}
            <Link
              to="/settings"
              className="text-foreground flex w-full items-center py-2 text-lg font-semibold"
              onClick={handleLinkClick}
            >
              User Settings
            </Link>
            <button
              onClick={handleLogout}
              className="flex w-full items-center py-2 text-lg font-semibold text-red-500"
            >
              Logout
            </button>
          </div>
        </SheetContent>
      </Sheet>
      <div className="relative flex h-full w-full items-center border-b px-6">
        <Link to="/" className="mr-6 hidden sm:flex">
          <Logo className="!text-base" logoSize="sm" />
          <span className="sr-only">Acme Inc</span>
        </Link>
        <nav className="hidden sm:flex">
          <ul className="flex space-x-4">
            {navItems.map((item) => (
              <li key={item.title}>
                <Link
                  to={item.path}
                  search={item.search}
                  className="hover:bg-accent hover:text-accent-foreground focus:bg-accent focus:text-accent-foreground data-[active]:bg-accent/50 data-[state=open]:bg-accent/50 text-primary group inline-flex h-9 w-max items-center justify-center rounded-md px-4 py-2 text-sm transition-colors focus:outline-none disabled:pointer-events-none disabled:opacity-50"
                >
                  {item.title}
                </Link>
              </li>
            ))}
          </ul>
        </nav>
        <UserMenu className="absolute right-0" />
      </div>
    </header>
  );
}

function MenuIcon(props: any) {
  return (
    <svg
      {...props}
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <line x1="4" x2="20" y1="12" y2="12" />
      <line x1="4" x2="20" y1="6" y2="6" />
      <line x1="4" x2="20" y1="18" y2="18" />
    </svg>
  );
}
