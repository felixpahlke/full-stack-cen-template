import { useQuery } from "@tanstack/react-query";

const useAuth = () => {
  const { data: user, isLoading } = useQuery({
    queryKey: ["currentUser"],
    queryFn: async () => {
      try {
        const res = await fetch("/oauth2/userinfo");

        // Check if the response is JSON
        const contentType = res.headers.get("content-type");
        if (!contentType || !contentType.includes("application/json")) {
          throw new Error("Not authenticated - received HTML instead of JSON");
        }

        const data = await res.json();

        if (!res.ok || !data) {
          throw new Error(`Failed to fetch user info: ${res.statusText}`);
        }

        return data;
      } catch (err) {
        console.error(err);
        throw err;
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
  };
};

export default useAuth;
