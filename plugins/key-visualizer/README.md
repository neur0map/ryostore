# Key Visualizer for Ryoku (Quickshell)

A lightweight on-screen key visualizer plugin for Hyprland on the Ryoku desktop environment.

## Installation

1. **Clone into plugins directory**:
   ```bash
   git clone https://github.com/h-jangra/key-visualizer ~/.config/quickshell/plugins/key-visualizer
   ```

2. **Add the capture hook to Hyprland** (`~/.config/hypr/hyprland.lua` or `user.lua`):
   ```lua
   local kv_paths = {
       os.getenv("HOME") .. "/.config/quickshell/plugins/key-visualizer/key-visualizer.lua",
       os.getenv("HOME") .. "/.local/share/ryoku/plugins/key-visualizer/key-visualizer.lua"
   }
   for _, p in ipairs(kv_paths) do
       local f = io.open(p, "r")
       if f then f:close(); dofile(p); break end
   end
   ```
   Then reload Hyprland:
   ```bash
   hyprctl reload
   ```

3. **Enable the plugin**:
   - **GUI**: Open **Ryoku Settings** (`Super + ,`) → **Add-ons** → toggle **Key Visualizer** on.
   - **CLI**:
     ```bash
     ryoku-plugins-place key-visualizer enabled true
     ```

## Controls & Settings

- **Toggle Pause**: Click the topbar keyboard icon or run `quickshell ipc call key-visualizer toggle`.
- **Configuration**: Configure via **Ryoku Settings** or CLI:
  ```bash
  # Position: bottom-center | bottom-left | bottom-right | top-center | top-left | top-right
  ryoku-plugins-place key-visualizer settings '{"position": "bottom-center"}'

  # Margins (px) & Linger (ms)
  ryoku-plugins-place key-visualizer settings '{"margin": 67, "lingerMs": 1000}'

  # History stack count (1 - 5)
  ryoku-plugins-place key-visualizer settings '{"historyCount": 2}'
  ```
