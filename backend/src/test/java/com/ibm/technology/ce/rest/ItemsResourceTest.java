package com.ibm.technology.ce.rest;

import static io.restassured.RestAssured.*;
import static org.hamcrest.CoreMatchers.*;

import org.jboss.resteasy.reactive.RestResponse.StatusCode;
import org.junit.jupiter.api.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ibm.technology.ce.model.Item;

import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import io.restassured.http.ContentType;

@QuarkusTest
class ItemsResourceTest {

        private final Logger logger = LoggerFactory.getLogger(ItemsResourceTest.class);

        @Test
        @TestSecurity(user = "writer", roles = { "reader", "writer" })
        void testItemCreateReadListAndDelete() {

                final Item testItem = getValidItem();

                final Long createdItemId = given()
                                .contentType(ContentType.JSON)
                                .body(testItem)
                                .when().post("/items")
                                .then()
                                .statusCode(StatusCode.CREATED)
                                .extract().body().as(Item.class).getId();

                logger.info("Created test item with id: " + createdItemId);

                given()
                                .when()
                                .get("/items/" + createdItemId)
                                .then()
                                .statusCode(StatusCode.OK)
                                .body("id", equalTo(createdItemId.intValue()))
                                .and().body("title", equalTo(testItem.title))
                                .and().body("description", equalTo(testItem.description))
                                .and().body("ownerUsername", equalTo("writer"));

                given()
                                .when()
                                .get("/items")
                                .then()
                                .statusCode(StatusCode.OK);

                given()
                                .when()
                                .delete("/items/" + createdItemId)
                                .then()
                                .statusCode(StatusCode.ACCEPTED);
        }

        @Test
        @TestSecurity(user = "reader", roles = { "reader" })
        void testListAll() {

                given()
                                .when()
                                .get("/items")
                                .then()
                                .statusCode(StatusCode.OK);
        }

        @Test
        @TestSecurity(user = "writer", roles = { "writer" })
        void testDeleteNonExisting() {
                given()
                                .when()
                                .delete("/items/1234")
                                .then()
                                .statusCode(StatusCode.NOT_FOUND);
        }

        @Test
        @TestSecurity(user = "writer", roles = { "writer" })
        void testCreateAlreadyExisting() {
                final Item testItem = getValidItem();

                final Long createdItemId = given()
                                .contentType(ContentType.JSON)
                                .body(testItem)
                                .when().post("/items")
                                .then()
                                .statusCode(StatusCode.CREATED)
                                .extract().body().as(Item.class).getId();

                logger.info("Created test item with id: " + createdItemId);

                testItem.setId(createdItemId);
                given()
                                .contentType(ContentType.JSON)
                                .body(testItem)
                                .when()
                                .post("/items")
                                .then()
                                .statusCode(StatusCode.CONFLICT);

                testItem.setId(createdItemId + 1);
                given()
                                .contentType(ContentType.JSON)
                                .body(testItem)
                                .when()
                                .post("/items")
                                .then()
                                .statusCode(StatusCode.CONFLICT);

        }

        private Item getValidItem() {
                var item = new Item();
                item.title = "Test title";
                item.description = "Test description";
                return item;
        }
}