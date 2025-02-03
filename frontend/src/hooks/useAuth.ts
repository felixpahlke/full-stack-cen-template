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
    window.location.href = "/oauth2/sign_out";
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
