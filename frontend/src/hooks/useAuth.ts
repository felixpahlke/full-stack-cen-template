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
    retry: false,
  });

  const logout = () => {
    window.location.href =
      "/oauth2/sign_out?rd=" + encodeURIComponent("/oauth2/sign_in");
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
