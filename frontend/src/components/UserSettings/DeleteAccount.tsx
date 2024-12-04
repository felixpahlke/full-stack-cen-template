import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useState } from "react";

import DeleteConfirmation from "./DeleteConfirmation";

const DeleteAccount = () => {
  const [isOpen, setIsOpen] = useState(false);

  const openModal = () => setIsOpen(true);
  const closeModal = () => setIsOpen(false);

  return (
    <Card className="max-w-md">
      <CardHeader>
        <CardTitle>Delete Account</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <p className="text-muted-foreground text-sm">
          Permanently delete your data and everything associated with your
          account.
        </p>
        <Button variant="destructive" onClick={openModal}>
          Delete
        </Button>
        <DeleteConfirmation isOpen={isOpen} onClose={closeModal} />
      </CardContent>
    </Card>
  );
};

export default DeleteAccount;
