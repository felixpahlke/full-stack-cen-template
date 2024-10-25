import { useMutation } from "@tanstack/react-query";
import { createFileRoute, redirect } from "@tanstack/react-router";
import { type SubmitHandler, useForm } from "react-hook-form";

import { type ApiError, LoginService } from "../client";
import { isLoggedIn } from "../hooks/useAuth";
import { emailPattern, handleError } from "../utils";
import { Form, FormControl, FormField, FormItem, FormMessage } from "@/components/ui/form";
import { Logo } from "@/components/Common/Logo";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { toast } from "sonner";

interface FormData {
  email: string;
}

export const Route = createFileRoute("/recover-password")({
  component: RecoverPassword,
  beforeLoad: async () => {
    if (isLoggedIn()) {
      throw redirect({
        to: "/",
        search: { page: 1 },
      });
    }
  },
});

function RecoverPassword() {
  const form = useForm<FormData>({
    defaultValues: {
      email: "",
    },
  });
  const { reset, handleSubmit, control, formState } = form;

  const recoverPassword = async (data: FormData) => {
    await LoginService.recoverPassword({
      email: data.email,
    });
  };

  const mutation = useMutation({
    mutationFn: recoverPassword,
    onSuccess: () => {
      toast.success("We sent an email with a link to get back into your account.");
      reset();
    },
    onError: (err: ApiError) => {
      handleError(err);
    },
  });

  const onSubmit: SubmitHandler<FormData> = async (data) => {
    mutation.mutate(data);
  };

  return (
    <Form {...form}>
      <form
        onSubmit={handleSubmit(onSubmit)}
        className="mx-auto flex min-h-[100dvh] max-w-sm flex-col justify-center space-y-6 p-4"
      >
        <Logo className="w-full" />

        <h1 className="text-center text-2xl font-semibold">Password Recovery</h1>
        <p className="text-center">
          A password recovery email will be sent to the registered account.
        </p>

        <FormField
          control={control}
          name="email"
          rules={{
            required: "Email is required",
            pattern: emailPattern,
          }}
          render={({ field, fieldState }) => (
            <FormItem>
              <FormControl>
                <Input
                  {...field}
                  placeholder="Email"
                  type="email"
                  className={fieldState.error ? "border-red-500" : ""}
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <Button type="submit" disabled={formState.isSubmitting || mutation.isPending}>
          {formState.isSubmitting || mutation.isPending ? "Sending..." : "Continue"}
        </Button>
      </form>
    </Form>
  );
}
