local _, ns = ...
local L = ns.L
local C = ns.colors

local Options = {}
ns.Options = Options

local LEFT = 16
local LABEL_WIDTH = 190
local CONTENT_WIDTH = 620

-- Everything with a text, so a language change can relabel the page without a reload.
local texts = {}
local refreshers = {}

local function Text(parent, key, font, color)
    local fontString = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fontString:SetJustifyH("LEFT")
    if color then fontString:SetTextColor(color[1], color[2], color[3]) end
    texts[#texts + 1] = { fontString = fontString, key = key }
    fontString:SetText(L[key])
    return fontString
end

local function Relabel()
    for _, entry in ipairs(texts) do
        if entry.fontString then
            entry.fontString:SetText(L[entry.key])
        else
            entry.button.label:SetText(L[entry.key])
        end
    end
    for _, refresh in ipairs(refreshers) do
        refresh()
    end
end

local function Button(parent, key, width)
    local button = ns.CreateFlatButton(parent, L[key], width, 22)
    button.solid = true
    button:Paint()
    texts[#texts + 1] = { button = button, key = key }
    return button
end

--- A row of buttons of which one is active (like the DE | EN switch in GT Toolz).
local function Segmented(parent, items, width, get, set)
    local group = ns.NewFrame("Frame", nil, parent)
    group:SetSize(#items * (width + 2), 22)
    local buttons = {}
    local function Refresh()
        local current = get()
        for _, button in ipairs(buttons) do
            button.selected = button.value == current
            button:Paint()
        end
    end
    for index, item in ipairs(items) do
        local button
        if item.key then
            button = Button(group, item.key, width)
        else
            button = ns.CreateFlatButton(group, item.text, width, 22)
            button.solid = true
        end
        button.value = item.value
        button:SetPoint("LEFT", (index - 1) * (width + 2), 0)
        button:SetScript("OnClick", function(self)
            set(self.value)
            Refresh()
        end)
        buttons[index] = button
    end
    refreshers[#refreshers + 1] = Refresh
    Refresh()
    return group
end

local function Checkbox(parent, key, get, set)
    local check = ns.NewFrame("Button", nil, parent)
    check:SetSize(300, 20)

    local box = check:CreateTexture(nil, "BACKGROUND")
    box:SetSize(16, 16)
    box:SetPoint("LEFT")
    box:SetColorTexture(C.surface[1], C.surface[2], C.surface[3], 1)
    local mark = check:CreateTexture(nil, "ARTWORK")
    mark:SetSize(10, 10)
    mark:SetPoint("CENTER", box, "CENTER")
    mark:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)

    local label = Text(check, key, "GameFontHighlightSmall", C.text)
    label:SetPoint("LEFT", box, "RIGHT", 8, 0)

    local function Refresh() mark:SetShown(get() and true or false) end
    check:SetScript("OnClick", function()
        set(not get())
        Refresh()
    end)
    refreshers[#refreshers + 1] = Refresh
    Refresh()
    return check
end

local function Slider(parent, minimum, maximum, step, get, set, format)
    local slider = ns.NewFrame("Slider", nil, parent)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(200, 16)
    slider:EnableMouse(true)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    track:SetColorTexture(C.surfaceHover[1], C.surfaceHover[2], C.surfaceHover[3], 1)

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(10, 16)
    thumb:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    slider:SetThumbTexture(thumb)

    local value = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("LEFT", slider, "RIGHT", 10, 0)
    value:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])

    slider:SetValue(get())
    value:SetText(format(get()))
    slider:SetScript("OnValueChanged", function(_, raw)
        local rounded = math.floor(raw / step + 0.5) * step
        set(rounded)
        value:SetText(format(rounded))
    end)
    return slider
end

local function Input(parent, width, maxLetters)
    local box = ns.NewFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetAutoFocus(false)
    box:SetSize(width, 20)
    box:SetMaxLetters(maxLetters)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    return box
end

local function Percent(value)
    return string.format("%d%%", math.floor(value * 100 + 0.5))
end

--- Builds the page the first time it is shown.
local function Build(panel)
    local db = ns.db
    local y = -16

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("TOPLEFT", LEFT, y)
    icon:SetTexture(ns.mediaPath .. "inccaller-icon")

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    title:SetText("|cffffa463Maldö's|r Inc Caller")

    local subtitle = Text(panel, "OPT_SUBTITLE", "GameFontHighlightSmall", C.textDim)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    y = y - 52

    local function Section(key)
        local header = Text(panel, key, "GameFontNormal", C.accentText)
        header:SetPoint("TOPLEFT", LEFT, y)
        y = y - 20
    end

    local function Row(key, control, height)
        local label = Text(panel, key, "GameFontHighlightSmall", C.text)
        label:SetPoint("TOPLEFT", LEFT, y - 4)
        label:SetWidth(LABEL_WIDTH)
        control:SetPoint("TOPLEFT", LEFT + LABEL_WIDTH, y)
        y = y - (height or 26)
    end

    -- Language
    Section("OPT_LANGUAGE")
    Row("OPT_UI_LANGUAGE", Segmented(panel, {
        { key = "OPT_AUTO", value = "auto" },
        { text = "English", value = "en" },
        { text = "Deutsch", value = "de" },
    }, 110, function() return db.language end, function(value)
        db.language = value
        ns.ApplyLanguage()
        Relabel()
        ns.UI:Refresh()
    end))
    Row("OPT_CALL_LANGUAGE", Segmented(panel, {
        { key = "OPT_SAME_AS_MENU", value = "ui" },
        { text = "English", value = "en" },
        { text = "Deutsch", value = "de" },
    }, 110, function() return db.callLanguage end, function(value)
        db.callLanguage = value
        ns.ApplyLanguage()
        Relabel()
        ns.UI:Refresh()
    end))
    y = y - 8

    -- Window
    Section("OPT_WINDOW")
    Row("OPT_OPACITY", Slider(panel, 0.1, 1, 0.05, function() return db.opacity end, function(value)
        db.opacity = value
        ns.UI:ApplyStyle()
    end, Percent))
    Row("OPT_SCALE", Slider(panel, 0.7, 1.5, 0.05, function() return db.scale end, function(value)
        db.scale = value
        ns.UI:ApplyStyle()
    end, Percent))

    local lock = Checkbox(panel, "OPT_LOCK", function() return db.locked end, function(value) db.locked = value end)
    lock:SetPoint("TOPLEFT", LEFT, y)
    local show = Button(panel, "OPT_SHOW", 150)
    show:SetPoint("TOPLEFT", LEFT + 330, y)
    show:SetScript("OnClick", function() ns.UI:Show() end)
    y = y - 24
    local autoShow = Checkbox(panel, "OPT_AUTOSHOW", function() return db.autoShow end,
        function(value) db.autoShow = value end)
    autoShow:SetPoint("TOPLEFT", LEFT, y)
    local resetPosition = Button(panel, "OPT_RESET_POS", 150)
    resetPosition:SetPoint("TOPLEFT", LEFT + 330, y)
    resetPosition:SetScript("OnClick", function()
        ns.UI:ResetPosition()
        ns.UI:Show()
    end)
    y = y - 32

    Row("OPT_CHANNEL", Segmented(panel, {
        { key = "OPT_CH_AUTO", value = "auto" },
        { key = "OPT_CH_INSTANCE", value = "instance" },
        { key = "OPT_CH_RAID", value = "raid" },
        { key = "OPT_CH_PARTY", value = "party" },
    }, 96, function() return db.channel end, function(value)
        db.channel = value
        ns.UI:Refresh()
    end))
    Row("OPT_COOLDOWN", Slider(panel, 0, 10, 1, function() return db.cooldown end, function(value)
        db.cooldown = value
    end, function(value)
        if value <= 0 then return L.OPT_COOLDOWN_OFF end
        return string.format("%d s", value)
    end))

    local deselect = Checkbox(panel, "OPT_DESELECT", function() return db.deselect end,
        function(value) db.deselect = value end)
    deselect:SetPoint("TOPLEFT", LEFT, y)
    y = y - 26
    Row("OPT_DESELECT_RANGE", Slider(panel, 1, 4, 0.5, function() return db.deselectRange end, function(value)
        db.deselectRange = value
    end, function(value)
        return string.format("%.1f x", value)
    end))
    y = y - 8

    -- Phrases
    Section("OPT_PHRASES")
    local hint = Text(panel, "OPT_PHRASES_HINT", "GameFontHighlightSmall", C.textDim)
    hint:SetPoint("TOPLEFT", LEFT, y)
    y = y - 20

    local preview = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    preview:SetJustifyH("LEFT")
    preview:SetTextColor(C.accentText[1], C.accentText[2], C.accentText[3])
    -- The preview shows the phrase or button that was edited last.
    local previewFlag = false
    local previewIndex = 2
    local function UpdatePreview()
        local sample = ns.DemoBattleground.targets[1]
        if previewFlag then sample = ns.DemoFlagBattleground.targets[1] end
        local buttons = ns.GetButtons()
        preview:SetText(L.OPT_PREVIEW:format(ns.BuildMessage(sample, buttons[previewIndex] or buttons[1])))
    end

    local function TemplateBox(field, isFlag)
        local box = Input(panel, 380, 120)
        box:SetText(db[field] or ns.defaults[field])
        box:SetScript("OnTextChanged", function(self, userInput)
            if not userInput then return end
            local value = ns.Trim(self:GetText())
            db[field] = value ~= "" and value or nil
            previewFlag = isFlag
            -- The phrases are part of the macros on the call buttons.
            ns.UI:Refresh()
            UpdatePreview()
        end)
        box:SetScript("OnEditFocusGained", function()
            previewFlag = isFlag
            UpdatePreview()
        end)
        box:SetScript("OnEditFocusLost", function(self)
            -- An empty box means "use the default": show it again.
            if not db[field] then self:SetText(ns.defaults[field]) end
        end)
        return box
    end

    local templateBox = TemplateBox("template", false)
    Row("OPT_TEMPLATE", templateBox)
    templateBox:SetPoint("TOPLEFT", LEFT + LABEL_WIDTH + 6, y + 26)
    local flagBox = TemplateBox("flagTemplate", true)
    Row("OPT_FLAG_TEMPLATE", flagBox)
    flagBox:SetPoint("TOPLEFT", LEFT + LABEL_WIDTH + 6, y + 26)

    preview:SetPoint("TOPLEFT", LEFT, y - 2)
    preview:SetWidth(CONTENT_WIDTH - 2 * LEFT)
    preview:SetWordWrap(false)
    y = y - 28

    -- Buttons: a list that grows, so everything below it hangs on its lower edge.
    Section("OPT_BUTTONS")
    local buttonsHint = Text(panel, "OPT_BUTTONS_HINT", "GameFontHighlightSmall", C.textDim)
    buttonsHint:SetPoint("TOPLEFT", LEFT, y)
    buttonsHint:SetWidth(CONTENT_WIDTH - 2 * LEFT)
    y = y - 32

    local TEXT_X, PHRASE_X, REMOVE_X = LEFT + 6, LEFT + 126, LEFT + 500
    local ROW_STEP = 26
    local listTop = y
    local list = ns.NewFrame("Frame", nil, panel)
    list:SetPoint("TOPLEFT", 0, listTop)
    list:SetSize(CONTENT_WIDTH, 60)

    local textHeader = Text(list, "OPT_BUTTON_TEXT", "GameFontHighlightSmall", C.textFaint)
    textHeader:SetPoint("TOPLEFT", TEXT_X - 6, 0)
    local phraseHeader = Text(list, "OPT_BUTTON_PHRASE", "GameFontHighlightSmall", C.textFaint)
    phraseHeader:SetPoint("TOPLEFT", PHRASE_X - 6, 0)

    local addButton = Button(list, "OPT_ADD_BUTTON", 170)
    local resetPhrases = Button(list, "OPT_RESET_PHRASES", 250)
    resetPhrases:SetPoint("LEFT", addButton, "RIGHT", 8, 0)

    local support = ns.NewFrame("Frame", nil, panel)
    support:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -14)
    support:SetSize(CONTENT_WIDTH, 134)

    local rows = {}
    local RebuildRows

    local function AcquireRow(index)
        local row = rows[index]
        if row then return row end

        row = ns.NewFrame("Frame", nil, list)
        row:SetSize(CONTENT_WIDTH, 22)

        row.text = Input(row, 100, 24)
        row.text:SetPoint("LEFT", TEXT_X, 0)
        row.text:SetScript("OnTextChanged", function(self, userInput)
            if not userInput then return end
            local value = ns.Trim(self:GetText())
            -- A button needs a text: an empty box changes nothing and is refilled on leaving.
            if value == "" then return end
            ns.GetOwnButtons()[row.index].text = value
            previewIndex = row.index
            ns.UI:Refresh()
            UpdatePreview()
        end)
        row.text:SetScript("OnEditFocusLost", function(self)
            local button = ns.GetButtons()[row.index]
            if button then self:SetText(button.text or "") end
        end)

        row.phrase = Input(row, 360, 120)
        row.phrase:SetPoint("LEFT", PHRASE_X, 0)
        row.phrase:SetScript("OnTextChanged", function(self, userInput)
            if not userInput then return end
            local value = ns.Trim(self:GetText())
            ns.GetOwnButtons()[row.index].phrase = value ~= "" and value or nil
            previewIndex = row.index
            ns.UI:Refresh()
            UpdatePreview()
        end)

        local function Focused()
            previewIndex = row.index
            UpdatePreview()
        end
        row.text:SetScript("OnEditFocusGained", Focused)
        row.phrase:SetScript("OnEditFocusGained", Focused)

        row.remove = ns.CreateFlatButton(row, "x", 22, 20)
        row.remove.solid = true
        row.remove.textColor = C.danger
        row.remove:SetPoint("LEFT", REMOVE_X, 0)
        row.remove:SetScript("OnClick", function()
            local own = ns.GetOwnButtons()
            if #own <= 1 then return end
            table.remove(own, row.index)
            RebuildRows()
        end)

        rows[index] = row
        return row
    end

    RebuildRows = function()
        local buttons = ns.GetButtons()
        for index, button in ipairs(buttons) do
            local row = AcquireRow(index)
            row.index = index
            row.text:ClearFocus()
            row.phrase:ClearFocus()
            row.text:SetText(button.text or "")
            row.phrase:SetText(button.phrase or "")
            row.remove.tooltip = L.OPT_REMOVE_BUTTON
            -- The last button cannot be removed.
            row.remove:SetShown(#buttons > 1)
            row.remove:Paint()
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -(16 + (index - 1) * ROW_STEP))
            row:Show()
        end
        for index = #buttons + 1, #rows do
            rows[index]:Hide()
        end

        local listHeight = 16 + #buttons * ROW_STEP + 6
        addButton:ClearAllPoints()
        addButton:SetPoint("TOPLEFT", LEFT, -listHeight)
        listHeight = listHeight + 22
        list:SetHeight(listHeight)
        panel:SetHeight(-listTop + listHeight + 14 + 134 + 16)

        if previewIndex > #buttons then previewIndex = #buttons end
        ns.UI:Refresh()
        UpdatePreview()
    end

    addButton:SetScript("OnClick", function()
        local own = ns.GetOwnButtons()
        own[#own + 1] = { text = L.OPT_NEW_BUTTON }
        previewIndex = #own
        RebuildRows()
    end)

    resetPhrases:SetScript("OnClick", function()
        db.template = nil
        db.flagTemplate = nil
        db.buttons = nil
        templateBox:ClearFocus()
        flagBox:ClearFocus()
        templateBox:SetText(ns.defaults.template)
        flagBox:SetText(ns.defaults.flagTemplate)
        previewIndex = 2
        RebuildRows()
    end)

    -- Troubleshooting
    local diagnoseTitle = Text(support, "OPT_DIAGNOSE", "GameFontNormal", C.accentText)
    diagnoseTitle:SetPoint("TOPLEFT", LEFT, 0)
    local debug = Checkbox(support, "OPT_DEBUG", function() return db.debug end,
        function(value) ns.SetDebug(value) end)
    debug:SetPoint("TOPLEFT", LEFT, -20)
    local showLog = Button(support, "OPT_SHOW_LOG", 150)
    showLog:SetPoint("TOPLEFT", LEFT + 330, -20)
    showLog:SetScript("OnClick", function() ns.ShowReport() end)

    -- Support
    local supportTitle = Text(support, "OPT_SUPPORT", "GameFontNormal", C.accentText)
    supportTitle:SetPoint("TOPLEFT", LEFT, -58)
    local supportHint = Text(support, "OPT_SUPPORT_HINT", "GameFontHighlightSmall", C.textDim)
    supportHint:SetPoint("TOPLEFT", LEFT, -78)
    local linkBar = ns.CreateLinkBar(support, "medium")
    linkBar:SetPoint("TOPLEFT", LEFT, -98)

    refreshers[#refreshers + 1] = function()
        linkBar:Relabel()
        for _, row in ipairs(rows) do
            row.remove.tooltip = L.OPT_REMOVE_BUTTON
        end
        UpdatePreview()
    end
    RebuildRows()
end

function Options:Register()
    local panel = ns.NewFrame("Frame")
    panel.name = "Maldö's Inc Caller"
    -- The settings window calls these on some client versions; everything here saves at once.
    panel.OnCommit = function() end
    panel.OnDefault = function() end
    panel.OnRefresh = function() end
    panel:Hide()

    local built = false
    panel:SetScript("OnShow", function(self)
        if built then return end
        built = true
        -- The list of buttons can get long, so the page scrolls.
        local scroll = ns.NewFrame("ScrollFrame", nil, self, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 0, -4)
        scroll:SetPoint("BOTTOMRIGHT", -28, 4)
        local content = ns.NewFrame("Frame", nil, scroll)
        content:SetSize(CONTENT_WIDTH, 600)
        scroll:SetScrollChild(content)
        Build(content)
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        ns.settingsCategory = category
    end
end
