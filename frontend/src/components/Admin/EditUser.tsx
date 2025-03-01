import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm, type SubmitHandler } from "react-hook-form";
import { useRef } from "react";

import {
  type ApiError,
  type UserPublic,
  type UserUpdate,
  UsersService,
} from "../../client";
import { emailPattern, handleError } from "../../utils";

import {
  Checkbox,
  Form,
  Modal,
  PasswordInput,
  Stack,
  TextInput,
} from "@carbon/react";
import { toast } from "@/components/Common/Toaster";

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
    mode: "onBlur",
    criteriaMode: "all",
    defaultValues: {
      ...user,
      password: "",
      confirm_password: "",
    },
  });

  const { errors, isValid } = form.formState;

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

  const onSubmit: SubmitHandler<UserUpdateForm> = (data) => {
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
      onRequestSubmit={form.handleSubmit(onSubmit)}
      primaryButtonDisabled={isPending || !isValid}
      launcherButtonRef={buttonRef}
    >
      <Form className="py-4">
        <Stack gap={5}>
          <TextInput
            id="email"
            labelText="Email"
            placeholder="Email"
            type="email"
            invalid={!!errors.email}
            invalidText={errors.email?.message}
            {...form.register("email", {
              required: "Email is required",
              pattern: emailPattern,
            })}
          />

          <TextInput
            id="full_name"
            labelText="Full name"
            placeholder="Full name"
            invalid={!!errors.full_name}
            invalidText={errors.full_name?.message}
            {...form.register("full_name")}
          />

          <PasswordInput
            id="password"
            labelText="Set Password"
            placeholder="Password"
            hidePasswordLabel="Hide password"
            showPasswordLabel="Show password"
            invalid={!!errors.password}
            invalidText={errors.password?.message}
            {...form.register("password", {
              minLength: {
                value: 8,
                message: "Password must be at least 8 characters",
              },
            })}
          />

          <PasswordInput
            id="confirm_password"
            labelText="Confirm Password"
            placeholder="Confirm password"
            hidePasswordLabel="Hide password"
            showPasswordLabel="Show password"
            invalid={!!errors.confirm_password}
            invalidText={errors.confirm_password?.message}
            {...form.register("confirm_password", {
              validate: (value) =>
                !form.getValues("password") ||
                value === form.getValues("password") ||
                "The passwords do not match",
            })}
          />

          <div className="flex space-x-8">
            <Checkbox
              id="is_superuser"
              labelText="Is superuser?"
              {...form.register("is_superuser")}
            />

            <Checkbox
              id="is_active"
              labelText="Is active?"
              {...form.register("is_active")}
            />
          </div>
        </Stack>
      </Form>
    </Modal>
  );
};

export default EditUser;
