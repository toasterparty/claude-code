# C

Assume modern GCC, C99+, unless evidence says otherwise. Prefer data-oriented design.

## Language & safety
- Keep the preprocessor to header guards, constants, and small helpers like `BIT`/`ARRAY_LEN`; avoid macros containing logic and conditional-compilation feature gates.
- No bit fields; use `BIT` macros.
- Prefer a compiler error over a runtime failure, and a runtime failure over a panic.
- Fix every compiler warning within the current task's scope.
- Fixed-width integers (`stdint.h`) for I/O-bound data (wire formats, `packed` structs); plain `int`/`size_t` elsewhere.
- `_Static_assert` for compile-time invariants, which GCC accepts before C11.

## Functions & control flow
- Declare zero-arg functions with `(void)`.
- Test pointers and counts by truthiness (`if (data)`, `if (!data)`), never against `NULL` or `0`.
- On error, `goto EXIT` a single cleanup block:
```c
int foo(void) {
    int ret = -1;
    bar_t *bar = bar_create();
    if (!bar) goto EXIT;
    if (bar_fetch(bar) != 0) goto EXIT;
    ret = 0;
EXIT:
    bar_destroy(bar);
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
- Guard with `#ifndef`/`#define`, never `#pragma once`, named for the file and closed by a matching comment: `event_db.h` opens with `#ifndef EVENT_DB__` / `#define EVENT_DB__` and ends with `#endif // EVENT_DB__`.

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
- Before reporting done, format large sections of new code with the project's `.clang-format`.
- Avoid explicit casts; convert implicitly through an intermediate variable, preferably `const`.
- Head a section of code or a block of documentation with a `/* */` comment; `//` stays fine inline and trailing.
- Spread a designated initializer over multiple lines whenever it sets more than one field: `{` opens on the designator's line, one field per line, trailing comma (see `FOO_DATA` above).
