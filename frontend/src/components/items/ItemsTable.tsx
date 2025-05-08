import {
  DataTable,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  Button,
} from "@carbon/react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useNavigate, useSearch } from "@tanstack/react-router";
import { useEffect } from "react";

import { ItemsService } from "../../client";
import ActionsMenu from "../common/ActionsMenu";

const PER_PAGE = 10;

function getItemsQueryOptions({ page }: { page: number }) {
  return {
    queryFn: () =>
      ItemsService.readItems({ skip: (page - 1) * PER_PAGE, limit: PER_PAGE }),
    queryKey: ["items", { page }],
  };
}

export default function ItemsTable() {
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const { page } = useSearch({ from: "/_layout/items" });
  const setPage = (page: number) =>
    navigate({ search: (prev: any) => ({ ...prev, page }) });

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

  const headers = [
    { header: "ID", key: "id" },
    { header: "Title", key: "title" },
    { header: "Description", key: "description" },
    { header: "Actions", key: "actions" },
  ];

  const rows =
    items?.data.map((item) => ({
      id: item.id,
      title: <div className="max-w-[150px] truncate">{item.title}</div>,
      description: (
        <div
          className={`max-w-[150px] truncate ${!item.description ? "text-gray-500" : ""}`}
        >
          {item.description || "N/A"}
        </div>
      ),
      actions: <ActionsMenu type="Item" value={item} />,
    })) || [];

  return (
    <>
      <DataTable rows={rows} headers={headers}>
        {({ rows, headers, getHeaderProps, getTableProps }) => (
          <Table {...getTableProps()}>
            <TableHead>
              <TableRow>
                {headers.map((header) => (
                  <TableHeader
                    {...getHeaderProps({ header, isSortable: false })}
                    key={header.key}
                  >
                    {header.header}
                  </TableHeader>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {isPending ? (
                <TableRow>
                  {headers.map((_, i) => (
                    <TableCell key={i}>
                      <div className="h-4 w-full animate-pulse bg-gray-200" />
                    </TableCell>
                  ))}
                </TableRow>
              ) : (
                rows.map((row) => (
                  <TableRow key={row.id}>
                    {row.cells.map((cell, i) => (
                      <TableCell key={i}>{cell.value}</TableCell>
                    ))}
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        )}
      </DataTable>
      <div className="mt-4 flex items-center justify-end gap-4">
        <Button
          kind="secondary"
          onClick={() => setPage(page - 1)}
          disabled={!hasPreviousPage}
        >
          Previous
        </Button>
        <span>Page {page}</span>
        <Button
          kind="primary"
          disabled={!hasNextPage}
          onClick={() => setPage(page + 1)}
        >
          Next
        </Button>
      </div>
    </>
  );
}
