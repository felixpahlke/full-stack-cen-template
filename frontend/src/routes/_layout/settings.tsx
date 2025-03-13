import { useQueryClient } from "@tanstack/react-query";
import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";

import type { UserPublic } from "../../client";
import Appearance from "@/components/user-settings/Appearance";
import ChangePassword from "@/components/user-settings/ChangePassword";
import DeleteAccount from "@/components/user-settings/DeleteAccount";
import UserInformation from "@/components/user-settings/UserInformation";

import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

const tabsConfig = [
  { id: "profile", title: "My profile", component: UserInformation },
  { id: "password", title: "Password", component: ChangePassword },
  { id: "appearance", title: "Appearance", component: Appearance },
  { id: "danger", title: "Danger zone", component: DeleteAccount },
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
  const [activeTab, setActiveTab] = useState(finalTabs[0].id);

  return (
    <div className="min-w-96">
      <h1 className="py-2 text-2xl font-bold">User Settings</h1>
      <Tabs
        className="mt-6"
        defaultValue={activeTab}
        onValueChange={setActiveTab}
      >
        <TabsList className="mb-4">
          {finalTabs.map((tab) => (
            <TabsTrigger key={tab.id} value={tab.id}>
              {tab.title}
            </TabsTrigger>
          ))}
        </TabsList>
        {finalTabs.map((tab) => (
          <TabsContent key={tab.id} value={tab.id}>
            <tab.component />
          </TabsContent>
        ))}
      </Tabs>
    </div>
  );
}
