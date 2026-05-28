# Local Tools

## Godot

Installed executable:

```text
E:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe
```

Version checked:

```text
4.6.3.stable.official.7d41c59c4
```

Validate project:

```powershell
& 'E:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\Desktop\DeskHub\Game Vibe Godot' --quit
```

Open editor:

```powershell
& 'E:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe' --path 'D:\Desktop\DeskHub\Game Vibe Godot'
```

## Godot MCP

Codex user config:

```text
C:\Users\94426\.codex\config.toml
```

Configured MCP server:

```toml
[mcp_servers.godot]
command = 'npx.cmd'
args = ['-y', '@coding-solo/godot-mcp']
startup_timeout_sec = 120

[mcp_servers.godot.env]
GODOT_PATH = 'E:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'
DEBUG = 'true'
```

Smoke test:

```powershell
$env:GODOT_PATH='E:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'
$env:DEBUG='true'
npx.cmd -y @coding-solo/godot-mcp --help
```

Restart Codex after changing MCP config so the new Godot tools are loaded.
