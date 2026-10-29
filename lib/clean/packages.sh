#!/bin/bash
# lib/clean/packages.sh — Package manager caches: npm, pip, yarn, pnpm, cargo, gradle, etc.
# Source this file; do not execute directly.

clean_package_managers() {
    ui_section "Package Manager Caches"

    # ── Python ────────────────────────────────────────────────────────────────
    safe_clean_dir "$HOME/.cache/pip"                  "pip (Python)"
    safe_clean_dir "$HOME/Library/Caches/pip"          "pip (Python, macOS)"
    safe_clean_dir "$HOME/.cache/uv"                   "uv (Python)"
    safe_clean_dir "$HOME/Library/Caches/uv"           "uv (Python, macOS)"
    safe_clean_dir "$HOME/.cache/poetry"               "Poetry"
    safe_clean_dir "$HOME/.cache/huggingface"          "Hugging Face"

    # pip cache command
    if command -v pip3 >/dev/null 2>&1; then
        if [[ "${DRY_RUN:-false}" != "true" ]]; then
            pip3 cache purge 2>/dev/null || true
        else
            ui_dry "pip cache purge" "?" "pip3 cache purge"
        fi
    elif command -v pip >/dev/null 2>&1; then
        if [[ "${DRY_RUN:-false}" != "true" ]]; then
            pip cache purge 2>/dev/null || true
        fi
    fi

    # Python bytecode (current working dir context — skip in maccleanup, done by --deep-clean)

    # ── Node.js / JavaScript ─────────────────────────────────────────────────
    safe_clean_dir "$HOME/.cache/yarn"                 "Yarn"
    safe_clean_dir "$HOME/.cache/pnpm"                 "pnpm (legacy cache path)"
    safe_clean_dir "$HOME/.npm/_npx"                   "npm npx cache"
    safe_clean_dir "$HOME/.npm/_logs"                  "npm logs"
    safe_clean_dir "$HOME/.npm/_cacache"                "npm cache (fallback, no npm CLI)"

    if command -v npm >/dev/null 2>&1; then
        if [[ "${DRY_RUN:-false}" != "true" ]]; then
            npm cache clean --force 2>/dev/null || true
            ui_cleaned "npm cache" "cleaned"
        else
            ui_dry "npm cache" "?" "npm cache clean --force"
        fi
    fi

    # pnpm's real content-addressable store lives at ~/Library/pnpm/store on
    # modern installs, not ~/.cache/pnpm — `pnpm store prune` is the safe way
    # to drop unreferenced packages from it.
    if command -v pnpm >/dev/null 2>&1; then
        if [[ "${DRY_RUN:-false}" != "true" ]]; then
            pnpm store prune 2>/dev/null || true
            ui_cleaned "pnpm store" "pruned"
        else
            ui_dry "pnpm store" "?" "pnpm store prune"
        fi
    fi

    # ── JVM / Android ─────────────────────────────────────────────────────────
    safe_clean_dir "$HOME/.gradle/caches"              "Gradle"
    safe_clean_dir "$HOME/.m2/repository"              "Maven"
    safe_clean_dir "$HOME/.cache/coursier"             "Coursier (Scala/sbt)"
    safe_clean_dir "$HOME/.ivy2/cache"                 "Ivy (Scala)"
    safe_clean_dir "$HOME/.sbt/boot"                   "sbt boot cache"

    # ── Go ────────────────────────────────────────────────────────────────────
    safe_clean_dir "$HOME/go/pkg/mod/cache"            "Go modules"

    # ── Rust / Cargo ──────────────────────────────────────────────────────────
    safe_clean_dir "$HOME/.cargo/registry/cache"       "Rust/Cargo registry cache"
    safe_clean_dir "$HOME/.cargo/registry/src"         "Rust/Cargo registry sources"

    # ── Homebrew ──────────────────────────────────────────────────────────────
    if command -v brew >/dev/null 2>&1; then
        if [[ "${DRY_RUN:-false}" != "true" ]]; then
            brew cleanup --prune=all 2>/dev/null || true
            ui_cleaned "Homebrew" "cleaned (brew cleanup --prune=all)"
        else
            ui_dry "Homebrew" "?" "brew cleanup --prune=all"
        fi
    fi
}
