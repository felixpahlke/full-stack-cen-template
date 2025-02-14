package com.ibm.technology.ce.rest;

import java.util.Set;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import io.quarkus.security.Authenticated;
import io.quarkus.security.identity.SecurityIdentity;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;

@Authenticated
@Path("/me")
public class AuthenticationCheckResource {

    private final static Logger logger = LoggerFactory.getLogger(AuthenticationCheckResource.class);

    @Inject
    SecurityIdentity identity;

    @GET
    public User me() {
        return new User(identity);
    }

    public static class User {

        private final String userName;
        private final Set<String> roles;

        User(SecurityIdentity identity) {
            logger.info("Currently logged in identiy: " + identity.getPrincipal().getName());
            logger.info("Currently logged in identiy roles: "
                    + String.join(",", identity.getRoles()));
            this.userName = identity.getPrincipal().getName();
            this.roles = identity.getRoles();
        }

        public String getUserName() {
            return userName;
        }

        public Set<String> getRoles() {
            return roles;
        }
    }
}