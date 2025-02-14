package com.ibm.technology.ce.repositories;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ibm.technology.ce.model.Item;

import io.quarkus.hibernate.orm.panache.PanacheRepository;
import io.quarkus.security.identity.SecurityIdentity;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/**
 * Look here for help: https://quarkus.io/guides/hibernate-orm-panache
 */
@ApplicationScoped
public class ItemRepository implements PanacheRepository<Item> {

    private final Logger logger = LoggerFactory.getLogger(ItemRepository.class);

    @Inject
    SecurityIdentity identity;

    @Override
    public void persist(Item entity) {

        logger.debug("Persisting item with id: ", entity.getId());

        entity.ownerUsername = identity.getPrincipal().getName();
        PanacheRepository.super.persist(entity);
    }

}
