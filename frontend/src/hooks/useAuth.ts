import { useQuery } from "@tanstack/react-query";
import { UsersService } from "@/client";

const useAuth = () => {
  const { data: user, isLoading } = useQuery({
    queryKey: ["currentUser"],
    queryFn: UsersService.readUserMe,
  });

  const logout = () => {
    window.location.href = "/oauth2/sign_out";
  };

  return {
    logout,
    user,
    isLoading,
  };
};

export default useAuth;
