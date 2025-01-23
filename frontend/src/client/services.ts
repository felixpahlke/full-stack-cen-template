import type { CancelablePromise } from "./core/CancelablePromise";
import { OpenAPI } from "./core/OpenAPI";
import { request as __request } from "./core/request";

import type {
  User,
  ItemCreate,
  ItemPublic,
  ItemsPublic,
  ItemUpdate,
  Message,
} from "./models";

export type UsersData = {};

export type ItemsData = {
  ReadItems: {
    limit?: number;
    skip?: number;
  };
  CreateItem: {
    requestBody: ItemCreate;
  };
  ReadItem: {
    id: string;
  };
  UpdateItem: {
    id: string;
    requestBody: ItemUpdate;
  };
  DeleteItem: {
    id: string;
  };
};

export class UsersService {
  /**
   * Read User Me
   * Get current user.
   * @returns User Successful Response
   * @throws ApiError
   */
  public static readUserMe(): CancelablePromise<User> {
    return __request(OpenAPI, {
      method: "GET",
      url: "/api/v1/users/me",
    });
  }
}

export class ItemsService {
  /**
   * Read Items
   * Retrieve items.
   * @returns ItemsPublic Successful Response
   * @throws ApiError
   */
  public static readItems(
    data: ItemsData["ReadItems"] = {},
  ): CancelablePromise<ItemsPublic> {
    const { skip = 0, limit = 100 } = data;
    return __request(OpenAPI, {
      method: "GET",
      url: "/api/v1/items/",
      query: {
        skip,
        limit,
      },
      errors: {
        422: `Validation Error`,
      },
    });
  }

  /**
   * Create Item
   * Create new item.
   * @returns ItemPublic Successful Response
   * @throws ApiError
   */
  public static createItem(
    data: ItemsData["CreateItem"],
  ): CancelablePromise<ItemPublic> {
    const { requestBody } = data;
    return __request(OpenAPI, {
      method: "POST",
      url: "/api/v1/items/",
      body: requestBody,
      mediaType: "application/json",
      errors: {
        422: `Validation Error`,
      },
    });
  }

  /**
   * Read Item
   * Get item by ID.
   * @returns ItemPublic Successful Response
   * @throws ApiError
   */
  public static readItem(
    data: ItemsData["ReadItem"],
  ): CancelablePromise<ItemPublic> {
    const { id } = data;
    return __request(OpenAPI, {
      method: "GET",
      url: "/api/v1/items/{id}",
      path: {
        id,
      },
      errors: {
        422: `Validation Error`,
      },
    });
  }

  /**
   * Update Item
   * Update an item.
   * @returns ItemPublic Successful Response
   * @throws ApiError
   */
  public static updateItem(
    data: ItemsData["UpdateItem"],
  ): CancelablePromise<ItemPublic> {
    const { id, requestBody } = data;
    return __request(OpenAPI, {
      method: "PUT",
      url: "/api/v1/items/{id}",
      path: {
        id,
      },
      body: requestBody,
      mediaType: "application/json",
      errors: {
        422: `Validation Error`,
      },
    });
  }

  /**
   * Delete Item
   * Delete an item.
   * @returns Message Successful Response
   * @throws ApiError
   */
  public static deleteItem(
    data: ItemsData["DeleteItem"],
  ): CancelablePromise<Message> {
    const { id } = data;
    return __request(OpenAPI, {
      method: "DELETE",
      url: "/api/v1/items/{id}",
      path: {
        id,
      },
      errors: {
        422: `Validation Error`,
      },
    });
  }
}
