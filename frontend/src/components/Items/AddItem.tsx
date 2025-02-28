import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { useRef } from "react";

import { type ApiError, type ItemCreate, ItemsService } from "../../client";
import { handleError } from "../../utils";

import { Modal, TextInput } from "@carbon/react";
import { toast } from "@/components/Common/Toaster";

interface AddItemProps {
  isOpen: boolean;
  onClose: () => void;
}

const AddItem = ({ isOpen, onClose }: AddItemProps) => {
  const queryClient = useQueryClient();
  const form = useForm<ItemCreate>({
    defaultValues: {
      title: "",
      description: "",
    },
    mode: "onChange",
  });

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
      onRequestSubmit={onSubmit}
      primaryButtonDisabled={isPending}
      launcherButtonRef={buttonRef}
    >
      <div className="space-y-6 py-4">
        <TextInput
          id="title"
          labelText="Title"
          placeholder="Title"
          value={form.watch("title")}
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

export default AddItem;
