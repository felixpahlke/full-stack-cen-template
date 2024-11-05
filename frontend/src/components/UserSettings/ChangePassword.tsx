import { useMutation } from "@tanstack/react-query";
import { useForm, type SubmitHandler } from "react-hook-form";

import { UsersService, type ApiError, type UpdatePassword } from "../../client";
import { confirmPasswordRules, handleError, passwordRules } from "../../utils";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { toast } from "sonner";

interface UpdatePasswordForm extends UpdatePassword {
  confirm_password: string;
}

const ChangePassword = () => {
  const {
    register,
    handleSubmit,
    reset,
    getValues,
    formState: { errors, isSubmitting },
  } = useForm<UpdatePasswordForm>({
    mode: "onBlur",
    criteriaMode: "all",
  });

  const mutation = useMutation({
    mutationFn: (data: UpdatePassword) =>
      UsersService.updatePasswordMe({ requestBody: data }),
    onSuccess: () => {
      toast.success("Password updated successfully.");
      reset();
    },
    onError: (err: ApiError) => {
      handleError(err);
    },
  });

  const onSubmit: SubmitHandler<UpdatePasswordForm> = async (data) => {
    mutation.mutate(data);
  };

  return (
    <Card className="max-w-md">
      <CardHeader>
        <CardTitle>Change Password</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <div>
            <Input
              label="Current Password"
              id="current_password"
              {...register("current_password", {
                required: "Current password is required",
              })}
              type="password"
            />
            {errors.current_password && (
              <p className="text-sm text-cds-text-error">
                {errors.current_password.message}
              </p>
            )}
          </div>
          <div>
            <Input
              label="New Password"
              id="new_password"
              {...register("new_password", passwordRules())}
              type="password"
            />
            {errors.new_password && (
              <p className="text-sm text-cds-text-error">
                {errors.new_password.message}
              </p>
            )}
          </div>
          <div>
            <Input
              label="Confirm Password"
              id="confirm_password"
              {...register("confirm_password", confirmPasswordRules(getValues))}
              type="password"
            />
            {errors.confirm_password && (
              <p className="text-sm text-cds-text-error">
                {errors.confirm_password.message}
              </p>
            )}
          </div>
          <Button type="submit" disabled={isSubmitting}>
            {isSubmitting ? "Saving..." : "Save"}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
};

export default ChangePassword;
