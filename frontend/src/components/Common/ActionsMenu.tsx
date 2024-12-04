import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Edit, MoreVertical, Trash } from "lucide-react";
import { useState } from "react";

import type { ItemPublic, UserPublic } from "../../client";
import EditUser from "../Admin/EditUser";
import EditItem from "../Items/EditItem";
import Delete from "./DeleteAlert";

interface ActionsMenuProps {
  type: string;
  value: ItemPublic | UserPublic;
  disabled?: boolean;
}

const ActionsMenu = ({ type, value, disabled }: ActionsMenuProps) => {
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const [isDeleteModalOpen, setIsDeleteModalOpen] = useState(false);

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild disabled={disabled}>
          <Button
            variant="ghost"
            className="h-8 w-8 justify-center p-0"
            disabled={disabled}
          >
            <span className="sr-only">Open menu</span>
            <MoreVertical className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onClick={() => setIsEditModalOpen(true)}>
            <Edit className="mr-2 h-4 w-4" />
            <span>Edit {type}</span>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => setIsDeleteModalOpen(true)}>
            <Trash className="mr-2 h-4 w-4" />
            <span className="text-destructive">Delete {type}</span>
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
      {type === "User" ? (
        <EditUser
          user={value as UserPublic}
          isOpen={isEditModalOpen}
          onClose={() => setIsEditModalOpen(false)}
        />
      ) : (
        <EditItem
          item={value as ItemPublic}
          isOpen={isEditModalOpen}
          onClose={() => setIsEditModalOpen(false)}
        />
      )}
      <Delete
        type={type}
        id={value.id}
        isOpen={isDeleteModalOpen}
        onClose={() => setIsDeleteModalOpen(false)}
      />
    </>
  );
};

export default ActionsMenu;
