local _, ns = ...
local L = ns.L
local C = ns.colors

local UI = {}
ns.UI = UI

local WIDTH = 244
local PAD = 8
local GAP = 4
local HEADER_HEIGHT = 26
local ROW_HEIGHT = 22
local COUNT_HEIGHT = 26
local MAX_PER_ROW = 5

-- ---------------------------------------------------------------------------
-- Building blocks (also used by the options)
-- ---------------------------------------------------------------------------

--- How opaque the buttons are: a little more than the window, so they stay readable.
local function FillAlpha()
    local opacity = ns.db and ns.db.opacity or 0.5
    return math.min(1, opacity + 0.3)
end

function ns.AddBorder(frame)
    local border = {}
    for index = 1, 4 do
        border[index] = frame:CreateTexture(nil, "BORDER")
    end
    border[1]:SetPoint("TOPLEFT")
    border[1]:SetPoint("TOPRIGHT")
    border[1]:SetHeight(1)
    border[2]:SetPoint("BOTTOMLEFT")
    border[2]:SetPoint("BOTTOMRIGHT")
    border[2]:SetHeight(1)
    border[3]:SetPoint("TOPLEFT")
    border[3]:SetPoint("BOTTOMLEFT")
    border[3]:SetWidth(1)
    border[4]:SetPoint("TOPRIGHT")
    border[4]:SetPoint("BOTTOMRIGHT")
    border[4]:SetWidth(1)

    function border:SetColor(r, g, b, a)
        for index = 1, 4 do
            self[index]:SetColorTexture(r, g, b, a or 1)
        end
    end
    border:SetColor(unpack(C.border))
    return border
end

local function PaintButton(self)
    local alpha = self.solid and 1 or FillAlpha()
    if self.selected then
        self.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.95)
        self.label:SetTextColor(unpack(C.onAccent))
        if self.border then self.border:SetColor(C.accent[1], C.accent[2], C.accent[3], 1) end
    elseif self.hover then
        self.bg:SetColorTexture(C.surfaceHover[1], C.surfaceHover[2], C.surfaceHover[3], math.max(alpha, 0.9))
        self.label:SetTextColor(1, 1, 1)
        if self.border then self.border:SetColor(unpack(C.border)) end
    else
        local color = self.textColor or C.text
        self.bg:SetColorTexture(C.surface[1], C.surface[2], C.surface[3], self.ghost and 0 or alpha)
        self.label:SetTextColor(color[1], color[2], color[3])
        if self.border then self.border:SetColor(unpack(C.border)) end
    end
end

--[[
A flat button. Fields the caller may set before Paint():
  selected   amber fill
  textColor  colour of the label
  ghost      no fill and no border until hovered
  solid      ignore the window opacity (for the options)
  tooltip    text shown on hover
]]
function ns.CreateFlatButton(parent, text, width, height, ghost, template)
    local button = ns.NewFrame("Button", nil, parent, template)
    button:SetSize(width, height)
    button.ghost = ghost

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    if not ghost then button.border = ns.AddBorder(button) end

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("LEFT", 4, 0)
    button.label:SetPoint("RIGHT", -4, 0)
    button.label:SetJustifyH("CENTER")
    button.label:SetWordWrap(false)
    button.label:SetText(text or "")

    button.Paint = PaintButton
    button:SetScript("OnEnter", function(self)
        self.hover = true
        self:Paint()
        if self.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(self)
        self.hover = false
        self:Paint()
        GameTooltip:Hide()
    end)
    button:Paint()
    return button
end

-- ---------------------------------------------------------------------------
-- Links: the game cannot open a browser, so a click shows the link to copy
-- ---------------------------------------------------------------------------

local linkDialog

local function ShowLink(link)
    if not linkDialog then
        local dialog = ns.NewFrame("Frame", "MaldoesIncCallerLinkDialog", UIParent)
        dialog:SetSize(380, 96)
        dialog:SetPoint("CENTER", 0, 120)
        dialog:SetFrameStrata("FULLSCREEN_DIALOG")
        dialog:EnableMouse(true)
        dialog:Hide()

        local bg = dialog:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], 0.97)
        ns.AddBorder(dialog)

        dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        dialog.title:SetPoint("TOPLEFT", 12, -10)
        dialog.title:SetTextColor(unpack(C.accentText))

        dialog.hint = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dialog.hint:SetPoint("BOTTOMLEFT", 12, 10)
        dialog.hint:SetPoint("BOTTOMRIGHT", -12, 10)
        dialog.hint:SetJustifyH("LEFT")
        dialog.hint:SetTextColor(unpack(C.textDim))

        local close = ns.CreateFlatButton(dialog, "x", 20, 18, true)
        close:SetPoint("TOPRIGHT", -5, -5)
        close:SetScript("OnClick", function() dialog:Hide() end)

        local box = ns.NewFrame("EditBox", nil, dialog, "InputBoxTemplate")
        box:SetAutoFocus(false)
        box:SetSize(350, 20)
        box:SetPoint("TOPLEFT", 16, -34)
        box:SetScript("OnEscapePressed", function() dialog:Hide() end)
        box:SetScript("OnEnterPressed", function() dialog:Hide() end)
        box:SetScript("OnTextChanged", function(self, userInput)
            -- The link is only there to be copied: undo anything typed into it.
            if userInput and dialog.url then
                self:SetText(dialog.url)
                self:HighlightText()
            end
        end)
        box:SetScript("OnKeyDown", function(_, key)
            if key == "C" and IsControlKeyDown() then
                ns.After(0.2, function() dialog:Hide() end)
            end
        end)
        dialog.box = box
        linkDialog = dialog
    end

    linkDialog.url = link.url
    linkDialog.title:SetText(link.name)
    linkDialog.hint:SetText(L.LINK_COPY_HINT)
    linkDialog.box:SetText(link.url)
    linkDialog:Show()
    linkDialog.box:SetFocus()
    linkDialog.box:HighlightText()
end

--[[
The donation bar: "small" for the window (Donate and short channel names),
"medium" for the options (full names). Returns the bar; call bar:Relabel() after a language change.
]]
function ns.CreateLinkBar(parent, size)
    local medium = size == "medium"
    local height = medium and 24 or 16
    local bar = ns.NewFrame("Frame", nil, parent)
    bar:SetHeight(height)
    bar.buttons = {}

    -- Maldö's avatar in front of the links in the options. The window has it in its header already.
    if medium then
        bar.avatar = bar:CreateTexture(nil, "ARTWORK")
        bar.avatar:SetSize(height, height)
        bar.avatar:SetPoint("LEFT", 0, 0)
        bar.avatar:SetTexture(ns.mediaPath .. "maldoe")
    end

    for index, link in ipairs(ns.Links) do
        local button
        if link.donate then
            button = ns.CreateFlatButton(bar, "", medium and 118 or 58, height, not medium)
            button.textColor = C.accentText
        else
            button = ns.CreateFlatButton(bar, medium and link.name or link.short, medium and 74 or 22, height, not medium)
            button.textColor = C.textDim
        end
        if not medium then
            -- The small buttons are as wide as their text (see Layout), so the label needs no inset.
            button.label:ClearAllPoints()
            button.label:SetPoint("CENTER")
        end
        button.solid = medium
        button.link = link
        button:SetScript("OnClick", function(self) ShowLink(self.link) end)

        if link.donate and ns.Links[index + 1] then
            -- A thin line between donating and the channels.
            bar.separator = bar:CreateTexture(nil, "ARTWORK")
            bar.separator:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.25)
            bar.separator:SetSize(1, height - 6)
        end
        bar.buttons[#bar.buttons + 1] = button
    end

    -- Place the buttons. The small ones take the width of their text: a fixed width cut "DC" and "TW"
    -- down to "..." with a wider interface font.
    local function Layout()
        local x = medium and height + 4 or 0
        for _, button in ipairs(bar.buttons) do
            if not medium then
                local textWidth = button.label:GetStringWidth() or 0
                if textWidth > 0 then button:SetWidth(math.ceil(textWidth) + 6) end
            end
            button:ClearAllPoints()
            button:SetPoint("LEFT", x, 0)
            x = x + button:GetWidth() + (medium and 4 or 1)
            if button.link.donate and bar.separator then
                bar.separator:ClearAllPoints()
                bar.separator:SetPoint("LEFT", x + 2, 0)
                x = x + 6
            end
        end
        bar:SetWidth(x)
    end

    function bar:Relabel()
        for _, button in ipairs(self.buttons) do
            local link = button.link
            if link.donate then
                button.label:SetText(medium and (L.LINK_DONATE .. " (" .. link.name .. ")") or L.LINK_DONATE)
                button.tooltip = L.LINK_DONATE_TIP:format(link.name)
            else
                button.tooltip = L.LINK_FOLLOW_TIP:format(link.name)
            end
            button:Paint()
        end
        Layout()
    end
    bar:Relabel()
    return bar
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------

local function SavePosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    ns.db.position = { point, relativePoint, x, y }
end

local function RestorePosition(frame)
    frame:ClearAllPoints()
    local position = ns.db.position
    if type(position) == "table" and position[1] then
        frame:SetPoint(position[1], UIParent, position[2] or position[1], position[3] or 0, position[4] or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 320, -40)
    end
end

function UI:Create()
    local frame = ns.NewFrame("Frame", "MaldoesIncCallerFrame", UIParent)
    self.frame = frame
    frame:SetSize(WIDTH, 120)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        -- The window holds secure buttons, so the game does not let it move in combat.
        if not ns.db.locked and not InCombatLockdown() then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    frame:Hide()

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    ns.AddBorder(frame)

    -- A thin amber line at the top, like the stripes of the logo.
    local stripe = frame:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT", 1, -1)
    stripe:SetPoint("TOPRIGHT", -1, -1)
    stripe:SetHeight(2)
    stripe:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.9)

    -- Header
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("TOPLEFT", PAD, -7)
    icon:SetTexture(ns.mediaPath .. "inccaller") -- Maldö's avatar with the war horn laid over it

    self.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.title:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    self.title:SetTextColor(unpack(C.accentText))

    local close = ns.CreateFlatButton(frame, "x", 18, 16, true)
    close:SetPoint("TOPRIGHT", -5, -7)
    close.textColor = C.textDim
    close:SetScript("OnClick", function() UI:Hide() end)
    self.closeButton = close

    local options = ns.NewFrame("Button", nil, frame)
    options:SetSize(14, 14)
    options:SetPoint("RIGHT", close, "LEFT", -3, 0)
    options:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    options:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton", "ADD")
    options:SetScript("OnClick", function() ns.OpenOptions() end)
    options:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.TIP_OPTIONS, 1, 1, 1)
        GameTooltip:Show()
    end)
    options:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.subtitle:SetPoint("LEFT", self.title, "RIGHT", 6, 0)
    self.subtitle:SetPoint("RIGHT", options, "LEFT", -4, 0)
    self.subtitle:SetJustifyH("RIGHT")
    self.subtitle:SetWordWrap(false)
    self.subtitle:SetTextColor(unpack(C.textFaint))

    -- Shown instead of the bases outside a battleground.
    self.emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.emptyText:SetPoint("TOPLEFT", PAD, -(HEADER_HEIGHT + 6))
    self.emptyText:SetWidth(WIDTH - 2 * PAD)
    self.emptyText:SetJustifyH("CENTER")
    self.emptyText:SetTextColor(unpack(C.textDim))

    self.targetButtons = {}

    self.selectedText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.selectedText:SetWidth(WIDTH - 2 * PAD)
    self.selectedText:SetJustifyH("LEFT")
    self.selectedText:SetWordWrap(false)

    -- The call buttons (1, 2, 3, 4+, Big or the player's own list) are made in Refresh().
    self.countButtons = {}

    self.linkBar = ns.CreateLinkBar(frame, "small")

    --[[
    Spam protection. After a call this cover lies over the call buttons for a few seconds and
    takes the clicks, so no second call can go out. The call buttons are secure and addon code
    cannot switch them off in combat; a normal frame on top of them can be shown and hidden at
    any time.
    ]]
    local cooldown = ns.NewFrame("Frame", nil, frame)
    cooldown:SetFrameLevel(frame:GetFrameLevel() + 20)
    cooldown:EnableMouse(true)
    cooldown:Hide()
    local cover = cooldown:CreateTexture(nil, "BACKGROUND")
    cover:SetAllPoints()
    cover:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], 0.8)
    -- A bar that runs out, and the seconds left.
    cooldown.bar = cooldown:CreateTexture(nil, "ARTWORK")
    cooldown.bar:SetPoint("BOTTOMLEFT")
    cooldown.bar:SetHeight(2)
    cooldown.bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    cooldown.text = cooldown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cooldown.text:SetPoint("CENTER")
    cooldown.text:SetTextColor(unpack(C.accentText))
    cooldown:SetScript("OnUpdate", function(self)
        local left = (self.ends or 0) - GetTime()
        if left <= 0 then
            self:Hide()
            return
        end
        self.text:SetText(string.format("%.1f", left))
        self.bar:SetWidth(math.max(1, self:GetWidth() * left / (self.duration or 1)))
    end)
    self.cooldown = cooldown

    -- Follows the player a few times per second while the window is visible.
    local elapsedTotal = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal < 0.3 then return end
        elapsedTotal = 0
        ns.UpdateProximity()
    end)

    RestorePosition(frame)
    self:ApplyStyle()
    self:Refresh()
end

-- Runs in the game's restricted environment when a base button is clicked: copies the macros
-- prepared for this base to the call buttons.
local SELECT_SNIPPET = [[
    local count = self:GetAttribute("count") or 0
    for index = 1, count do
        local call = self:GetFrameRef("call" .. index)
        if call then
            call:SetAttribute("macrotext", self:GetAttribute("macro" .. index) or "")
        end
    end
]]

local function AcquireTargetButton(self, index)
    local button = self.targetButtons[index]
    if button then return button end

    -- A secure button: its click may rewrite the macros of the call buttons even in combat,
    -- which normal addon code is not allowed to do. See the note above UI:Refresh().
    button = ns.CreateFlatButton(self.frame, "", 10, ROW_HEIGHT, false, "SecureHandlerClickTemplate")
    button:SetAttribute("_onclick", SELECT_SNIPPET)
    -- The amber mark on the left: "you are here".
    button.near = button:CreateTexture(nil, "OVERLAY")
    button.near:SetPoint("TOPLEFT", 1, -1)
    button.near:SetPoint("BOTTOMLEFT", 1, 1)
    button.near:SetWidth(3)
    button.near:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    button:SetScript("PostClick", function(clicked)
        ns.selected = clicked.target
        ns.CancelPendingSelection()
        UI:UpdateStates()
    end)
    self.targetButtons[index] = button
    return button
end

local function AcquireCountButton(self, index)
    local button = self.countButtons[index]
    if button then return button end

    -- A secure macro button: the game itself runs "/i <call>" on the click. Chat sent by addon
    -- code is blocked during a battleground (chat lockdown), a macro pressed by the player is not.
    button = ns.CreateFlatButton(self.frame, "", 10, COUNT_HEIGHT, false, "SecureActionButtonTemplate")
    button.label:SetFontObject("GameFontNormal")
    -- Both, because the game setting "cast on key down" decides which of the two runs the macro.
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", "")
    button:SetScript("PostClick", function(clicked, _, down)
        if down then return end
        if ns.OnCallClicked(ns.selected, clicked.definition) then
            UI:StartCooldown()
        end
    end)
    button:HookScript("OnEnter", function(hovered)
        if ns.selected and hovered.definition then
            GameTooltip:SetOwner(hovered, "ANCHOR_TOP")
            GameTooltip:SetText(L.TIP_COUNT:format(ns.BuildMessage(ns.selected, hovered.definition)), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    self.countButtons[index] = button
    return button
end

--[[
How a call is sent.

The call buttons are secure macro buttons. Their macro ("/i *Inc call* Stables 2 *INC*") is
written by addon code out of combat only, because the game forbids that in combat. So that
another base can still be picked in combat, every base button carries the finished macros for
all call buttons as attributes ("macro1", "macro2", ...) and copies them over with a secure
snippet when it is clicked.

Refresh() lays out and fills the secure buttons and therefore waits for the end of combat.
UpdateStates() only changes colours and texts and may run at any time.
]]
function UI:Refresh()
    local frame = self.frame
    if not frame then return end
    if InCombatLockdown() then
        ns.AfterCombat("refresh", function() UI:Refresh() end)
        self:UpdateStates()
        return
    end

    self.title:SetText(L.TITLE)
    self.subtitle:SetText(ns.bgName or "")
    self.closeButton.tooltip = L.TIP_CLOSE
    self.linkBar:Relabel()

    local targets = ns.targets
    local y = -(HEADER_HEIGHT + 2)
    local columnWidth = (WIDTH - 2 * PAD - GAP) / 2
    local column = 0
    local used = 0

    for _, target in ipairs(targets) do
        used = used + 1
        local button = AcquireTargetButton(self, used)
        button.target = target
        button.label:SetText(ns.TargetName(target, ns.uiLang))
        button:ClearAllPoints()
        if target.flag then
            -- The flag carrier gets a row of its own.
            if column == 1 then
                y = y - ROW_HEIGHT - GAP
                column = 0
            end
            button:SetSize(WIDTH - 2 * PAD, ROW_HEIGHT)
            button:SetPoint("TOPLEFT", PAD, y)
            button.textColor = C.accentText
            y = y - ROW_HEIGHT - GAP
        else
            button:SetSize(columnWidth, ROW_HEIGHT)
            button:SetPoint("TOPLEFT", PAD + column * (columnWidth + GAP), y)
            button.textColor = nil
            column = column + 1
            if column == 2 then
                column = 0
                y = y - ROW_HEIGHT - GAP
            end
        end
        button:Show()
    end
    if column == 1 then y = y - ROW_HEIGHT - GAP end
    for index = used + 1, #self.targetButtons do
        self.targetButtons[index]:Hide()
    end

    local hasTargets = used > 0
    self.emptyText:SetShown(not hasTargets)
    self.selectedText:SetShown(hasTargets)

    local definitions = ns.GetButtons()
    local shownButtons = hasTargets and #definitions or 0
    for index = shownButtons + 1, #self.countButtons do
        self.countButtons[index]:Hide()
    end

    if hasTargets then
        y = y - 2
        self.selectedText:ClearAllPoints()
        self.selectedText:SetPoint("TOPLEFT", PAD, y)
        y = y - 14

        local callsTop = y
        -- As many buttons as the player made, in even rows of at most MAX_PER_ROW.
        local rows = math.ceil(shownButtons / MAX_PER_ROW)
        local perRow = math.ceil(shownButtons / rows)
        local index = 1
        while index <= shownButtons do
            local inRow = math.min(perRow, shownButtons - index + 1)
            local width = (WIDTH - 2 * PAD - (inRow - 1) * GAP) / inRow
            for slot = 0, inRow - 1 do
                local definition = definitions[index + slot]
                local button = AcquireCountButton(self, index + slot)
                button.definition = definition
                button.label:SetText(definition.text or "")
                button.textColor = (definition.danger and C.danger) or (definition.good and C.good) or nil
                button:SetSize(width, COUNT_HEIGHT)
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", PAD + slot * (width + GAP), y)
                button:Show()
            end
            index = index + inRow
            y = y - COUNT_HEIGHT - GAP
        end
        y = y + GAP

        -- The pause cover lies exactly over the call buttons.
        self.cooldown:ClearAllPoints()
        self.cooldown:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, callsTop)
        self.cooldown:SetSize(WIDTH - 2 * PAD, callsTop - y)
    else
        self.cooldown:Hide()
        self.emptyText:SetText(ns.bg and L.NO_TARGETS or L.NO_BG)
        y = y - math.max(28, self.emptyText:GetStringHeight() + 12)
    end

    y = y - 6
    self.linkBar:ClearAllPoints()
    self.linkBar:SetPoint("TOPLEFT", PAD - 4, y)
    y = y - 16 - 5

    frame:SetHeight(-y)

    -- Give every base button the finished macros and the call buttons to write them to.
    for targetIndex = 1, used do
        local targetButton = self.targetButtons[targetIndex]
        targetButton:SetAttribute("count", shownButtons)
        for index = 1, shownButtons do
            targetButton:SetAttribute("macro" .. index, ns.MacroText(targetButton.target, definitions[index]))
            SecureHandlerSetFrameRef(targetButton, "call" .. index, self.countButtons[index])
        end
    end
    self:ApplySelection()
    self:UpdateStates()
end

--- Writes the macros of the selected base into the call buttons. Out of combat only: in
--- combat the click on a base button does the same through its secure snippet.
function UI:ApplySelection()
    if not self.frame or InCombatLockdown() then return false end
    for _, button in ipairs(self.countButtons) do
        local macro = ""
        if ns.selected and button.definition and button:IsShown() then
            macro = ns.MacroText(ns.selected, button.definition)
        end
        button:SetAttribute("macrotext", macro)
    end
    return true
end

--- Updates the highlight of the selected base and the "you are here" mark.
function UI:UpdateStates()
    if not self.frame then return end
    for _, button in ipairs(self.targetButtons) do
        if button:IsShown() then
            button.selected = button.target == ns.selected
            button.near:SetShown(button.target == ns.nearTarget)
            button.tooltip = button.target == ns.nearTarget and L.TIP_NEAR or nil
            button:Paint()
        end
    end
    for _, button in ipairs(self.countButtons) do
        button:Paint()
    end
    self.linkBar:Relabel()

    if ns.selected then
        self.selectedText:SetText(L.SELECTED:format(ns.TargetName(ns.selected, ns.callLang) or ""))
        self.selectedText:SetTextColor(unpack(C.accentText))
    else
        self.selectedText:SetText(L.SELECT_FIRST)
        self.selectedText:SetTextColor(unpack(C.textFaint))
    end
end

--- Covers the call buttons for the pause set in the options.
function UI:StartCooldown()
    local seconds = ns.db.cooldown or 0
    if seconds <= 0 or not self.cooldown then return end
    self.cooldown.duration = seconds
    self.cooldown.ends = GetTime() + seconds
    self.cooldown:Show()
end

--- Opacity and size from the options.
function UI:ApplyStyle()
    local frame = self.frame
    if not frame then return end
    frame.bg:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], ns.db.opacity)
    ns.AfterCombat("scale", function() frame:SetScale(ns.db.scale) end)
    self:UpdateStates()
end

--[[
The window holds secure buttons, so the game does not let addon code show, hide, move or
resize it in combat. These actions wait for the end of combat and say so.
]]
local function WhenOutOfCombat(key, action)
    if not ns.AfterCombat(key, action) then ns.Print(L.AFTER_COMBAT) end
end

function UI:ResetPosition()
    ns.db.position = nil
    WhenOutOfCombat("position", function() RestorePosition(self.frame) end)
end

function UI:Show()
    WhenOutOfCombat("visibility", function() self.frame:Show() end)
end

function UI:Hide()
    WhenOutOfCombat("visibility", function()
        self.frame:Hide()
        -- Closing the window also ends the demo.
        if ns.testMode then ns.SetTestMode(nil) end
    end)
end

function UI:Toggle()
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end
