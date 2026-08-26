local QOL = _G.qtQOL
if not QOL then return end

local BOARD_WIDTH = 320
local BOARD_GAP = 8
local BOARD_PAD = 10
local CARD_GAP = 7
local MAX_MEMBERS = 5
local MAX_TARGETS = 4

local board
local cards = {}
local emptyLabel

local function CreateMemberCard(parent)
    local C = PelKit.COLORS
    local card = PelKit.Card(parent, BOARD_WIDTH - BOARD_PAD * 2, 98)

    card.name = PelKit.Label(card, "", "GameFontNormal", C.felBright)
    card.name:SetPoint("TOPLEFT", 10, -8)

    card.level = PelKit.Label(card, "", "GameFontNormal", C.gold)
    card.level:SetPoint("TOPRIGHT", -10, -8)

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
    card.level:SetText("Mythic +" .. QOL:FormatCompactNumber(snapshot.level))

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

local function Render()
    if not board then return end
    local order = QOL:GetPartyOrder()
    local shown = 0
    local offset = 82

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

    emptyLabel = PelKit.Label(board, "", "GameFontHighlightSmall", C.textDim)
    emptyLabel:SetPoint("TOPLEFT", BOARD_PAD, -88)
    emptyLabel:SetPoint("TOPRIGHT", -BOARD_PAD, -88)
    emptyLabel:SetJustifyH("LEFT")

    for index = 1, MAX_MEMBERS do
        cards[index] = CreateMemberCard(board)
        cards[index]:Hide()
    end

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
