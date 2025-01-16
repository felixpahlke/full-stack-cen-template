import { useQuery } from "@tanstack/react-query";
import { useState } from "react";

const useAuth = () => {
  const [error, setError] = useState<string | null>(null);

  const { data: user, isLoading } = useQuery({
    queryKey: ["currentUser"],
    queryFn: async () => {
      try {
        return await fetch("/oauth2/userinfo").then((res) => res.json());
      } catch (err) {
        console.error(err);
      }
    },
  });

  const logout = () => {
    window.location.href = "/oauth2/sign_out";
  };

  return {
    logout,
    user,
    isLoading,
    error,
    resetError: () => setError(null),
  };
};

export default useAuth;
