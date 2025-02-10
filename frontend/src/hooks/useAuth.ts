import { useQuery } from "@tanstack/react-query";
import { UsersService } from "@/client";

const useAuth = () => {
  const {
    data: user,
    isLoading,
    error,
  } = useQuery({
    queryKey: ["currentUser"],
    queryFn: UsersService.readUserMe,
  });

  const logout = () => {
    // oauth2/sign_in - the login page, which also doubles as a sign-out page (it clears cookies)
    window.location.href = "/oauth2/sign_in";
  };

  if (error) {
    logout();
  }

  return {
    logout,
    user,
    isLoading,
  };
};

export default useAuth;
