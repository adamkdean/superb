-- Superb: its own context menu, flat and in the bar's theme. A row with a submenu opens it on a click, not on
-- hover, and it stays open until another row is clicked. A click outside the menu, or Escape, closes it.
--
-- A menu is described the way Blizzard's menus are, so a module's Menu function needs no change:
--   root:CreateTitle(text)
--   root:CreateDivider()
--   root:CreateButton(text, onClick, data)        -- returns a description; add elements to it for a submenu
--   root:CreateCheckbox(text, isSelected, setSelected, data)
--   root:CreateRadio(text, isSelected, setSelected, data)
Superb = Superb or {}
local S = Superb
local Menu = {}
S.Menu = Menu

local ROW, DIVIDER, PAD, GUTTER, ARROW, MARK = 20, 7, 5, 18, 16, 8
local levels = {}  -- the menu frames: 1 is the menu, 2 its open submenu, and so on

-- Descriptions -------------------------------------------------------------------------------------------------

local function describe(label, kind)
  local d = { label = label, kind = kind, children = {} }
  local function add(childKind, text, a, b, data)
    local e = describe(text, childKind)
    d.children[#d.children + 1] = e
    if childKind == "radio" or childKind == "checkbox" then
      e.isSelected = function() return a(data) and true or false end
      e.selected = e.isSelected()
      e.select = function() b(data) Menu.Refresh() end
    elseif a then
      e.click = function() a(data) end
    end
    return e
  end
  function d:CreateTitle(text) return add("title", text) end
  function d:CreateDivider() return add("divider", "") end
  function d:CreateButton(text, fn, data) return add("button", text, fn, nil, data) end
  function d:CreateRadio(text, isSel, setSel, data) return add("radio", text, isSel, setSel, data) end
  function d:CreateCheckbox(text, isSel, setSel, data) return add("checkbox", text, isSel, setSel, data) end
  return d
end

-- Frames -------------------------------------------------------------------------------------------------------

-- Hides level i and every submenu under it.
local function hideFrom(i)
  for j = i, #levels do levels[j]:Hide() end
  local parent = levels[i - 1]
  if parent and parent.openRow then
    parent.openRow.hl:Hide()
    parent.openRow = nil
  end
end

-- A dim square is an empty checkbox; a solid one is a ticked checkbox or the chosen radio.
local function mark(row)
  local node = row.node
  if node.kind == "checkbox" then
    row.mark:SetAlpha(node.selected and 1 or 0.25)
    row.mark:Show()
  else
    row.mark:SetAlpha(1)
    row.mark:SetShown(node.kind == "radio" and node.selected)
  end
end

local show

local function activate(row)
  local node, frame = row.node, levels[row.level]
  if node.kind == "title" or node.kind == "divider" then return end
  if #node.children > 0 then
    local open = frame.openRow == row
    hideFrom(row.level + 1)
    if not open then
      show(row.level + 1, node, function(f) f:SetPoint("TOPLEFT", row, "TOPRIGHT", 0, PAD) end)
      frame.openRow = row
      row.hl:Show()
    end
  elseif node.select then
    node.select()  -- a checkbox or radio keeps the menu open
  elseif node.click then
    Menu.Close()
    node.click()
  end
end

local function edge(f, a, b)
  local e = f:CreateTexture(nil, "BORDER")
  e:SetPoint(a)
  e:SetPoint(b)
  return e
end

local function level(i)
  if levels[i] then return levels[i] end
  local f = CreateFrame("Frame", i == 1 and "SuperbMenu" or nil, UIParent)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints()
  f.edges = { edge(f, "TOPLEFT", "TOPRIGHT"), edge(f, "BOTTOMLEFT", "BOTTOMRIGHT"), edge(f, "TOPLEFT", "BOTTOMLEFT"), edge(f, "TOPRIGHT", "BOTTOMRIGHT") }
  f.rows = {}
  f:Hide()
  levels[i] = f
  if i == 1 then
    tinsert(UISpecialFrames, "SuperbMenu")  -- Escape hides it
    f:SetScript("OnHide", function() Menu.Close() end)
    -- A click anywhere else closes the menu, and still reaches what was clicked.
    f:RegisterEvent("GLOBAL_MOUSE_DOWN")
    f:SetScript("OnEvent", function()
      for _, l in ipairs(levels) do if l:IsShown() and l:IsMouseOver() then return end end
      Menu.Close()
    end)
  end
  return f
end

local function row(f, n, i)
  if f.rows[n] then return f.rows[n] end
  local r = CreateFrame("Button", nil, f)
  r.level = i
  r.hl = r:CreateTexture(nil, "BACKGROUND")
  r.hl:SetAllPoints()
  r.hl:Hide()
  r.mark = r:CreateTexture(nil, "ARTWORK")
  r.mark:SetSize(MARK, MARK)
  r.mark:SetPoint("LEFT", PAD + 1, 0)
  r.line = r:CreateTexture(nil, "ARTWORK")
  r.line:SetHeight(1)
  r.line:SetPoint("LEFT", PAD, 0)
  r.line:SetPoint("RIGHT", -PAD, 0)
  r.text = r:CreateFontString(nil, "OVERLAY")
  r.text:SetPoint("LEFT", GUTTER, 0)
  r.arrow = r:CreateFontString(nil, "OVERLAY")
  r.arrow:SetPoint("RIGHT", -PAD, 0)
  r:SetScript("OnEnter", function(self)
    if self.node.kind ~= "title" and self.node.kind ~= "divider" then self.hl:Show() end
  end)
  r:SetScript("OnLeave", function(self) if f.openRow ~= self then self.hl:Hide() end end)
  r:SetScript("OnClick", activate)
  f.rows[n] = r
  return r
end

-- Draws the elements of `parent` as level i, placed by `anchor`.
show = function(i, parent, anchor)
  local f, theme = level(i), S:Theme()
  local r, g, b, a = unpack(theme.bg)
  if theme.bgTexture then
    f.bg:SetTexture(theme.bgTexture, "REPEAT", "REPEAT")
    f.bg:SetHorizTile(true)
    f.bg:SetVertTile(true)
  else
    f.bg:SetColorTexture(r, g, b, math.max(a, 0.95))
  end
  local er, eg, eb, ea = unpack(theme.edge)
  for n, e in ipairs(f.edges) do
    e:SetColorTexture(er, eg, eb, math.max(ea, 0.25))
    if n <= 2 then e:SetHeight(1) else e:SetWidth(1) end
  end
  local tr, tg, tb = unpack(theme.text)

  local width, y = 0, PAD
  for n, node in ipairs(parent.children) do
    local line = row(f, n, i)
    local divider, title = node.kind == "divider", node.kind == "title"
    line.node = node
    line.hl:SetColorTexture(unpack(theme.highlight))
    line.hl:Hide()
    line.mark:SetColorTexture(tr, tg, tb, 1)
    line.line:SetColorTexture(theme.sep[1], theme.sep[2], theme.sep[3], 1)
    line.line:SetShown(divider)
    for _, fs in ipairs({ line.text, line.arrow }) do
      fs:SetFont(theme.font, theme.size - 1, theme.flags)
      fs:SetTextColor(tr, tg, tb, title and 0.55 or 1)
      if theme.shadow then fs:SetShadowOffset(1, -1) fs:SetShadowColor(0, 0, 0, 1) else fs:SetShadowOffset(0, 0) end
    end
    line.text:SetText(node.label)
    line.arrow:SetText(#node.children > 0 and ">" or "")
    mark(line)
    width = math.max(width, line.text:GetStringWidth())
    local height = divider and DIVIDER or ROW
    line:SetHeight(height)
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -y)
    line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -y)
    line:Show()
    y = y + height
  end
  for n = #parent.children + 1, #f.rows do f.rows[n]:Hide() end

  f.node, f.openRow = parent, nil
  f:SetSize(math.ceil(width) + GUTTER + ARROW + PAD, y + PAD)
  f:ClearAllPoints()
  anchor(f)
  f:Show()
end

-- API ----------------------------------------------------------------------------------------------------------

-- Opens a menu. `generator(owner, root)` adds the elements to `root`. `place(frame)` anchors the menu; without
-- it, the menu opens at the cursor.
function Menu.Open(owner, generator, place)
  Menu.Close()
  local root = describe("root")
  generator(owner, root)
  Menu.root = root
  show(1, root, place or function(f)
    -- The cursor is in screen pixels from the bottom left; WorldFrame covers the screen, UIParent may not.
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    f:SetPoint("TOPLEFT", WorldFrame, "BOTTOMLEFT", x / scale, y / scale)
  end)
end

function Menu.Close()
  if levels[1] then hideFrom(1) end
end

-- Reads every checkbox and radio again, after one changed.
function Menu.Refresh()
  for _, f in ipairs(levels) do
    if f:IsShown() then
      for n = 1, #f.node.children do
        local line = f.rows[n]
        if line.node.isSelected then
          line.node.selected = line.node.isSelected()
          mark(line)
        end
      end
    end
  end
end
