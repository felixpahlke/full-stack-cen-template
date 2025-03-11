import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

import DeleteConfirmation from "./delete-confirmation";

const DeleteAccount = () => {
  const [isOpen, setIsOpen] = useState(false);

  const openModal = () => setIsOpen(true);
  const closeModal = () => setIsOpen(false);

  return (
    <Card className="max-w-md">
      <CardHeader>
        <CardTitle>Delete Account</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          <p className="text-sm text-muted-foreground">
            Permanently delete your data and everything associated with your
            account.
          </p>
          <Button variant="destructive" onClick={openModal}>
            Delete
          </Button>
          <DeleteConfirmation isOpen={isOpen} onClose={closeModal} />
        </div>
      </CardContent>
    </Card>
  );
};

export default DeleteAccount;
