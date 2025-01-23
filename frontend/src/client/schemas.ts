export const $HTTPValidationError = {
  properties: {
    detail: {
      type: "array",
      contains: {
        type: "ValidationError",
      },
    },
  },
} as const;

export const $ItemCreate = {
  properties: {
    title: {
      type: "string",
      isRequired: true,
      maxLength: 255,
      minLength: 1,
    },
    description: {
      type: "any-of",
      contains: [
        {
          type: "string",
          maxLength: 255,
        },
        {
          type: "null",
        },
      ],
    },
  },
} as const;

export const $ItemPublic = {
  properties: {
    title: {
      type: "string",
      isRequired: true,
      maxLength: 255,
      minLength: 1,
    },
    description: {
      type: "any-of",
      contains: [
        {
          type: "string",
          maxLength: 255,
        },
        {
          type: "null",
        },
      ],
    },
    id: {
      type: "string",
      isRequired: true,
      format: "uuid",
    },
    owner_id: {
      type: "string",
      isRequired: true,
      format: "uuid",
    },
  },
} as const;

export const $ItemUpdate = {
  properties: {
    title: {
      type: "any-of",
      contains: [
        {
          type: "string",
          maxLength: 255,
          minLength: 1,
        },
        {
          type: "null",
        },
      ],
    },
    description: {
      type: "any-of",
      contains: [
        {
          type: "string",
          maxLength: 255,
        },
        {
          type: "null",
        },
      ],
    },
  },
} as const;

export const $ItemsPublic = {
  properties: {
    data: {
      type: "array",
      contains: {
        type: "ItemPublic",
      },
      isRequired: true,
    },
    count: {
      type: "number",
      isRequired: true,
    },
  },
} as const;

export const $Message = {
  properties: {
    message: {
      type: "string",
      isRequired: true,
    },
  },
} as const;

export const $User = {
  properties: {
    id: {
      type: "string",
      isRequired: true,
    },
    email: {
      type: "string",
      isRequired: true,
    },
    name: {
      type: "string",
      isRequired: true,
    },
  },
} as const;

export const $ValidationError = {
  properties: {
    loc: {
      type: "array",
      contains: {
        type: "any-of",
        contains: [
          {
            type: "string",
          },
          {
            type: "number",
          },
        ],
      },
      isRequired: true,
    },
    msg: {
      type: "string",
      isRequired: true,
    },
    type: {
      type: "string",
      isRequired: true,
    },
  },
} as const;
