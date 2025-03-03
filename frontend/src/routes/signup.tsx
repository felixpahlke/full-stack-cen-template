import { Button, Form, PasswordInput, Stack, TextInput } from "@carbon/react";
import { createFileRoute, Link, redirect } from "@tanstack/react-router";
import { type SubmitHandler, useForm } from "react-hook-form";

import { Logo } from "@/components/common/Logo";
import type { UserRegister } from "../client";
import useAuth, { isLoggedIn } from "../hooks/useAuth";
import { confirmPasswordRules, emailPattern, passwordRules } from "../utils";

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

interface UserRegisterForm extends UserRegister {
  confirm_password: string;
}

function SignUp() {
  const { signUpMutation } = useAuth();
  const form = useForm({
    mode: "onBlur",
    criteriaMode: "all",
    defaultValues: {
      email: "",
      full_name: "",
      password: "",
      confirm_password: "",
      access_password: "",
    },
  });

  const { errors, isValid } = form.formState;

  const onSubmit: SubmitHandler<UserRegisterForm> = (data) => {
    signUpMutation.mutate(data);
  };

  return (
    <div className="mx-auto flex min-h-[100dvh] max-w-sm flex-col justify-center p-4">
      <Form onSubmit={form.handleSubmit(onSubmit)}>
        <Stack gap={5}>
          <Logo className="mb-2 w-full" />
          <TextInput
            id="full_name"
            labelText="Full Name"
            placeholder="Full Name"
            invalid={!!errors.full_name}
            invalidText={errors.full_name?.message}
            {...form.register("full_name", {
              required: "Full Name is required",
              minLength: 3,
            })}
          />

          <TextInput
            id="email"
            labelText="Email"
            placeholder="Email"
            invalid={!!errors.email}
            invalidText={errors.email?.message}
            {...form.register("email", {
              required: "Email is required",
              pattern: emailPattern,
            })}
          />

          <PasswordInput
            id="password"
            labelText="Password"
            placeholder="Password"
            invalid={!!errors.password}
            invalidText={errors.password?.message}
            {...form.register("password", passwordRules())}
          />

          <PasswordInput
            id="confirm_password"
            labelText="Repeat Password"
            placeholder="Repeat Password"
            invalid={!!errors.confirm_password}
            invalidText={errors.confirm_password?.message}
            {...form.register(
              "confirm_password",
              confirmPasswordRules(form.getValues),
            )}
          />

          <PasswordInput
            id="access_password"
            labelText="Access Password"
            placeholder="Access Password"
            invalid={!!errors.access_password}
            invalidText={errors.access_password?.message}
            {...form.register("access_password", {
              required: "Access Password is required",
            })}
          />

          <Button type="submit" className="mt-4 w-full max-w-full">
            {signUpMutation.isPending ? "loading..." : "Sign Up"}
          </Button>

          <div className="mt-4 flex w-full justify-center gap-2">
            Already have an account? <Link to="/login">Log In</Link>
          </div>
        </Stack>
      </Form>
    </div>
  );
}

export default SignUp;
