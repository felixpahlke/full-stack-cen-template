-- name: GetAllItems :many
SELECT *
FROM items LIMIT @lim OFFSET @offst;

-- name: FindItem :one
SELECT *
FROM items WHERE id = @id;