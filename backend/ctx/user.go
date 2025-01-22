package ctx

import (
	"context"
	"fmt"
	"github.com/google/uuid"
)

type userContext struct{}

type User struct {
	ID    uuid.UUID
	Email string
}

func CreateUserContext(ctx context.Context, user User) context.Context {
	return context.WithValue(ctx, userContext{}, user)
}

func GetUserFromContext(ctx context.Context) (User, error) {
	if u, ok := ctx.Value(userContext{}).(User); ok {
		return u, nil
	}
	return User{}, fmt.Errorf("missing user context")
}
