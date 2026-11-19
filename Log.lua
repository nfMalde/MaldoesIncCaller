local ADDON, ns = ...

--[[
Error handling and logs.

  ns.Safe(fn)        wraps a function: an error inside is caught, recorded with its stack and
                     reported once, and the rest of the addon keeps running
  ns.NewFrame(...)   CreateFrame whose SetScript/HookScript wrap every handler with ns.Safe
  ns.After(s, fn)    C_Timer.After with ns.Safe
  ns.Debug(...)      a line for the log; also printed to chat while debug mode is on
  ns.Warn(...)       the same for something that went wrong but was handled
  ns.ShowReport()    a window with a report (version, settings, errors, log) to copy into a
                     GitHub issue

The log and the errors are kept in the saved settings, so a report can still be made after a
reload or the next login. The report contains no character or account names and no own phrases.
]]

local MAX_LINES = 200
local MAX_ERRORS = 20
local REPORT_LINES = 80

local lines = {} -- the log; becomes MaldoesIncCallerDB.log once the settings are loaded
local errors = {} -- distinct errors; becomes MaldoesIncCallerDB.errors
local announced = {} -- errors already reported in this session
local inErrorHandler = false

local function Text(value)
    if issecretvalue ~= nil and issecretvalue(value) then return "<secret>" end
    return tostring(value)
end

local function Join(...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[index] = Text((select(index, ...)))
    end
    return table.concat(parts, " ")
end

local function AddLine(level, text)
    lines[#lines + 1] = date("%H:%M:%S") .. " " .. level .. " " .. text
    while #lines > MAX_LINES do
        table.remove(lines, 1)
    end
end

local function DebugEnabled()
    return ns.db ~= nil and ns.db.debug == true
end

function ns.Debug(...)
    local text = Join(...)
    AddLine("DBG", text)
    if DebugEnabled() then
        DEFAULT_CHAT_FRAME:AddMessage("|cff7d7166Inc Caller debug:|r |cffb9ada1" .. text .. "|r")
    end
end

function ns.Warn(...)
    local text = Join(...)
    AddLine("WRN", text)
    if DebugEnabled() then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffa463Inc Caller warning:|r " .. text)
    end
end

-- ---------------------------------------------------------------------------
-- Errors
-- ---------------------------------------------------------------------------

local function RecordError(message, stack)
    local now = date("%Y-%m-%d %H:%M:%S")
    local entry
    for _, known in ipairs(errors) do
        if known.message == message then
            entry = known
            break
        end
    end
    if entry then
        entry.count = (entry.count or 1) + 1
        entry.last = now
    else
        entry = { message = message, stack = stack, count = 1, first = now, last = now }
        errors[#errors + 1] = entry
        while #errors > MAX_ERRORS do
            table.remove(errors, 1)
        end
        AddLine("ERR", message)
    end

    -- Tell the player once per error and session, not on every frame.
    if not announced[message] then
        announced[message] = true
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8a3dMaldö's Inc Caller|r: |cfffb4868" .. ns.L.ERROR_CAPTURED .. "|r")
        -- Also hand it to the game's own error handler (the error window, BugSack and the like).
        local handler = geterrorhandler and geterrorhandler()
        if type(handler) == "function" then pcall(handler, message) end
    end
end

local function OnError(err)
    local message = Text(err)
    -- An error while recording an error must not loop.
    if inErrorHandler then return message end
    inErrorHandler = true
    local stack = ""
    if debugstack then
        local ok, result = pcall(debugstack, 2, 14, 0)
        if ok and type(result) == "string" then stack = result end
    end
    pcall(RecordError, message, stack)
    inErrorHandler = false
    return message
end

local function Finish(ok, ...)
    if ok then return ... end
    return nil
end

--- Returns fn wrapped so that an error is caught and recorded instead of breaking the caller.
function ns.Safe(fn)
    if type(fn) ~= "function" then return fn end
    return function(...)
        return Finish(xpcall(fn, OnError, ...))
    end
end

--- Records an error that was caught elsewhere (for example by pcall).
function ns.ReportError(message)
    pcall(RecordError, Text(message), "")
end

local function Protect(frame)
    local setScript, hookScript = frame.SetScript, frame.HookScript
    frame.SetScript = function(self, script, handler)
        return setScript(self, script, ns.Safe(handler))
    end
    frame.HookScript = function(self, script, handler)
        return hookScript(self, script, ns.Safe(handler))
    end
    return frame
end

--- CreateFrame for all frames of the addon: every script handler set later is error-safe.
function ns.NewFrame(...)
    return Protect(CreateFrame(...))
end

function ns.After(seconds, fn)
    C_Timer.After(seconds, ns.Safe(fn))
end

-- ---------------------------------------------------------------------------
-- Settings, report
-- ---------------------------------------------------------------------------

local function AddonVersion()
    local read = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ok, version = pcall(read, ADDON, "Version")
    return ok and version or "?"
end

--- Called once the saved settings are loaded: continues the log of the last session.
function ns.InitLog()
    local db = ns.db
    local early = lines
    lines = type(db.log) == "table" and db.log or {}
    db.log = lines
    local version, build, _, interface = GetBuildInfo()
    AddLine("---", "session " .. date("%Y-%m-%d") .. ", addon " .. AddonVersion() .. ", client "
        .. Text(version) .. " (" .. Text(build) .. ") interface " .. Text(interface))
    if early ~= lines then
        for _, line in ipairs(early) do
            lines[#lines + 1] = line
        end
    end
    while #lines > MAX_LINES do
        table.remove(lines, 1)
    end

    local earlyErrors = errors
    errors = type(db.errors) == "table" and db.errors or {}
    db.errors = errors
    -- Errors of an older version say nothing about this one: start clean after an update.
    if db.errorsVersion ~= AddonVersion() then
        wipe(errors)
        db.errorsVersion = AddonVersion()
    end
    for _, entry in ipairs(earlyErrors) do
        errors[#errors + 1] = entry
    end
end

function ns.ClearLog()
    wipe(lines)
    wipe(errors)
    wipe(announced)
end

function ns.ErrorCount()
    return #errors
end

local function Try(fn, ...)
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h end
    return nil
end

--- The report as Markdown, ready for a GitHub issue. Always English.
function ns.BuildReport()
    local db = ns.db or {}
    local out = {}
    local function add(text) out[#out + 1] = text end

    local version, build, _, interface = GetBuildInfo()
    add("### Maldö's Inc Caller report")
    add("")
    add("- Addon: " .. AddonVersion())
    add("- Client: " .. Text(version) .. " (" .. Text(build) .. "), interface " .. Text(interface)
        .. ", project " .. Text(WOW_PROJECT_ID) .. ", locale " .. Text(GetLocale()))
    add("- Date: " .. date("%Y-%m-%d %H:%M:%S"))
    add("- Settings: language " .. Text(db.language) .. ", call language " .. Text(db.callLanguage)
        .. ", channel " .. Text(db.channel) .. ", opacity " .. Text(db.opacity) .. ", scale " .. Text(db.scale)
        .. ", buttons " .. (type(db.buttons) == "table" and (#db.buttons .. " (own)") or "default")
        .. ", own phrases " .. ((db.template or db.flagTemplate) and "yes" or "no")
        .. ", pause " .. Text(db.cooldown) .. ", deselect " .. (db.deselect and Text(db.deselectRange) or "off")
        .. ", debug " .. (db.debug and "on" or "off"))

    local _, instanceType, _, _, _, _, _, instanceID = Try(GetInstanceInfo)
    local mapID = C_Map and C_Map.GetBestMapForUnit and Try(C_Map.GetBestMapForUnit, "player")
    local group = "none"
    if Try(IsInGroup, LE_PARTY_CATEGORY_INSTANCE) then
        group = "battleground"
    elseif Try(IsInRaid) then
        group = "raid"
    elseif Try(IsInGroup) then
        group = "party"
    end
    add("- Where: instance type " .. Text(instanceType) .. ", instance " .. Text(instanceID) .. ", map " .. Text(mapID)
        .. ", group " .. group .. ", bases " .. #(ns.targets or {}) .. (ns.testMode and ", demo" or ""))
    add("")

    add("#### Errors (" .. #errors .. ")")
    add("")
    if #errors == 0 then
        add("No errors recorded.")
    else
        add("```")
        for index, entry in ipairs(errors) do
            add(index .. ". x" .. Text(entry.count) .. ", first " .. Text(entry.first) .. ", last " .. Text(entry.last))
            add(Text(entry.message))
            if entry.stack and entry.stack ~= "" then add((entry.stack:gsub("%s+$", ""))) end
            add("")
        end
        add("```")
    end
    add("")

    local first = math.max(1, #lines - REPORT_LINES + 1)
    add("#### Log (last " .. (#lines - first + 1) .. " lines)")
    add("")
    add("```")
    for index = first, #lines do
        add(lines[index])
    end
    add("```")
    return table.concat(out, "\n")
end

local reportFrame

--- Shows the report in a window to copy (Ctrl+A, Ctrl+C).
function ns.ShowReport()
    local L, C = ns.L, ns.colors
    if not reportFrame then
        local frame = ns.NewFrame("Frame", "MaldoesIncCallerReportFrame", UIParent)
        frame:SetSize(600, 420)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:SetClampedToScreen(true)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:Hide()

        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], 0.97)
        ns.AddBorder(frame)

        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.title:SetPoint("TOPLEFT", 12, -10)
        frame.title:SetTextColor(C.accentText[1], C.accentText[2], C.accentText[3])

        frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        frame.hint:SetPoint("TOPLEFT", 12, -30)
        frame.hint:SetPoint("TOPRIGHT", -12, -30)
        frame.hint:SetJustifyH("LEFT")
        frame.hint:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])

        local scroll = ns.NewFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -62)
        scroll:SetPoint("BOTTOMRIGHT", -32, 42)

        local box = ns.NewFrame("EditBox", nil, scroll)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetFontObject("ChatFontNormal")
        box:SetWidth(550)
        box:SetMaxLetters(0)
        box:SetScript("OnEscapePressed", function() frame:Hide() end)
        scroll:SetScrollChild(box)
        frame.box = box

        local function SelectAll()
            box:SetFocus()
            box:HighlightText()
        end

        frame.selectAll = ns.CreateFlatButton(frame, "", 150, 22)
        frame.selectAll.solid = true
        frame.selectAll:SetPoint("BOTTOMLEFT", 12, 10)
        frame.selectAll:SetScript("OnClick", SelectAll)

        frame.clear = ns.CreateFlatButton(frame, "", 150, 22)
        frame.clear.solid = true
        frame.clear:SetPoint("LEFT", frame.selectAll, "RIGHT", 6, 0)
        frame.clear:SetScript("OnClick", function()
            ns.ClearLog()
            box:SetText(ns.BuildReport())
            ns.Print(ns.L.LOG_CLEARED)
        end)

        frame.close = ns.CreateFlatButton(frame, "", 110, 22)
        frame.close.solid = true
        frame.close:SetPoint("BOTTOMRIGHT", -12, 10)
        frame.close:SetScript("OnClick", function() frame:Hide() end)

        frame.SelectAll = SelectAll
        reportFrame = frame
    end

    reportFrame.title:SetText(L.LOG_TITLE)
    reportFrame.hint:SetText(L.LOG_HINT)
    reportFrame.selectAll.label:SetText(L.LOG_SELECT_ALL)
    reportFrame.clear.label:SetText(L.LOG_CLEAR)
    reportFrame.close.label:SetText(L.LOG_CLOSE)
    reportFrame.selectAll:Paint()
    reportFrame.clear:Paint()
    reportFrame.close:Paint()
    reportFrame.box:SetText(ns.BuildReport())
    reportFrame:Show()
    reportFrame.SelectAll()
end
