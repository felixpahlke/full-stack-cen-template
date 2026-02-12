import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm, type SubmitHandler } from "react-hook-form";
import type { AxiosError } from "axios";

import { type ItemCreate, Items } from "../../client";
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
    mutationFn: (data: ItemCreate) => Items.createItem({ body: data }),
    onSuccess: () => {
      toast.success("Item created successfully.");
      form.reset();
      onClose();
    },
    onError: (err: AxiosError) => {
      handleError(err);
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ["items"] });
    },
  });

  const onSubmit: SubmitHandler<ItemCreate> = (data) => {
    createItem(data);
  };

  return (
    <Modal
      open={isOpen}
      onRequestClose={onClose}
      modalHeading="Add Item"
      primaryButtonText={isPending ? "Saving..." : "Save"}
      secondaryButtonText="Cancel"
      onRequestSubmit={form.handleSubmit(onSubmit)}
      primaryButtonDisabled={isPending || !isValid}
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
