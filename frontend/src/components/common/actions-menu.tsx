import { useState } from "react";
import { Edit, MoreVertical, Trash } from "lucide-react";

import type { ItemPublic, UserPublic } from "../../client";
import EditUser from "../admin/edit-user";
import EditItem from "../items/edit-item";
import Delete from "./delete-alert";

import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Button } from "@/components/ui/button";

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
          <Button variant="ghost" size="sm">
            <MoreVertical className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onClick={() => setIsEditModalOpen(true)}>
            <Edit className="mr-2 h-4 w-4" />
            Edit {type}
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          <DropdownMenuItem
            onClick={() => setIsDeleteModalOpen(true)}
            className="text-destructive focus:text-destructive"
          >
            <Trash className="mr-2 h-4 w-4" />
            Delete {type}
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
