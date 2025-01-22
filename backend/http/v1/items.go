package v1

import (
	"context"
	"errors"
	"github.com/jackc/pgerrcode"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	app_context "github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/ctx"
	"github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/postgresql"
)

func (a ApiHandler) ReadItems(ctx context.Context, request ReadItemsRequestObject) (ReadItemsResponseObject, error) {
	user, err := app_context.GetUserFromContext(ctx)
	if err != nil {
		return nil, err
	}

	offset, limit := 0, 100

	if request.Params.Skip != nil {
		offset = *request.Params.Skip
	}
	if request.Params.Limit != nil {
		limit = *request.Params.Limit
	}

	items, err := a.querier.GetAllItems(ctx, a.db, postgresql.GetAllItemsParams{
		Offst: int32(offset),
		Lim:   int32(limit),
	})
	if err != nil {
		return nil, err
	}

	res := make([]Item, len(items))
	for i, item := range items {
		res[i] = Item{
			Id:          item.ID,
			Title:       item.Title,
			Description: item.Description,
			OwnerId:     user.Id,
		}
	}

	return ReadItems200JSONResponse{
		Count: len(items),
		Data:  res,
	}, nil
}

func (a ApiHandler) CreateItem(ctx context.Context, request CreateItemRequestObject) (CreateItemResponseObject, error) {
	user, err := app_context.GetUserFromContext(ctx)
	if err != nil {
		return nil, err
	}

	item, err := a.querier.CreateItem(ctx, a.db, postgresql.CreateItemParams{
		Title:       request.Body.Title,
		Description: request.Body.Description,
		OwnerID:     user.Id,
	})
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) {
			if pgErr.Code == pgerrcode.UniqueViolation {
				return CreateItem409ApplicationProblemPlusJSONResponse{}, ErrItemAlreadyExists
			}
		}
		return nil, err
	}

	return CreateItem200JSONResponse{
		Id:          item.ID,
		Title:       item.Title,
		Description: item.Description,
		OwnerId:     item.OwnerID,
	}, nil
}

func (a ApiHandler) DeleteItem(ctx context.Context, request DeleteItemRequestObject) (DeleteItemResponseObject, error) {
	err := a.querier.DeleteItem(ctx, a.db, request.Id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return DeleteItem404ApplicationProblemPlusJSONResponse{}, ErrItemNotFound
		}
		return nil, err
	}

	return DeleteItem204Response{}, nil

}

func (a ApiHandler) ReadItem(ctx context.Context, request ReadItemRequestObject) (ReadItemResponseObject, error) {
	item, err := a.querier.FindItem(ctx, a.db, request.Id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ReadItem404ApplicationProblemPlusJSONResponse{}, ErrItemNotFound
		}
		return nil, err
	}

	return ReadItem200JSONResponse{
		Id:          item.ID,
		Title:       item.Title,
		Description: item.Description,
		OwnerId:     item.OwnerID,
	}, nil
}

func (a ApiHandler) UpdateItem(ctx context.Context, request UpdateItemRequestObject) (UpdateItemResponseObject, error) {
	user, err := app_context.GetUserFromContext(ctx)
	if err != nil {
		return nil, err
	}

	item, err := a.querier.UpdateItem(ctx, a.db, postgresql.UpdateItemParams{
		ID:          request.Id,
		Title:       request.Body.Title,
		Description: request.Body.Description,
		OwnerID:     user.Id,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return UpdateItem404ApplicationProblemPlusJSONResponse{}, ErrItemNotFound
		}
		return nil, err
	}

	return UpdateItem200JSONResponse{
		Id:          item.ID,
		Title:       item.Title,
		Description: item.Description,
		OwnerId:     item.OwnerID,
	}, nil
}
