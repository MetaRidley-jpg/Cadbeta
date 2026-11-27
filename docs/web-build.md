# Cadavire web build (iPhone, no PC)

Decision (T, 2026-11-26): "iPhone and we will use web route". T has no PC available, so the phone test build is a web page that Safari opens. GitHub builds it in the cloud and hosts it on GitHub Pages.

## Live
- **Play:** https://metaridley-jpg.github.io/Cadbeta/
- **Repo:** https://github.com/MetaRidley-jpg/Cadbeta (public, branch `main`)
- **Builds:** https://github.com/MetaRidley-jpg/Cadbeta/actions — each push to `main` rebuilds the site in about 1 minute.

## How it works
1. Push to `main`.
2. `.github/workflows/web.yml` on GitHub's servers:
   - Downloads Godot 4.7.2 and its web export templates (cached after the first run).
   - Imports the project.
   - Runs the rule tests (366), the dogfight tests (197) and the touch tests (25). **A failed test stops the publish**, so a broken build never replaces a good one. The gate greps for "passed, 0 failed" (a plain "0 failed" would match "10 failed").
   - Exports the "Web" preset to `build/web/` and publishes to GitHub Pages.
3. T opens the link in Safari. Share → "Add to Home Screen" makes it open full screen like an app.

## Settings (in the project)
- `export_presets.cfg`, preset **Web**:
  - Threads OFF (plain GitHub Pages cannot send COOP/COEP headers).
  - Include filter `data/*.json, art/stacks/*.json`: the game reads these by path at runtime. **Any new folder the game reads by path must be added here.**
  - Exclude `tools/*, tests/*, build/*, *.md`.
  - A head tag so "Add to Home Screen" opens full screen, and a viewport tag that stops pinch zoom.
  - Canvas resize policy 2 (fill the browser window).
- `project.godot`: `renderer/rendering_method.web="gl_compatibility"` (WebGL 2). Desktop and native phone builds stay on "mobile".
- `.gitignore`: `export_presets.cfg` and `*.import` are committed; `build/`, `tools/demos/`, `tools/redraw/backup/` are ignored.
- **Phones:** `Game.is_phone()` = native mobile OR `web_ios` / `web_android` feature OR `--phone`. Web phones keep 4.5% of the screen height free at the bottom (no safe area from the browser; the iOS home-bar swipe sits there).

## One-time setup (done 2026-11-26)
1. GitHub linked to Claude: Customize → Connectors → **GitHub Integration** (it is NOT in the connector directory search).
2. Public repo `Cadbeta` created by T.
3. **Claude GitHub App** installed on the repo. Without it, the push returned 403 even with GitHub linked.
4. Repo Settings → Pages → Source: **GitHub Actions** (the workflow token cannot turn Pages on).

## Check an export locally
`godot --headless --path . --export-pack "Web" build/test.pck`, then run that pack alone from an empty folder with `--main-pack` (needs no export templates).

## Known warnings
- GitHub warns that the actions target Node 20 (forced onto Node 24). It works; bump versions later.

## Risks (hostile audit)
1. **Speed is not native speed.** WebAssembly on one thread with WebGL 2. The dogfight costs ~16 ms of units drawing on desktop (CPU work; draw calls 100-420). A fast web build proves a fast native app; a slow one does not prove a slow native app.
2. **Saves can vanish.** IndexedDB; Safari can delete site storage after 7 days with no visit. Treat web saves as test saves.
3. **Public code.** T's final art and any store secrets must not go in a public repo. Later: private repo + paid Pages, or another host.
4. **First load size** (tens of MB engine file). **Sound starts after the first tap.** **Cache:** if a new build does not show, close the tab / Home Screen app and open it again.
