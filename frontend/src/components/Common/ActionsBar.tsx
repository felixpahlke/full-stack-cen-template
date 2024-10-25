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
        {/* TODO: Complete search functionality */}
        {/* <div className="relative w-full md:w-auto">
          <input
            type="text"
            placeholder="Search"
            className="pl-10 pr-4 py-2 text-sm md:text-base rounded-lg border border-input bg-background"
          />
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground" size={16} />
        </div> */}
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
