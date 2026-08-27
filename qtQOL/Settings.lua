local QOL = _G.qtQOL
if not QOL then return end

local panel = CreateFrame("Frame", "qtQOLSettingsPanel")
panel.name = "qtQOL"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("qtQOL")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetWidth(560)
subtitle:SetJustifyH("LEFT")
subtitle:SetText("Peloria quality-of-life and client performance patches.")

local section = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
section:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -24)
section:SetText("Combat performance")

local detail = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
detail:SetPoint("TOPLEFT", section, "BOTTOMLEFT", 0, -8)
detail:SetWidth(560)
detail:SetJustifyH("LEFT")
detail:SetText(
    "PeloriaUI creates correction records for every damage event. Large AoE bursts can make "
    .. "those queues expensive to maintain, especially in parties and raids."
)

local function CreateCheckButton(name, label, anchor, offset, horizontalOffset)
    local button = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
    button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", horizontalOffset or -4, offset)
    button:SetHitRectInsets(0, -300, 0, 0)
    _G[name .. "Text"]:SetText(label)
    return button
end

local function AddTooltip(button, heading, text)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(heading, 1, 0.82, 0)
        GameTooltip:AddLine(text, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
end

local enabled = CreateCheckButton(
    "qtQOLCombatPerformanceEnabled",
    "Reduce PeloriaUI combat overhead",
    detail,
    -14
)
AddTooltip(
    enabled,
    "Reduce PeloriaUI combat overhead",
    "Enables qtQOL's combat correction patch using the selected mode."
)

local solo = CreateCheckButton(
    "qtQOLCombatPerformanceSolo",
    "Apply the optimization while solo",
    enabled,
    -6,
    0
)
AddTooltip(
    solo,
    "Apply while solo",
    "Keeps the selected correction mode active outside parties and raids."
)

local modeTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
modeTitle:SetPoint("TOPLEFT", solo, "BOTTOMLEFT", 4, -15)
modeTitle:SetText("Correction mode")

local optimized = CreateCheckButton(
    "qtQOLOptimizedMeterMode",
    "Optimized meters",
    modeTitle,
    -6
)
AddTooltip(
    optimized,
    "Optimized meters",
    "Preserves accurate uncapped DPS reporting with a lightweight, lazily-expiring correction queue."
)

local maximum = CreateCheckButton(
    "qtQOLMaximumPerformanceMode",
    "Maximum performance",
    optimized,
    -4,
    0
)
AddTooltip(
    maximum,
    "Maximum performance",
    "Blocks correction packets. Damage meter values above the client cap will be inaccurate."
)

local peloria = CreateCheckButton(
    "qtQOLPeloriaDefaultMode",
    "Peloria default",
    maximum,
    -4,
    0
)
AddTooltip(
    peloria,
    "Peloria default",
    "Uses PeloriaUI's original meter and combat-text correction processing."
)

local statusLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
statusLabel:SetPoint("TOPLEFT", peloria, "BOTTOMLEFT", 4, -20)
statusLabel:SetText("Current status:")

local status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
status:SetPoint("LEFT", statusLabel, "RIGHT", 8, 0)

local modeButtons = {
    optimized = optimized,
    maximum = maximum,
    peloria = peloria,
}

local function SetModeEnabled(value)
    for _, button in pairs(modeButtons) do
        if value then button:Enable() else button:Disable() end
    end
end

local function Refresh()
    local db = QOL:GetDB()
    enabled:SetChecked(db.combatPerformance)
    solo:SetChecked(db.combatPerformanceSolo)
    for mode, button in pairs(modeButtons) do
        button:SetChecked(db.combatMode == mode)
    end
    if db.combatPerformance then
        solo:Enable()
    else
        solo:Disable()
    end
    SetModeEnabled(db.combatPerformance)
    status:SetText(QOL:GetCombatPerformanceStatus())
end

local function Save()
    local db = QOL:GetDB()
    db.combatPerformance = enabled:GetChecked() and true or false
    db.combatPerformanceSolo = solo:GetChecked() and true or false
    QOL:RefreshCombatPerformancePatch()
    Refresh()
end

local function SelectMode(mode)
    QOL:GetDB().combatMode = mode
    QOL:RefreshCombatPerformancePatch()
    Refresh()
end

enabled:SetScript("OnClick", Save)
solo:SetScript("OnClick", Save)
optimized:SetScript("OnClick", function() SelectMode("optimized") end)
maximum:SetScript("OnClick", function() SelectMode("maximum") end)
peloria:SetScript("OnClick", function() SelectMode("peloria") end)
panel:SetScript("OnShow", Refresh)

function QOL:RefreshCombatPerformanceStatus()
    if status then status:SetText(self:GetCombatPerformanceStatus()) end
end

InterfaceOptions_AddCategory(panel)

SLASH_QTQOL1 = "/qtqol"
SlashCmdList.QTQOL = function()
    InterfaceOptionsFrame_OpenToCategory(panel)
end
