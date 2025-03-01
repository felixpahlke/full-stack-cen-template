import { useMutation } from "@tanstack/react-query";
import { useForm, type SubmitHandler } from "react-hook-form";

import { type ApiError, type UpdatePassword, UsersService } from "../../client";
import { handleError } from "../../utils";

import { Button, Form, PasswordInput, Stack, Tile } from "@carbon/react";
import { toast } from "@/components/Common/Toaster";

interface UpdatePasswordForm extends UpdatePassword {
  confirm_password: string;
}

const ChangePassword = () => {
  const form = useForm<UpdatePasswordForm>({
    mode: "onBlur",
    criteriaMode: "all",
    defaultValues: {
      current_password: "",
      new_password: "",
      confirm_password: "",
    },
  });

  const { errors, isValid } = form.formState;

  const { mutate: updatePassword, isPending } = useMutation({
    mutationFn: (data: UpdatePassword) =>
      UsersService.updatePasswordMe({ requestBody: data }),
    onSuccess: () => {
      toast.success("Password updated successfully.");
      form.reset();
    },
    onError: (err: ApiError) => {
      handleError(err);
    },
  });

  const onSubmit: SubmitHandler<UpdatePasswordForm> = (data) => {
    updatePassword(data);
  };

  return (
    <Tile className="max-w-md">
      <h3 className="mb-4 text-lg font-medium">Change Password</h3>
      <Form className="py-4" onSubmit={form.handleSubmit(onSubmit)}>
        <Stack gap={5}>
          <PasswordInput
            id="current_password"
            labelText="Current Password"
            placeholder="Current password"
            hidePasswordLabel="Hide password"
            showPasswordLabel="Show password"
            invalid={!!errors.current_password}
            invalidText={errors.current_password?.message}
            {...form.register("current_password", {
              required: "Current password is required",
            })}
          />

          <PasswordInput
            id="new_password"
            labelText="New Password"
            placeholder="New password"
            hidePasswordLabel="Hide password"
            showPasswordLabel="Show password"
            invalid={!!errors.new_password}
            invalidText={errors.new_password?.message}
            {...form.register("new_password", {
              required: "New password is required",
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
              required: "Please confirm your password",
              validate: (value) =>
                value === form.getValues("new_password") ||
                "The passwords do not match",
            })}
          />

          <div>
            <Button
              type="submit"
              kind="primary"
              disabled={isPending || !isValid}
            >
              {isPending ? "Saving..." : "Save"}
            </Button>
          </div>
        </Stack>
      </Form>
    </Tile>
  );
};

export default ChangePassword;
