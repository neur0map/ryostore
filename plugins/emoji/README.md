# Emoji

A keyboard-first emoji picker for Ryoku. Open it, type to search, arrow-key to
select, and copy (or insert) any emoji without leaving your keyboard.

## What it does

- **Search** the full Unicode emoji catalogue (3944 emojis, 9 groups) with a
  single search box - names and codepoints both match, with a live
  matches/total counter.
- **A theme-aware panel**: the popout is framed by a hairline border and a soft
  accent-tinted bed that recolours live with the active theme.
- **Full keyboard control**: `← →` move across a row (wrapping at the edges),
  `↑ ↓` move between rows in the same column, `PgUp`/`PgDn` flip a full page of
  visible rows, `Home`/`End` jump to the first/last result, and `Enter` picks
  the highlighted emoji. `Esc` clears the search (and resets the category), and
  a second `Esc` closes the popout. The wheel over the grid nudges the
  selection too.
- **A placeable frame popout**: dock it to any edge via the Hub's drag editor -
  where it sits is the host's job, not a plugin setting (see below). It never
  closes on its own; it stays until `Esc`, its frame menu, or your chosen
  shortcut takes it away.
- **`wl-copy` clipboard** under the hood, so copy works on every Wayland
  compositor (Hyprland, niri, sway, ...). No compositor-specific IPC is used.
- Optional **type-into-window** mode (`insert`) that types the emoji into the
  window you were using before the picker opened - the picker closes first so
  the keystrokes land behind it, not in the search box. `insert + copy` does
  both at once.
- Category chips filter by emoji group (with per-group counts); a live readout
  shows the highlighted emoji's name and position; right-click a cell to
  force-copy.

## Install

- **Ryoku Settings -> Plugins -> Discover -> Emoji -> Install**, then enable it
  as a **Frame popout**. Open it by hovering its placed frame edge, or via
  `ryoku-shell plugin emoji`.

**Want a shortcut?** Ryoku Settings > Keybinds > add a custom shortcut:
`SUPER, period` -> Run command -> `ryoku-shell plugin emoji`. That binds the
chord on YOUR side (stored in your config, generated into Hyprland), survives
updates, and never collides with Ryoku's shipped bind table. The plugin never
touches your keybinds and ships no key of its own - you pick the chord.

## Dependencies

| Command    | Package       | Needed for                          |
| ---------- | ------------- | ----------------------------------- |
| `wl-copy`  | `wl-clipboard` | Copy mode (always).                |
| `wtype`    | `wtype`        | `insert` / `both` modes only.      |

Copy works without `wtype`; picking an insert-mode emoji without it logs a
warning instead of typing. Both tools are Wayland-standard and work on
Hyprland, niri, sway, river, and friends - no compositor-specific setup.

## Where it sits

Placement belongs to the host: drag the "popout" chip in the Hub's placement
editor (Add-ons > Emoji) to dock it top/bottom/left/right, start/centre/end.
The plugin declares `bottom` + `centre` as its preferred default; a shell that
seeds defaults lands it there, otherwise it appears wherever the host places
first-time popouts and you can drag it anywhere you like. There is no separate
placement setting in the plugin on purpose - one source of truth, no conflicts.

## How it plugs in

The shell owns the popout surface - hover or your custom chord melts it out of
the frame edge - and mounts `content/Widget.qml` at `full` density, laying it
out at the size it reports. This plugin ships two pieces:

- `service/Main.qml` - the persistent logic: it holds the catalogue, the query
  and group, the filtered results, your settings, and the copy/insert command.
  It loads `data/emojis.json` once and keeps state while the popout opens and
  closes (`main` entry point).
- `content/Widget.qml` - the search-chips-grid view. It reads everything from
  the service via `pluginApi.mainInstance` and forwards picks back to it
  (`content` entry point).

`hosts` in `manifest.json` lists where it can render (`framePopout`);
`defaults.host` is where it lands when first enabled. The emoji catalogue
`data/emojis.json` is generated from the Unicode `emoji-test.txt` data set and
contains every fully-qualified Unicode 17.0 emoji, grouped by category.

## Settings

| Key               | Default          | Meaning                                            |
| ----------------- | ---------------- | -------------------------------------------------- |
| `action`          | `copy`           | What Enter does: `copy` (clipboard), `insert` (type into the window behind), or `both`. |
| `closeAfterPick`  | `false`          | Close the popout after `copy` (insert modes close first either way, so the keystrokes reach the window behind). |
| `resetOnOpen`     | `true`           | Clear the search AND reset the category to "All" every time the popout opens. |
| `columns`         | `8`              | Emoji grid columns (4-16).                          |
| `rows`            | `5`              | Visible grid rows (2-10); the popout grows to match. |
| `cellSize`        | `44`             | Minimum cell size in px (24-72); cells grow to fill the width. |
| `showGroupChips`  | `true`           | Show the category chips row (with per-group counts). |
| `showHint`        | `true`           | Show the hint footer and the live search/results counters. |

Settings are declared as the `metadata.settings` schema in `manifest.json`; the
shell renders the form in the plugin's menu and persists changes to
`pluginApi.pluginSettings`. Everything applies live.

## Test it before merge

The plugin runs straight from a clone of this repo - no store install, no
registry entry:

```sh
git clone https://github.com/Kavy-Codes/ryostore.git -b feat/emoji-plugin
cd ryostore
systemctl --user set-environment RYOSTORE_PLUGINS_DIR="$PWD/plugins"
systemctl --user restart ryoku-shell
```

Then open **Settings (`Super+comma`) -> Add-ons -> Plugins**, find **Emoji**,
toggle it on, place it as a **Frame popout**, and use it. Saved edits
hot-reload; watch the log while you test:

```sh
journalctl --user -u ryoku-shell -f
```

To preview the whole store catalogue from your checkout instead (install path,
hashes, receipts - exactly what users get):

```sh
mkdir -p ~/.config/ryoku
echo "file://$PWD" > ~/.config/ryoku/ryostore-base
```

Open the Store, install Emoji normally, then remove the override file when
done. When finished testing:

```sh
systemctl --user unset-environment RYOSTORE_PLUGINS_DIR
rm -f ~/.config/ryoku/ryostore-base
systemctl --user restart ryoku-shell
```

### Suggested pass

1. Install from Store (or live dir), enable as Frame popout, place it.
2. Search "fire", `↑ ↓ ← →` walk the grid in the same column/row;
   `PgUp`/`PgDn` flip a whole page of visible rows; `Home`/`End` jump.
3. `Enter` copies; pick several in a row - the popout stays open.
4. Switch On-pick to *Type into the window behind*, focus a text editor, open
   the picker, `Enter`: the emoji lands in the editor (needs `wtype`).
5. Right-click force-copies; click a category chip, close, reopen - with
   *Start fresh on open* the query AND category are reset.
6. Every setting renders and applies live; `Esc Esc` clears then closes;
   removal from Add-ons is clean and leaves nothing behind.

## Develop

```
emoji/
  manifest.json             # id, version, entry points, hosts, settings schema
  product-manifest.json     # store install spec (hashes, modes)
  service/Main.qml          # main: catalogue, search, pick action
  content/Widget.qml        # content: the adaptive view
  content/components/Chip.qml  # the category chip
  data/emojis.json          # generated emoji catalogue (Unicode 17.0)
  data/emoji-test.txt       # the source data set
  bin/ryoku-emoji           # compositor-independent copy/insert helper
  assets/preview-popout.png # the store preview image
```

The catalogue can be regenerated from `data/emoji-test.txt`. The service and
content are plain QML against `Ryoku.PluginKit`; see `plugins/AUTHORING.md` for
the full guide and [`DEVELOP.md`](../../DEVELOP.md) for the live-reload loop.

## Changelog

### 1.1.0

Fixes from end-to-end testing on a live Ryoku box:

- `↑`/`↓` now move the selection a full row. The SearchField consumes Up/Down
  in its own key handlers before the generic pressed event ever fires, so the
  grid listens to the field's `moved` signal instead.
- `PgUp`/`PgDn` flip a whole page (visible rows x columns) instead of stepping
  a few cells.
- `resetOnOpen` clears the category back to "All" along with the query, so a
  previously picked group can no longer leave the next open staring at an
  empty grid.
- `closeAfterPick` default is `false` everywhere - the popout stays open after
  a plain copy so several emojis can be picked in a row (manifest and service
  disagreed before).
- The last grid row no longer clips: the well height accounts for the grid's
  inner margins.
- `wtype` declared as a dependency; insert/both modes warn loudly instead of
  failing silently when it is missing.
- Placement defaults declare a real edge (`bottom`, centred); removed the
  unconsumed `"key"` default and all keybind claims - the README documents the
  sanctioned user-owned chord via Settings > Keybinds instead.

### 1.0.0

Initial release: search over 3944 Unicode 17.0 emojis, keyboard-first
navigation with paging and wrapping, copy/insert/both actions, category chips,
live readout, placeable frame popout host.

## Credits

Part of Ryoku, MIT-licensed. Emoji catalogue from the Unicode Consortium's
`emoji-test.txt` (Unicode 17.0).
