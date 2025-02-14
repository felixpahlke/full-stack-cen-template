package com.ibm.technology.ce.model;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;

/**
 * Look here for help: https://quarkus.io/guides/hibernate-orm-panache
 */
@Entity
public class Item {

    @Id
    @GeneratedValue
    private Long id;

    public String title;
    public String description;

    public String ownerUsername;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

}
