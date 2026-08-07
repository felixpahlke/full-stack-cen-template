import {
  DataTable,
  Pagination,
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
import { useEffect, useState } from "react";

import { type UserPublic, Users } from "../../client";
import ActionsMenu from "../common/ActionsMenu";

const getUsersQueryOptions = (page: number, pageSize: number) => {
  return {
    queryFn: async () => {
      const response = await Users.readUsers({
        query: { skip: (page - 1) * pageSize, limit: pageSize },
      });
      return response.data!;
    },
    queryKey: ["users", { page }],
  };
};

export default function UsersTable() {
  const queryClient = useQueryClient();
  const currentUser = queryClient.getQueryData<UserPublic>(["currentUser"]);
  const [pageSize, setPageSize] = useState<number>(10);
  const { page } = useSearch({ from: "/_layout/admin" });
  const navigate = useNavigate({ from: "/admin" });
  const setPage = (newPage: number) => navigate({ search: () => ({ page: newPage }) });

  const {
    data: users,
    isPending,
    isPlaceholderData,
  } = useQuery({
    ...getUsersQueryOptions(page, pageSize),
    placeholderData: (prevData) => prevData,
  });

  useEffect(() => {
    const hasNextPage = !isPlaceholderData && users?.data.length === pageSize;
    if (hasNextPage) {
      queryClient.prefetchQuery(getUsersQueryOptions(page + 1, pageSize));
    }
  }, [page, pageSize, queryClient, users, isPlaceholderData]);

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
          <span className={!user.full_name ? "text-gray-500" : ""}>{user.full_name || "N/A"}</span>
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
            className={`h-2 w-2 rounded-full ${user.is_active ? "bg-green-500" : "bg-red-500"}`}
          />
          {user.is_active ? "Active" : "Inactive"}
        </div>
      ),
      actions: <ActionsMenu type="User" value={user} disabled={currentUser?.id === user.id} />,
    })) || [];

  return (
    <>
      <DataTable rows={rows} headers={headers}>
        {({ rows, headers, getHeaderProps, getTableProps }) => (
          <Table {...getTableProps()}>
            <TableHead>
              <TableRow>
                {headers.map((header) => (
                  <TableHeader {...getHeaderProps({ header, isSortable: false })} key={header.key}>
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
      <Pagination
        pageSizes={[10, 25, 50, 100]}
        page={page}
        pageSize={pageSize}
        onChange={(data) => {
          setPage(data.page);
          setPageSize(data.pageSize);
        }}
        totalItems={users?.count}
      />
    </>
  );
}
