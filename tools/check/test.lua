local ns = __NS
local failures = 0
local lastErrors = 0

local function check(name, condition, detail)
    if condition then
        print("ok   " .. name)
    else
        failures = failures + 1
        print("FAIL " .. name .. (detail and (": " .. tostring(detail)) or ""))
    end
end

local function eq(name, got, want)
    check(name, got == want, ("got %s, want %s"):format(("%q"):format(tostring(got)), ("%q"):format(tostring(want))))
end

local function noErrors(step)
    local count = ns.ErrorCount()
    if count > lastErrors then
        failures = failures + 1
        print("FAIL errors after " .. step)
        print(ns.BuildReport())
        lastErrors = count
    else
        print("ok   no errors after " .. step)
    end
end

local function noViolations(step)
    if #VIOLATIONS > 0 then
        failures = failures + 1
        print("FAIL protected frames touched in combat after " .. step .. ": " .. table.concat(VIOLATIONS, "; "))
        VIOLATIONS = {}
    else
        print("ok   no protected frame touched in combat after " .. step)
    end
end

local function chatHas(text)
    for _, line in ipairs(CHAT) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

local function key(target) return target and target.key or nil end

local function targetButton(wanted)
    for _, button in ipairs(ns.UI.targetButtons) do
        if button:IsShown() and button.target and button.target.key == wanted then return button end
    end
    error("no base button " .. tostring(wanted))
end

--- A click on a call button as the player does it: the pause cover takes it while it is shown.
local function clickCall(index)
    if ns.UI.cooldown:IsShown() then return false end
    SecureClick(ns.UI.countButtons[index])
    return true
end

local function endPause()
    NOW = NOW + 60
    ns.UI.cooldown:Fire("OnUpdate", 0.1)
end

local function enter(definition)
    for field, value in pairs(definition) do BG[field] = value end
    FireEvent("PLAYER_ENTERING_WORLD")
    RunTimers()
end

local function leave()
    enter({ name = nil, type = "none", id = 0, map = 1415, subzone = "", markers = {}, x = false, y = false })
    BG.x, BG.y = nil, nil
end

local ARATHI = {
    name = "Arathibecken", type = "pvp", id = 529, map = 1461, subzone = "",
    markers = {
        { name = "Ställe", x = 0.37, y = 0.29 },
        { name = "Schmiede", x = 0.46, y = 0.45 },
        { name = "Sägewerk", x = 0.40, y = 0.56 },
        { name = "Goldmine", x = 0.57, y = 0.30 },
        { name = "Hof", x = 0.56, y = 0.58 },
    },
}

-- Load ------------------------------------------------------------------------
FireEvent("ADDON_LOADED", "SomeOtherAddon")
check("other addon ignored", ns.db == nil)
FireEvent("ADDON_LOADED", "MaldoesIncCaller")
noErrors("ADDON_LOADED")
check("db created", type(ns.db) == "table" and MaldoesIncCallerDB == ns.db)
eq("language de", ns.uiLang, "de")
eq("L lookup de", ns.L.LOG_CLOSE, "Schließen")
eq("L unknown key", ns.L.NO_SUCH_KEY, "NO_SUCH_KEY")
eq("default cooldown", ns.db.cooldown, 3)
eq("default deselect", ns.db.deselect, true)
eq("default deselect range", ns.db.deselectRange, 2)
check("options registered", OPTIONS_PANEL ~= nil and OPTIONS_PANEL.name == "Maldö's Inc Caller")
TEST_LOCALE = "frFR"
eq("unknown locale is English", ns.ResolveLanguage("auto"), "en")
eq("explicit language", ns.ResolveLanguage("de"), "de")
TEST_LOCALE = "deDE"

FireEvent("PLAYER_ENTERING_WORLD")
RunTimers()
noErrors("PLAYER_ENTERING_WORLD")
eq("no bases outside a battleground", #ns.targets, 0)
check("window hidden outside a battleground", not ns.UI.frame:IsShown())
eq("window title", ns.UI.title:GetText(), "Maldö's Inc Caller")

-- Messages ----------------------------------------------------------------------
local stables = ns.DemoBattleground.targets[1]
local buttons = ns.GetButtons()
eq("six default buttons", #buttons, 6)
eq("message", ns.BuildMessage(stables, buttons[2]), "*Inc call* Ställe 2 *INC*")
eq("message big", ns.BuildMessage(stables, buttons[5]), "*Inc call* Ställe Big *INC*")
eq("message clear", ns.BuildMessage(stables, buttons[6]), "*Clear call* Ställe *CLEAR*")
eq("message flag", ns.BuildMessage(ns.DemoFlagBattleground.targets[1], buttons[1]), "*Inc call* Flaggenträger 1 *INC*")
ns.db.template = "{base}  ||cffff0000{count}|r   inc"
eq("pipes and spaces removed", ns.BuildMessage(stables, buttons[1]), "Ställe cffff00001r inc")
ns.db.template = string.rep("x", 300)
eq("message cut to 240", #ns.BuildMessage(stables, buttons[1]), 240)
ns.db.template = "%1 {base} %d"
eq("percent signs are plain text", ns.BuildMessage(stables, buttons[1]), "%1 Ställe %d")
ns.db.template = nil
ns.db.callLanguage = "en"
ns.ApplyLanguage()
eq("call language en", ns.BuildMessage(stables, buttons[1]), "*Inc call* Stables 1 *INC*")
ns.db.callLanguage = "ui"
ns.ApplyLanguage()

-- Demo ------------------------------------------------------------------------
SlashCmdList.MALDOESINCCALLER("test")
noErrors("/inc test")
eq("demo bases", #ns.targets, 5)
check("demo shows the window", ns.UI.frame:IsShown())
GROUP = "party"
FireEvent("GROUP_ROSTER_UPDATE")
RunTimers()
eq("demo sends to the group", ns.ChatCommand(), "/p")
SecureClick(targetButton("stables"))
eq("demo selection", key(ns.selected), "stables")
eq("demo macro", ns.UI.countButtons[1]:GetAttribute("macrotext"), "/p *Inc call* Ställe 1 *INC*")
MACROS_RUN = {}
check("demo call clicked", clickCall(1))
eq("demo ran the macro", MACROS_RUN[1], "/p *Inc call* Ställe 1 *INC*")
check("demo call starts the pause", ns.UI.cooldown:IsShown())
endPause()
GROUP = "none"
FireEvent("GROUP_ROSTER_UPDATE")
RunTimers()
eq("demo without a group sends nothing", ns.ChatCommand(), nil)
eq("demo macro is empty without a group", ns.UI.countButtons[1]:GetAttribute("macrotext"), "")
CHAT = {}
MACROS_RUN = {}
check("demo preview clicked", clickCall(1))
eq("demo preview ran no macro", #MACROS_RUN, 0)
check("demo prints a preview", chatHas("*Inc call* Ställe 1 *INC*"))
check("no pause after a preview", not ns.UI.cooldown:IsShown())
SlashCmdList.MALDOESINCCALLER("test flag")
eq("flag demo bases", #ns.targets, 4)
check("flag demo has the carrier first", ns.targets[1].flag == true)
SlashCmdList.MALDOESINCCALLER("test darkspear")
eq("darkspear demo bases", #ns.targets, 6)
noErrors("demos")
SlashCmdList.MALDOESINCCALLER("")
check("slash hides the window", not ns.UI.frame:IsShown())
eq("hiding ends the demo", ns.testMode, nil)
eq("no bases after the demo", #ns.targets, 0)

-- Arathi Basin -----------------------------------------------------------------
GROUP = "instance"
LOCKDOWN = true
enter(ARATHI)
FireEvent("GROUP_ROSTER_UPDATE")
noErrors("entering Arathi")
eq("arathi bases", #ns.targets, 5)
check("window shown in a battleground", ns.UI.frame:IsShown())
eq("subtitle is the battleground", ns.UI.subtitle:GetText(), "Arathibecken")
local positioned = 0
for _, target in ipairs(ns.targets) do
    if target.x and target.y then positioned = positioned + 1 end
end
eq("positions from the map markers", positioned, 5)
eq("chat command", ns.ChatCommand(), "/i")
eq("nothing selected at first", ns.selected, nil)
eq("call buttons empty without a base", ns.UI.countButtons[1]:GetAttribute("macrotext"), "")
eq("base button carries the macros", targetButton("farm"):GetAttribute("macro2"), "/i *Inc call* Hof 2 *INC*")
eq("base button knows the count", targetButton("farm"):GetAttribute("count"), 6)

-- Near a base: selected automatically
BG.x, BG.y = 0.37, 0.30
ns.UpdateProximity()
eq("near base", key(ns.nearTarget), "stables")
eq("near base selected", key(ns.selected), "stables")
eq("call button filled", ns.UI.countButtons[3]:GetAttribute("macrotext"), "/i *Inc call* Ställe 3 *INC*")
eq("clear button filled", ns.UI.countButtons[6]:GetAttribute("macrotext"), "/i *Clear call* Ställe *CLEAR*")
eq("selected text", ns.UI.selectedText:GetText(), "Ansage für: Ställe")

-- A call, and the pause after it
MACROS_RUN = {}
check("call clicked", clickCall(3))
eq("the game ran the macro", MACROS_RUN[1], "/i *Inc call* Ställe 3 *INC*")
check("pause cover shown", ns.UI.cooldown:IsShown())
check("second click is taken by the cover", not clickCall(1))
eq("only one macro ran", #MACROS_RUN, 1)
NOW = NOW + 1
ns.UI.cooldown:Fire("OnUpdate", 0.1)
check("pause still running after 1 s", ns.UI.cooldown:IsShown())
endPause()
check("pause over", not ns.UI.cooldown:IsShown())
ns.db.cooldown = 0
check("call without pause", clickCall(1))
check("no cover with the pause off", not ns.UI.cooldown:IsShown())
CHAT = {}
check("fast second call", clickCall(2))
check("too fast is said", chatHas("Zu schnell"))
ns.db.cooldown = 3
NOW = NOW + 10
noErrors("calls")

-- Another base by hand
SecureClick(targetButton("farm"))
eq("manual selection", key(ns.selected), "farm")
eq("snippet rewrote the call buttons", ns.UI.countButtons[2]:GetAttribute("macrotext"), "/i *Inc call* Hof 2 *INC*")
ns.UpdateProximity()
eq("manual selection stays while the near base is the same", key(ns.selected), "farm")

-- Leaving a base ----------------------------------------------------------------
ns.UpdateProximity()
eq("a base picked from far away stays", key(ns.selected), "farm")
SecureClick(targetButton("stables"))
ns.UpdateProximity()
BG.x, BG.y = 0.37, 0.39 -- 0.10 away: not near any more (0.07), but inside twice that
ns.UpdateProximity()
eq("near mark gone", ns.nearTarget, nil)
eq("selection kept inside the range", key(ns.selected), "stables")
BG.x, BG.y = 0.22, 0.29 -- 0.15 away
ns.UpdateProximity()
eq("deselected when far away", ns.selected, nil)
eq("call buttons emptied", ns.UI.countButtons[1]:GetAttribute("macrotext"), "")
eq("text asks for a base", ns.UI.selectedText:GetText(), "Wähle zuerst eine Basis aus.")
MACROS_RUN = {}
CHAT = {}
check("call click without a base", clickCall(1))
eq("no macro without a base", #MACROS_RUN, 0)
check("says to select a base", chatHas("Wähle zuerst eine Basis aus."))

SecureClick(targetButton("farm"))
ns.UpdateProximity()
ns.UpdateProximity()
eq("far base picked by hand stays", key(ns.selected), "farm")

BG.x, BG.y = 0.37, 0.29
ns.UpdateProximity()
eq("selected again at the base", key(ns.selected), "stables")
ns.db.deselectRange = 1
BG.x, BG.y = 0.37, 0.39
ns.UpdateProximity()
eq("range 1 deselects as soon as the base is left", ns.selected, nil)
ns.db.deselectRange = 4
BG.x, BG.y = 0.37, 0.29
ns.UpdateProximity()
BG.x, BG.y = 0.12, 0.29 -- 0.25 away, inside 4 x 0.07
ns.UpdateProximity()
eq("range 4 keeps it longer", key(ns.selected), "stables")
ns.db.deselectRange = 2
ns.UpdateProximity()
eq("a smaller range applies at once", ns.selected, nil)

ns.db.deselect = false
BG.x, BG.y = 0.37, 0.29
ns.UpdateProximity()
BG.x, BG.y = 0.10, 0.10
ns.UpdateProximity()
eq("option off: selection stays", key(ns.selected), "stables")
ns.db.deselect = true
ns.UpdateProximity()
eq("option on again: deselected", ns.selected, nil)

-- The game does not say where the player is: nothing is dropped
BG.x, BG.y = 0.37, 0.29
ns.UpdateProximity()
BG.x, BG.y = nil, nil
ns.UpdateProximity()
eq("unknown position keeps the selection", key(ns.selected), "stables")
noErrors("leaving a base")

-- Combat ------------------------------------------------------------------------
BG.x, BG.y = 0.37, 0.29
ns.UpdateProximity()
COMBAT = true
BG.x, BG.y = 0.10, 0.10
ns.UpdateProximity()
ns.UpdateProximity()
eq("in combat the selection waits", key(ns.selected), "stables")
eq("in combat the call buttons stay", ns.UI.countButtons[1]:GetAttribute("macrotext"), "/i *Inc call* Ställe 1 *INC*")
BG.x, BG.y = 0.56, 0.58
ns.UpdateProximity()
eq("near mark changes in combat", key(ns.nearTarget), "farm")
eq("selection waits for the end of combat", key(ns.selected), "stables")
check("a call works in combat", clickCall(1))
endPause()
SecureClick(targetButton("goldmine"))
eq("manual selection in combat", key(ns.selected), "goldmine")
eq("snippet works in combat", ns.UI.countButtons[4]:GetAttribute("macrotext"), "/i *Inc call* Goldmine 4+ *INC*")
ns.UI:Refresh()
ns.UI:ApplyStyle()
CHAT = {}
ns.UI:Hide()
check("hiding in combat is announced", chatHas("Im Kampf nicht möglich"))
check("window still shown in combat", ns.UI.frame:IsShown())
ns.UI:Show()
ns.UI.frame:Fire("OnDragStart")
BG.markers[5] = nil
FireEvent("AREA_POIS_UPDATED")
RunTimers()
eq("bases are not rebuilt in combat", #ns.targets, 5)
SlashCmdList.MALDOESINCCALLER("options")
eq("options do not open in combat", OPENED_CATEGORY, nil)
noViolations("combat")
COMBAT = false
FireEvent("PLAYER_REGEN_ENABLED")
RunTimers()
noErrors("combat")
check("window shown after combat", ns.UI.frame:IsShown())
eq("manual selection survives the end of combat", key(ns.selected), "goldmine")
BG.markers[5] = { name = "Hof", x = 0.56, y = 0.58 }
FireEvent("AREA_POIS_UPDATED")
RunTimers()

-- Automatic selection that had to wait
BG.x, BG.y = 0.10, 0.10
ns.UpdateProximity()
COMBAT = true
BG.x, BG.y = 0.46, 0.45
ns.UpdateProximity()
eq("still the old selection in combat", key(ns.selected), "goldmine")
COMBAT = false
FireEvent("PLAYER_REGEN_ENABLED")
eq("near base selected after combat", key(ns.selected), "blacksmith")
eq("call buttons follow after combat", ns.UI.countButtons[1]:GetAttribute("macrotext"), "/i *Inc call* Schmiede 1 *INC*")

-- Left in combat: dropped when it ends
ns.UpdateProximity()
COMBAT = true
BG.x, BG.y = 0.10, 0.10
ns.UpdateProximity()
eq("left in combat: still selected", key(ns.selected), "blacksmith")
COMBAT = false
FireEvent("PLAYER_REGEN_ENABLED")
ns.UpdateProximity()
eq("left in combat: deselected afterwards", ns.selected, nil)
noViolations("selection in combat")
noErrors("selection in combat")

-- Group changes rewrite the macros ---------------------------------------------
SecureClick(targetButton("farm"))
GROUP = "raid"
FireEvent("GROUP_ROSTER_UPDATE")
eq("raid command", ns.UI.countButtons[1]:GetAttribute("macrotext"), "/raid *Inc call* Hof 1 *INC*")
ns.db.channel = "party"
ns.UI:Refresh()
eq("channel setting party", ns.UI.countButtons[1]:GetAttribute("macrotext"), "/p *Inc call* Hof 1 *INC*")
ns.db.channel = "instance"
ns.UI:Refresh()
eq("channel instance without such a group", ns.UI.countButtons[1]:GetAttribute("macrotext"), "")
ns.db.channel = "auto"
GROUP = "instance"
FireEvent("GROUP_ROSTER_UPDATE")
eq("instance command again", ns.UI.countButtons[1]:GetAttribute("macrotext"), "/i *Inc call* Hof 1 *INC*")

-- Own buttons -------------------------------------------------------------------
local own = ns.GetOwnButtons()
own[#own + 1] = { text = "Hilfe", phrase = "{base} braucht Hilfe" }
ns.UI:Refresh()
eq("seven buttons", ns.UI.countButtons[7]:GetAttribute("macrotext"), "/i Hof braucht Hilfe")
check("seventh button shown", ns.UI.countButtons[7]:IsShown())
ns.db.buttons = nil
ns.UI:Refresh()
check("seventh button hidden again", not ns.UI.countButtons[7]:IsShown())
eq("hidden button sends nothing", ns.UI.countButtons[7]:GetAttribute("macrotext"), "")
noErrors("own buttons")

-- Bases known by subzone only -----------------------------------------------------
leave()
check("window hidden after the battleground", not ns.UI.frame:IsShown())
eq("selection gone after the battleground", ns.selected, nil)
enter({ name = "Arathibecken", type = "pvp", id = 529, map = 1461, subzone = "", markers = {} })
eq("arathi without markers", #ns.targets, 5)
BG.x, BG.y = 0.5, 0.5
BG.subzone = "Ställe"
ns.UpdateProximity()
eq("near by subzone", key(ns.selected), "stables")
BG.subzone = "Arathibecken"
ns.UpdateProximity()
eq("without a position the subzone decides", ns.selected, nil)
BG.subzone = SECRET
ns.UpdateProximity()
noErrors("secret subzone")
BG.subzone = ""

-- Warsong Gulch: flag carrier and estimated positions -----------------------------
leave()
enter({ name = "Kriegshymnenschlucht", type = "pvp", id = 489, map = 1460, subzone = "", markers = {} })
eq("warsong bases", #ns.targets, 4)
BG.x, BG.y = 0.50, 0.15
ns.UpdateProximity()
eq("warsong near base", key(ns.selected), "alliance")
SecureClick(targetButton("fc"))
eq("flag carrier macro", ns.UI.countButtons[1]:GetAttribute("macrotext"), "/i *Inc call* Flaggenträger 1 *INC*")
BG.x, BG.y = 0.50, 0.50
ns.UpdateProximity()
eq("moving on selects the next base", key(ns.selected), "mid")
SecureClick(targetButton("fc"))
ns.UpdateProximity()
BG.x, BG.y = nil, nil
ns.UpdateProximity()
eq("the flag carrier is never dropped", key(ns.selected), "fc")
ns.db.flagTemplate = "FC {count}"
ns.UI:Refresh()
eq("own flag phrase", ns.UI.countButtons[2]:GetAttribute("macrotext"), "/i FC 2")
ns.db.flagTemplate = nil

-- Darkspear Islands by ID and by name; an unknown battleground ----------------------
local DARKSPEAR_MARKERS = {
    { name = "Camp", x = 0.42, y = 0.62 },
    { name = "Ruins", x = 0.61, y = 0.62 },
    { name = "Abandoned Tower", x = 0.62, y = 0.45 },
    { name = "Shipwreck Cove", x = 0.41, y = 0.43 },
    { name = "Darkspear Flag", x = 0.51, y = 0.52 },
}
leave()
enter({ name = "Darkspear Islands", type = "pvp", id = 2997, map = 2524, markers = DARKSPEAR_MARKERS })
eq("darkspear bases", #ns.targets, 6)
eq("darkspear position from the marker", targetButton("camp").target.x, 0.42)
eq("flag marker belongs to the middle", targetButton("mid").target.y, 0.52)
leave()
enter({ name = "Darkspear Islands", type = "pvp", id = 4711, map = 2524, markers = DARKSPEAR_MARKERS })
eq("darkspear by name", #ns.targets, 6)
leave()
enter({ name = "Neues Schlachtfeld", type = "pvp", id = 4712, map = 9999, markers = {
    { name = "Südturm", x = 0.5, y = 0.8 },
    { name = "Nordturm", x = 0.5, y = 0.2 },
    { name = SECRET, x = 0.1, y = 0.1 },
    { name = "Nordturm", x = 0.5, y = 0.2 },
} })
eq("unknown battleground uses its markers", #ns.targets, 2)
eq("markers sorted north to south", ns.targets[1].name, "Nordturm")
eq("marker name is sent as it is", ns.UI.targetButtons[2]:GetAttribute("macro1"), "/i *Inc call* Südturm 1 *INC*")
leave()
enter({ name = "Alteractal", type = "pvp", id = 30, map = 1459, markers = {} })
eq("alterac fallback list", #ns.targets, 17)
leave()
noErrors("battlegrounds")
noViolations("battlegrounds")

-- Options page ------------------------------------------------------------------
local firstOptionFrame = #ALL_FRAMES + 1
OPTIONS_PANEL:Show()
OPTIONS_PANEL:Fire("OnShow")
OPTIONS_PANEL:Fire("OnShow")
noErrors("options page")
check("options page built", #ALL_FRAMES > firstOptionFrame + 20)
local lastOptionFrame = #ALL_FRAMES
-- Poke every control of the page once. A control that an earlier click has hidden (a removed
-- button row) cannot be used in the game either.
for index = firstOptionFrame, lastOptionFrame do
    local frame = ALL_FRAMES[index]
    if not frame:IsVisible() then
        -- skip
    elseif frame.__kind == "Slider" then
        local low, high = frame:GetMinMaxValues()
        frame:SetValue(high)
        frame:SetValue(low)
    elseif frame.__kind == "EditBox" then
        frame:Fire("OnEditFocusGained")
        frame:SetText("{base} {count} Test")
        frame:Fire("OnTextChanged", true)
        frame:SetText("")
        frame:Fire("OnTextChanged", true)
        frame:Fire("OnEditFocusLost")
    elseif frame.__kind == "Button" then
        frame:Fire("OnEnter")
        frame:Fire("OnLeave")
        frame:Fire("OnClick")
    end
end
RunTimers()
noErrors("using every control of the options page")
eq("sliders reach the settings", ns.db.deselectRange, 1)
eq("cooldown slider can switch the pause off", ns.db.cooldown, 0)
if _G.MaldoesIncCallerReportFrame then MaldoesIncCallerReportFrame:Hide() end
ns.db.buttons, ns.db.template, ns.db.flagTemplate = nil, nil, nil
ns.db.language, ns.db.callLanguage, ns.db.channel = "auto", "ui", "auto"
ns.db.cooldown, ns.db.deselect, ns.db.deselectRange, ns.db.debug = 3, true, 2, false
ns.ApplyLanguage()
ns.UI:Refresh()

-- Commands, report ----------------------------------------------------------------
OPENED_CATEGORY = nil
SlashCmdList.MALDOESINCCALLER("options")
eq("options open", OPENED_CATEGORY, 7)
MaldoesIncCaller_OnAddonCompartmentClick(nil, "RightButton")
ns.UI:Hide()
MaldoesIncCaller_OnAddonCompartmentClick(nil, "LeftButton")
check("compartment click shows the window", ns.UI.frame:IsShown())
SlashCmdList.MALDOESINCCALLER("reset")
CHAT = {}
SlashCmdList.MALDOESINCCALLER("help")
check("help lists the commands", chatHas("/inc test"))
check("chat prefix", chatHas("Maldö's Inc Caller"))
SlashCmdList.MALDOESINCCALLER("debug")
eq("debug on", ns.db.debug, true)
ns.Debug("a debug line")
check("debug lines reach the chat", chatHas("a debug line"))
SlashCmdList.MALDOESINCCALLER("debug")
eq("debug off", ns.db.debug, false)
SlashCmdList.MALDOESINCCALLER("log")
noErrors("commands")
check("report window", MaldoesIncCallerReportFrame ~= nil and MaldoesIncCallerReportFrame:IsShown())
local report = ns.BuildReport()
check("report heading", report:find("### Maldö's Inc Caller report", 1, true) ~= nil)
check("report has the version", report:find("- Addon: 1.0.0", 1, true) ~= nil)
check("report has the deselect setting", report:find("deselect 2", 1, true) ~= nil)
check("report has the log", report:find("bases rebuilt", 1, true) ~= nil)
check("report has no phrases", report:find("Inc call", 1, true) == nil)

-- Errors ------------------------------------------------------------------------
eq("no errors so far", ns.ErrorCount(), 0)
FireEvent("ADDON_ACTION_BLOCKED", "AnotherAddon", "SendChatMessage()")
eq("blocked action of another addon ignored", ns.ErrorCount(), 0)
CHAT = {}
FireEvent("ADDON_ACTION_BLOCKED", "MaldoesIncCaller", "SendChatMessage()")
FireEvent("ADDON_ACTION_BLOCKED", "MaldoesIncCaller", "SendChatMessage()")
eq("blocked action recorded once", ns.ErrorCount(), 1)
check("error announced", chatHas("/inc log"))
local broken = ns.Safe(function() error("kaputt") end)
broken()
eq("a caught error is recorded", ns.ErrorCount(), 2)
check("the caught error is in the report", ns.BuildReport():find("kaputt", 1, true) ~= nil)
SlashCmdList.MALDOESINCCALLER("log clear")
eq("log clear", ns.ErrorCount(), 0)

-- A new version starts without the old errors
ns.ReportError("alter Fehler")
ns.db.errorsVersion = "0.9.0"
ns.InitLog()
eq("errors of an older version are dropped", ns.ErrorCount(), 0)

print(failures == 0 and "ALL TESTS PASSED" or (failures .. " TEST(S) FAILED"))
TEST_FAILURES = failures
