import { useQueryClient } from "@tanstack/react-query";
import { createFileRoute } from "@tanstack/react-router";

import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import type { UserPublic } from "../../client";
import Appearance from "../../components/UserSettings/Appearance";
import ChangePassword from "../../components/UserSettings/ChangePassword";
import DeleteAccount from "../../components/UserSettings/DeleteAccount";
import UserInformation from "../../components/UserSettings/UserInformation";

const tabsConfig = [
  { title: "My profile", component: UserInformation },
  { title: "Password", component: ChangePassword },
  { title: "Appearance", component: Appearance },
  { title: "Danger zone", component: DeleteAccount },
];

export const Route = createFileRoute("/_layout/settings")({
  component: UserSettings,
});

function UserSettings() {
  const queryClient = useQueryClient();
  const currentUser = queryClient.getQueryData<UserPublic>(["currentUser"]);
  const finalTabs = currentUser?.is_superuser
    ? tabsConfig.slice(0, 3)
    : tabsConfig;

  return (
    <div className="container">
      <h1 className="py-12 text-2xl font-bold">User Settings</h1>
      <Tabs defaultValue={finalTabs[0].title.toLowerCase().replace(" ", "-")}>
        <TabsList className="w-full max-w-md">
          {finalTabs.map((tab, index) => (
            <TabsTrigger
              key={index}
              value={tab.title.toLowerCase().replace(" ", "-")}
              className="w-full"
            >
              {tab.title}
            </TabsTrigger>
          ))}
        </TabsList>
        {finalTabs.map((tab, index) => (
          <TabsContent
            key={index}
            value={tab.title.toLowerCase().replace(" ", "-")}
          >
            <tab.component />
          </TabsContent>
        ))}
      </Tabs>
    </div>
  );
}
