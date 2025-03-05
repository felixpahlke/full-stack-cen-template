import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm, type SubmitHandler } from "react-hook-form";

import { type UserCreate, UsersService } from "../../client";
import type { ApiError } from "../../client/core/ApiError";
import { emailPattern, handleError } from "../../utils";

import {
  Checkbox,
  Form,
  Modal,
  PasswordInput,
  Stack,
  TextInput,
} from "@carbon/react";
import { toast } from "@/components/common/Toaster";

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
    mode: "onBlur",
    criteriaMode: "all",
    defaultValues: {
      email: "",
      full_name: "",
      password: "",
      confirm_password: "",
      is_superuser: false,
      is_active: false,
    },
  });

  const { errors, isValid } = form.formState;

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

  const onSubmit: SubmitHandler<UserCreateForm> = (data) => {
    createUser(data);
  };

  return (
    <Modal
      open={isOpen}
      onRequestClose={onClose}
      modalHeading="Add User"
      primaryButtonText={isPending ? "Saving..." : "Save"}
      secondaryButtonText="Cancel"
      onRequestSubmit={form.handleSubmit(onSubmit)}
      primaryButtonDisabled={isPending || !isValid}
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
            {...form.register("full_name", {
              required: "Full name is required",
              minLength: 3,
            })}
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
              required: "Password is required",
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
              required: "Confirm password is required",
              validate: (value) =>
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

export default AddUser;
