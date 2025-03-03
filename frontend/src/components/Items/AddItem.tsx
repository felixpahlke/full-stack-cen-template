import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm, type SubmitHandler } from "react-hook-form";
import { useRef } from "react";

import { type ApiError, type ItemCreate, ItemsService } from "../../client";
import { handleError } from "../../utils";

import { Form, Modal, Stack, TextInput } from "@carbon/react";
import { toast } from "@/components/common/Toaster";

interface AddItemProps {
  isOpen: boolean;
  onClose: () => void;
}

const AddItem = ({ isOpen, onClose }: AddItemProps) => {
  const queryClient = useQueryClient();
  const form = useForm<ItemCreate>({
    mode: "onBlur",
    criteriaMode: "all",
    defaultValues: {
      title: "",
      description: "",
    },
  });

  const { errors, isValid } = form.formState;

  const { mutate: createItem, isPending } = useMutation({
    mutationFn: (data: ItemCreate) =>
      ItemsService.createItem({ requestBody: data }),
    onSuccess: () => {
      toast.success("Item created successfully.");
      form.reset();
      onClose();
    },
    onError: (err: ApiError) => {
      handleError(err);
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ["items"] });
    },
  });

  const onSubmit: SubmitHandler<ItemCreate> = (data) => {
    createItem(data);
  };

  const buttonRef = useRef(null);

  return (
    <Modal
      open={isOpen}
      onRequestClose={onClose}
      modalHeading="Add Item"
      primaryButtonText={isPending ? "Saving..." : "Save"}
      secondaryButtonText="Cancel"
      onRequestSubmit={form.handleSubmit(onSubmit)}
      primaryButtonDisabled={isPending || !isValid}
      launcherButtonRef={buttonRef}
    >
      <Form className="py-4">
        <Stack gap={5}>
          <TextInput
            id="title"
            labelText="Title"
            placeholder="Title"
            invalid={!!errors.title}
            invalidText={errors.title?.message}
            {...form.register("title", {
              required: "Title is required",
            })}
          />

          <TextInput
            id="description"
            labelText="Description"
            placeholder="Description"
            invalid={!!errors.description}
            invalidText={errors.description?.message}
            {...form.register("description")}
          />
        </Stack>
      </Form>
    </Modal>
  );
};

export default AddItem;
