# Python

Applies to Python review or complex changes. Assume latest production Python version, unless evidence says otherwise.

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
Prefer the least powerful construct that fits:
- `enum.Enum`/`IntEnum`/`StrEnum` over `@dataclass` for a fixed, named set of values
- `@dataclass` over a class when there's no behavior to bind to the data
- a class over a module of related functions only when state must be threaded through methods

## Dataclasses
- Use `@dataclass(frozen=True, slots=True)`; prefer immutability.
- Initialize, set, and copy safely:
```py
foo = Foo()                          # initialize (field defaults)
foo = dataclasses.replace(foo, a=1)  # set (immutable update)
foo_b = copy.copy(foo)               # copy
```

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
