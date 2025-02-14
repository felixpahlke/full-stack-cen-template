package com.ibm.technology.ce.rest;

import static io.restassured.RestAssured.*;
import static org.hamcrest.CoreMatchers.*;

import org.junit.jupiter.api.Test;

import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;

@QuarkusTest
class AuthenticationCheckResourceTest {

    @Test
    void testUnauthorizedEndpoint() {
        given()
                .when().get("/me")
                .then()
                .statusCode(401);
    }

    @Test
    @TestSecurity(user = "reader", roles = "reader")
    void testAuthorizedEndpoint() {
        given()
                .when().get("/me")
                .then()
                .statusCode(200)
                .body("userName", equalTo("reader"))
                .and().body("roles", hasItem("reader"));
    }
}