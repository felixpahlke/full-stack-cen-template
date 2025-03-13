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
import type { UserRegister } from "../client";
import useAuth, { isLoggedIn } from "../hooks/useAuth";
import {
  emailPattern,
  passwordRules,
  confirmPasswordRules,
  namePattern,
} from "../utils";

export const Route = createFileRoute("/signup")({
  component: SignUp,
  beforeLoad: async () => {
    if (isLoggedIn()) {
      throw redirect({
        to: "/",
      });
    }
  },
});

function SignUp() {
  const { signUpMutation, error, resetError } = useAuth();
  const form = useForm({
    defaultValues: {
      email: "",
      full_name: "",
      password: "",
      confirm_password: "",
      access_password: "",
    },
    mode: "onBlur",
  });

  const onSubmit = async (data: any) => {
    if (resetError) resetError();
    signUpMutation.mutate(data as UserRegister);
  };

  return (
    <div className="mx-auto flex min-h-[100dvh] max-w-sm flex-col justify-center p-4">
      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
          <Logo className="mb-3 w-full" />

          <FormField
            control={form.control}
            name="full_name"
            rules={{
              required: "Full name is required",
              minLength: {
                value: 3,
                message: "Full name must be at least 3 characters",
              },
              pattern: namePattern,
            }}
            render={({ field }) => (
              <FormItem>
                <FormLabel>Full Name</FormLabel>
                <FormControl>
                  <Input {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="email"
            rules={{
              required: "Email is required",
              pattern: emailPattern,
            }}
            render={({ field }) => (
              <FormItem>
                <FormLabel>Email Address</FormLabel>
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
            rules={passwordRules()}
            render={({ field }) => (
              <FormItem>
                <FormLabel>Create Password</FormLabel>
                <FormControl>
                  <Input type="password" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="confirm_password"
            rules={confirmPasswordRules(form.getValues)}
            render={({ field }) => (
              <FormItem>
                <FormLabel>Confirm Password</FormLabel>
                <FormControl>
                  <Input type="password" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="access_password"
            rules={{ required: "Access password is required" }}
            render={({ field }) => (
              <FormItem>
                <FormLabel>Access Code</FormLabel>
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
            disabled={form.formState.isSubmitting || signUpMutation.isPending}
          >
            {signUpMutation.isPending ? "Loading..." : "Sign Up"}
          </Button>

          <div className="flex w-full justify-center gap-2">
            Already have an account? <Link to="/login">Log In</Link>
          </div>
        </form>
      </Form>
    </div>
  );
}

export default SignUp;
