import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";
import AddUser from "@/components/admin/AddUser";
import UsersTable from "@/components/admin/UsersTable";
import ActionsBar from "@/components/common/ActionsBar";

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
      <h1 className="py-2 text-center text-2xl font-bold md:text-left">Users Management</h1>

      <ActionsBar type={"User"} addModalAs={AddUser} />
      <UsersTable />
    </div>
  );
}
