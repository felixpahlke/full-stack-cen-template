import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";

import UsersTable from "../../components/admin/users-table";
import AddUser from "../../components/admin/add-user";
import ActionsBar from "../../components/common/actions-bar";

const usersSearchSchema = z.object({
  page: z.number().catch(1),
});

export const Route = createFileRoute("/_layout/admin")({
  component: Admin,
  validateSearch: (search) => usersSearchSchema.parse(search),
});

function Admin() {
  return (
    <div className="w-full">
      <h1 className="py-2 text-center text-2xl font-bold md:text-left">
        Users Management
      </h1>

      <ActionsBar type={"User"} addModalAs={AddUser} />
      <UsersTable />
    </div>
  );
}
