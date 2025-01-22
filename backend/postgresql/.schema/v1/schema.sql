-- name: create-extension
-- Create the pgcrypto extension for usage of gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- name: create-items-table
-- Create the items table
CREATE TABLE IF NOT EXISTS items
(
	id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	title          VARCHAR(255) NOT NULL,
	description    VARCHAR(255),
	owner_id       UUID NOT NULL
);

-- Add ON CONFLICT clause for 'title' and 'description column
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_title_description ON items (title, description);