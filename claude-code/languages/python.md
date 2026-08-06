# Python

Assume latest production Python version, unless evidence says otherwise.

## Language & safety
- Never rely on CPython implementation details (refcounting-based cleanup timing, GIL-based atomicity of compound operations like `list.append`).
- Avoid metaclasses and monkey-patching.

## Functions & control flow
- Type-annotate every function signature, including the return type.
- Prefer scalable patterns: `for item in items: item()` over `item1(); item2(); item3()`.

## Scope & visibility
- module-private (`_name`) over public
- function-scope over module-scope
- local/nested definitions over module-level; define as late as possible
- declare the public API explicitly via `__all__`

## File layout
Order: imports -> module constants -> type aliases -> private helpers -> public functions/classes.
- Keep imports at the top of the file; only import inside a function to break a circular import or defer an expensive/optional dependency.

## Choosing a construct
Prefer the least powerful construct that fits.

Data:
- no new type - plain values or a function's parameters - until two or more travel together through more than one call
- `enum.Enum`/`IntEnum`/`StrEnum` for a fixed, named set of values
- `typing.NamedTuple` for a small immutable record; already frozen, hashable, and slotted
- `@dataclass(frozen=True, slots=True)` once the type needs `field()` defaults, `__post_init__`, inheritance, or must not be usable as a plain tuple
- `dict`/`TypedDict` only for dynamic keys or a shape dictated by an external payload (JSON, config); convert at the deserialization boundary rather than passing the mapping inward

Behavior:
- a module of functions until state must be threaded through methods
- `typing.Protocol` over an ABC or a shared base class; declare the shape you consume instead of growing an inheritance tree
- an ABC only to share implementation via `@abstractmethod` hooks, never as a bare interface declaration; still preferred over a concrete base with `NotImplementedError` stubs

## Dataclasses & named tuples
```py
from copy import copy
from dataclasses import replace

foo = Foo()
foo = replace(foo, a=1)
foo_b = copy(foo)
```
- Never wrap `replace` in a `with_(**changes)` helper; `**kwargs` loses type-checker field validation.
- Name a recurring update as a past-participle method: `cursor.advanced(1)`.
- Construct once from locals over chained `replace`.
- Non-frozen (still `slots=True`) only for a short-lived local accumulator.
- These rules carry over to `NamedTuple`, with `_replace` in place of `replace`.

## Enums
- Use `enum.Enum`/`enum.IntEnum`; members are already namespaced (`Foo.A`), so don't prefix values (`FOO_A`).
- Use `len(Foo)` or iteration instead of a manual `COUNT` sentinel.
- Back enums with data via a dict keyed by member, not a parallel index-based lookup table:
```py
class Foo(enum.Enum):
    A = enum.auto()
    B = enum.auto()

FOO_DATA = {
    Foo.A: {...},
    Foo.B: {...},
}
```

## Environment & dependencies
- Use `uv` for packages and environments; never hand-roll `pip`/`venv`/`poetry`, and run commands via `uv run` rather than activating a venv.
- Bootstrap `uv` in setup scripts (official installer if missing) rather than assuming it's preinstalled.
- Default to the lockfile (`uv run --locked`, `uv sync --frozen`); upgrading (`uv lock --upgrade`) is a separate, explicit action.
- Pass `--directory`/`--all-packages` explicitly instead of relying on cwd or a single-package assumption.

## CLI & entry points
- Use `click` for argument parsing over `argparse` or hand-rolled `sys.argv` handling.
- Expose the CLI through `<package>/__main__.py`, registered as a `[project.scripts]` entry point in `pyproject.toml`; invoke it as `uv run foo <command>`, not `uv run python foo/main.py`.

## Packaging & releases
- Library meant to be imported by other Python projects: publish a wheel/sdist to PyPI.
- Standalone application/CLI meant to be run directly: ship a binary built with Nuitka rather than bundling with PyInstaller.
