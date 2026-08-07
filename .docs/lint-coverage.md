# Known lint coverage gaps

Biome 2.5.4 enforces the available equivalents for the previous ESLint configuration:

- React Hooks' classic rules through `useHookAtTopLevel` and `useExhaustiveDependencies`
- component/hook factories through the nursery `noComponentHookFactories` rule
- nested static components through `noNestedComponentDefinitions`
- React prop mutation through `noReactPropAssignments`
- Vite Fast Refresh module exports through `useComponentExportOnlyModules`
- unused expressions, TypeScript namespaces, literal const assertions, and CommonJS imports
- `@ts-ignore` through `noTsIgnore`

Biome has no full equivalent for React Hooks 7's `config`, `set-state-in-effect`,
`error-boundaries`, `gating`, `globals`, `immutability`, `preserve-manual-memoization`, `purity`,
`refs`, `set-state-in-render`, `static-components`, `unsupported-syntax`, `use-memo`, or
`incompatible-library` rules. The enabled prop-mutation and nested-component rules cover only part
of `immutability` and `static-components`. These remain known gaps rather than claimed parity.

Biome also cannot ban `@ts-nocheck` or require descriptions on `@ts-expect-error`. The canonical
check supplements it with `scripts/lint-ts-comments.mjs`, which bans `@ts-ignore` and
`@ts-nocheck` and requires a description of at least three characters for `@ts-expect-error`.
