import {
  Header as CarbonHeader,
  HeaderContainer,
  HeaderGlobalBar,
  HeaderMenuButton,
  HeaderMenuItem,
  HeaderName,
  HeaderNavigation,
  HeaderSideNavItems,
  SideNav,
  SideNavItems,
  SkipToContent,
} from "@carbon/react";
import { useQueryClient } from "@tanstack/react-query";
import { Link } from "@tanstack/react-router";
import type { UserPublic } from "../../client";
import useAuth from "../../hooks/useAuth";
import UserMenu from "./UserMenu";
import ThemeSwitcher from "./ThemeSwitcher";

export function Header() {
  const { logout } = useAuth();
  const queryClient = useQueryClient();
  const currentUser = queryClient.getQueryData<UserPublic>(["currentUser"]);

  const handleLogout = () => {
    logout();
  };

  const navItems: {
    title: string;
    path: string;
  }[] = [
    { title: "Items", path: "/items" },
    { title: "Scanner", path: "/scanner" },
  ];

  if (currentUser?.is_superuser) {
    navItems.push(
      { title: "Dashboard", path: "/admin/dashboard" },
      { title: "All Tickets", path: "/admin/tickets" },
      { title: "Upload Tickets", path: "/admin/tickets/upload" },
    );
  }

  return (
    <HeaderContainer
      render={({ isSideNavExpanded, onClickSideNavExpand }: any) => (
        <>
          <CarbonHeader aria-label="IBM Client Engineering">
            <SkipToContent />
            <HeaderMenuButton
              aria-label={isSideNavExpanded ? "Close menu" : "Open menu"}
              onClick={onClickSideNavExpand}
              isActive={isSideNavExpanded}
              aria-expanded={isSideNavExpanded}
            />

            <HeaderName href="/">Client Engineering</HeaderName>
            <HeaderNavigation
              aria-label="IBM Client Engineering"
              className="hidden lg:flex"
            >
              {navItems.map((item) => (
                <HeaderMenuItem as={Link} key={item.title} to={item.path}>
                  {item.title}
                </HeaderMenuItem>
              ))}
            </HeaderNavigation>
            <HeaderGlobalBar>
              <ThemeSwitcher />
              <UserMenu />
            </HeaderGlobalBar>
            <SideNav
              aria-label="Side navigation"
              expanded={isSideNavExpanded}
              isPersistent={false}
              onSideNavBlur={onClickSideNavExpand}
            >
              <SideNavItems>
                <HeaderSideNavItems>
                  {navItems.map((item) => (
                    <HeaderMenuItem key={item.title} href={item.path}>
                      {item.title}
                    </HeaderMenuItem>
                  ))}
                  <HeaderMenuItem href="/settings">
                    User Settings
                  </HeaderMenuItem>
                  <HeaderMenuItem>
                    <button onClick={handleLogout} className="text-red-500">
                      Logout
                    </button>
                  </HeaderMenuItem>
                </HeaderSideNavItems>
              </SideNavItems>
            </SideNav>
          </CarbonHeader>
        </>
      )}
    />
  );
}
