local QOL = _G.qtQOL
if not QOL then return end

local BOARD_WIDTH = 320
local BOARD_GAP = 8
local BOARD_PAD = 10
local CARD_GAP = 7
local MAX_MEMBERS = 5
local MAX_TARGETS = 4
local MAX_PARTY_TARGETS = MAX_MEMBERS * MAX_TARGETS
local INSTANCE_COLORS = {
    { 0.36, 0.43, 0.48 },
    { 0.43, 0.37, 0.48 },
    { 0.35, 0.45, 0.39 },
    { 0.48, 0.40, 0.34 },
}
local INSTANCE_ACHIEVEMENTS = {
    ["blackwing lair"] = 685,
    ["molten core"] = 686,
    ["temple of ahn'qiraj"] = 687,
    ["zul'gurub"] = 688,
    ["ruins of ahn'qiraj"] = 689,
    ["karazhan"] = 690,
    ["zul'aman"] = 691,
    ["gruul's lair"] = 692,
    ["magtheridon's lair"] = 693,
    ["serpentshrine cavern"] = 694,
    ["the battle for mount hyjal"] = 695,
    ["tempest keep"] = 696,
    ["black temple"] = 697,
    ["sunwell plateau"] = 698,
    ["naxxramas"] = 576,
    ["the obsidian sanctum"] = 624,
    ["the eye of eternity"] = 622,
    ["ulduar"] = 2894,
    ["trial of the crusader"] = 3917,
    ["icecrown citadel"] = 4532,
}

local board
local cards = {}
local emptyLabel
local toggleButton
local instanceScroll
local instanceContent
local instanceHeaders = {}
local instanceRows = {}
local viewMode = "party"

local function FormatWholeNumber(value)
    local number = math.floor(math.abs(tonumber(value) or 0))
    local text = tostring(number)
    local parts = {}
    while string.len(text) > 3 do
        table.insert(parts, 1, string.sub(text, -3))
        text = string.sub(text, 1, -4)
    end
    table.insert(parts, 1, text)
    return (tonumber(value) or 0) < 0 and "-" .. table.concat(parts, ",") or table.concat(parts, ",")
end

local function GetInstanceIcon(raid)
    local achievementID = INSTANCE_ACHIEVEMENTS[string.lower(raid or "")]
    local icon = achievementID and GetAchievementInfo and select(10, GetAchievementInfo(achievementID))
    return icon or "Interface\\Icons\\Achievement_Boss_Murmur"
end

local function CreateMemberCard(parent)
    local C = PelKit.COLORS
    local card = PelKit.Card(parent, BOARD_WIDTH - BOARD_PAD * 2, 98)

    card.name = PelKit.Label(card, "", "GameFontNormal", C.felBright)
    card.name:SetPoint("TOPLEFT", 10, -8)
    card.name:SetPoint("TOPRIGHT", -150, -8)
    card.name:SetJustifyH("LEFT")

    card.level = PelKit.Label(card, "", "GameFontNormal", C.gold)
    card.level:SetPoint("TOPRIGHT", -10, -8)
    card.level:SetWidth(135)
    card.level:SetJustifyH("RIGHT")

    card.targets = {}
    card.queueButtons = {}
    for index = 1, MAX_TARGETS do
        local row = PelKit.Label(card, "", "GameFontHighlightSmall", C.text)
        row:SetPoint("TOPLEFT", 10, -(25 + (index - 1) * 16))
        row:SetPoint("TOPRIGHT", -10, -(25 + (index - 1) * 16))
        row:SetJustifyH("LEFT")
        card.targets[index] = row

        local queueButton = PelKit.Button(card, 48, 15, "Queue")
        queueButton:SetPoint("TOPRIGHT", -8, -(23 + (index - 1) * 16))
        PelKit.OnClick(queueButton, function(self)
            QOL:QueueEliteTarget(self.owner, self.slot)
        end)
        queueButton:Hide()
        card.queueButtons[index] = queueButton
    end
    return card
end

local function RenderCard(card, snapshot)
    local C = PelKit.COLORS
    local count = math.min(MAX_TARGETS, table.getn(snapshot.targets or {}))
    card:SetHeight(math.max(45, 31 + count * 16))
    card.name:SetText(snapshot.name)
    card.level:SetText("Mythic +" .. FormatWholeNumber(snapshot.level))

    for index = 1, MAX_TARGETS do
        local row = card.targets[index]
        local queueButton = card.queueButtons[index]
        local target = snapshot.targets[index]
        if target then
            local status = target.killed and "[x]" or "[ ]"
            local canQueue = not target.killed
                and (target.queueEntry or 0) > 0
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 10, -(25 + (index - 1) * 16))
            row:SetPoint("TOPRIGHT", canQueue and -62 or -10, -(25 + (index - 1) * 16))
            row:SetText(status .. " " .. target.raid .. " - " .. target.boss)
            local color = target.killed and C.textDim or C.text
            row:SetTextColor(color[1], color[2], color[3])
            row:Show()
            queueButton.owner = snapshot.name
            queueButton.slot = target.slot
            if canQueue then queueButton:Show() else queueButton:Hide() end
        else
            row:Hide()
            queueButton:Hide()
        end
    end
end

local function CreateInstanceView(parent)
    local C = PelKit.COLORS
    instanceScroll = CreateFrame("ScrollFrame", nil, parent)
    instanceScroll:SetPoint("TOPLEFT", BOARD_PAD, -82)
    instanceScroll:SetPoint("BOTTOMRIGHT", -BOARD_PAD, BOARD_PAD)
    instanceScroll:EnableMouseWheel(true)

    instanceContent = CreateFrame("Frame", nil, instanceScroll)
    instanceContent:SetWidth(BOARD_WIDTH - BOARD_PAD * 2)
    instanceContent:SetHeight(1)
    instanceScroll:SetScrollChild(instanceContent)
    instanceScroll:SetScript("OnMouseWheel", function(self, delta)
        local maximum = math.max(0, instanceContent:GetHeight() - self:GetHeight())
        local offset = math.max(0, math.min(maximum, self:GetVerticalScroll() - delta * 40))
        self:SetVerticalScroll(offset)
    end)

    for index = 1, MAX_PARTY_TARGETS do
        local header = CreateFrame("Frame", nil, instanceContent)
        header:SetWidth(BOARD_WIDTH - BOARD_PAD * 2)
        header:SetHeight(18)
        header.background = header:CreateTexture(nil, "BACKGROUND")
        header.background:SetAllPoints()
        header.icon = header:CreateTexture(nil, "ARTWORK")
        header.icon:SetWidth(15)
        header.icon:SetHeight(15)
        header.icon:SetPoint("LEFT", 3, 0)
        header.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        header.label = PelKit.Label(header, "", "GameFontNormal", C.text)
        header.label:SetPoint("LEFT", header.icon, "RIGHT", 5, 0)
        header.label:SetPoint("RIGHT", -5, 0)
        header:Hide()
        instanceHeaders[index] = header

        local row = {}
        row.frame = CreateFrame("Frame", nil, instanceContent)
        row.frame:SetWidth(BOARD_WIDTH - BOARD_PAD * 2)
        row.frame:SetHeight(17)
        row.background = row.frame:CreateTexture(nil, "BACKGROUND")
        row.background:SetAllPoints()
        row.label = PelKit.Label(row.frame, "", "GameFontHighlightSmall", C.text)
        row.label:SetPoint("LEFT", 5, 0)
        row.label:SetJustifyH("LEFT")

        row.level = PelKit.Label(row.frame, "", "GameFontHighlightSmall", C.gold)
        row.level:SetWidth(110)
        row.level:SetJustifyH("RIGHT")

        row.queueButton = PelKit.Button(row.frame, 48, 15, "Queue")
        row.queueButton:SetPoint("RIGHT", -1, 0)
        PelKit.OnClick(row.queueButton, function(self)
            QOL:QueueEliteTarget(self.owner, self.slot)
        end)
        row.queueButton:Hide()
        row.frame:Hide()
        instanceRows[index] = row
    end

    instanceScroll:Hide()
end

local function HidePartyCards()
    for index = 1, MAX_MEMBERS do
        cards[index]:Hide()
    end
end

local function RenderParty()
    local order = QOL:GetPartyOrder()
    local shown = 0
    local offset = 82

    instanceScroll:Hide()
    for i = 1, table.getn(order) do
        local snapshot = QOL.bountySnapshots[order[i]]
        if snapshot and shown < MAX_MEMBERS then
            shown = shown + 1
            local card = cards[shown]
            RenderCard(card, snapshot)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", BOARD_PAD, -offset)
            card:Show()
            offset = offset + card:GetHeight() + CARD_GAP
        end
    end

    for i = shown + 1, MAX_MEMBERS do
        cards[i]:Hide()
    end

    if shown == 0 then
        emptyLabel:SetText("No party bounty data yet. Press Sync Party after everyone has qtQOL enabled.")
        emptyLabel:Show()
    else
        emptyLabel:Hide()
    end
end

local function RenderInstances()
    local C = PelKit.COLORS
    local groups = {}
    local raidNames = {}
    local order = QOL:GetPartyOrder()

    HidePartyCards()
    for i = 1, table.getn(order) do
        local snapshot = QOL.bountySnapshots[order[i]]
        if snapshot then
            for targetIndex = 1, table.getn(snapshot.targets or {}) do
                local target = snapshot.targets[targetIndex]
                local raid = target.raid ~= "" and target.raid or "Unknown Instance"
                if not groups[raid] then
                    groups[raid] = {}
                    table.insert(raidNames, raid)
                end
                table.insert(groups[raid], {
                    owner = snapshot.name,
                    level = snapshot.level,
                    target = target,
                })
            end
        end
    end

    table.sort(raidNames)
    local headerCount = 0
    local rowCount = 0
    local offset = 0
    for raidIndex = 1, table.getn(raidNames) do
        local raid = raidNames[raidIndex]
        local entries = groups[raid]
        table.sort(entries, function(left, right)
            if left.target.boss == right.target.boss then
                return left.owner < right.owner
            end
            return left.target.boss < right.target.boss
        end)

        headerCount = headerCount + 1
        local header = instanceHeaders[headerCount]
        local color = INSTANCE_COLORS[(raidIndex - 1) % table.getn(INSTANCE_COLORS) + 1]
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", 0, -offset)
        header.background:SetTexture(color[1], color[2], color[3], 0.32)
        header.icon:SetTexture(GetInstanceIcon(raid))
        header.icon:SetVertexColor(0.78, 0.78, 0.78)
        header.label:SetText(raid .. " (" .. table.getn(entries) .. ")")
        header.label:SetTextColor(0.78, 0.82, 0.84)
        header:Show()
        offset = offset + 19

        for entryIndex = 1, table.getn(entries) do
            rowCount = rowCount + 1
            local entry = entries[entryIndex]
            local target = entry.target
            local row = instanceRows[rowCount]
            local canQueue = not target.killed and (target.queueEntry or 0) > 0
            local status = target.killed and "[x]" or "[ ]"
            local color = target.killed and C.textDim or C.text

            row.label:ClearAllPoints()
            row.label:SetPoint("TOPLEFT", 5, -offset)
            row.label:SetPoint("TOPRIGHT", canQueue and -58 or 0, -offset)
            row.label:SetText(status .. " " .. target.boss .. " - " .. entry.owner)
            row.label:SetTextColor(color[1], color[2], color[3])
            row.label:Show()

            row.queueButton:ClearAllPoints()
            row.queueButton:SetPoint("TOPRIGHT", 0, -offset)
            row.queueButton.owner = entry.owner
            row.queueButton.slot = target.slot
            if canQueue then row.queueButton:Show() else row.queueButton:Hide() end
            offset = offset + 17
        end
        offset = offset + 5
    end

    for index = headerCount + 1, MAX_PARTY_TARGETS do
        instanceHeaders[index]:Hide()
    end
    for index = rowCount + 1, MAX_PARTY_TARGETS do
        instanceRows[index].label:Hide()
        instanceRows[index].queueButton:Hide()
    end

    instanceContent:SetHeight(math.max(1, offset))
    instanceScroll:SetVerticalScroll(0)
    instanceScroll:Show()
    if rowCount == 0 then
        emptyLabel:SetText("No party bounty data yet. Press Sync Party after everyone has qtQOL enabled.")
        emptyLabel:Show()
    else
        emptyLabel:Hide()
    end
end

local function Render()
    if not board then return end
    if viewMode == "instances" then
        RenderInstances()
    else
        RenderParty()
    end
end

local function CreateBoard()
    if board or not PeloriaBountyFrame or not PelKit then return false end
    local C = PelKit.COLORS

    PeloriaBountyFrame:ClearAllPoints()
    PeloriaBountyFrame:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        -(BOARD_WIDTH + BOARD_GAP) / 2,
        0
    )

    board = PelKit.Panel(PeloriaBountyFrame)
    board:SetWidth(BOARD_WIDTH)
    board:SetPoint("TOPLEFT", PeloriaBountyFrame, "TOPRIGHT", BOARD_GAP, 0)
    board:SetPoint("BOTTOMLEFT", PeloriaBountyFrame, "BOTTOMRIGHT", BOARD_GAP, 0)
    board:SetFrameLevel(PeloriaBountyFrame:GetFrameLevel() + 5)

    local title = PelKit.Label(board, "Party Elite Bounties", "GameFontNormalLarge", C.felBright)
    title:SetPoint("TOPLEFT", BOARD_PAD, -11)

    local subtitle = PelKit.Label(
        board,
        "Shared by party members running qtQOL",
        "GameFontHighlightSmall",
        C.textDim
    )
    subtitle:SetPoint("TOPLEFT", BOARD_PAD, -31)

    local sayButton = PelKit.Button(board, 105, 22, "Say Mine")
    sayButton:SetPoint("TOPLEFT", BOARD_PAD, -51)
    PelKit.OnClick(sayButton, function()
        QOL:AnnounceEliteBounty()
    end)

    local syncButton = PelKit.Button(board, 105, 22, "Sync Party")
    syncButton:SetPoint("LEFT", sayButton, "RIGHT", 7, 0)
    PelKit.OnClick(syncButton, function()
        QOL:RequestBountySync()
    end)

    toggleButton = PelKit.Button(board, 76, 22, "Instances")
    toggleButton:SetPoint("LEFT", syncButton, "RIGHT", 7, 0)
    PelKit.OnClick(toggleButton, function()
        if viewMode == "party" then
            viewMode = "instances"
            toggleButton:SetText("Party")
        else
            viewMode = "party"
            toggleButton:SetText("Instances")
        end
        Render()
    end)

    emptyLabel = PelKit.Label(board, "", "GameFontHighlightSmall", C.textDim)
    emptyLabel:SetPoint("TOPLEFT", BOARD_PAD, -88)
    emptyLabel:SetPoint("TOPRIGHT", -BOARD_PAD, -88)
    emptyLabel:SetJustifyH("LEFT")

    for index = 1, MAX_MEMBERS do
        cards[index] = CreateMemberCard(board)
        cards[index]:Hide()
    end

    CreateInstanceView(board)
    QOL:RegisterBountyListener(Render)
    board:Show()
    Render()
    QOL:RequestBountySync()
    return true
end

local loader = CreateFrame("Frame")
local elapsedTotal = 0
loader:SetScript("OnUpdate", function(self, elapsed)
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal < 0.25 then return end
    elapsedTotal = 0
    if CreateBoard() then
        self:SetScript("OnUpdate", nil)
    end
end)
