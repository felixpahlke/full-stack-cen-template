import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";

import { type ApiError, type ItemCreate, ItemsService } from "../../client";
import { handleError } from "../../utils";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
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

interface AddItemProps {
  isOpen: boolean;
  onClose: () => void;
}

const formSchema = z.object({
  title: z.string().min(1, "Title is required"),
  description: z.string().optional(),
});

const AddItem = ({ isOpen, onClose }: AddItemProps) => {
  const queryClient = useQueryClient();
  const form = useForm<z.infer<typeof formSchema>>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      title: "",
      description: "",
    },
    mode: "onBlur",
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

  const onSubmit = (data: z.infer<typeof formSchema>) => {
    createItem(data);
  };

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Add Item</DialogTitle>
        </DialogHeader>

        <Form {...form}>
          <form
            onSubmit={form.handleSubmit(onSubmit)}
            className="space-y-6 py-4"
          >
            <FormField
              control={form.control}
              name="title"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Title</FormLabel>
                  <FormControl>
                    <Input {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="description"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Description</FormLabel>
                  <FormControl>
                    <Input {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <DialogFooter>
              <Button variant="outline" onClick={onClose} type="button">
                Cancel
              </Button>
              <Button
                type="submit"
                disabled={isPending || !form.formState.isValid}
              >
                {isPending ? "Saving..." : "Save"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
};

export default AddItem;
