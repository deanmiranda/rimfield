# GDScript Formatter Setup

This guide helps you set up **gdformat** (part of gdtoolkit) to automatically format GDScript files on save.

## Installation

### 1. Install gdtoolkit (includes gdformat)

```bash
pip install gdtoolkit
```

Or with pipx (recommended to avoid global package conflicts):

```bash
pipx install gdtoolkit
```

### 2. Verify Installation

```bash
gdformat --version
```

## Usage

### Format a Single File

```bash
gdformat scripts/ui/hud_slot.gd
```

### Format All GDScript Files

```bash
gdformat scripts/**/*.gd
```

## Editor Integration

### VS Code / Cursor

1. Install the **"godot-tools"** extension
2. Add to your `.vscode/settings.json`:

```json
{
  "godot_tools.gdscript_formatter": "gdformat",
  "[gdscript]": {
    "editor.defaultFormatter": "geequlim.godot-tools",
    "editor.formatOnSave": true
  }
}
```

### Manual Format Command

You can also add a task to format all files:

1. Create `.vscode/tasks.json`:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Format All GDScript",
      "type": "shell",
      "command": "gdformat",
      "args": ["scripts/**/*.gd"],
      "problemMatcher": []
    }
  ]
}
```

2. Run with `Ctrl+Shift+B` (or `Cmd+Shift+B` on Mac)

## Configuration

Create `.gdformat.cfg` in your project root to customize formatting:

```ini
[gdformat]
indent_size = 4
max_line_length = 100
```

## Git Pre-Commit Hook (Optional)

To automatically format files before committing:

1. Create `.git/hooks/pre-commit` (no extension):

```bash
#!/bin/sh
# Format all staged GDScript files
gdformat $(git diff --cached --name-only --diff-filter=ACM | grep '\.gd$')
git add $(git diff --cached --name-only --diff-filter=ACM | grep '\.gd$')
```

2. Make it executable:

```bash
chmod +x .git/hooks/pre-commit
```

## Quick Fix Script

For immediate formatting of all project files:

```bash
# PowerShell
Get-ChildItem -Path scripts -Recurse -Filter *.gd | ForEach-Object { gdformat $_.FullName }

# Bash
find scripts -name "*.gd" -exec gdformat {} \;
```

