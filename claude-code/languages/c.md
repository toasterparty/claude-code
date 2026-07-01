# C

Applies when reviewing C or making complex C changes. Assume modern GCC and C99+ unless evidence suggests otherwise. Prefer data-oriented design.

## Language & safety
- Never rely on undefined behavior.
- Avoid the preprocessor, superfluous casts, and bit fields (use `BIT` macros instead).
- Prefer a compiler error over a runtime failure, and a runtime failure over a panic.
- Fix all compiler warnings before release; treat each as a TODO.

## Functions & control flow
- Declare zero-arg functions with `(void)`.
- Place the success exit point at the bottom of the function.
- Use `return`/`break`/`continue` to avoid `else` blocks.
- Keep indentation to 1–3 levels; never 5+.
- Keep functions small; extract standalone logic into `static` functions.

## Scope & visibility
Minimize the visibility of every variable, function, struct, and enum:
- `.c` over `.h`
- `static` over global
- function-scope over file-scope
- define as late and as nested (`{ }`) as possible

## File layout (`.c`)
Order: includes → preprocessor → typedefs → extern vars → static vars → static functions → public functions.

## Structs
- Always `typedef`; prefer anonymous.
- Add `packed` to any struct that is serialized/deserialized.
- Initialize, set, and copy safely:
```c
foo_t foo = { /* optional initial values */ }; // initialize (designated initializer)
foo = (foo_t){ /* ... */ };                    // set (compound literal)
foo = foo_b;                                   // copy
```

## Enums
- Always `typedef`; prefer anonymous.
- Prefix every value; end with `<PREFIX>_COUNT`.
- Use enums only for contiguous ranges starting at 0; use `const`/`#define` otherwise.
- Back enums with static lookup tables indexed by value:
```c
typedef enum {
    FOO_A,
    FOO_B,
    FOO_COUNT,
} foo_t;

static const struct {
    // ...
} FOO_DATA[] = {
    [FOO_A] = { /* ... */ },
    [FOO_B] = { /* ... */ },
};
// static assert: ARRAY_LEN(FOO_DATA) == FOO_COUNT
```
