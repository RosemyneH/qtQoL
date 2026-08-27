local QOL = _G.qtQOL or {}
_G.qtQOL = QOL

qtQOLDB = qtQOLDB or {}

local validCombatModes = {
    optimized = true,
    maximum = true,
    peloria = true,
}

if not validCombatModes[qtQOLDB.combatMode] then qtQOLDB.combatMode = "optimized" end
qtQOLDB.preserveDamageCorrections = nil

local defaults = {
    combatPerformance = true,
    combatPerformanceSolo = false,
    combatMode = "optimized",
}

for key, value in pairs(defaults) do
    if qtQOLDB[key] == nil then qtQOLDB[key] = value end
end

function QOL:GetDB()
    return qtQOLDB
end

function QOL:IsCombatPerformanceActive()
    if not qtQOLDB.combatPerformance then return false end
    if qtQOLDB.combatPerformanceSolo then return true end
    local partyCount = GetNumPartyMembers and GetNumPartyMembers() or 0
    local raidCount = GetNumRaidMembers and GetNumRaidMembers() or 0
    return partyCount > 0 or raidCount > 0
end
