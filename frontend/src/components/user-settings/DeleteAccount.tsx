import { useState } from "react";
import { Button, Tile } from "@carbon/react";

import DeleteConfirmation from "./DeleteConfirmation";

const DeleteAccount = () => {
  const [isOpen, setIsOpen] = useState(false);

  const openModal = () => setIsOpen(true);
  const closeModal = () => setIsOpen(false);

  return (
    <Tile className="max-w-md">
      <h3 className="mb-4 text-lg font-medium">Delete Account</h3>
      <div className="space-y-4 py-4">
        <p className="text-sm text-gray-600">
          Permanently delete your data and everything associated with your
          account.
        </p>
        <Button kind="danger" onClick={openModal}>
          Delete
        </Button>
        <DeleteConfirmation isOpen={isOpen} onClose={closeModal} />
      </div>
    </Tile>
  );
};

export default DeleteAccount;
