## Panda Assets Verify Action

This GitHub Action compiles and verifies Panda asset pipelines
across Panda Core and all registered Panda modules.

It runs the unified Ruby-based asset pipeline (`Panda::Assets::Runner`)
and uploads a human-readable HTML report to GitHub Actions.

No Node, Yarn, or JS toolchain is required — Panda uses `propshaft`,
`tailwindcss-ruby`, and `importmap-rails`, all of which run fully on Ruby.

---

## Inputs

```
dummy_root:
  description: "Path to the dummy Rails app"
  required: false
  default: "spec/dummy"
```

---

## Outputs

```
result:
  description: "PASS or FAIL"
```

---

## Example Usage

```yaml
jobs:
  verify-assets:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Run Panda asset verification
        uses: tastybamboo/panda-assets-verify-action@v1
        with:
          dummy_root: spec/dummy
```

---

## What this Action Does

1. Installs Ruby (via `ruby/setup-ruby`)
2. Installs only the small Ruby gems required by the action:
   - `webrick`
   - `benchmark` (Ruby 3.5+)
3. Runs the unified Panda asset pipeline:
   - Compiles engine + module assets
   - Runs HTTP checks
   - Scans importmaps
   - Validates manifest files
4. Writes a Tailwind-styled HTML report (`panda-assets-report.html`)
5. Uploads the report to GitHub Actions Artifacts

---

## No Bundler, No Node Required

This action does **not** run `bundle install`.

Why?

- It contains no runtime Gemfile
- Dependencies are minimal and installed directly with `gem install`
- It does not load Rails or the parent application
- It executes plain Ruby inside `lib/panda/assets/*`
- Tailwind + Propshaft + Importmap all run via Ruby

This keeps the action fast, isolated, and deterministic across environments.

---

## Local Development

Run the pipeline locally with:

```bash
ruby lib/panda/assets/runner.rb --dummy spec/dummy
```

This will produce:

- `panda-assets-report.html`
- pretty console output
```
