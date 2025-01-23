export type HTTPValidationError = {
  detail?: Array<ValidationError>;
};

export type ItemCreate = {
  title: string;
  description?: string | null;
};

export type ItemPublic = {
  title: string;
  description?: string | null;
  id: string;
  owner_id: string;
};

export type ItemUpdate = {
  title?: string | null;
  description?: string | null;
};

export type ItemsPublic = {
  data: Array<ItemPublic>;
  count: number;
};

export type Message = {
  message: string;
};

export type User = {
  id: string;
  email: string;
  name: string;
};

export type ValidationError = {
  loc: Array<string | number>;
  msg: string;
  type: string;
};
