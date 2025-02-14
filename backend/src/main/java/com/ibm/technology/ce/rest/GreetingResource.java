package com.ibm.technology.ce.rest;

import org.eclipse.microprofile.openapi.annotations.Operation;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

/**
 * This is an unsecure demo endpoint.
 */
@Path("/hello")
public class GreetingResource {

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    @Operation(summary = "Greets anybody friendly", description = "An unprotected hello endpoint.")
    public String hello() {
        return "Hello from Quarkus REST";
    }
}
