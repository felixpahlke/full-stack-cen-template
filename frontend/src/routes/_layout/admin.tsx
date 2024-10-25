import { useQuery, useQueryClient } from "@tanstack/react-query";
import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";
import { z } from "zod";

import { type UserPublic, UsersService } from "../../client";
import AddUser from "../../components/Admin/AddUser";
import ActionsMenu from "../../components/Common/ActionsMenu";
import ActionsBar from "../../components/Common/ActionsBar";
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
import { Badge } from "@/components/ui/badge";

const usersSearchSchema = z.object({
  page: z.number().catch(1),
});

export const Route = createFileRoute("/_layout/admin")({
  component: Admin,
  validateSearch: (search) => usersSearchSchema.parse(search),
});

const PER_PAGE = 5;

function getUsersQueryOptions({ page }: { page: number }) {
  return {
    queryFn: () => UsersService.readUsers({ skip: (page - 1) * PER_PAGE, limit: PER_PAGE }),
    queryKey: ["users", { page }],
  };
}

function UsersTable() {
  const queryClient = useQueryClient();
  const currentUser = queryClient.getQueryData<UserPublic>(["currentUser"]);
  const { page } = Route.useSearch();
  const navigate = useNavigate({ from: Route.fullPath });
  const setPage = (page: number) => navigate({ search: (prev: any) => ({ ...prev, page }) });

  const {
    data: users,
    isPending,
    isPlaceholderData,
  } = useQuery({
    ...getUsersQueryOptions({ page }),
    placeholderData: (prevData) => prevData,
  });

  const hasNextPage = !isPlaceholderData && users?.data.length === PER_PAGE;
  const hasPreviousPage = page > 1;

  useEffect(() => {
    if (hasNextPage) {
      queryClient.prefetchQuery(getUsersQueryOptions({ page: page + 1 }));
    }
  }, [page, queryClient, hasNextPage]);

  return (
    <>
      <div className="border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="w-[20%]">Full name</TableHead>
              <TableHead className="w-[50%]">Email</TableHead>
              <TableHead className="w-[10%]">Role</TableHead>
              <TableHead className="w-[10%]">Status</TableHead>
              <TableHead className="w-[10%]">Actions</TableHead>
            </TableRow>
          </TableHeader>
          {isPending ? (
            <TableBody>
              <TableRow>
                {new Array(5).fill(null).map((_, index) => (
                  <TableCell key={index}>
                    <Skeleton className="h-4 w-full" />
                  </TableCell>
                ))}
              </TableRow>
            </TableBody>
          ) : (
            <TableBody>
              {users?.data.map((user) => (
                <TableRow key={user.id}>
                  <TableCell className="max-w-[150px] truncate">
                    <span className={!user.full_name ? "text-muted-foreground" : ""}>
                      {user.full_name || "N/A"}
                    </span>
                    {currentUser?.id === user.id && (
                      <Badge variant="outline" className="ml-2">
                        You
                      </Badge>
                    )}
                  </TableCell>
                  <TableCell className="max-w-[150px] truncate">{user.email}</TableCell>
                  <TableCell>{user.is_superuser ? "Superuser" : "User"}</TableCell>
                  <TableCell>
                    <div className="flex items-center gap-2">
                      <div
                        className={`h-2 w-2 rounded-full ${
                          user.is_active ? "bg-green-500" : "bg-red-500"
                        }`}
                      />
                      {user.is_active ? "Active" : "Inactive"}
                    </div>
                  </TableCell>
                  <TableCell>
                    <ActionsMenu type="User" value={user} disabled={currentUser?.id === user.id} />
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

function Admin() {
  return (
    <div className="w-full">
      <h1 className="py-12 text-center text-2xl font-bold md:text-left">Users Management</h1>

      <ActionsBar type={"User"} addModalAs={AddUser} />
      <UsersTable />
    </div>
  );
}
