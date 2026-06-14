# Publishing this to GitHub as `t2companion-keyroost-builder`

The repo doesn't exist yet. Two ways to create and push it — pick one.

## Option A — GitHub CLI (fastest, one command to create + push)

If you have the GitHub CLI (`gh`) installed and logged in (`gh auth login`):

```bash
# from inside this folder (the one containing README.md and rebrand-*.ps1)
git init
git add .
git commit -m "Initial commit: Token2 Companion Keyroost builder"
gh repo create t2companion-keyroost-builder --public --source=. --remote=origin --push
```

That creates the repo under your account and pushes in one step. Use
`--private` instead of `--public` if you want it private.

## Option B — create on the website, then push

1. Go to https://github.com/new
2. **Repository name:** `t2companion-keyroost-builder`
3. Leave "Add a README / .gitignore / license" **unchecked** (this folder
   already has them — adding them on GitHub causes a push conflict).
4. Click **Create repository**.
5. Back in this folder, run (replace `YOUR-USERNAME`):

```bash
git init
git add .
git commit -m "Initial commit: Token2 Companion Keyroost builder"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/t2companion-keyroost-builder.git
git push -u origin main
```

If you use SSH instead of HTTPS, the remote is
`git@github.com:YOUR-USERNAME/t2companion-keyroost-builder.git`.

## On Windows (PowerShell)

The commands are identical — run them in PowerShell from this folder. The only
difference is the line-continuation character if you split a command across
lines (PowerShell uses a backtick `` ` ``, not `\`). The single-line commands
above work as-is.

## After the first push

- **Run the CI:** the workflow at `.github/workflows/package.yml` is set to run
  on manual dispatch. Go to the repo's **Actions** tab → "Package
  distributables" → **Run workflow**. It builds the AppImage, Windows installer,
  and macOS DMG and uploads them as run artifacts. (It does not publish a
  Release — it's a build demonstration. Add a publish step if you want tagged
  releases.)
- **Add a LICENSE.** Pick one (MIT is a good default for build tooling) and
  commit a `LICENSE` file; the README points here.
- **Tag a version** to trigger the same workflow on a tag:
  `git tag v0.1.0 && git push origin v0.1.0`.

## What gets committed

Everything in this folder **except** what `.gitignore` excludes (build output,
the rebranded checkout under `build/`, OS cruft). The branding assets, scripts,
patch, packaging recipes, docs builder, and CI workflow are all included — they
are the point of the repo.

## A note on the workflow building Windows/macOS artifacts

The CI uses GitHub's `windows-latest` and `macos-latest` runners, so it can
build the Setup .exe and the DMG even though you're working from Windows. The
macOS DMG and Windows installer steps were **not** run end-to-end in the
environment that produced these scripts (no macOS box, no Inno Setup), so the
first CI run is also their first real execution — expect to fix a small
environment detail or two (a missing tool, a path). The Linux AppDir assembly
and the rebrand/docs flows were tested.
