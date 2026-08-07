import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";

import UsersTable from "@/components/admin/UsersTable";
import AddUser from "../../components/admin/AddUser";
import ActionsBar from "../../components/common/ActionsBar";

const usersSearchSchema = z.object({
  page: z.number().catch(1),
});

export const Route = createFileRoute("/_layout/admin")({
  component: Admin,
  validateSearch: (search) => usersSearchSchema.parse(search),
});

export function Admin() {
  return (
    <div className="w-full">
      <h1 className="sm:text-left py-12 text-center text-2xl font-bold">Users Management</h1>

      <ActionsBar type={"User"} addModalAs={AddUser} />
      <UsersTable />
    </div>
  );
}
