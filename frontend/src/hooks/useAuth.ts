import { useQuery } from "@tanstack/react-query";
import { Users } from "@/client";

const useAuth = () => {
  const {
    data: user,
    isLoading,
    error,
  } = useQuery({
    queryKey: ["currentUser"],
    queryFn: async () => {
      const res = await Users.readUserMe();
      return res.data;
    },
    retry: false,
  });

  const logout = () => {
    window.location.assign("/oauth2/sign_out?rd=" + encodeURIComponent("/oauth2/sign_in"));
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
