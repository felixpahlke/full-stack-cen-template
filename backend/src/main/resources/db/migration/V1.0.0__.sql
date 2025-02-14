
    create sequence Item_SEQ start with 1 increment by 50;

    create table Item (
        id bigint not null,
        description varchar(255),
        ownerUsername varchar(255),
        title varchar(255),
        primary key (id)
    );
