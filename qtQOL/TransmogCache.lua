local QOL = _G.qtQOL
if not QOL then return end

local RETRY_INTERVAL = 0.4
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

local originalHandler
local wrappedHandler
local scanDisabled = false
local hoveredItem
local hoveredCell
local retryElapsed = 0
local refreshing = false

local function IsInside(frame, ancestor)
    while frame do
        if frame == ancestor then return true end
        frame = frame.GetParent and frame:GetParent()
    end
    return false
end

local function IsTransmogFocus(frame)
    return TransmogFrame and IsInside(frame, TransmogFrame)
end

local function RunWithoutBulkQueries(handler, body)
    local realGetItemInfo = GetItemInfo
    local realGetItemIcon = GetItemIcon
    GetItemInfo = function(item)
        return tostring(item)
    end
    GetItemIcon = function()
        return nil
    end

    local ok, err = pcall(handler, body)
    GetItemInfo = realGetItemInfo
    GetItemIcon = realGetItemIcon
    if not ok then error(err) end
end

local function InstallPacketFilter()
    local handlers = _G.PeloriaPacketHandlers
    if not handlers or type(handlers.PELTMOG) ~= "function" then return false end
    if handlers.PELTMOG == wrappedHandler then return true end

    originalHandler = handlers.PELTMOG
    wrappedHandler = function(body)
        if type(body) == "string" and string.find(body, "^LEND%^") then
            RunWithoutBulkQueries(originalHandler, body)
            return
        end
        return originalHandler(body)
    end
    handlers.PELTMOG = wrappedHandler
    return true
end

local function DisablePeloriaScanner()
    if scanDisabled or not TransmogScanTip then return scanDisabled end
    TransmogScanTip.SetHyperlink = function() end
    scanDisabled = true
    return true
end

local function RefreshHoveredCell(itemID)
    if not hoveredCell then return end
    local regions = { hoveredCell:GetRegions() }
    local texture = GetItemIcon(itemID)
    for index = 1, table.getn(regions) do
        local region = regions[index]
        if region.GetTexture and region:GetTexture() == QUESTION_MARK then
            region:SetTexture(texture)
            break
        end
    end

    local leave = hoveredCell:GetScript("OnLeave")
    local enter = hoveredCell:GetScript("OnEnter")
    refreshing = true
    if leave then leave(hoveredCell) end
    if enter then enter(hoveredCell) end
    refreshing = false
end

if hooksecurefunc and GameTooltip then
    hooksecurefunc(GameTooltip, "SetHyperlink", function(_, hyperlink)
        if refreshing or not IsTransmogFocus(GetMouseFocus()) then return end
        local itemID = type(hyperlink) == "string" and tonumber(string.match(hyperlink, "item:(%d+)"))
        if not itemID then return end
        hoveredItem = itemID
        hoveredCell = GetMouseFocus()
        retryElapsed = RETRY_INTERVAL
    end)
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
    InstallPacketFilter()
    DisablePeloriaScanner()

    if not hoveredItem then return end
    if not GameTooltip:IsShown() or not IsTransmogFocus(GetMouseFocus()) then
        hoveredItem = nil
        hoveredCell = nil
        return
    end

    retryElapsed = retryElapsed + elapsed
    if retryElapsed < RETRY_INTERVAL then return end
    retryElapsed = 0

    if GetItemInfo(hoveredItem) then
        local itemID = hoveredItem
        hoveredItem = nil
        RefreshHoveredCell(itemID)
    end
end)
