import { zodResolver } from "@hookform/resolvers/zod";
import { createFileRoute, Link, redirect } from "@tanstack/react-router";
import { useForm } from "react-hook-form";
import * as z from "zod";

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
import { Logo } from "@/components/common/logo";
import type { Body_login_login_access_token as AccessToken } from "../client";
import useAuth, { isLoggedIn } from "../hooks/useAuth";

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

const formSchema = z.object({
  username: z
    .string()
    .email("Please enter a valid email address")
    .min(1, "Email is required"),
  password: z.string().min(1, "Password is required"),
});

function Login() {
  const { loginMutation, error, resetError } = useAuth();
  const form = useForm<z.infer<typeof formSchema>>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      username: "",
      password: "",
    },
  });

  const onSubmit = async (data: z.infer<typeof formSchema>) => {
    resetError();

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
            render={({ field }) => (
              <FormItem>
                <FormLabel>Password</FormLabel>
                <FormControl>
                  <Input type="password" {...field} />
                </FormControl>
                {error && (
                  <p className="text-sm font-medium text-destructive">
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
