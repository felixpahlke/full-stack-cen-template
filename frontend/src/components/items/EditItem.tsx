import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm, type SubmitHandler } from "react-hook-form";

import {
  type ApiError,
  type ItemPublic,
  type ItemUpdate,
  ItemsService,
} from "../../client";
import { handleError } from "../../utils";

import { Form, Modal, Stack, TextInput } from "@carbon/react";
import { toast } from "@/components/common/Toaster";

interface EditItemProps {
  item: ItemPublic;
  isOpen: boolean;
  onClose: () => void;
}

const EditItem = ({ item, isOpen, onClose }: EditItemProps) => {
  const queryClient = useQueryClient();

  const form = useForm<ItemUpdate>({
    mode: "onBlur",
    criteriaMode: "all",
    defaultValues: {
      title: item.title,
      description: item.description,
    },
  });

  const { errors, isValid } = form.formState;

  const { mutate: updateItem, isPending } = useMutation({
    mutationFn: (data: ItemUpdate) =>
      ItemsService.updateItem({ id: item.id, requestBody: data }),
    onSuccess: () => {
      toast.success("Item updated successfully.");
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

  const onSubmit: SubmitHandler<ItemUpdate> = (data) => {
    updateItem(data);
  };

  return (
    <Modal
      open={isOpen}
      onRequestClose={onClose}
      modalHeading="Edit Item"
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

export default EditItem;
