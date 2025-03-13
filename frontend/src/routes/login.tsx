import { createFileRoute, Link, redirect } from "@tanstack/react-router";
import { useForm } from "react-hook-form";

import { Button } from "@/components/ui/button";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Logo } from "@/components/common/Logo";
import type { Body_login_login_access_token as AccessToken } from "../client";
import useAuth, { isLoggedIn } from "../hooks/useAuth";
import { emailPattern } from "../utils";

export const Route = createFileRoute("/login")({
  component: Login,
  beforeLoad: async () => {
    if (isLoggedIn()) {
      throw redirect({
        to: "/",
      });
    }
  },
});

interface FormValues {
  username: string;
  password: string;
}

function Login() {
  const { loginMutation, error, resetError } = useAuth();
  const form = useForm<FormValues>({
    defaultValues: {
      username: "",
      password: "",
    },
    mode: "onBlur",
  });

  const onSubmit = async (data: FormValues) => {
    if (resetError) resetError();

    try {
      await loginMutation.mutateAsync(data as AccessToken);
    } catch {
      // error is handled by useAuth hook
    }
  };

  return (
    <div className="mx-auto flex min-h-[100dvh] max-w-sm flex-col justify-center p-4">
      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
          <Logo className="mb-3 w-full" />

          <FormField
            control={form.control}
            name="username"
            rules={{
              required: "Email is required",
              pattern: emailPattern,
            }}
            render={({ field }) => (
              <FormItem>
                <FormLabel>Email</FormLabel>
                <FormControl>
                  <Input {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="password"
            rules={{ required: "Password is required" }}
            render={({ field }) => (
              <FormItem>
                <FormLabel>Password</FormLabel>
                <FormControl>
                  <Input type="password" {...field} />
                </FormControl>
                {error && (
                  <p className="text-destructive text-sm font-medium">
                    {error}
                  </p>
                )}
                <FormMessage />
              </FormItem>
            )}
          />

          <Button
            type="submit"
            className="w-full"
            disabled={form.formState.isSubmitting}
          >
            {form.formState.isSubmitting ? "Loading..." : "Log In"}
          </Button>

          <div className="flex w-full justify-center gap-2">
            Don't have an account? <Link to="/signup">Sign up</Link>
          </div>
        </form>
      </Form>
    </div>
  );
}
