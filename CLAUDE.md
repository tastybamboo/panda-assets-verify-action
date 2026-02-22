# CLAUDE.md

This file provides guidance to Claude Code when working with panda-assets-verify-action.

**Parent:** See `~/Projects/panda/CLAUDE.md` for monorepo-wide rules.

## Project Overview

A GitHub Action that verifies assets in panda-core (and other panda-* gems) are compiled and accessible correctly. It runs two phases:

1. **Prepare**: Compiles Propshaft assets, copies JavaScript files, generates importmap.json
2. **Verify**: Starts a WEBrick server and checks HTTP accessibility of all assets

## Key Architecture

- **Runner** (`lib/panda/assets/runner.rb`) — Orchestrates prepare and verify phases
- **Preparer** (`lib/panda/assets/preparer.rb`) — Asset compilation and setup
- **Verifier** (`lib/panda/assets/verifier.rb`) — HTTP verification of assets
- **UI** (`lib/panda/assets/ui.rb`) — Console output formatting with ANSI colors

## Running Locally

```bash
# Direct Ruby execution
ruby lib/panda/assets/runner.rb --dummy ../core/spec/dummy

# Or via the bin script
./bin/panda-assets --dummy ../core/spec/dummy
```

## Known Issues

- **Box alignment bug**: ANSI color codes are counted as characters when calculating box width in `lib/panda/assets/ui.rb`. Fix: strip ANSI codes before measuring length.
- **Hardcoded port**: WEBrick server uses port 4579. Could be made configurable via PORT env var.

## Technical Analysis

For detailed analysis of the architecture, fixed issues, and recommendations, see [docs/analysis.md](docs/analysis.md).
