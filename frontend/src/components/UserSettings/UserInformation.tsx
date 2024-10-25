import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm, type SubmitHandler } from "react-hook-form";

import { type ApiError, type UserPublic, type UserUpdateMe, UsersService } from "../../client";
import useAuth from "../../hooks/useAuth";
import { emailPattern, handleError } from "../../utils";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { toast } from "sonner";

const UserInformation = () => {
  const queryClient = useQueryClient();
  const [editMode, setEditMode] = useState(false);
  const { user: currentUser } = useAuth();
  const {
    register,
    handleSubmit,
    reset,
    getValues,
    formState: { isSubmitting, errors, isDirty },
  } = useForm<UserPublic>({
    mode: "onBlur",
    criteriaMode: "all",
    defaultValues: {
      full_name: currentUser?.full_name,
      email: currentUser?.email,
    },
  });

  const toggleEditMode = () => {
    setEditMode(!editMode);
  };

  const mutation = useMutation({
    mutationFn: (data: UserUpdateMe) => UsersService.updateUserMe({ requestBody: data }),
    onSuccess: () => {
      toast.success("User updated successfully.");
    },
    onError: (err: ApiError) => {
      handleError(err);
    },
    onSettled: () => {
      queryClient.invalidateQueries();
    },
  });

  const onSubmit: SubmitHandler<UserUpdateMe> = async (data) => {
    mutation.mutate(data);
  };

  const onCancel = () => {
    reset();
    toggleEditMode();
  };

  return (
    <Card className="max-w-md">
      <CardHeader>
        <CardTitle>User Information</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <div>
            <Label htmlFor="name">Full name</Label>
            {editMode ? (
              <Input id="name" {...register("full_name", { maxLength: 30 })} type="text" />
            ) : (
              <p className={`py-2 ${!currentUser?.full_name ? "text-muted-foreground" : ""}`}>
                {currentUser?.full_name || "N/A"}
              </p>
            )}
          </div>
          <div>
            <Label htmlFor="email">Email</Label>
            {editMode ? (
              <Input
                id="email"
                {...register("email", {
                  required: "Email is required",
                  pattern: emailPattern,
                })}
                type="email"
              />
            ) : (
              <p className="py-2">{currentUser?.email}</p>
            )}
            {errors.email && <p className="text-destructive text-sm">{errors.email.message}</p>}
          </div>
          <div className="flex gap-3">
            <Button
              variant={editMode ? "default" : "outline"}
              onClick={toggleEditMode}
              type={editMode ? "button" : "submit"}
              disabled={editMode ? !isDirty || !getValues("email") : false}
            >
              {editMode ? "Save" : "Edit"}
            </Button>
            {editMode && (
              <Button variant="outline" onClick={onCancel} disabled={isSubmitting}>
                Cancel
              </Button>
            )}
          </div>
        </form>
      </CardContent>
    </Card>
  );
};

export default UserInformation;
