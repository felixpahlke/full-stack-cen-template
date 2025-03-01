import { useState } from "react";
import { OverflowMenu, OverflowMenuItem } from "@carbon/react";
import { Edit, TrashCan } from "@carbon/icons-react";

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
      <OverflowMenu
        size="sm"
        flipped
        disabled={disabled}
        ariaLabel="Actions menu"
      >
        <OverflowMenuItem
          itemText={
            <div className="flex items-center gap-2">
              <Edit size={16} /> Edit {type}
            </div>
          }
          onClick={() => setIsEditModalOpen(true)}
        />
        <OverflowMenuItem
          itemText={
            <div className="flex items-center gap-2">
              <TrashCan size={16} /> Delete {type}
            </div>
          }
          onClick={() => setIsDeleteModalOpen(true)}
          isDelete
          hasDivider
        />
      </OverflowMenu>
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
