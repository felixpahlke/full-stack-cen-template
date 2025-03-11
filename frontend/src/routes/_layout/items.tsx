import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";

import ItemsTable from "../../components/items/items-table";
import ActionBar from "../../components/common/actions-bar";
import AddItem from "../../components/items/add-item";

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
      <h1 className="py-2 text-center text-2xl font-bold md:text-left">
        Items Management
      </h1>

      <ActionBar type={"Item"} addModalAs={AddItem} />
      <ItemsTable />
    </div>
  );
}
