-- name: CreateItem :one
INSERT INTO items (title, description, owner_id)
VALUES (@title, @description, @owner_id)
RETURNING *;

-- name: DeleteItem :exec
DELETE FROM items WHERE id = @id;

-- name: UpdateItem :one
UPDATE items
SET title = @title, description = @description, owner_id = @owner_id
WHERE id = @id
RETURNING *;