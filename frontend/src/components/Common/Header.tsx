import UserMenu from "./UserMenu";
import useAuth from "../../hooks/useAuth";
import { useQueryClient } from "@tanstack/react-query";
import type { UserPublic } from "../../client";
import {
  Header as CarbonHeader,
  HeaderName,
  HeaderGlobalBar,
  HeaderNavigation,
  HeaderMenuItem,
  HeaderContainer,
  HeaderMenuButton,
  SkipToContent,
  SideNav,
  SideNavItems,
  HeaderSideNavItems,
} from "@carbon/react";
import { Link } from "@tanstack/react-router";

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
    search?: { page: number };
  }[] = [{ title: "Items", path: "/items", search: { page: 1 } }];

  if (currentUser?.is_superuser) {
    navItems.push({ title: "Admin", path: "/admin" });
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
                <HeaderMenuItem
                  as={Link}
                  key={item.title}
                  to={item.path}
                  search={item.search}
                >
                  {item.title}
                </HeaderMenuItem>
              ))}
            </HeaderNavigation>
            <HeaderGlobalBar>
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
