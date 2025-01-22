package ctx

import (
	"context"
	"fmt"
	"github.com/google/uuid"
)

const userContextKey = "user.context"

type User struct {
	Id    uuid.UUID
	Email string
}

func CreateUserContext(ctx context.Context, user User) context.Context {
	return context.WithValue(ctx, userContextKey, user)
}

func GetUserFromContext(ctx context.Context) (User, error) {
	if u, ok := ctx.Value(userContextKey).(User); ok {
		return u, nil
	}
	return User{}, fmt.Errorf("missing user context")
}
