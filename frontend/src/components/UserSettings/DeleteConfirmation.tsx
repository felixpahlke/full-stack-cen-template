import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";

import { type ApiError, UsersService } from "../../client";
import useAuth from "../../hooks/useAuth";
import { handleError } from "../../utils";
import { Modal } from "@carbon/react";
import { toast } from "@/components/Common/Toaster";

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
    <Modal
      open={isOpen}
      onRequestClose={onClose}
      modalHeading="Confirmation Required"
      primaryButtonText={isSubmitting ? "Deleting..." : "Confirm"}
      secondaryButtonText="Cancel"
      primaryButtonDisabled={isSubmitting}
      onRequestSubmit={handleSubmit(onSubmit)}
      danger
    >
      <p className="mb-4">
        All your account data will be <strong>permanently deleted.</strong> If
        you are sure, please click <strong>"Confirm"</strong> to proceed. This
        action cannot be undone.
      </p>
    </Modal>
  );
};

export default DeleteConfirmation;
