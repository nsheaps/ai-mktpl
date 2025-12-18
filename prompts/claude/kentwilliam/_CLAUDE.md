# Verifying your work

- Instead of using `curl` or similar approaches, please add proper test automation and run that automation to verify output.
- Do not suggest running any tools that include pipes and/or multiple commands.

# Introducing tools

- Always verify with me before introducing additional tools for problems that were not explicitly mentioned.

# Preparing for deploy/prod

- Please make sure that all imported modules are at the latest version if possible
- Audit the code for security problems before declaring it 'done' and ready to go, and make sure you continue to do so as things evolve

# JavaScript/TypeScript style

- Leave all code under ./src
- Modules that export functions and hooks should be camelCase
- Modules that export types, classes, and components should be PascalCase
- Avoid circular dependencies. The root of the project, which typically is run when doing npm run start, should not export anything. If two modules both need something from each other, move one of the dependencies into a third module to ensure a clean, directed dependency graph.
- Prefer `export default` and a single export per file. If you have a great reason to have a single file with many exports, please ask before proceeding
- The name of a file should generally always be the same as its export. The exception is any file that exports multiple things, and index.ts/tsx
- Use `function` for top level functions
- Define logic top-down, i.e. high-level first, then any functions used by the high-level function
- Prefer `type` to `interface`
- Prefer inlining types unless they're reused more than 3 times
- When modeling state, be strict. Avoid empty string being a third null value, instead say `string | null`
- When modeling steps or state machine states, give them proper type names, don't use numbers or strings. Use type unions to make it obvious. If the state machines have attached state, you can model this as objects with a type parameter, still relying on union types for the disambiguation
- Never use comments. If you feel the code is not intention-revealing, prefer introducing a function or variable name to make your intention obvious. If necessary, use longer names for these functions or variables to explain what they do, but whenever the same thing could be said with similar clarity and a shorter name, make it shorter
- Never swallow errors. If you don't know what to do about an error case, either 1. ask me (best) 2. don't catch it or 3. log error and exit process / crash
- When naming functions, variables, arguments, components and hooks, avoid abbreviations at all cost except in the extremely rare case that the abbreviation is typically used when speaking, such as `id` and `SQL`. In particular, write `error`, not `err` or `e`. If you're unsure about exceptions to this rule, please ask me.
- Avoid overly nested logic. Use extract-function and early returns to ensure the core logic is concerned with the golden path
- Always use arrow functions when declaring closures inside a function/component. Always use `function` for external functions and for components.
- Avoid utils folders and utils naming. Instead, just leave the utils as functions, and try to co-locate them with the components that need them.
- By default, leave all files in a flat directory. If there's a strong reason they should be grouped (i.e. they pertain to the same topic), start by using a shared prefix, then introduce a folder if there's a lot of files that share this topic
- Organize by relatedness and shared responsibilities, _not_ by the type of the JS file. I.e. no hooks/ and components/ folders.
- Instead of exposing several helpers from one file, export each separately.
- Functions that export a single function, type, or hook should be named the same as that export, and use export default. The case should match the export
- Module constants should be ALL_UPPER_CASE.
- Place all "general" app configuration in index.tsx unless we discuss it first
- Unless an array is mutable, always annotate it as ReadonlyArray
- Unless an object is mutable, always annotate it as Readonly
- Always use Prettier, and install it for the project if needed
- For switch cases that are pure maps, prefer placing those maps in local constants instead.

# React style

- Avoid temporary variables in render unless the result is referenced repeatedly. Instead, inline the decision making and extract components to reduce render complexity
- Define the top-level component first, then any components that it depends on
- Avoid overspecifying layout, i.e. prefer a minimal set of constraints
- Prefer minWidth and maxWidth to width
- Use useReducer whenever the state transitions become more complex -- i.e. if there are 3 or more state transitions in the render, and you cannot avoid this more simply by extracting components to co-locate the state there. For example, input parsing has no business being part of render, it should be modeled as a input -> action loop similar to redux
- Do not call functions directly in render -- if the component has dependencies, use custom hooks and ensure those will manage their state updates well
- If a function does not have dependencies on render-internal state, extract it to the local scope. We don't want to redefine those functions every render, this causes GC churn
- Similarly, extract long handler bodies to local functions and call those from terser closures
- Inline props types and don't give them names. So `function Component({foo}: Readonly<{foo: number}>): React.ReactNode {`, not `type ComponentProps ..., function Component({foo}: ComponentProps`
- Don't use useState inside useEffect -- normally this means you should instead introduce a derived state, possibly with useMemo if deriving it is expensive.

# State management

- Unless otherwise specified, default to built-in React state management.

# Prettier configuration

- Use defaults, except:
- Trailing commas everywhere possible (`"trailingComma": "all"`)
- Single quotes for strings (`"singleQuote": true`)
- 100 character line width (`"printWidth": 100`)

# Testing strategy

## Integration tests first

- Start with integration tests that cover core user workflows end-to-end
- Integration tests should verify behavior, not implementation details
- Avoid testing specific strings or DOM structure unless they're critical to the user experience
- Focus on: can users complete the workflow without errors? Does data flow correctly?
- Examples of good integration tests:
  - Upload flow: upload image → wait for processing → verify image appears in gallery
  - Detail flow: click image → detail panel opens → can close panel
  - API flow: POST /api/images → returns 200 → database contains record

## When to write unit tests

Only introduce unit tests when:

1. **Complex business logic**: Pure functions with significant branching or calculations
2. **Error handling**: Edge cases that are hard to trigger in integration tests
3. **API contracts**: Endpoint inputs/outputs, especially error responses
4. **Stateful components**: Components with complex internal state machines (3+ states)

## When NOT to write unit tests

Avoid unit tests for:

- Simple React components that just render props
- Trivial functions (formatters, mappers without logic)
- Implementation details (callback invocations, internal state)
- Specific DOM structure or CSS classes
- Content that frequently changes (marketing copy, labels)

## Component testing guidelines

For React components:

- **Default**: One smoke test that verifies the component renders without errors
- **Add tests only when**: The component has complex interaction logic, multiple states, or tricky edge cases
- **Test user interactions**: Click handlers, form submissions, keyboard navigation
- **Don't test**: Specific text content, CSS classes, internal callbacks unless they affect user-visible behavior

Example of minimal component test:

```typescript
it('renders without errors', () => {
  render(<ImageCard image={mockImage} />);
});
```

Only expand if the component warrants it:

```typescript
it('calls onClick when card is clicked', () => {
  let clicked = false;
  render(<ImageCard image={mockImage} onClick={() => { clicked = true; }} />);
  fireEvent.click(screen.getByRole('button'));
  expect(clicked).toBe(true);
});
```

## Test structure

- Prefer `it` to `test`, and use natural form, e.g, "it('renders the component without errors', ..)". No 'should'.
- Use `describe` to nest related tests once the test suite gets past 5-6 tests.
- Broadly speaking, aim for one `expect` or assertion per test. If more than one assertion makes sense for a single "guarantee", it's OK, but if the guarantees could fail independently, they should probably be separate tests.
- Use minimal mocks, and only name a mock or stub if it's to be referenced in the assertions. Otherwise just pass it directly.
- Test interfaces, not implementations. Don't test that callbacks are called; test the effect of calling them.

# Eslint

- Include the common, strict eslint rule sets for the technologies in use.
- For Node applications, include node globals.
- For Browser applications, include browser globals.

# CSS / styles

- Do not use autoprefixer. Modern browsers support CSS features natively.
- Only use PostCSS for Tailwind CSS processing.
- Whenever defining style configuration (i.e. stylex, cva() calls), move it to the end of the file so that the component is the first thing the reader sees.
