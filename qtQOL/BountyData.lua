local QOL = _G.qtQOL or {}
_G.qtQOL = QOL

local PREFIX = "qtQOLBounty"
local VERSION = "1"
local ELITE_LINE_ID = 12
local MAX_TARGETS = 4
local snapshots = {}
local pending = {}
local listeners = {}
local lastSignature

QOL.bountySnapshots = snapshots

local function ShortName(name)
    return name and string.match(name, "^([^-]+)") or nil
end

local function PlayerName()
    return ShortName(UnitName("player"))
end

function QOL:GetPlayerName()
    return PlayerName()
end

local function CleanText(value, limit)
    local text = tostring(value or "")
    text = string.gsub(text, "[%c%^]", " ")
    text = string.gsub(text, "%s+", " ")
    if string.len(text) > limit then
        text = string.sub(text, 1, limit)
    end
    return text
end

local function Split(message)
    local fields = {}
    local start = 1
    while true do
        local pos = string.find(message, "^", start, true)
        if not pos then
            table.insert(fields, string.sub(message, start))
            return fields
        end
        table.insert(fields, string.sub(message, start, pos - 1))
        start = pos + 1
    end
end

local function Notify()
    for i = 1, table.getn(listeners) do
        listeners[i]()
    end
end

function QOL:RegisterBountyListener(listener)
    table.insert(listeners, listener)
end

function QOL:FormatCompactNumber(value)
    local number = tonumber(value) or 0
    local sign = number < 0 and "-" or ""
    number = math.abs(number)
    local suffixes = { "", "k", "m", "b", "t", "q" }
    local tier = 1
    while number >= 1000 and tier < table.getn(suffixes) do
        number = number / 1000
        tier = tier + 1
    end
    if tier == 1 then
        return sign .. tostring(math.floor(number + 0.5))
    end
    local text = string.format("%.1f", number)
    text = string.gsub(text, "%.0$", "")
    return sign .. text .. suffixes[tier]
end

function QOL:GetPartyOrder()
    local names = {}
    local player = PlayerName()
    if player then
        table.insert(names, player)
    end
    local count = GetNumPartyMembers and GetNumPartyMembers() or 0
    for index = 1, count do
        local name = ShortName(UnitName("party" .. index))
        if name then
            table.insert(names, name)
        end
    end
    return names
end

local function IsPartyMember(name)
    local short = ShortName(name)
    if not short then return false end
    local order = QOL:GetPartyOrder()
    for i = 1, table.getn(order) do
        if order[i] == short then return true end
    end
    return false
end

function QOL:PruneBountySnapshots()
    local keep = {}
    local order = self:GetPartyOrder()
    for i = 1, table.getn(order) do
        keep[order[i]] = true
    end
    for name in pairs(snapshots) do
        if not keep[name] then
            snapshots[name] = nil
            pending[name] = nil
        end
    end
    Notify()
end

function QOL:CaptureEliteBounty()
    if type(PeloriaBountyLines) ~= "function" then return nil end
    local elite
    local lines = PeloriaBountyLines() or {}
    for i = 1, table.getn(lines) do
        if tonumber(lines[i].id) == ELITE_LINE_ID then
            elite = lines[i]
            break
        end
    end
    if not elite then return nil end

    local snapshot = {
        name = PlayerName() or "Player",
        level = math.max(0, math.floor(tonumber(elite.required) or 0)),
        targets = {},
    }
    local targets = elite.targets or {}
    for index = 1, MAX_TARGETS do
        local target = targets[index]
        if target then
            table.insert(snapshot.targets, {
                slot = index,
                boss = CleanText(target.boss, 72),
                raid = CleanText(target.raid, 72),
                killed = target.killed and true or false,
                queueEntry = math.max(0, math.floor(tonumber(target.queueEntry) or 0)),
            })
        end
    end
    return snapshot
end

local function SnapshotSignature(snapshot)
    if not snapshot then return "" end
    local parts = { tostring(snapshot.level) }
    for i = 1, table.getn(snapshot.targets) do
        local target = snapshot.targets[i]
        table.insert(parts, table.concat({
            tostring(target.slot),
            target.killed and "1" or "0",
            target.boss,
            target.raid,
            tostring(target.queueEntry),
        }, "^"))
    end
    return table.concat(parts, "~")
end

local function Send(message)
    if (GetNumPartyMembers and GetNumPartyMembers() or 0) == 0 then return end
    if ChatThrottleLib and ChatThrottleLib.SendAddonMessage then
        ChatThrottleLib:SendAddonMessage("NORMAL", PREFIX, message, "PARTY")
    elseif SendAddonMessage then
        SendAddonMessage(PREFIX, message, "PARTY")
    end
end

function QOL:BroadcastBountySnapshot(force)
    local snapshot = self:CaptureEliteBounty()
    if not snapshot then return false end
    snapshots[snapshot.name] = snapshot
    Notify()

    local signature = SnapshotSignature(snapshot)
    if not force and signature == lastSignature then return true end
    lastSignature = signature

    Send(table.concat({ "H", VERSION, tostring(snapshot.level), tostring(table.getn(snapshot.targets)) }, "^"))
    for i = 1, table.getn(snapshot.targets) do
        local target = snapshot.targets[i]
        Send(table.concat({
            "T",
            VERSION,
            tostring(target.slot),
            target.killed and "1" or "0",
            target.boss,
            target.raid,
            tostring(target.queueEntry),
        }, "^"))
    end
    Send("D^" .. VERSION)
    return true
end

function QOL:RequestBountySync()
    self:PruneBountySnapshots()
    Send("R^" .. VERSION)
    self:BroadcastBountySnapshot(true)
end

function QOL:AnnounceEliteBounty()
    local snapshot = self:CaptureEliteBounty()
    if not snapshot or table.getn(snapshot.targets) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8a00qtQOL:|r no Elite bounty targets are loaded.")
        return
    end
    if (GetNumPartyMembers and GetNumPartyMembers() or 0) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8a00qtQOL:|r join a party before announcing your bounty.")
        return
    end
    local level = self:FormatCompactNumber(snapshot.level)
    local count = table.getn(snapshot.targets)
    for i = 1, count do
        local target = snapshot.targets[i]
        local status = target.killed and "Done" or "Open"
        local message = string.format(
            "Elite %d/%d: %s - %s - M+%s [%s]",
            i,
            count,
            target.raid,
            target.boss,
            level,
            status
        )
        SendChatMessage(string.sub(message, 1, 240), "PARTY")
    end
end

function QOL:QueueEliteTarget(slot)
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > MAX_TARGETS then return end
    local snapshot = self:CaptureEliteBounty()
    if not snapshot then return end
    for i = 1, table.getn(snapshot.targets) do
        local target = snapshot.targets[i]
        if target.slot == slot
            and not target.killed
            and target.queueEntry > 0
            and PeloriaSend
        then
            PeloriaSend("BNTYC^QUEUE^" .. ELITE_LINE_ID .. "^" .. (slot - 1))
            return
        end
    end
end

local function AcceptSnapshot(sender)
    local incoming = pending[sender]
    if not incoming then return end
    local expected = incoming.expected or 0
    if incoming.received ~= expected then return end
    local targets = {}
    for slot = 1, MAX_TARGETS do
        if incoming.targets[slot] then
            table.insert(targets, incoming.targets[slot])
        end
    end
    incoming.expected = nil
    incoming.received = nil
    incoming.targets = targets
    snapshots[sender] = incoming
    pending[sender] = nil
    Notify()
end

local function HandleAddonMessage(message, sender)
    if type(message) ~= "string" or string.len(message) > 240 then return end
    sender = ShortName(sender)
    if not sender or not IsPartyMember(sender) then return end
    local fields = Split(message)
    if fields[2] ~= VERSION then return end

    if fields[1] == "R" then
        QOL:BroadcastBountySnapshot(true)
        return
    end
    if fields[1] == "H" then
        local level = tonumber(fields[3])
        local count = tonumber(fields[4])
        if not level or level < 0 or level > 1000000000000000 then return end
        if not count or count < 0 or count > MAX_TARGETS then return end
        pending[sender] = {
            name = sender,
            level = math.floor(level),
            expected = count,
            received = 0,
            targets = {},
        }
        return
    end
    if fields[1] == "T" then
        local incoming = pending[sender]
        local slot = tonumber(fields[3])
        if not incoming or not slot or slot < 1 or slot > MAX_TARGETS then return end
        if fields[4] ~= "0" and fields[4] ~= "1" then return end
        if incoming.targets[slot] then return end
        incoming.targets[slot] = {
            slot = slot,
            killed = fields[4] == "1",
            boss = CleanText(fields[5], 72),
            raid = CleanText(fields[6], 72),
            queueEntry = math.max(0, math.floor(tonumber(fields[7]) or 0)),
        }
        incoming.received = incoming.received + 1
        return
    end
    if fields[1] == "D" then
        AcceptSnapshot(sender)
    end
end

local driver = CreateFrame("Frame")
local syncDelay
local peloriaHooked = false

local function ScheduleSync(delay)
    syncDelay = delay
end

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PARTY_MEMBERS_CHANGED")
driver:RegisterEvent("CHAT_MSG_ADDON")
driver:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, message, _, sender = ...
        if prefix == PREFIX then
            HandleAddonMessage(message, sender)
        end
        return
    end
    QOL:PruneBountySnapshots()
    ScheduleSync(event == "PLAYER_ENTERING_WORLD" and 2 or 1)
end)

driver:SetScript("OnUpdate", function(_, elapsed)
    if not peloriaHooked
        and type(PeloriaBountyLines) == "function"
        and type(PeloriaBountyWindowUpdate) == "function"
    then
        peloriaHooked = true
        if hooksecurefunc then
            hooksecurefunc("PeloriaBountyWindowUpdate", function()
                QOL:BroadcastBountySnapshot()
            end)
        end
        QOL:BroadcastBountySnapshot()
    end

    if not syncDelay then return end
    syncDelay = syncDelay - elapsed
    if syncDelay <= 0 then
        syncDelay = nil
        QOL:RequestBountySync()
    end
end)

if RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix(PREFIX)
end
