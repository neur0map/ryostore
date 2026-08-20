-- Key Visualizer for Ryoku / Quickshell — lightweight key event capture.
--
-- Listens to Hyprland's `input.keyboard.key` event and writes active keys to
-- $XDG_RUNTIME_DIR/ryoku-key-visualizer.json.

local runtime = os.getenv("XDG_RUNTIME_DIR")
if not runtime or runtime == "" then runtime = "/tmp" end
local STATE_FILE = runtime .. "/ryoku-key-visualizer.json"

-- Modifiers keyed by xkb keycode (evdev + 8)
local MODS = {
  [50] = "Shift",  [62] = "Shift",   -- Shift_L / Shift_R
  [37] = "Ctrl",   [105] = "Ctrl",   -- Control_L / Control_R
  [64] = "Alt",    [108] = "Alt",    -- Alt_L / Alt_R
  [133] = "Super", [134] = "Super",  -- Super_L / Super_R
  [135] = "Menu",
  [109] = "AltGr",
}

local MOD_ORDER = { "Super", "Ctrl", "Alt", "Shift", "Menu", "AltGr" }

-- Special / Non-printing key labels
local KEYS = {
  [9] = "Esc", [22] = "Backspace", [23] = "Tab", [36] = "Enter", [66] = "Caps",
  [67] = "F1", [68] = "F2", [69] = "F3", [70] = "F4", [71] = "F5", [72] = "F6",
  [73] = "F7", [74] = "F8", [75] = "F9", [76] = "F10", [95] = "F11", [96] = "F12",
  [107] = "Print", [78] = "Scroll", [127] = "Pause",
  [118] = "Ins", [110] = "Home", [112] = "PgUp", [119] = "Del", [115] = "End", [117] = "PgDn",
  [111] = "Up", [113] = "Left", [116] = "Down", [114] = "Right",
  [65] = "Space",
  [77] = "Num", [106] = "KP/", [63] = "KP*", [82] = "KP-", [86] = "KP+",
  [104] = "KP Enter", [125] = "KP=",
  [79] = "KP7", [80] = "KP8", [81] = "KP9", [83] = "KP4", [84] = "KP5", [85] = "KP6",
  [87] = "KP1", [88] = "KP2", [89] = "KP3", [90] = "KP0", [91] = "KP.",
  [121] = "Mute", [122] = "Vol-", [123] = "Vol+",
  [94] = "\\", [51] = "\\",
}

-- Printable characters (US layout)
local CHARS = {
  [10] = "1", [11] = "2", [12] = "3", [13] = "4", [14] = "5", [15] = "6",
  [16] = "7", [17] = "8", [18] = "9", [19] = "0", [20] = "-", [21] = "=",
  [24] = "q", [25] = "w", [26] = "e", [27] = "r", [28] = "t", [29] = "y",
  [30] = "u", [31] = "i", [32] = "o", [33] = "p", [34] = "[", [35] = "]",
  [38] = "a", [39] = "s", [40] = "d", [41] = "f", [42] = "g", [43] = "h",
  [44] = "j", [45] = "k", [46] = "l", [47] = ";", [48] = "'", [49] = "`",
  [52] = "z", [53] = "x", [54] = "c", [55] = "v", [56] = "b", [57] = "n",
  [58] = "m", [59] = ",", [60] = ".", [61] = "/",
}

local SHIFTED = {
  [10] = "!", [11] = "@", [12] = "#", [13] = "$", [14] = "%", [15] = "^",
  [16] = "&", [17] = "*", [18] = "(", [19] = ")", [20] = "_", [21] = "+",
  [34] = "{", [35] = "}", [47] = ":", [48] = '"', [49] = "~",
  [59] = "<", [60] = ">", [61] = "?",
}

local pressed = {}
local combo = {}
local last_payload = ""

local function shift_down()
  return pressed[50] or pressed[62]
end

local function non_shift_mods_down()
  local seen = {}
  for kc, down in pairs(pressed) do
    local name = MODS[kc]
    if down and name and name ~= "Shift" then seen[name] = true end
  end
  local out = {}
  for _, name in ipairs(MOD_ORDER) do
    if seen[name] then out[#out + 1] = name end
  end
  return out
end

local function any_printable()
  for _, kc in ipairs(combo) do
    if CHARS[kc] then return true end
  end
  return false
end

local function key_label(kc, binding)
  local label = KEYS[kc]
  if label then return label end
  local ch = CHARS[kc]
  if not ch then return nil end
  if binding then return string.upper(ch) end
  if shift_down() then
    return SHIFTED[kc] or string.upper(ch)
  end
  return ch
end

local function labels()
  local parts = {}
  local ns = non_shift_mods_down()
  for _, m in ipairs(ns) do parts[#parts + 1] = m end
  local binding = #ns > 0
  if shift_down() and (binding or not any_printable()) then
    parts[#parts + 1] = "Shift"
  end
  for _, kc in ipairs(combo) do
    local label = key_label(kc, binding)
    if label then parts[#parts + 1] = label end
  end
  return parts
end

local function emit()
  local parts = labels()
  local payload
  if #parts > 0 then
    payload = '{"keys":["' .. table.concat(parts, '","') .. '"]}'
  else
    payload = '{"keys":[]}'
  end

  if payload == last_payload then return end
  last_payload = payload

  local f = io.open(STATE_FILE, "w")
  if f then
    f:write(payload)
    f:close()
  end
end

if hl and hl.on then
  hl.on("input.keyboard.key", function(keycode, timeMs, state)
    if state == 2 then return end -- ignore auto-repeat

    if state == 1 then
      pressed[keycode] = true
      if not MODS[keycode] then
        local found = false
        for _, kc in ipairs(combo) do
          if kc == keycode then found = true break end
        end
        if not found then combo[#combo + 1] = keycode end
      end
      emit()
    else
      pressed[keycode] = false
      if not MODS[keycode] then
        for i, kc in ipairs(combo) do
          if kc == keycode then
            table.remove(combo, i)
            break
          end
        end
      end
      local any_down = false
      for _, down in pairs(pressed) do
        if down then any_down = true break end
      end
      if not any_down then
        combo = {}
        pressed = {}
        emit()
      end
    end
  end)
end
