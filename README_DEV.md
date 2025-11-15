# 🛠️ Rimfield Development Guide

This document explains the local and CI automation that enforce Rimfield’s coding and architectural standards.  
Follow these steps when setting up your environment or contributing new code.

---

## ⚙️ Local Environment

### Prerequisites
- **Windows PowerShell 5+** (installed by default)  
  or **PowerShell Core (pwsh)** if you prefer cross-platform parity  
- **Git** 2.30+  
- **Godot 4.4** (project engine)  
- Optional: **Ripgrep** (`rg`) for faster local code scans

---

## 🧩 Repository Layout
```
Rimfield/
├── .cursor/
│   └── rules/
│       └── godot.md           # project standards + migration patterns
├── .github/
│   ├── workflows/verify.yml   # CI rule enforcement
│   └── PULL_REQUEST_TEMPLATE.md
├── scripts/
│   └── verify_rules.ps1       # local PowerShell rule checks
├── scenes/                    # game scenes
├── autoload/                  # singletons (signal bus, etc.)
├── assets/, resources/, ui/   # content + data
├── project.godot
└── ...
```

---

## 🧠 Cursor Integration
Cursor uses **`.cursor/rules/godot.md`** to understand this project’s standards.

**Highlights:**
- Modular, event-driven architecture  
- No `/root/...` absolute paths  
- No ternary operators  
- Signals and autoloads as the main communication channels  
- Typed exports and explicit `if/else` logic  
- Performance: no heavy logic in `_process()`  
- Data: configuration via `.tres` resources  
- Migration patterns for replacing absolute paths  
  (onready refs, signals, injections, relative `$Node`)

---

## 🧪 Local Rule Checks

Run manually:
```powershell
pwsh -File scripts/verify_rules.ps1
```

or (if using Windows PowerShell)
```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify_rules.ps1
```

**Checks performed:**
- ❌ Absolute `/root/` lookups  
- ❌ Ternary operators  
- ❌ Raw keycodes (`KEY_`, `MOUSE_BUTTON_`, `JOY_`)  
- ⚠️ Heavy `_process()` usage  
- ⚠️ Un-cached `get_node()` lookups  
- ⚠️ Magic numbers (10/12/24/30/60 etc.)

---

## 🔒 Pre-Commit Hook

Every commit automatically runs the verifier.

- File: `.git/hooks/pre-commit.cmd`  
- Behavior: runs `scripts/verify_rules.ps1` before completing a commit.  
- If violations are found → commit is **blocked**.  
- To skip temporarily:  
  ```bash
  git commit --no-verify -m "temporary commit"
  ```

---

## 🚦 CI Enforcement (GitHub Actions)

All pull requests run the same script via  
`.github/workflows/verify.yml`.

The pipeline:
1. Checks for rule violations.  
2. Fails the PR if any `/root/...` or ternary operators exist.  
3. Mirrors local behavior for consistency.

---

## 📝 Pull Request Checklist

When opening a PR, confirm:
- [ ] No `/root/...` paths remain  
- [ ] No ternary operators  
- [ ] Input handled via InputMap  
- [ ] Signals typed and connected once  
- [ ] `_process()` free of polling logic  
- [ ] `scripts/verify_rules.ps1` → **PASS**

---

## 🧱 Developer Setup (First-Time Clone)

1. Clone the repo  
2. Run the hook installer (optional helper script):
   ```powershell
   pwsh tools/setup-hooks.ps1
   ```
3. Verify hook runs on first commit  
4. Run `scripts/verify_rules.ps1` manually once for baseline

---

## 📚 Maintenance

- Update `.cursor/rules/godot.md` whenever architecture rules evolve  
- Adjust `scripts/verify_rules.ps1` for new code patterns  
- Use the CI output as the single source of truth for code compliance
