import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { useRef } from "react";

import { type UserCreate, UsersService } from "../../client";
import type { ApiError } from "../../client/core/ApiError";
import { emailPattern, handleError } from "../../utils";

import { Checkbox, Modal, TextInput } from "@carbon/react";
import { toast } from "@/components/Common/Toaster";

interface AddUserProps {
  isOpen: boolean;
  onClose: () => void;
}

interface UserCreateForm extends UserCreate {
  confirm_password: string;
}

const AddUser = ({ isOpen, onClose }: AddUserProps) => {
  const queryClient = useQueryClient();
  const form = useForm<UserCreateForm>({
    defaultValues: {
      email: "",
      full_name: "",
      password: "",
      confirm_password: "",
      is_superuser: false,
      is_active: false,
    },
    mode: "onChange",
  });

  const { mutate: createUser, isPending } = useMutation({
    mutationFn: (data: UserCreate) =>
      UsersService.createUser({ requestBody: data }),
    onSuccess: () => {
      toast.success("User created successfully.");
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
    console.log("onSubmit");
    const data = form.getValues();

    // Email validation
    if (!emailPattern.value.test(data.email)) {
      form.setError("email", {
        type: "validate",
        message: emailPattern.message,
      });
      return;
    }

    // Full name validation
    if (!data.full_name || data.full_name.trim() === "") {
      form.setError("full_name", {
        type: "validate",
        message: "Full name is required",
      });
      return;
    }

    // Password validation
    if (!data.password || data.password.trim() === "") {
      form.setError("password", {
        type: "validate",
        message: "Password is required",
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

    createUser(data);
  };

  const buttonRef = useRef(null);

  return (
    <Modal
      open={isOpen}
      onRequestClose={onClose}
      modalHeading="Add User"
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
          value={form.watch("email")}
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
          required
        />

        <TextInput
          id="password"
          labelText="Set Password"
          placeholder="Password"
          type="password"
          value={form.watch("password")}
          onChange={(e) => {
            form.setValue("password", e.target.value);
            form.clearErrors("password");
          }}
          invalid={!!form.formState.errors.password}
          invalidText={form.formState.errors.password?.message}
          required
        />

        <TextInput
          id="confirm_password"
          labelText="Confirm Password"
          placeholder="Confirm password"
          type="password"
          value={form.watch("confirm_password")}
          onChange={(e) => {
            form.setValue("confirm_password", e.target.value);
            form.clearErrors("confirm_password");
          }}
          invalid={!!form.formState.errors.confirm_password}
          invalidText={form.formState.errors.confirm_password?.message}
          required
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

export default AddUser;
