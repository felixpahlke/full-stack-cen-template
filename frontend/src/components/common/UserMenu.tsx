import { FiLogOut } from "react-icons/fi";
import { Button, Menu, MenuItem } from "@carbon/react";
import { cn } from "@/lib/utils";
import { UserAvatar } from "@carbon/icons-react";
import useAuth from "../../hooks/useAuth";
import { useRef, useState } from "react";

interface UserMenuProps {
  className?: string;
}

const UserMenu = ({ className }: UserMenuProps) => {
  const { logout } = useAuth();
  const [isOpen, setIsOpen] = useState(false);
  const buttonRef = useRef<HTMLButtonElement>(null);
  const handleLogout = async () => {
    logout();
    setIsOpen(false);
  };

  // Calculate position for the menu when button is clicked
  const getMenuPosition = () => {
    if (!buttonRef.current) return { x: 0, y: 0 };

    const rect = buttonRef.current.getBoundingClientRect();

    return {
      x: rect.right,
      y: rect.bottom,
    };
  };

  return (
    <>
      {/* Desktop */}
      <div className={cn("abolute right-4 hidden lg:block", className)}>
        <div className="h-full">
          <Button
            ref={buttonRef}
            kind="ghost"
            onClick={() => setIsOpen(!isOpen)}
            className="flex h-12 items-center"
            aria-label="User menu"
            data-testid="user-menu"
          >
            <UserAvatar className="h-6 w-6" />
          </Button>
          {isOpen && buttonRef.current && (
            <Menu
              label="User Menu"
              open={isOpen}
              onClose={() => setIsOpen(false)}
              {...getMenuPosition()}
            >
              <MenuItem
                label="Log out"
                onClick={handleLogout}
                className="font-bold text-cds-text-error"
                renderIcon={() => <FiLogOut className="mr-2 h-4 w-4" />}
              />
            </Menu>
          )}
        </div>
      </div>
    </>
  );
};

export default UserMenu;
