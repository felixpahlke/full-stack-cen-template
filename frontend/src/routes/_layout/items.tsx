import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";

import ItemsTable from "@/components/items/ItemsTable";
import ActionBar from "../../components/common/ActionsBar";
import AddItem from "../../components/items/AddItem";

const itemsSearchSchema = z.object({
  page: z.number().catch(1),
});

export const Route = createFileRoute("/_layout/items")({
  component: Items,
  validateSearch: (search) => itemsSearchSchema.parse(search),
});

function Items() {
  return (
    <div className="w-full">
      <h1 className="md:text-left py-12 text-center text-2xl font-bold">
        Items Management
      </h1>

      <ActionBar type={"Item"} addModalAs={AddItem} />
      <ItemsTable />
    </div>
  );
}
