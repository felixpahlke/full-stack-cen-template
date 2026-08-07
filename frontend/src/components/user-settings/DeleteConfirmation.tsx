import { useMutation, useQueryClient } from "@tanstack/react-query";
import type { AxiosError } from "axios";
import { useForm } from "react-hook-form";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Users } from "../../client";
import useAuth from "../../hooks/useAuth";
import { handleError } from "../../utils";

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
    mutationFn: () => Users.deleteUserMe(),
    onSuccess: () => {
      toast.success("Your account has been successfully deleted.");
      logout();
      onClose();
    },
    onError: (err: AxiosError) => {
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
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Confirmation Required</DialogTitle>
          <DialogDescription className="mb-4">
            All your account data will be <strong>permanently deleted.</strong> If you are sure,
            please click <strong>"Confirm"</strong> to proceed. This action cannot be undone.
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="destructive" disabled={isSubmitting} onClick={handleSubmit(onSubmit)}>
            {isSubmitting ? "Deleting..." : "Confirm"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};

export default DeleteConfirmation;
