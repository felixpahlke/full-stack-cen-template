package com.ibm.technology.ce.rest;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.List;
import java.util.Objects;

import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.jboss.resteasy.reactive.RestResponse.StatusCode;
import org.jboss.resteasy.reactive.server.ServerExceptionMapper;

import com.ibm.technology.ce.model.Item;
import com.ibm.technology.ce.repositories.ItemRepository;

import io.quarkus.hibernate.orm.panache.PanacheRepository;
import io.quarkus.security.Authenticated;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.persistence.EntityExistsException;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.core.Response;

/**
 * For help, check here:
 * 
 * https://quarkus.io/guides/openapi-swaggerui
 * https://quarkus.io/guides/security-keycloak-authorization
 */
@Authenticated
@Path("/items")
public class ItemsResource {

    private final PanacheRepository<Item> itemRepository;

    @Inject
    public ItemsResource(ItemRepository itemRepository) {
        this.itemRepository = itemRepository;
    }

    @ServerExceptionMapper
    public Response entityExistsExceptionMapper(EntityExistsException ex) {
        return Response.serverError().status(StatusCode.CONFLICT).entity("EntityExistsException: " + ex.getMessage())
                .build();
    }

    @GET
    @Operation(summary = "List all owned items", description = "Query all items the authenticated user owns.")
    @APIResponses(value = {
            @APIResponse(responseCode = "200", description = "Found items")
    })
    @RolesAllowed("reader")
    public List<Item> list() {
        return itemRepository.findAll().list();
    }

    @GET
    @Operation(summary = "Query an item by id", description = "Query one registered item with its id.")
    @APIResponses(value = {
            @APIResponse(responseCode = "200", description = "Found sample entry"),
            @APIResponse(responseCode = "404", description = "Entry not found")
    })
    @Path("{id}")
    @RolesAllowed("reader")
    public Item getItem(@PathParam("id") Long id) {
        return itemRepository.findById(id);
    }

    @POST
    @Transactional
    @Operation(summary = "Create an item", description = "Create an item.")
    @APIResponses(value = {
            @APIResponse(responseCode = "201", description = "Created item, returns also the URI to the new resource."),
            @APIResponse(responseCode = "409", description = "Item with id already exists, has not been updated."),
    })
    @RolesAllowed("writer")
    public Response add(Item item) throws URISyntaxException {

        if (Objects.nonNull(item.getId())) {
            var dbItem = itemRepository.findById(item.getId());

            if (Objects.nonNull(dbItem)) {
                throw new EntityExistsException("Item with id " + item.getId() + " already exists.");
            }
        }

        itemRepository.persist(item);
        return Response.created(new URI("/items/" + item.getId())).entity(item).build();
    }

    @DELETE
    @Transactional
    @Path("{id}")
    @Operation(summary = "Delete an item", description = "Delete an item.")
    @APIResponses(value = {
            @APIResponse(responseCode = "202", description = "Deleted item."),
            @APIResponse(responseCode = "404", description = "Item could not be found and was not deleted."),
    })
    @RolesAllowed("writer")
    public Response delete(@PathParam("id") Long id) {
        var item = itemRepository.findById(id);

        if (Objects.isNull(item)) {
            throw new NotFoundException("Item with id " + String.valueOf(id) + " not found.");
        }

        itemRepository.delete(item);
        return Response.accepted().build();
    }
}