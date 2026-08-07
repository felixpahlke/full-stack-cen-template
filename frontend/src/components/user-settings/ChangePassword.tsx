import { useMutation } from "@tanstack/react-query";
import type { AxiosError } from "axios";
import { useForm } from "react-hook-form";
import { toast } from "sonner";
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
import { type UpdatePassword, Users } from "../../client";
import { confirmPasswordRules, handleError, passwordRules } from "../../utils";

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
    mode: "onChange",
  });

  const { mutate: updatePassword, isPending } = useMutation({
    mutationFn: (data: UpdatePassword) => Users.updatePasswordMe({ body: data }),
    onSuccess: () => {
      toast.success("Password updated successfully.");
      form.reset();
    },
    onError: (err: AxiosError) => {
      handleError(err);
    },
  });

  const onSubmit = (data: FormValues) => {
    const updateData: UpdatePassword = {
      current_password: data.current_password,
      new_password: data.new_password,
    };
    updatePassword(updateData);
  };

  return (
    <Card className="max-w-md">
      <CardContent className="pt-6">
        <h3 className="mb-4 text-lg font-medium">Change Password</h3>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex flex-col gap-6 py-4">
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
              <Button type="submit" disabled={isPending || !form.formState.isValid}>
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
