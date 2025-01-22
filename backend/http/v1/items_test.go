package v1

import (
	"context"
	"fmt"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/wait"
	app_context "github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/ctx"
	"github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/postgresql"
	"log"
	"os"
	"testing"
	"time"
)

var pgxPool *pgxpool.Pool

func init() {
	os.Setenv("TESTCONTAINERS_RYUK_DISABLED", "true")
}

func TestMain(m *testing.M) {
	ctx := context.Background()

	user, password, database := "postgres", "postgres", "testdb"

	req := testcontainers.ContainerRequest{
		Image:        "postgres:15",
		ExposedPorts: []string{"5432/tcp"},
		Env: map[string]string{
			"POSTGRES_USER":     user,
			"POSTGRES_PASSWORD": password,
			"POSTGRES_DB":       database,
		},
		WaitingFor: wait.ForExposedPort().WithStartupTimeout(30 * time.Second),
	}

	genericContainer, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
		ContainerRequest: req,
		Started:          true,
		Logger:           log.New(os.Stdout, "", log.LstdFlags),
	})
	if err != nil {
		log.Fatalf("failed to start genericContainer: %v", err)
	}

	host, err := genericContainer.Host(ctx)
	if err != nil {
		log.Fatalf("failed to get genericContainer host: %v", err)
	}
	port, err := genericContainer.MappedPort(ctx, "5432")
	if err != nil {
		log.Fatalf("failed to get genericContainer port: %v", err)
	}

	pgxPool = postgresql.NewPgxPool(fmt.Sprintf("postgres://%s:%s@%s:%s/%s", user, password, host, port.Port(), database),
		database)

	if err := postgresql.MigrateSchema(pgxPool); err != nil {
		log.Fatalf("failed to migrate schema: %v", err)
	}

	defer pgxPool.Close()

	code := m.Run()

	log.Println("Terminating test container...")
	if err := genericContainer.Terminate(ctx); err != nil {
		log.Fatalf("failed to terminate container: %v", err)
	}

	os.Exit(code)
}

func TestApiHandler_ReadItems(t *testing.T) {
	apiHandler := NewAPIHandler(pgxPool)

	request := ReadItemsRequestObject{
		Params: ReadItemsParams{
			Skip:  nil,
			Limit: nil,
		},
	}

	mockUser := app_context.User{ID: uuid.New(), Email: "test@test.com"}
	mockContext := app_context.CreateUserContext(context.Background(), mockUser)

	mockItems := []postgresql.Item{
		{Title: "Read item 1", Description: ptr("Read item test 1"), OwnerID: mockUser.ID},
		{Title: "Read item 2", Description: ptr("Read item test 2"), OwnerID: mockUser.ID},
	}

	for i, mockItem := range mockItems {
		item, err := postgresql.New().CreateItem(context.Background(), pgxPool, postgresql.CreateItemParams{
			Title:       mockItem.Title,
			Description: mockItem.Description,
			OwnerID:     mockItem.OwnerID,
		})

		if err != nil {
			t.Error("failed to create item")
			return
		}

		mockItems[i].ID = item.ID
	}

	response, err := apiHandler.ReadItems(mockContext, request)

	assert.NoError(t, err)
	assert.Len(t, response.(ReadItems200JSONResponse).Data, 2)
	for i, item := range response.(ReadItems200JSONResponse).Data {
		assert.Equal(t, mockItems[i].ID, item.Id)
		assert.Equal(t, mockItems[i].Title, item.Title)
		assert.Equal(t, mockItems[i].Description, item.Description)
		assert.Equal(t, mockItems[i].OwnerID, item.OwnerId)
	}
}

func TestApiHandler_CreateItem(t *testing.T) {
	apiHandler := NewAPIHandler(pgxPool)

	mockUser := app_context.User{ID: uuid.New(), Email: "test@test.com"}
	mockContext := app_context.CreateUserContext(context.Background(), mockUser)

	request := CreateItemRequestObject{
		Body: &CreateItemJSONRequestBody{
			Title:       "Create Item test",
			Description: ptr("Description"),
		},
	}

	response, err := apiHandler.CreateItem(mockContext, request)

	assert.NoError(t, err)
	assert.NotNil(t, response.(CreateItem200JSONResponse).Id)
	assert.Equal(t, request.Body.Title, response.(CreateItem200JSONResponse).Title)
	assert.Equal(t, request.Body.Description, response.(CreateItem200JSONResponse).Description)
	assert.NotNil(t, response.(CreateItem200JSONResponse).OwnerId)

}

func TestApiHandler_DeleteItem(t *testing.T) {
	apiHandler := NewAPIHandler(pgxPool)

	mockUser := app_context.User{ID: uuid.New(), Email: "test@test.com"}
	mockContext := app_context.CreateUserContext(context.Background(), mockUser)

	mockItem := postgresql.Item{
		Title: "Delete item 1", Description: ptr("Delete item test 1"), OwnerID: mockUser.ID,
	}

	item, err := postgresql.New().CreateItem(context.Background(), pgxPool, postgresql.CreateItemParams{
		Title:       mockItem.Title,
		Description: mockItem.Description,
		OwnerID:     mockItem.OwnerID,
	})

	if err != nil {
		t.Error("failed to create item")
		return
	}

	request := DeleteItemRequestObject{Id: item.ID}

	response, err := apiHandler.DeleteItem(mockContext, request)

	assert.NoError(t, err)
	assert.NotNil(t, response)

	_, err = postgresql.New().FindItem(context.Background(), pgxPool, mockItem.ID)
	assert.ErrorIs(t, err, pgx.ErrNoRows)
}

func TestApiHandler_ReadItem(t *testing.T) {
	apiHandler := NewAPIHandler(pgxPool)

	mockUser := app_context.User{ID: uuid.New(), Email: "test@test.com"}
	mockContext := app_context.CreateUserContext(context.Background(), mockUser)

	mockItem := postgresql.Item{
		Title:       "Read Item test",
		Description: ptr("Read Item test"),
		OwnerID:     mockUser.ID,
	}

	item, err := postgresql.New().CreateItem(context.Background(), pgxPool, postgresql.CreateItemParams{
		Title:       mockItem.Title,
		Description: mockItem.Description,
		OwnerID:     mockItem.OwnerID,
	})

	if err != nil {
		t.Error("failed to create item")
		return
	}

	request := ReadItemRequestObject{Id: item.ID}

	response, err := apiHandler.ReadItem(mockContext, request)

	assert.NoError(t, err)
	assert.Equal(t, item.ID, response.(ReadItem200JSONResponse).Id)
	assert.Equal(t, mockItem.Title, response.(ReadItem200JSONResponse).Title)
	assert.Equal(t, mockItem.Description, response.(ReadItem200JSONResponse).Description)
	assert.Equal(t, mockItem.OwnerID, response.(ReadItem200JSONResponse).OwnerId)
}

func TestApiHandler_UpdateItem(t *testing.T) {
	apiHandler := NewAPIHandler(pgxPool)

	mockUser := app_context.User{ID: uuid.New(), Email: "test@test.com"}
	mockContext := app_context.CreateUserContext(context.Background(), mockUser)

	mockItem := postgresql.Item{
		Title:       "Update Item test",
		Description: ptr("Update Item test"),
		OwnerID:     mockUser.ID,
	}

	item, err := postgresql.New().CreateItem(context.Background(), pgxPool, postgresql.CreateItemParams{
		Title:       mockItem.Title,
		Description: mockItem.Description,
		OwnerID:     mockItem.OwnerID,
	})

	if err != nil {
		t.Error("failed to create item")
		return
	}

	request := UpdateItemRequestObject{
		Id: item.ID,
		Body: &UpdateItemJSONRequestBody{
			Title:       "Updated Item",
			Description: ptr("Updated Description"),
		},
	}

	response, err := apiHandler.UpdateItem(mockContext, request)

	assert.NoError(t, err)
	assert.Equal(t, item.ID, response.(UpdateItem200JSONResponse).Id)
	assert.Equal(t, request.Body.Title, response.(UpdateItem200JSONResponse).Title)
	assert.Equal(t, request.Body.Description, response.(UpdateItem200JSONResponse).Description)
	assert.Equal(t, mockItem.OwnerID, response.(UpdateItem200JSONResponse).OwnerId)
}

func ptr(s string) *string { return &s }
