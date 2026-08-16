# C

Assume modern GCC, C99+, unless evidence says otherwise. Prefer data-oriented design.

## Language & safety
- Keep the preprocessor to header guards, constants, and small helpers like `BIT`/`ARRAY_LEN`; avoid macros containing logic and conditional-compilation feature gates.
- Do not use bit fields (use `BIT` macros instead).
- Prefer a compiler error over a runtime failure, and a runtime failure over a panic.
- Fix all compiler warnings before release; treat each as a TODO.
- Prefer fixed-width integers (`stdint.h`) for I/O-bound data (wire formats, `packed` structs); plain `int`/`size_t` remain fine for loop counters and other transient values.
- Use `_Static_assert` for compile-time invariants; GCC supports it as an extension even before C11.

## Functions & control flow
- Declare zero-arg functions with `(void)`.
- Test pointers and counts by truthiness (`if (data)`, `if (!data)`) rather than comparing against `NULL` or `0`.
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
- prefix `static` function names with `_`
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
- Prefer an enum to `#define` for any group of related integer constants; reserve `const`/`#define` for sparse or non-integer values.
- Back enums with static lookup tables indexed by value, which requires a contiguous range starting at 0:
```c
typedef enum {
    FOO_A,
    FOO_B,
    FOO_COUNT,
} foo_t;

static const struct {
    const char *name;
    bool data_required;
} FOO_DATA[] = {
    [FOO_A] = {
        .name = "A",
        .data_required = true,
    },
    [FOO_B] = {
        .name = "B",
        .data_required = false,
    },
};
_Static_assert(ARRAY_LEN(FOO_DATA) == FOO_COUNT, "FOO_DATA/FOO_COUNT mismatch");
```

## Style
- Projects typically ship with a `.clang-format` file codifying stylistic preferences. Use it to format large sections of newly written code before reporting done.
- Avoid explicit casts unless absolutely necessary. Use intermediate variables, preferably `const`, to invoke casting implicitly instead.
- Head a section of code or a block of documentation with a `/* */` comment; `//` stays fine inline and trailing.
- Spread a designated initializer over multiple lines whenever it sets more than one field: `{` opens on the designator's line, one field per line, trailing comma (see `FOO_DATA` above).
