# Project instructions

Balance settings live in [`scripts/consts.gd`](scripts/consts.gd). See
[`BALANCE.md`](BALANCE.md) for the difficulty calculations, tuning guidance,
and full-run playtest results.

Build the release Web package with the installed Godot export templates:

```powershell
godot --headless --path . --export-release Web docs/index.html
```

Push the rebuilt `docs/` files and deploy that directory as a static website.
Keep all exported files together; the game loads `index.pck` and `index.wasm`
alongside `index.html`. This export uses the single-threaded Web template.
