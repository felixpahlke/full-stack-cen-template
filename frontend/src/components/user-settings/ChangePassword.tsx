import { useMutation } from "@tanstack/react-query";
import { useForm } from "react-hook-form";

import { type ApiError, type UpdatePassword, UsersService } from "../../client";
import { handleError, passwordRules, confirmPasswordRules } from "../../utils";

import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { toast } from "sonner";

interface FormValues {
  current_password: string;
  new_password: string;
  confirm_password: string;
}

const ChangePassword = () => {
  const form = useForm<FormValues>({
    defaultValues: {
      current_password: "",
      new_password: "",
      confirm_password: "",
    },
    mode: "onBlur",
  });

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

  const onSubmit = (data: FormValues) => {
    // Remove confirm_password as it's not needed in the API
    const { confirm_password, ...updateData } = data;
    updatePassword(updateData);
  };

  return (
    <Card className="max-w-md">
      <CardContent className="pt-6">
        <h3 className="mb-4 text-lg font-medium">Change Password</h3>
        <Form {...form}>
          <form
            onSubmit={form.handleSubmit(onSubmit)}
            className="space-y-6 py-4"
          >
            <FormField
              control={form.control}
              name="current_password"
              rules={{ required: "Current password is required" }}
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Current Password</FormLabel>
                  <FormControl>
                    <Input type="password" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="new_password"
              rules={passwordRules()}
              render={({ field }) => (
                <FormItem>
                  <FormLabel>New Password</FormLabel>
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

            <div>
              <Button
                type="submit"
                disabled={isPending || !form.formState.isValid}
              >
                {isPending ? "Saving..." : "Save"}
              </Button>
            </div>
          </form>
        </Form>
      </CardContent>
    </Card>
  );
};

export default ChangePassword;
