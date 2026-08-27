local QOL = _G.qtQOL
if not QOL then return end

local CORRECTION_TTL = 3
local originalResolver
local rawWrapper
local hexWrapper
local optimizedResolver
local maximumResolver
local corrections = {}
local expiry = {}
local expiryHead = 1
local expiryTail = 0
local lastActive
local lastMode

local function GuidLow(guid)
    if type(guid) == "number" then return guid end
    if type(guid) ~= "string" then return nil end
    local hex = string.match(guid, "([%x]+)$")
    return hex and tonumber(string.sub(hex, -8), 16) or nil
end

local function ClearCorrections()
    corrections = {}
    expiry = {}
    expiryHead = 1
    expiryTail = 0
end

local function RebuildOverflow(mantissa, exponent, fallback)
    if not mantissa or not exponent then return fallback end
    local numericMantissa = tonumber(mantissa)
    local numericExponent = tonumber(exponent)
    if not numericMantissa or not numericExponent then return fallback end
    local value = numericMantissa * 10 ^ numericExponent
    return value > (fallback or 0) and value or fallback
end

local function ParseCorrection(payload)
    local rest = string.match(payload or "", "^DHIT%^(.*)$")
    if not rest then return nil end

    local fields = {}
    for value in string.gmatch(rest, "([^^]+)") do
        fields[#fields + 1] = value
    end
    if #fields < 9 then return nil end

    local record = {
        target = tonumber(fields[1]),
        wireAmount = tonumber(fields[2]),
        trueAmount = tonumber(fields[3]),
        sequence = tonumber(fields[4]),
        kind = fields[5],
        source = tonumber(fields[6]),
        spellId = tonumber(fields[7]) or 0,
        wireAux = tonumber(fields[8]) or 0,
        trueAux = tonumber(fields[9]) or 0,
        trueResist = 0,
        trueAbsorb = 0,
        time = GetTime(),
    }
    if not record.target or not record.wireAmount or not record.trueAmount
        or not record.sequence or (record.kind ~= "D" and record.kind ~= "H")
        or not record.source
    then
        return nil
    end

    record.trueAmount = RebuildOverflow(fields[10], fields[11], record.trueAmount)
    record.trueAux = RebuildOverflow(fields[12], fields[13], record.trueAux)
    record.trueResist = RebuildOverflow(fields[15], fields[16], 0)
    record.trueAbsorb = RebuildOverflow(fields[18], fields[19], 0)
    return record
end

local function QueueCorrection(payload)
    local record = ParseCorrection(payload)
    if not record then return end

    local bucket = corrections[record.wireAmount]
    if not bucket then
        bucket = { first = 1, last = 0 }
        corrections[record.wireAmount] = bucket
    end
    bucket.last = bucket.last + 1
    bucket[bucket.last] = record
    record.bucket = bucket
    record.index = bucket.last

    expiryTail = expiryTail + 1
    expiry[expiryTail] = record
end

local function RemoveExpired()
    local now = GetTime()
    while expiryHead <= expiryTail do
        local record = expiry[expiryHead]
        if now - record.time <= CORRECTION_TTL then break end
        expiry[expiryHead] = nil
        expiryHead = expiryHead + 1

        local bucket = record.bucket
        if bucket[record.index] == record then bucket[record.index] = nil end
        while bucket.first <= bucket.last and bucket[bucket.first] == nil do
            bucket.first = bucket.first + 1
        end
        if bucket.first > bucket.last then
            corrections[record.wireAmount] = nil
        end
    end

    if expiryHead > expiryTail then
        expiry = {}
        expiryHead = 1
        expiryTail = 0
    end
end

local function WasUsed(record, consumer)
    if consumer == "Details" then return record.usedDetails end
    if consumer == "Skada" then return record.usedSkada end
    if consumer == "Recount" then return record.usedRecount end
    return record.usedOther and record.usedOther[consumer]
end

local function MarkUsed(record, consumer)
    if consumer == "Details" then record.usedDetails = true
    elseif consumer == "Skada" then record.usedSkada = true
    elseif consumer == "Recount" then record.usedRecount = true
    else
        record.usedOther = record.usedOther or {}
        record.usedOther[consumer] = true
    end
end

local function ConsumerCursor(bucket, consumer)
    if consumer == "Details" then return bucket.detailsCursor or bucket.first end
    if consumer == "Skada" then return bucket.skadaCursor or bucket.first end
    if consumer == "Recount" then return bucket.recountCursor or bucket.first end
    bucket.otherCursors = bucket.otherCursors or {}
    return bucket.otherCursors[consumer] or bucket.first
end

local function SetConsumerCursor(bucket, consumer, index)
    if consumer == "Details" then bucket.detailsCursor = index
    elseif consumer == "Skada" then bucket.skadaCursor = index
    elseif consumer == "Recount" then bucket.recountCursor = index
    else
        bucket.otherCursors = bucket.otherCursors or {}
        bucket.otherCursors[consumer] = index
    end
end

optimizedResolver = function(consumer, kind, sourceGuid, targetGuid, spellId, wireAmount, wireAux,
    wireResist, wireAbsorb)
    wireAmount = tonumber(wireAmount)
    wireAux = tonumber(wireAux) or 0
    wireResist = tonumber(wireResist) or 0
    wireAbsorb = tonumber(wireAbsorb) or 0
    local source = GuidLow(sourceGuid)
    local target = GuidLow(targetGuid)
    local bucket = wireAmount and corrections[wireAmount]
    if not bucket or not source or not target then
        return wireAmount, wireAux, false, wireResist, wireAbsorb
    end

    local now = GetTime()
    spellId = tonumber(spellId) or 0
    local start = math.max(bucket.first, ConsumerCursor(bucket, consumer))
    for index = start, bucket.last do
        local record = bucket[index]
        if record and now - record.time <= CORRECTION_TTL
            and record.kind == kind
            and record.source == source
            and record.target == target
            and record.spellId == spellId
            and record.wireAux == wireAux
            and not WasUsed(record, consumer)
        then
            MarkUsed(record, consumer)
            SetConsumerCursor(bucket, consumer, index + 1)
            local resist = record.trueResist > 0 and record.trueResist or wireResist
            local absorb = record.trueAbsorb > 0 and record.trueAbsorb or wireAbsorb
            return record.trueAmount, record.trueAux, true, resist, absorb
        end
    end
    return wireAmount, wireAux, false, wireResist, wireAbsorb
end

maximumResolver = function(_, _, _, _, _, wireAmount, wireAux, wireResist, wireAbsorb)
    return wireAmount, wireAux, false, wireResist, wireAbsorb
end

local function DecodeHex(payload)
    return (string.gsub(payload, "(%x%x)", function(pair)
        return string.char(tonumber(pair, 16))
    end))
end

local function HandleDamagePacket(payload)
    if not QOL:IsCombatPerformanceActive() then return false end
    local mode = QOL:GetDB().combatMode
    if mode == "optimized" then QueueCorrection(payload) end
    return mode == "optimized" or mode == "maximum"
end

local function InstallPacketWrappers()
    if type(PeloriaOnRawPacket) == "function" and PeloriaOnRawPacket ~= rawWrapper then
        local original = PeloriaOnRawPacket
        rawWrapper = function(payload)
            if type(payload) == "string" and string.sub(payload, 1, 5) == "DHIT^"
                and HandleDamagePacket(payload)
            then
                return
            end
            return original(payload)
        end
        PeloriaOnRawPacket = rawWrapper
    end

    if type(PeloriaOnPacket) == "function" and PeloriaOnPacket ~= hexWrapper then
        local original = PeloriaOnPacket
        hexWrapper = function(payload)
            if type(payload) == "string"
                and string.lower(string.sub(payload, 1, 10)) == "444849545e"
            then
                local active = QOL:IsCombatPerformanceActive()
                local mode = QOL:GetDB().combatMode
                if active and mode == "maximum" then return end
                if active and mode == "optimized" then
                    QueueCorrection(DecodeHex(payload))
                    return
                end
            end
            return original(payload)
        end
        PeloriaOnPacket = hexWrapper
    end
end

local function SetResolver(resolver)
    if resolver then
        if PeloriaResolveCombatLog ~= resolver then
            if PeloriaResolveCombatLog ~= optimizedResolver
                and PeloriaResolveCombatLog ~= maximumResolver
            then
                originalResolver = PeloriaResolveCombatLog
            end
            PeloriaResolveCombatLog = resolver
        end
    elseif PeloriaResolveCombatLog == optimizedResolver
        or PeloriaResolveCombatLog == maximumResolver
    then
        PeloriaResolveCombatLog = originalResolver
    end
end

local function Apply()
    InstallPacketWrappers()

    local db = QOL:GetDB()
    local active = QOL:IsCombatPerformanceActive()
    local mode = db.combatMode
    if active and mode == "optimized" then
        SetResolver(optimizedResolver)
    elseif active and mode == "maximum" then
        SetResolver(maximumResolver)
    else
        SetResolver(nil)
    end

    if active ~= lastActive or mode ~= lastMode then
        ClearCorrections()
        lastActive = active
        lastMode = mode
        if QOL.RefreshCombatPerformanceStatus then
            QOL:RefreshCombatPerformanceStatus()
        end
    end
end

function QOL:RefreshCombatPerformancePatch()
    Apply()
end

function QOL:GetCombatPerformanceStatus()
    if not self:GetDB().combatPerformance then return "Disabled" end
    if not self:IsCombatPerformanceActive() then return "Waiting for a group" end
    local mode = self:GetDB().combatMode
    if mode == "optimized" then return "Optimized meters: accurate DPS corrections" end
    if mode == "maximum" then return "Maximum performance: corrections blocked" end
    return "Peloria default: all corrections enabled"
end

local driver = CreateFrame("Frame")
local elapsedTotal = 0
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PARTY_MEMBERS_CHANGED")
driver:RegisterEvent("RAID_ROSTER_UPDATE")
driver:SetScript("OnEvent", Apply)
driver:SetScript("OnUpdate", function(_, elapsed)
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal < 0.5 then return end
    elapsedTotal = 0
    Apply()
    RemoveExpired()
end)
