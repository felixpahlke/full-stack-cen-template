import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { useForm, type SubmitHandler } from "react-hook-form";

import { type ApiError, type UserUpdateMe, UsersService } from "../../client";
import useAuth from "../../hooks/useAuth";
import { emailPattern, handleError } from "../../utils";
import {
  Button,
  Form,
  Stack,
  TextInput,
  Tile,
  FormGroup,
  FormLabel,
} from "@carbon/react";
import { toast } from "@/components/common/Toaster";

interface UserUpdateForm extends UserUpdateMe {}

const UserInformation = () => {
  const queryClient = useQueryClient();
  const [editMode, setEditMode] = useState(false);
  const { user: currentUser } = useAuth();

  const form = useForm<UserUpdateForm>({
    mode: "onBlur",
    criteriaMode: "all",
    defaultValues: {
      full_name: currentUser?.full_name,
      email: currentUser?.email,
    },
  });

  const { errors, isValid, isDirty } = form.formState;

  const toggleEditMode = () => {
    setEditMode(!editMode);
    if (!editMode) {
      form.reset({
        full_name: currentUser?.full_name,
        email: currentUser?.email,
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

  const onSubmit: SubmitHandler<UserUpdateForm> = (data) => {
    updateUser(data);
  };

  const onCancel = () => {
    form.reset();
    toggleEditMode();
  };

  return (
    <Tile className="max-w-md">
      <h3 className="mb-4 text-xl font-medium">User Information</h3>
      {editMode ? (
        <Form className="py-4" onSubmit={form.handleSubmit(onSubmit)}>
          <Stack gap={5}>
            <TextInput
              id="full_name"
              labelText="Full name"
              placeholder="Full name"
              invalid={!!errors.full_name}
              invalidText={errors.full_name?.message}
              {...form.register("full_name")}
              maxLength={30}
            />

            <TextInput
              id="email"
              labelText="Email"
              placeholder="Email"
              type="email"
              invalid={!!errors.email}
              invalidText={errors.email?.message}
              {...form.register("email", {
                required: "Email is required",
                pattern: emailPattern,
              })}
            />

            <Stack orientation="horizontal" gap={3}>
              <Button
                type="submit"
                kind="primary"
                disabled={isPending || !isValid || !isDirty}
              >
                {isPending ? "Saving..." : "Save"}
              </Button>
              <Button kind="secondary" onClick={onCancel} disabled={isPending}>
                Cancel
              </Button>
            </Stack>
          </Stack>
        </Form>
      ) : (
        <Stack gap={5}>
          <FormGroup legendText="">
            <FormLabel className="mt-2">Full name</FormLabel>
            <p
              className={`py-2 ${!currentUser?.full_name ? "text-gray-500" : ""}`}
            >
              {currentUser?.full_name || "N/A"}
            </p>
          </FormGroup>
          <FormGroup legendText="">
            <FormLabel>Email</FormLabel>
            <p className="py-2">{currentUser?.email}</p>
          </FormGroup>
          <Stack>
            <Button kind="tertiary" onClick={toggleEditMode} type="button">
              Edit
            </Button>
          </Stack>
        </Stack>
      )}
    </Tile>
  );
};

export default UserInformation;
