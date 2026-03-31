import { useQuery } from "@tanstack/react-query";
import type { User } from "@/client";
import { Users } from "@/client";

const useAuth = () => {
  const {
    data: user,
    isLoading,
    error,
  } = useQuery<User | null, Error>({
    queryKey: ["currentUser"],
    queryFn: async () => {
      const response = await Users.readUserMe();
      return response.data ?? null;
    },
    retry: false,
  });

  const logout = () => {
    window.location.assign(
      "/oauth2/sign_out?rd=" + encodeURIComponent("/oauth2/sign_in"),
    );
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
