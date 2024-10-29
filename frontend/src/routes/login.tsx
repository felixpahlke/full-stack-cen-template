import { createFileRoute, redirect } from "@tanstack/react-router";
import { type SubmitHandler, useForm } from "react-hook-form";

import type { Body_login_login_access_token as AccessToken } from "../client";
import useAuth, { isLoggedIn } from "../hooks/useAuth";
import { emailPattern } from "../utils";
import {
  Form,
  FormField,
  FormControl,
  FormItem,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useState } from "react";
import { BsEye, BsEyeSlash } from "react-icons/bs";
import { Logo } from "@/components/Common/Logo";
import { Link } from "@/components/ui/link";
import { Label } from "@/components/ui/label";

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

function Login() {
  const [show, setShow] = useState(false);
  const { loginMutation, error, resetError } = useAuth();
  const form = useForm({
    mode: "onBlur",
    criteriaMode: "all",
    defaultValues: {
      username: "",
      password: "",
    },
  });

  // console.log(form.formState.isSubmitting);

  const onSubmit: SubmitHandler<AccessToken> = async (data) => {
    // if (form.formState.isSubmitting) return;

    resetError();

    try {
      await loginMutation.mutateAsync(data);
    } catch {
      // error is handled by useAuth hook
    }
  };

  return (
    <div className="mx-auto flex min-h-[100dvh] max-w-sm flex-col justify-center p-4">
      <Form {...form}>
        <form
          onSubmit={form.handleSubmit(onSubmit)}
          className="flex flex-col space-y-4"
        >
          <Logo className="mb-3 w-full" />
          <FormField
            control={form.control}
            name="username"
            rules={{
              required: "Username is required",
              pattern: emailPattern,
            }}
            render={({ field, fieldState }) => (
              <FormItem>
                <FormControl>
                  <Input
                    {...field}
                    label="Email"
                    placeholder="Email"
                    className={fieldState.error ? "border-cds-text-error" : ""}
                    tabIndex={1}
                  />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
          <FormField
            control={form.control}
            name="password"
            rules={{
              required: "Password is required",
            }}
            render={({ field, fieldState }) => (
              <FormItem className="relative">
                <FormControl>
                  <>
                    <div className="flex justify-between">
                      <Label className="text-xs text-cds-text-secondary">
                        Password
                      </Label>
                      <Link
                        to="/recover-password"
                        className="text-xs"
                        tabIndex={6}
                      >
                        Forgot password?
                      </Link>
                    </div>
                    <Input
                      {...field}
                      type={show ? "text" : "password"}
                      placeholder="Password"
                      className={
                        fieldState.error ? "border-cds-text-error" : ""
                      }
                      tabIndex={2}
                    />
                    <Button
                      variant={"ghost"}
                      size={"icon"}
                      type="button"
                      className="absolute right-0 top-6 !m-0 h-10 w-10 hover:bg-transparent"
                      onClick={() => setShow(!show)}
                      tabIndex={3}
                    >
                      {show ? <BsEyeSlash /> : <BsEye />}
                    </Button>
                  </>
                </FormControl>
                <FormMessage />
                {error && !fieldState.error && (
                  <FormMessage>{error}</FormMessage>
                )}
              </FormItem>
            )}
          />
          <Button type="submit" tabIndex={4}>
            {form.formState.isSubmitting ? "loading..." : "Log In"}
          </Button>
          <div className="flex w-full justify-center gap-2">
            Don't have an account?{" "}
            <Link tabIndex={5} to="/signup">
              Sign up
            </Link>
          </div>{" "}
        </form>
      </Form>
    </div>
  );
}
