import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { useRef } from "react";

import {
  type ApiError,
  type ItemPublic,
  type ItemUpdate,
  ItemsService,
} from "../../client";
import { handleError } from "../../utils";

import { Modal, TextInput } from "@carbon/react";
import { toast } from "@/components/Common/Toaster";

interface EditItemProps {
  item: ItemPublic;
  isOpen: boolean;
  onClose: () => void;
}

const EditItem = ({ item, isOpen, onClose }: EditItemProps) => {
  const queryClient = useQueryClient();

  const form = useForm<ItemUpdate>({
    defaultValues: item,
  });

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

  const onSubmit = () => {
    const data = form.getValues();

    // Title validation
    if (!data.title || data.title.trim() === "") {
      form.setError("title", {
        type: "validate",
        message: "Title is required",
      });
      return;
    }

    updateItem(data);
  };

  const buttonRef = useRef(null);

  return (
    <Modal
      open={isOpen}
      onRequestClose={onClose}
      modalHeading="Edit Item"
      primaryButtonText={isPending ? "Saving..." : "Save"}
      secondaryButtonText="Cancel"
      onRequestSubmit={onSubmit}
      primaryButtonDisabled={isPending}
      launcherButtonRef={buttonRef}
    >
      <div className="space-y-6 py-4">
        <TextInput
          id="title"
          labelText="Title"
          placeholder="Title"
          value={form.watch("title") || ""}
          onChange={(e) => {
            form.setValue("title", e.target.value);
            form.clearErrors("title");
          }}
          invalid={!!form.formState.errors.title}
          invalidText={form.formState.errors.title?.message}
          required
        />

        <TextInput
          id="description"
          labelText="Description"
          placeholder="Description"
          value={form.watch("description") || ""}
          onChange={(e) => {
            form.setValue("description", e.target.value);
            form.clearErrors("description");
          }}
          invalid={!!form.formState.errors.description}
          invalidText={form.formState.errors.description?.message}
        />
      </div>
    </Modal>
  );
};

export default EditItem;
