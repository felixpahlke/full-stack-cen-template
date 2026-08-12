import { useQuery } from "@tanstack/react-query";
import type { AxiosError } from "axios";
import { useCallback, useEffect } from "react";
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

  const logout = useCallback(() => {
    window.location.assign(`/oauth2/sign_out?rd=${encodeURIComponent("/oauth2/sign_in")}`);
  }, []);

  const authenticationFailed = (error as AxiosError | null)?.response?.status === 401;

  useEffect(() => {
    if (authenticationFailed) logout();
  }, [authenticationFailed, logout]);

  return {
    error: authenticationFailed ? null : error,
    logout,
    user,
    isLoading: isLoading || authenticationFailed,
  };
};

export default useAuth;
