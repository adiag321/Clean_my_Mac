# Contributing to MacCleanUp

Thanks for your interest in improving MacCleanUp! Bug reports, feature suggestions, and pull requests are all welcome.

---

## Getting Started

1. **Fork the repository** on GitHub.
2. **Clone your fork locally**:
   ```bash
   git clone https://github.com/adiag321/maccleanup.git
   cd maccleanup
   ```
3. **Run the automated test suite** to verify your environment:
   ```bash
   bash tests/test_maccleanup.sh
   ```

---

## Development Guidelines

- **Shell compatibility:** scripts must run on macOS's default Bash (`/bin/bash` v3.2+). Avoid Bash 4+ features like namerefs (`local -n`) or associative arrays (`declare -A`).
- **Safety first:**
  - Every destructive operation must honor `DRY_RUN`.
  - Check paths against `is_whitelisted()` before modifying anything.
  - Never touch system-critical paths without an explicit, named reason.
- **Modularity:** place new cleanup targets in the appropriate submodule under `lib/clean/` or `lib/optimize/`, not in the main `maccleanup` script.
- **Testing:** add assertions to `tests/test_maccleanup.sh` for new features or bug fixes, and run the full suite before opening a PR.

---

## Submitting Pull Requests

1. Create a feature branch:
   ```bash
   git checkout -b feature/my-new-feature
   ```
2. Commit with a clear message describing the *why*, not just the *what*:
   ```bash
   git commit -m "Add cleanup for Foo app caches"
   ```
3. Run the test suite:
   ```bash
   bash tests/test_maccleanup.sh
   ```
4. Push to your fork and open a Pull Request.
