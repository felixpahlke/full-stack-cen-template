import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";

import { type ApiError, UsersService } from "../../client";
import useAuth from "../../hooks/useAuth";
import { handleError } from "../../utils";

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
  isOpen: boolean;
  onClose: () => void;
}

const DeleteConfirmation = ({ isOpen, onClose }: DeleteProps) => {
  const queryClient = useQueryClient();
  const {
    handleSubmit,
    formState: { isSubmitting },
  } = useForm();
  const { logout } = useAuth();

  const mutation = useMutation({
    mutationFn: () => UsersService.deleteUserMe(),
    onSuccess: () => {
      toast.success("Your account has been successfully deleted.");
      logout();
      onClose();
    },
    onError: (err: ApiError) => {
      handleError(err);
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ["currentUser"] });
    },
  });

  const onSubmit = async () => {
    mutation.mutate();
  };

  return (
    <AlertDialog open={isOpen} onOpenChange={onClose}>
      <AlertDialogContent>
        <form onSubmit={handleSubmit(onSubmit)}>
          <AlertDialogHeader>
            <AlertDialogTitle>Confirmation Required</AlertDialogTitle>
            <AlertDialogDescription>
              All your account data will be <strong>permanently deleted.</strong> If you are sure,
              please click <strong>"Confirm"</strong> to proceed. This action cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter className="mt-4">
            <AlertDialogCancel asChild>
              <Button variant="outline" disabled={isSubmitting}>
                Cancel
              </Button>
            </AlertDialogCancel>
            <AlertDialogAction asChild>
              <Button variant="destructive" type="submit" disabled={isSubmitting}>
                {isSubmitting ? "Deleting..." : "Confirm"}
              </Button>
            </AlertDialogAction>
          </AlertDialogFooter>
        </form>
      </AlertDialogContent>
    </AlertDialog>
  );
};

export default DeleteConfirmation;
