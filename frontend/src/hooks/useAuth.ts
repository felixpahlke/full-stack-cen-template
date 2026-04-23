import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "@tanstack/react-router";
import { useState } from "react";

import { AxiosError } from "axios";
import { toast } from "@/components/common/Toaster";
import {
  type BodyLoginLoginAccessToken as AccessToken,
  type UserPublic,
  type UserRegister,
  Login,
  Users,
} from "../client";

const isLoggedIn = () => {
  return localStorage.getItem("access_token") !== null;
};

const useAuth = () => {
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { data: user, isLoading } = useQuery<UserPublic | null, Error>({
    queryKey: ["currentUser"],
    queryFn: async () => {
      try {
        const response = await Users.readUserMe();
        return response.data ?? null;
      } catch (err) {
        if (err instanceof AxiosError) {
          const status = err.response?.status;
          if (status === 404 || status === 403) {
            localStorage.removeItem("access_token");
            navigate({ to: "/login" });
            return null;
          }
        }
        throw err; // Re-throw other error
      }
    },
    enabled: isLoggedIn(),
  });

  const signUpMutation = useMutation({
    mutationFn: async (data: UserRegister) => {
      const response = await Users.registerUser({ body: data });
      return response.data;
    },
    onSuccess: () => {
      navigate({ to: "/login" });
      toast.success("Your account has been created successfully.");
    },
    onError: (err: AxiosError) => {
      let errDetail = "Something went wrong.";
      const responseData = err.response?.data as any;
      if (responseData?.detail) {
        if (Array.isArray(responseData.detail)) {
          errDetail = responseData.detail.map((e: any) => e.msg).join(", ");
        } else if (typeof responseData.detail === "string") {
          errDetail = responseData.detail;
        }
      } else {
        errDetail = err.message;
      }

      toast.error("Registration failed", {
        caption: errDetail,
      });
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ["users"] });
    },
  });

  const loginMutation = useMutation({
    mutationFn: async (data: AccessToken) => {
      const response = await Login.loginAccessToken({ body: data });
      if (response.data?.access_token) {
        localStorage.setItem("access_token", response.data.access_token);
      }
      return response.data;
    },
    onSuccess: () => {
      navigate({ to: "/" });
    },
    onError: (err: AxiosError) => {
      let errDetail = "Invalid credentials";
      const responseData = err.response?.data as any;
      if (responseData?.detail && typeof responseData.detail === "string") {
        errDetail = responseData.detail;
      } else {
        errDetail = err.message;
      }

      setError(errDetail);
    },
  });

  const logout = () => {
    localStorage.removeItem("access_token");
    navigate({ to: "/login" });
  };

  return {
    signUpMutation,
    loginMutation,
    logout,
    user,
    isLoading,
    error,
    resetError: () => setError(null),
  };
};

export { isLoggedIn };
export default useAuth;
