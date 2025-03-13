import { useRouter } from "@tanstack/react-router";
import { FiLogOut, FiUser } from "react-icons/fi";
import { cn } from "@/lib/utils";
import useAuth from "../../hooks/useAuth";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";

interface UserMenuProps {
  className?: string;
}

const UserMenu = ({ className }: UserMenuProps) => {
  const { logout } = useAuth();
  const [isOpen, setIsOpen] = useState(false);
  const router = useRouter();
  const { user } = useAuth();

  const handleLogout = async () => {
    logout();
    setIsOpen(false);
  };

  return (
    <>
      {/* Desktop */}
      <div className={cn(className)}>
        <div className="h-full">
          <DropdownMenu open={isOpen} onOpenChange={setIsOpen}>
            <DropdownMenuTrigger asChild>
              <Button
                variant="ghost"
                className="w-10"
                aria-label="User menu"
                data-testid="user-menu"
              >
                <Avatar className="h-8 w-8">
                  <AvatarFallback>
                    {user?.full_name ? user.full_name.charAt(0) : "U"}
                  </AvatarFallback>
                </Avatar>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem
                onClick={() => {
                  router.navigate({ to: "/settings" });
                }}
                className="flex items-center"
              >
                <FiUser className="mr-2 h-4 w-4" />
                My profile
              </DropdownMenuItem>
              <DropdownMenuItem
                onClick={handleLogout}
                className="flex items-center text-destructive"
              >
                <FiLogOut className="mr-2 h-4 w-4" />
                Log out
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>
    </>
  );
};

export default UserMenu;
