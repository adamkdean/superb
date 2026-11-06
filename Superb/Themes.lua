-- Superb: bar themes. Colours are {r, g, b, a}. Fonts and textures are paths seen in the Blizzard UI source
-- (Blizzard_Fonts_Shared/Mainline/GameFonts.xml, Blizzard_SharedXML/Backdrop.lua).
Superb = Superb or {}

local ARIAL = "Fonts\\ARIALN.TTF"
local FRIZ = "Fonts\\FRIZQT__.TTF"

Superb.Themes = {
  order = { "defaultLight", "defaultDark", "minimal", "tooltip", "vanilla" },

  defaultLight = {
    name = "Default Light", height = 24, font = ARIAL, size = 14, flags = "", shadow = false,
    bg = { 0.96, 0.96, 0.97, 0.82 }, edge = { 0, 0, 0, 0.18 }, edgeSize = 1,
    text = { 0.08, 0.08, 0.08, 1 }, highlight = { 0, 0, 0, 0.10 }, pad = 9, spacing = 6,
  },
  defaultDark = {
    name = "Default Dark", height = 24, font = ARIAL, size = 14, flags = "", shadow = false,
    bg = { 0.11, 0.11, 0.12, 0.80 }, edge = { 1, 1, 1, 0.10 }, edgeSize = 1,
    text = { 0.95, 0.95, 0.95, 1 }, highlight = { 1, 1, 1, 0.16 }, pad = 9, spacing = 6,
  },
  minimal = {
    name = "Minimal", height = 20, font = ARIAL, size = 13, flags = "OUTLINE", shadow = false,
    bg = { 0, 0, 0, 0.35 }, edge = { 0, 0, 0, 0 }, edgeSize = 1,
    text = { 1, 1, 1, 1 }, highlight = { 1, 1, 1, 0.10 }, pad = 7, spacing = 4,
  },
  tooltip = {
    name = "Tooltip", height = 24, font = FRIZ, size = 12, flags = "", shadow = true,
    bg = { 0.03, 0.03, 0.08, 0.92 }, edge = { 0.62, 0.62, 0.66, 1 }, edgeSize = 2,
    text = { 1, 1, 1, 1 }, highlight = { 1, 1, 1, 0.12 }, pad = 9, spacing = 6,
  },
  vanilla = {
    name = "Vanilla", height = 26, font = FRIZ, size = 12, flags = "", shadow = true,
    bgTexture = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", bg = { 1, 1, 1, 1 },
    edge = { 0.78, 0.62, 0.25, 1 }, edgeSize = 2,
    text = { 1, 0.82, 0, 1 }, highlight = { 1, 0.82, 0, 0.16 }, pad = 10, spacing = 6,
  },
}

Superb.DEFAULT_THEME = "defaultDark"
