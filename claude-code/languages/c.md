# C

Assume modern GCC, C99+, unless evidence says otherwise. Prefer data-oriented design.

## Language & safety
- Keep the preprocessor to header guards, constants, and small helpers like `BIT`/`ARRAY_LEN`; avoid macros containing logic and conditional-compilation feature gates.
- Avoid superfluous casts and bit fields (use `BIT` macros instead).
- Prefer a compiler error over a runtime failure, and a runtime failure over a panic.
- Fix all compiler warnings before release; treat each as a TODO.
- Prefer fixed-width integers (`stdint.h`) for I/O-bound data (wire formats, `packed` structs); plain `int`/`size_t` remain fine for loop counters and other transient values.
- Use `_Static_assert` for compile-time invariants; GCC supports it as an extension even before C11.

## Functions & control flow
- Declare zero-arg functions with `(void)`.
- On error, `goto EXIT` a single cleanup block rather than duplicating cleanup at each early return:
```c
int foo(void) {
    int ret = -1;
    resource_t *r = acquire();
    if (!r) goto EXIT;
    if (do_work(r) != 0) goto EXIT;
    ret = 0;
EXIT:
    release(r);
    return ret;
}
```

## Scope & visibility
- `.c` over `.h`
- `static` over global
- function-scope over file-scope
- `const` wherever possible
- define as late and as nested (`{ }`) as possible

## File layout (`.c`)
Order: includes -> preprocessor -> typedefs -> extern vars -> static vars -> static functions -> public functions.

## Header files (`.h`)
- Guard with `#ifndef`/`#define` (not `#pragma once`), named `<FILENAME>__` (e.g. `event_db.h` -> `EVENT_DB__`):
```c
#ifndef FILENAME__
#define FILENAME__

// ...

#endif // FILENAME__
```

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
_Static_assert(ARRAY_LEN(FOO_DATA) == FOO_COUNT, "FOO_DATA/FOO_COUNT mismatch");
```
