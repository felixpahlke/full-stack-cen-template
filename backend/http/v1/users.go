package v1

import (
	"context"
	"errors"
	app_context "github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/ctx"
)

var ErrUserNotFound = errors.New("user not found")

func (a ApiHandler) UserMe(ctx context.Context, request UserMeRequestObject) (UserMeResponseObject, error) {
	user, err := app_context.GetUserFromContext(ctx)
	if err != nil {
		return nil, ErrUserNotFound
	}

	return UserMe200JSONResponse{
		Email: user.Email,
		Id:    user.Id,
		Name:  user.Name,
	}, nil
}
