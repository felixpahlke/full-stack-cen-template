import type { ComponentType, ElementType } from "react";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Plus } from "lucide-react";

interface NavbarProps {
  type: string;
  addModalAs: ComponentType | ElementType;
}

const ActionBar = ({ type, addModalAs }: NavbarProps) => {
  const [isModalOpen, setIsModalOpen] = useState(false);

  const AddModal = addModalAs;
  return (
    <>
      <div className="flex gap-4 py-8">
        <Button
          variant="default"
          className="gap-1 text-sm md:text-base"
          onClick={() => setIsModalOpen(true)}
        >
          <Plus className="h-4 w-4" /> Add {type}
        </Button>
        <AddModal isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} />
      </div>
    </>
  );
};

export default ActionBar;
