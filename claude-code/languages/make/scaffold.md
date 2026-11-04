# Makefile scaffold
Start a Makefile with this header, which forces every recipe to run under bash on every OS:
```Makefile
.PHONY: install run start stop logs test format upgrade clean
.DEFAULT_GOAL := run

ifeq ($(OS),Windows_NT)
    # Guard via BASH, not SHELL: make silently falls back to cmd.exe on an empty SHELL.
    BASH_CACHE := build/.bash-path
    BASH := $(file < $(BASH_CACHE))
    space := $() $()
    ifeq ($(wildcard $(subst $(space),\$(space),$(BASH))),)
        BASH := $(shell powershell -NoProfile -ExecutionPolicy Bypass -File tools/find-bash.ps1)
        ifeq ($(BASH),)
            $(error Git bash not found by tools/find-bash.ps1)
        endif
        ifneq ($(wildcard build),)
            $(file > $(BASH_CACHE),$(BASH))
        endif
    endif
    SHELL := $(BASH)
else
    SHELL := bash
endif
.SHELLFLAGS := -euo pipefail -c
```

On Windows the header relies on the two scripts in `languages/make/tools/`. Copy both unchanged into the project's `tools/`, without reading them: `find-bash.ps1` runs on every make invocation, and the user runs `install-bash.ps1` once by hand to bootstrap.
