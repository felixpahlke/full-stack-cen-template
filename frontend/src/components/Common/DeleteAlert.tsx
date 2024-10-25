import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useRef } from "react";
import { useForm } from "react-hook-form";

import { ItemsService, UsersService } from "../../client";

import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";
import { toast } from "sonner";

interface DeleteProps {
  type: string;
  id: string;
  isOpen: boolean;
  onClose: () => void;
}

const Delete = ({ type, id, isOpen, onClose }: DeleteProps) => {
  const queryClient = useQueryClient();
  const cancelRef = useRef<HTMLButtonElement>(null);
  const {
    handleSubmit,
    formState: { isSubmitting },
  } = useForm();

  const deleteEntity = async (id: string) => {
    if (type === "Item") {
      await ItemsService.deleteItem({ id: id });
    } else if (type === "User") {
      await UsersService.deleteUser({ userId: id });
    } else {
      throw new Error(`Unexpected type: ${type}`);
    }
  };

  const mutation = useMutation({
    mutationFn: deleteEntity,
    onSuccess: () => {
      toast.success(`The ${type.toLowerCase()} was deleted successfully.`);
      onClose();
    },
    onError: () => {
      toast.error(`An error occurred while deleting the ${type.toLowerCase()}.`);
    },
    onSettled: () => {
      queryClient.invalidateQueries({
        queryKey: [type === "Item" ? "items" : "users"],
      });
    },
  });

  const onSubmit = async () => {
    mutation.mutate(id);
  };

  return (
    <AlertDialog open={isOpen} onOpenChange={onClose}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Delete {type}</AlertDialogTitle>
          <AlertDialogDescription>
            {type === "User" && (
              <span>
                All items associated with this user will also be{" "}
                <strong>permanently deleted. </strong>
              </span>
            )}
            Are you sure? You will not be able to undo this action.
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel ref={cancelRef} disabled={isSubmitting}>
            Cancel
          </AlertDialogCancel>
          <AlertDialogAction asChild>
            <Button variant="destructive" onClick={handleSubmit(onSubmit)} disabled={isSubmitting}>
              Delete
            </Button>
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
};

export default Delete;
