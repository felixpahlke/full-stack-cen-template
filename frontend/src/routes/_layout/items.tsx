import { useQuery, useQueryClient } from "@tanstack/react-query";
import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";
import { z } from "zod";

import { ItemsService } from "../../client";
import ActionsMenu from "../../components/Common/ActionsMenu";
import ActionBar from "../../components/Common/ActionsBar";
import AddItem from "../../components/Items/AddItem";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";

const itemsSearchSchema = z.object({
  page: z.number().catch(1),
});

export const Route = createFileRoute("/_layout/items")({
  component: Items,
  validateSearch: (search) => itemsSearchSchema.parse(search),
});

const PER_PAGE = 5;

function getItemsQueryOptions({ page }: { page: number }) {
  return {
    queryFn: () => ItemsService.readItems({ skip: (page - 1) * PER_PAGE, limit: PER_PAGE }),
    queryKey: ["items", { page }],
  };
}

function ItemsTable() {
  const queryClient = useQueryClient();
  const { page } = Route.useSearch();
  const navigate = useNavigate({ from: Route.fullPath });
  const setPage = (page: number) => navigate({ search: (prev) => ({ ...prev, page }) });

  const {
    data: items,
    isPending,
    isPlaceholderData,
  } = useQuery({
    ...getItemsQueryOptions({ page }),
    placeholderData: (prevData) => prevData,
  });

  const hasNextPage = !isPlaceholderData && items?.data.length === PER_PAGE;
  const hasPreviousPage = page > 1;

  useEffect(() => {
    if (hasNextPage) {
      queryClient.prefetchQuery(getItemsQueryOptions({ page: page + 1 }));
    }
  }, [page, queryClient, hasNextPage]);

  return (
    <>
      <div className="border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>ID</TableHead>
              <TableHead>Title</TableHead>
              <TableHead>Description</TableHead>
              <TableHead>Actions</TableHead>
            </TableRow>
          </TableHeader>
          {isPending ? (
            <TableBody>
              <TableRow>
                {new Array(4).fill(null).map((_, index) => (
                  <TableCell key={index}>
                    <Skeleton className="h-4 w-full" />
                  </TableCell>
                ))}
              </TableRow>
            </TableBody>
          ) : (
            <TableBody>
              {items?.data.map((item) => (
                <TableRow key={item.id} className={isPlaceholderData ? "opacity-50" : ""}>
                  <TableCell>{item.id}</TableCell>
                  <TableCell className="max-w-[150px] truncate">{item.title}</TableCell>
                  <TableCell
                    className={`max-w-[150px] truncate ${!item.description ? "text-muted-foreground" : ""}`}
                  >
                    {item.description || "N/A"}
                  </TableCell>
                  <TableCell>
                    <ActionsMenu type={"Item"} value={item} />
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          )}
        </Table>
      </div>
      <div className="mt-4 flex items-center justify-end gap-4">
        <Button onClick={() => setPage(page - 1)} disabled={!hasPreviousPage}>
          Previous
        </Button>
        <span>Page {page}</span>
        <Button disabled={!hasNextPage} onClick={() => setPage(page + 1)}>
          Next
        </Button>
      </div>
    </>
  );
}

function Items() {
  return (
    <div className="w-full">
      <h1 className="py-12 text-center text-2xl font-bold md:text-left">Items Management</h1>

      <ActionBar type={"Item"} addModalAs={AddItem} />
      <ItemsTable />
    </div>
  );
}
