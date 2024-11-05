import { useMutation } from "@tanstack/react-query";
import { createFileRoute, redirect, useNavigate } from "@tanstack/react-router";
import { type SubmitHandler, useForm } from "react-hook-form";

import { type ApiError, LoginService, type NewPassword } from "../client";
import { isLoggedIn } from "../hooks/useAuth";
import { confirmPasswordRules, handleError, passwordRules } from "../utils";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormMessage,
} from "@/components/ui/form";
import { Logo } from "@/components/Common/Logo";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { toast } from "sonner";

interface NewPasswordForm extends NewPassword {
  confirm_password: string;
}

export const Route = createFileRoute("/reset-password")({
  component: ResetPassword,
  beforeLoad: async () => {
    if (isLoggedIn()) {
      throw redirect({
        to: "/",
        search: { page: 1 },
      });
    }
  },
});

function ResetPassword() {
  const form = useForm<NewPasswordForm>({
    mode: "onBlur",
    criteriaMode: "all",
    defaultValues: {
      new_password: "",
    },
  });
  const { reset, handleSubmit, control, formState, getValues } = form;
  const navigate = useNavigate();

  const resetPassword = async (data: NewPassword) => {
    const token = new URLSearchParams(window.location.search).get("token");
    if (!token) return;
    await LoginService.resetPassword({
      requestBody: { new_password: data.new_password, token: token },
    });
  };

  const mutation = useMutation({
    mutationFn: resetPassword,
    onSuccess: () => {
      toast.success("Password updated successfully.");
      reset();
      navigate({ to: "/login" });
    },
    onError: (err: ApiError) => {
      handleError(err);
    },
  });

  const onSubmit: SubmitHandler<NewPasswordForm> = async (data) => {
    mutation.mutate(data);
  };

  return (
    <Form {...form}>
      <form
        onSubmit={handleSubmit(onSubmit)}
        className="mx-auto flex min-h-[100dvh] max-w-sm flex-col justify-center space-y-6 p-4"
      >
        <Logo className="w-full" />

        <h1 className="text-center text-2xl font-semibold">Reset Password</h1>
        <p className="text-center">
          Please enter your new password and confirm it to reset your password.
        </p>

        <FormField
          control={control}
          name="new_password"
          rules={passwordRules()}
          render={({ field, fieldState }) => (
            <FormItem>
              <FormControl>
                <Input
                  {...field}
                  placeholder="New Password"
                  type="password"
                  className={fieldState.error ? "border-red-500" : ""}
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={control}
          name="confirm_password"
          rules={confirmPasswordRules(getValues)}
          render={({ field, fieldState }) => (
            <FormItem>
              <FormControl>
                <Input
                  {...field}
                  placeholder="Confirm Password"
                  type="password"
                  className={fieldState.error ? "border-red-500" : ""}
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <Button
          type="submit"
          disabled={formState.isSubmitting || mutation.isPending}
        >
          {formState.isSubmitting || mutation.isPending
            ? "Resetting..."
            : "Reset Password"}
        </Button>
      </form>
    </Form>
  );
}
