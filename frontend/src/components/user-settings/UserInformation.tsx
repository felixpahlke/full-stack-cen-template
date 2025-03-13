import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { useForm } from "react-hook-form";

import { type ApiError, type UserUpdateMe, UsersService } from "../../client";
import useAuth from "../../hooks/useAuth";
import { handleError, emailPattern } from "../../utils";
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
  full_name: string;
  email: string;
}

const UserInformation = () => {
  const queryClient = useQueryClient();
  const [editMode, setEditMode] = useState(false);
  const { user: currentUser } = useAuth();

  const form = useForm<FormValues>({
    defaultValues: {
      full_name: currentUser?.full_name || "",
      email: currentUser?.email || "",
    },
    mode: "onBlur",
  });

  const toggleEditMode = () => {
    setEditMode(!editMode);
    if (!editMode) {
      form.reset({
        full_name: currentUser?.full_name || "",
        email: currentUser?.email || "",
      });
    }
  };

  const { mutate: updateUser, isPending } = useMutation({
    mutationFn: (data: UserUpdateMe) =>
      UsersService.updateUserMe({ requestBody: data }),
    onSuccess: () => {
      toast.success("User updated successfully.");
      toggleEditMode();
    },
    onError: (err: ApiError) => {
      handleError(err);
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ["currentUser"] });
    },
  });

  const onSubmit = (data: FormValues) => {
    updateUser(data);
  };

  const onCancel = () => {
    form.reset();
    toggleEditMode();
  };

  return (
    <Card className="max-w-md">
      <CardContent className="pt-6">
        <h3 className="mb-4 text-lg font-medium">User Information</h3>
        <Form {...form}>
          {editMode ? (
            <form
              onSubmit={form.handleSubmit(onSubmit)}
              className="space-y-6 py-4"
            >
              <FormField
                control={form.control}
                name="full_name"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Full name</FormLabel>
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
                    <FormLabel>Email</FormLabel>
                    <FormControl>
                      <Input type="email" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <div className="flex space-x-2">
                <Button
                  type="submit"
                  disabled={
                    isPending ||
                    !form.formState.isValid ||
                    !form.formState.isDirty
                  }
                >
                  {isPending ? "Saving..." : "Save"}
                </Button>
                <Button
                  variant="outline"
                  onClick={onCancel}
                  disabled={isPending}
                  type="button"
                >
                  Cancel
                </Button>
              </div>
            </form>
          ) : (
            <div className="space-y-6 py-4">
              <div className="space-y-1">
                <FormLabel>Full name</FormLabel>
                <p
                  className={`py-2 ${!currentUser?.full_name ? "text-muted-foreground" : ""}`}
                >
                  {currentUser?.full_name || "N/A"}
                </p>
              </div>
              <div className="space-y-1">
                <FormLabel>Email</FormLabel>
                <p className="py-2">{currentUser?.email}</p>
              </div>
              <div>
                <Button
                  variant="outline"
                  onClick={toggleEditMode}
                  type="button"
                >
                  Edit
                </Button>
              </div>
            </div>
          )}
        </Form>
      </CardContent>
    </Card>
  );
};

export default UserInformation;
