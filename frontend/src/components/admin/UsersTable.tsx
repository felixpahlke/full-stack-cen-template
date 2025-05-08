import {
  Button,
  DataTable,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  Tag,
} from "@carbon/react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useNavigate, useSearch } from "@tanstack/react-router";
import { useEffect } from "react";

import { type UserPublic, UsersService } from "../../client";
import ActionsMenu from "../common/ActionsMenu";

const PER_PAGE = 10;

function getUsersQueryOptions({ page }: { page: number }) {
  return {
    queryFn: () =>
      UsersService.readUsers({ skip: (page - 1) * PER_PAGE, limit: PER_PAGE }),
    queryKey: ["users", { page }],
  };
}

export default function UsersTable() {
  const queryClient = useQueryClient();
  const currentUser = queryClient.getQueryData<UserPublic>(["currentUser"]);

  const { page } = useSearch({ from: "/_layout/admin" });
  const navigate = useNavigate();
  const setPage = (page: number) =>
    navigate({ search: (prev: any) => ({ ...prev, page }) });

  const {
    data: users,
    isPending,
    isPlaceholderData,
  } = useQuery({
    ...getUsersQueryOptions({ page }),
    placeholderData: (prevData) => prevData,
  });

  const totalPages = Math.ceil((users?.count ?? 0) / PER_PAGE);

  const hasNextPage = !isPlaceholderData && users?.data.length === PER_PAGE;
  const hasPreviousPage = page > 1;

  useEffect(() => {
    if (hasNextPage) {
      queryClient.prefetchQuery(getUsersQueryOptions({ page: page + 1 }));
    }
  }, [page, queryClient, hasNextPage]);

  const headers = [
    { header: "Full name", key: "full_name" },
    { header: "Email", key: "email" },
    { header: "Role", key: "role" },
    { header: "Status", key: "status" },
    { header: "Actions", key: "actions" },
  ];

  const rows =
    users?.data.map((user) => ({
      id: user.id,
      full_name: (
        <div className="flex items-center gap-2">
          <span className={!user.full_name ? "text-gray-500" : ""}>
            {user.full_name || "N/A"}
          </span>
          {currentUser?.id === user.id && (
            <Tag type="blue" size="sm">
              You
            </Tag>
          )}
        </div>
      ),
      email: user.email,
      role: user.is_superuser ? "Superuser" : "User",
      status: (
        <div className="flex items-center gap-2">
          <div
            className={`h-2 w-2 rounded-full ${
              user.is_active ? "bg-green-500" : "bg-red-500"
            }`}
          />
          {user.is_active ? "Active" : "Inactive"}
        </div>
      ),
      actions: (
        <ActionsMenu
          type="User"
          value={user}
          disabled={currentUser?.id === user.id}
        />
      ),
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
        <span>
          Page {page} of {totalPages}
        </span>
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
