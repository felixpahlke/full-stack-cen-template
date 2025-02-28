import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";

import {
  type ApiError,
  type UserPublic,
  type UserUpdate,
  UsersService,
} from "../../client";
import { emailPattern, handleError } from "../../utils";

import { Checkbox, Modal, TextInput } from "@carbon/react";
import { toast } from "@/components/Common/Toaster";
import { useRef } from "react";

interface EditUserProps {
  user: UserPublic;
  isOpen: boolean;
  onClose: () => void;
}

interface UserUpdateForm extends UserUpdate {
  confirm_password: string;
}

const EditUser = ({ user, isOpen, onClose }: EditUserProps) => {
  const queryClient = useQueryClient();

  const form = useForm<UserUpdateForm>({
    defaultValues: user,
  });

  const { mutate: updateUser, isPending } = useMutation({
    mutationFn: (data: UserUpdateForm) =>
      UsersService.updateUser({ userId: user.id, requestBody: data }),
    onSuccess: () => {
      toast.success("User updated successfully.");
      form.reset();
      onClose();
    },
    onError: (err: ApiError) => {
      handleError(err);
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ["users"] });
    },
  });

  const onSubmit = () => {
    const data = form.getValues();

    // Email validation
    if (data.email && !emailPattern.value.test(data.email)) {
      form.setError("email", {
        type: "validate",
        message: emailPattern.message,
      });
      return;
    }

    // Password validation - only if provided
    if (data.password) {
      if (data.password.length < 8) {
        form.setError("password", {
          type: "validate",
          message: "Password must be at least 8 characters",
        });
        return;
      }

      // Password match validation
      if (data.password !== data.confirm_password) {
        form.setError("confirm_password", {
          type: "validate",
          message: "The passwords do not match",
        });
        return;
      }
    }

    // Remove empty password
    if (data.password === "") {
      data.password = undefined;
    }

    updateUser(data);
  };

  const buttonRef = useRef(null);

  return (
    <Modal
      open={isOpen}
      onRequestClose={onClose}
      modalHeading="Edit User"
      primaryButtonText={isPending ? "Saving..." : "Save"}
      secondaryButtonText="Cancel"
      onRequestSubmit={onSubmit}
      primaryButtonDisabled={isPending}
      launcherButtonRef={buttonRef}
    >
      <div className="space-y-6 py-4">
        <TextInput
          id="email"
          labelText="Email"
          placeholder="Email"
          type="email"
          value={form.watch("email") || ""}
          onChange={(e) => {
            form.setValue("email", e.target.value);
            form.clearErrors("email");
          }}
          invalid={!!form.formState.errors.email}
          invalidText={form.formState.errors.email?.message}
          required
        />

        <TextInput
          id="full_name"
          labelText="Full name"
          placeholder="Full name"
          value={form.watch("full_name") || ""}
          onChange={(e) => {
            form.setValue("full_name", e.target.value);
            form.clearErrors("full_name");
          }}
          invalid={!!form.formState.errors.full_name}
          invalidText={form.formState.errors.full_name?.message}
        />

        <TextInput
          id="password"
          labelText="Set Password"
          placeholder="Password"
          type="password"
          value={form.watch("password") || ""}
          onChange={(e) => {
            form.setValue("password", e.target.value);
            form.clearErrors("password");
          }}
          invalid={!!form.formState.errors.password}
          invalidText={form.formState.errors.password?.message}
        />

        <TextInput
          id="confirm_password"
          labelText="Confirm Password"
          placeholder="Confirm password"
          type="password"
          value={form.watch("confirm_password") || ""}
          onChange={(e) => {
            form.setValue("confirm_password", e.target.value);
            form.clearErrors("confirm_password");
          }}
          invalid={!!form.formState.errors.confirm_password}
          invalidText={form.formState.errors.confirm_password?.message}
        />

        <div className="flex space-x-8">
          <Checkbox
            id="is_superuser"
            labelText="Is superuser?"
            checked={form.watch("is_superuser")}
            onChange={(e) => form.setValue("is_superuser", e.target.checked)}
          />

          <Checkbox
            id="is_active"
            labelText="Is active?"
            checked={form.watch("is_active")}
            onChange={(e) => form.setValue("is_active", e.target.checked)}
          />
        </div>
      </div>
    </Modal>
  );
};

export default EditUser;
