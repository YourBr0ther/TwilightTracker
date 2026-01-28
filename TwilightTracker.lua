-------------------------------------------------------------------------------
-- TwilightTracker - Midnight Prepatch Rare Rotation Tracker
-- Tracks the 18-rare fixed rotation + Voice of the Eclipse
-- Deterministic schedule based on EST clock (no sync needed)
-- Shows current/next rare, countdown, coordinates, kill checklist
-------------------------------------------------------------------------------

local ADDON_NAME = "TwilightTracker"
TwilightTrackerDB = TwilightTrackerDB or {}

-------------------------------------------------------------------------------
-- Rare data: fixed rotation order, NPC IDs, coordinates
-- 6 locations cycle through the 18 rares (3 rares per location)
-------------------------------------------------------------------------------
local ROTATION = {
    { name = "Redeye the Skullchewer",         npcID = 246572, x = 65.2, y = 52.2 },
    { name = "T'aavihan the Unbound",          npcID = 246844, x = 57.6, y = 75.6 },
    { name = "Ray of Putrescence",             npcID = 246460, x = 71.2, y = 29.9 },
    { name = "Ix the Bloodfallen",             npcID = 246471, x = 46.7, y = 25.2 },
    { name = "Commander Ix'vaarha",            npcID = 246478, x = 45.2, y = 48.8 },
    { name = "Sharfadi, Bulwark of the Night", npcID = 246559, x = 41.8, y = 16.5 },
    { name = "Ez'Haadosh the Liminality",      npcID = 246549, x = 65.2, y = 52.2 },
    { name = "Berg the Spellfist",             npcID = 237853, x = 57.6, y = 75.6 },
    { name = "Corla, Herald of Twilight",      npcID = 237997, x = 71.2, y = 29.9 },
    { name = "Void Zealot Devinda",            npcID = 246272, x = 46.7, y = 25.2 },
    { name = "Asira Dawnslayer",               npcID = 246343, x = 45.2, y = 49.2 },
    { name = "Archbishop Benedictus",          npcID = 246462, x = 41.8, y = 16.5 },
    { name = "Nedrand the Eyegorger",          npcID = 246577, x = 65.2, y = 52.2 },
    { name = "Executioner Lynthelma",          npcID = 246840, x = 57.6, y = 75.6 },
    { name = "Gustavan, Herald of the End",    npcID = 246565, x = 71.2, y = 29.9 },
    { name = "Voidclaw Hexathor",              npcID = 246578, x = 46.7, y = 25.2 },
    { name = "Mirrorvise",                     npcID = 246566, x = 45.2, y = 49.2 },
    { name = "Saligrum the Observer",          npcID = 246558, x = 41.8, y = 16.5 },
}

-- Voice of the Eclipse: spawns hourly at one of 4 locations
local VOICE_OF_ECLIPSE = {
    name  = "Voice of the Eclipse",
    npcID = 246900,
    locations = {
        { label = "Ruins of Drakgor",       x = 40.1, y = 14.2 },
        { label = "Verrall Delta",          x = 67.0, y = 53.2 },
        { label = "Thunderstrike Mountain", x = 69.1, y = 29.5 },
        { label = "Verrall River",          x = 47.2, y = 45.6 },
    },
}

local NUM_RARES    = #ROTATION       -- 18
local TOTAL_RARES  = NUM_RARES + 1   -- +1 for Voice of the Eclipse
local SLOT_SECONDS = 600             -- 10 minutes per rare
local CYCLE_SECONDS = NUM_RARES * SLOT_SECONDS  -- 10800 = 3 hours
local MAP_ID       = 241             -- Twilight Highlands

-- EST offset from UTC (seconds). EST = UTC - 5h.
local EST_OFFSET = -5 * 3600

-- Build fast lookups
local NPC_TO_INDEX = {}
for i, r in ipairs(ROTATION) do
    NPC_TO_INDEX[r.npcID] = i
end
NPC_TO_INDEX[VOICE_OF_ECLIPSE.npcID] = "eclipse"

local NAME_TO_NPC = {}
for _, r in ipairs(ROTATION) do
    NAME_TO_NPC[r.name:lower()] = r.npcID
end
NAME_TO_NPC[VOICE_OF_ECLIPSE.name:lower()] = VOICE_OF_ECLIPSE.npcID

-------------------------------------------------------------------------------
-- Visual constants
-------------------------------------------------------------------------------
local FRAME_WIDTH     = 340
local ROW_HEIGHT      = 22
local HEADER_HEIGHT   = 76
local PADDING         = 10
local PROGRESS_HEIGHT = 12

-- Colors (font string format: {r, g, b})
local C_GOLD    = { r = 1.00, g = 0.82, b = 0.00 }
local C_GREEN   = { r = 0.30, g = 1.00, b = 0.30 }
local C_RED     = { r = 1.00, g = 0.30, b = 0.30 }
local C_WHITE   = { r = 0.90, g = 0.90, b = 0.90 }
local C_GRAY    = { r = 0.45, g = 0.45, b = 0.45 }
local C_CYAN    = { r = 0.40, g = 0.85, b = 1.00 }
local C_PURPLE  = { r = 0.70, g = 0.50, b = 1.00 }
local C_DIM     = { r = 0.55, g = 0.55, b = 0.55 }
local C_KILLED  = { r = 0.20, g = 0.65, b = 0.20 }
local C_ORANGE  = { r = 1.00, g = 0.60, b = 0.15 }
local C_COORD   = { r = 0.70, g = 0.70, b = 0.85 }

-- Background colors (RGBA arrays for SetColorTexture)
local BG_DARK   = { 0.06, 0.06, 0.10, 0.92 }
local BG_TITLE  = { 0.12, 0.08, 0.20, 1.00 }
local BG_ROW_A  = { 1, 1, 1, 0.02 }
local BG_ROW_B  = { 1, 1, 1, 0.055 }
local BG_HOVER  = { 1, 1, 1, 0.10 }
local BG_NOW    = { 1.0, 0.82, 0.0, 0.14 }
local BG_NEXT   = { 0.4, 0.85, 1.0, 0.10 }
local BG_GOTO   = { 1.0, 0.60, 0.15, 0.16 }
local BORDER_C  = { 0.40, 0.30, 0.60, 0.90 }
local PROG_BG   = { 0.10, 0.10, 0.16, 1.0 }

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------
local db
local mainFrame, contentFrame
local rows = {}
local eclipseRow
local headerText, timerText, goToText
local progressBar, progressText
local isCollapsed = false

-------------------------------------------------------------------------------
-- Utility
-------------------------------------------------------------------------------
local function Hex(c)
    return string.format("%02x%02x%02x",
        math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255))
end

local function Col(text, c)
    return "|cff" .. Hex(c) .. text .. "|r"
end

local function FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function IsKilled(npcID)
    return db.kills and db.kills[npcID]
end

local function MarkKilled(npcID)
    if not db.kills then db.kills = {} end
    if db.kills[npcID] then return false end
    db.kills[npcID] = true
    return true
end

local function GetKillCount()
    local count = 0
    for _, r in ipairs(ROTATION) do
        if IsKilled(r.npcID) then count = count + 1 end
    end
    if IsKilled(VOICE_OF_ECLIPSE.npcID) then count = count + 1 end
    return count, TOTAL_RARES
end

local function GetNPCIDFromGUID(guid)
    if not guid then return nil end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(npcID)
    end
    return nil
end

local function GetRareName(npcID)
    local idx = NPC_TO_INDEX[npcID]
    if idx == "eclipse" then return VOICE_OF_ECLIPSE.name end
    if type(idx) == "number" then return ROTATION[idx].name end
    return nil
end

-------------------------------------------------------------------------------
-- Deterministic rotation schedule
-- The 18 rares cycle every 3 hours. Rare #2 spawns at exactly :00 EST
-- (the top of every 3-hour window: 0:00, 3:00, 6:00, ...).
-- Rare #1 spawns at :50 of the preceding hour (i.e. 10 min before).
-- Slot formula: slot 0 => rare #2, slot 1 => rare #3, ... slot 17 => rare #1
-------------------------------------------------------------------------------
local function GetCurrentRareInfo()
    local utcNow = GetServerTime()
    local estNow = utcNow + EST_OFFSET
    local secSinceMidnight = estNow % 86400
    local cyclePos = secSinceMidnight % CYCLE_SECONDS  -- 0..10799
    local slot = math.floor(cyclePos / SLOT_SECONDS)    -- 0..17
    local secIntoSlot = cyclePos - (slot * SLOT_SECONDS)
    local remaining = SLOT_SECONDS - secIntoSlot

    -- slot 0 => rare index 2, slot 1 => rare index 3, ..., slot 17 => rare index 1
    local rareIndex = (slot + 1) % NUM_RARES + 1
    return rareIndex, remaining
end

-- Find the next unkilled rare in rotation order starting from current
local function GetNextUnkilled(currentIdx)
    for offset = 0, NUM_RARES - 1 do
        local idx = ((currentIdx - 1 + offset) % NUM_RARES) + 1
        if not IsKilled(ROTATION[idx].npcID) then
            return idx, offset * SLOT_SECONDS  -- approx seconds until it spawns
        end
    end
    return nil, nil  -- all killed
end

-------------------------------------------------------------------------------
-- Waypoint integration (TomTom with built-in map pin fallback)
-------------------------------------------------------------------------------
local function HasTomTom()
    return TomTom and TomTom.AddWaypoint
end

local function SetWaypoint(x, y, title)
    -- TomTom (arrow + waypoint)
    if HasTomTom() then
        if db.lastWaypoint and TomTom.RemoveWaypoint then
            pcall(TomTom.RemoveWaypoint, TomTom, db.lastWaypoint)
        end
        local uid = TomTom:AddWaypoint(MAP_ID, x / 100, y / 100, { title = title, crazy = true })
        db.lastWaypoint = uid
        print(Col("[Twilight Tracker]", C_GOLD) .. " TomTom waypoint: " ..
            Col(title, C_CYAN) .. Col(string.format(" (%.1f, %.1f)", x, y), C_COORD))
        return
    end

    -- Built-in WoW waypoint (map pin + supertrack arrow)
    if C_Map and C_Map.SetUserWaypoint then
        local mapPoint = UiMapPoint.CreateFromCoordinates(MAP_ID, x / 100, y / 100)
        C_Map.SetUserWaypoint(mapPoint)
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        print(Col("[Twilight Tracker]", C_GOLD) .. " Waypoint set: " ..
            Col(title, C_CYAN) .. Col(string.format(" (%.1f, %.1f)", x, y), C_COORD) ..
            Col("  (map pin + tracking arrow)", C_DIM))
    else
        -- Last resort: just print coords to chat
        print(Col("[Twilight Tracker]", C_GOLD) .. " Go to: " ..
            Col(title, C_CYAN) .. Col(string.format(" at %.1f, %.1f", x, y), C_COORD))
    end
end

-------------------------------------------------------------------------------
-- Kill flash animation
-------------------------------------------------------------------------------
local function FlashRow(row)
    if not row or not row.bg then return end
    local flash = row.flash
    if not flash then
        flash = row:CreateTexture(nil, "OVERLAY")
        flash:SetAllPoints(row.bg)
        flash:SetColorTexture(0.3, 1.0, 0.3, 0.5)
        row.flash = flash
    end
    flash:SetAlpha(0.7)
    flash:Show()
    local elapsed = 0
    C_Timer.NewTicker(0.03, function(ticker)
        elapsed = elapsed + 0.03
        if elapsed >= 1.5 then
            flash:Hide()
            ticker:Cancel()
            return
        end
        flash:SetAlpha(0.7 * (1 - (elapsed / 1.5)))
    end)
end

-------------------------------------------------------------------------------
-- Kill announcement
-------------------------------------------------------------------------------
local function AnnounceKill(rareName)
    print(Col("[Twilight Tracker]", C_GOLD) .. " " ..
        Col(rareName, C_GREEN) .. " " .. Col("defeated!", C_WHITE))
    if UIErrorsFrame then
        UIErrorsFrame:AddMessage(
            Col("Twilight Tracker: ", C_GOLD) .. Col(rareName .. " defeated!", C_GREEN),
            1.0, 1.0, 1.0, 1.0, 3)
    end
end

-------------------------------------------------------------------------------
-- Core kill registration
-------------------------------------------------------------------------------
local UpdateUI  -- forward declaration

local function RegisterKill(npcID)
    if not npcID or not NPC_TO_INDEX[npcID] then return end
    local isNew = MarkKilled(npcID)
    if isNew then
        AnnounceKill(GetRareName(npcID))
        local idx = NPC_TO_INDEX[npcID]
        if idx == "eclipse" then
            FlashRow(eclipseRow)
        elseif rows[idx] then
            FlashRow(rows[idx])
        end
        -- Check if all done
        local killed, total = GetKillCount()
        if killed == total then
            print(Col("[Twilight Tracker]", C_GOLD) .. " " ..
                Col("ALL RARES DEFEATED! Achievement complete!", C_GREEN))
        end
    end
    if UpdateUI then UpdateUI() end
end

-------------------------------------------------------------------------------
-- UI Construction
-------------------------------------------------------------------------------
local function CreateRow(parent, index, rare, yOffset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(FRAME_WIDTH - 2, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, yOffset)

    -- Background
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    local stripe = (index and index % 2 == 0) and BG_ROW_B or BG_ROW_A
    bg:SetColorTexture(unpack(stripe))
    row.bg = bg
    row.defaultBG = stripe
    row.currentBG = stripe

    -- Hover
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if not self.isActive then
            bg:SetColorTexture(unpack(BG_HOVER))
        end
        -- Tooltip
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        local r = self.rare
        GameTooltip:AddLine(r.name, C_GOLD.r, C_GOLD.g, C_GOLD.b)
        if r.x and r.y then
            GameTooltip:AddLine(string.format("Location: %.1f, %.1f", r.x, r.y), 0.7, 0.7, 0.85)
        end
        if r.locations then
            for _, loc in ipairs(r.locations) do
                GameTooltip:AddLine(string.format("%s: %.1f, %.1f", loc.label, loc.x, loc.y), 0.7, 0.7, 0.85)
            end
        end
        if IsKilled(r.npcID) then
            GameTooltip:AddLine("Defeated", C_KILLED.r, C_KILLED.g, C_KILLED.b)
        end
        if HasTomTom() then
            GameTooltip:AddLine("Click to set TomTom waypoint", 0.5, 0.5, 0.5)
        else
            GameTooltip:AddLine("Click to set map waypoint", 0.5, 0.5, 0.5)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        if not self.isActive then
            bg:SetColorTexture(unpack(self.currentBG or self.defaultBG))
        end
        GameTooltip:Hide()
    end)
    row:SetScript("OnMouseDown", function(self)
        local r = self.rare
        if r.x and r.y then
            SetWaypoint(r.x, r.y, r.name)
        elseif r.locations then
            SetWaypoint(r.locations[1].x, r.locations[1].y, r.name)
        end
    end)

    -- Check / number
    local checkLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkLabel:SetPoint("LEFT", row, "LEFT", 6, 0)
    checkLabel:SetWidth(22)
    checkLabel:SetJustifyH("CENTER")
    row.checkLabel = checkLabel

    -- Name
    local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("LEFT", checkLabel, "RIGHT", 3, 0)
    nameLabel:SetWidth(180)
    nameLabel:SetJustifyH("LEFT")
    row.nameLabel = nameLabel

    -- Coord label
    local coordLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    coordLabel:SetPoint("RIGHT", row, "RIGHT", -60, 0)
    coordLabel:SetWidth(60)
    coordLabel:SetJustifyH("RIGHT")
    row.coordLabel = coordLabel

    -- Status
    local statusLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusLabel:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    statusLabel:SetWidth(54)
    statusLabel:SetJustifyH("RIGHT")
    row.statusLabel = statusLabel

    row.rare = rare
    row.index = index
    row.isActive = false
    return row
end

local CHECK_ICON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t"

local function UpdateRow(row, currentIdx, goToIdx)
    local rare = row.rare
    local idx = row.index
    local killed = IsKilled(rare.npcID)

    local isCurrent = (idx and currentIdx and idx == currentIdx)
    local isNext = (idx and currentIdx and ((currentIdx % NUM_RARES) + 1) == idx)
    local isGoTo = (idx and goToIdx and idx == goToIdx and not isCurrent)

    -- Check / number
    if killed then
        row.checkLabel:SetText(CHECK_ICON)
    elseif idx then
        row.checkLabel:SetText(Col(tostring(idx), C_DIM))
    else
        row.checkLabel:SetText(Col("*", C_PURPLE))
    end

    -- Row highlight
    row.isActive = isCurrent or isNext or isGoTo
    if killed then
        row.currentBG = row.defaultBG
    elseif isCurrent then
        row.currentBG = BG_NOW
    elseif isGoTo then
        row.currentBG = BG_GOTO
    elseif isNext then
        row.currentBG = BG_NEXT
    else
        row.currentBG = row.defaultBG
    end
    row.bg:SetColorTexture(unpack(row.currentBG))

    -- Name
    if killed then
        row.nameLabel:SetText(Col(rare.name, C_GRAY))
    elseif isCurrent then
        row.nameLabel:SetText(Col(rare.name, C_GOLD))
    elseif isGoTo then
        row.nameLabel:SetText(Col(rare.name, C_ORANGE))
    elseif isNext then
        row.nameLabel:SetText(Col(rare.name, C_CYAN))
    else
        row.nameLabel:SetText(Col(rare.name, C_WHITE))
    end

    -- Coords
    if rare.x and rare.y then
        local cc = killed and C_GRAY or C_COORD
        row.coordLabel:SetText(Col(string.format("%.1f, %.1f", rare.x, rare.y), cc))
    else
        row.coordLabel:SetText("")
    end

    -- Status
    if killed then
        row.statusLabel:SetText(Col("Done", C_KILLED))
    elseif isCurrent then
        row.statusLabel:SetText(Col("NOW", C_GOLD))
    elseif isGoTo then
        row.statusLabel:SetText(Col("GO TO", C_ORANGE))
    elseif isNext then
        row.statusLabel:SetText(Col("Next", C_CYAN))
    else
        row.statusLabel:SetText("")
    end
end

local function BuildUI()
    local listHeight = (NUM_RARES + 2) * ROW_HEIGHT  -- +2 for separator + eclipse
    local totalHeight = HEADER_HEIGHT + listHeight + PROGRESS_HEIGHT + 18

    mainFrame = CreateFrame("Frame", "TwilightTrackerFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(FRAME_WIDTH, totalHeight)
    mainFrame:SetPoint("RIGHT", UIParent, "RIGHT", -30, 0)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:SetClampedToScreen(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        db.pos = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    mainFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    mainFrame:SetBackdropColor(unpack(BG_DARK))
    mainFrame:SetBackdropBorderColor(unpack(BORDER_C))
    mainFrame:SetFrameStrata("MEDIUM")

    if db.pos then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint(db.pos.point, UIParent, db.pos.relPoint, db.pos.x, db.pos.y)
    end

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, mainFrame)
    titleBar:SetHeight(22)
    titleBar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -1, -1)
    local titleBG = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBG:SetAllPoints()
    titleBG:SetColorTexture(unpack(BG_TITLE))

    local titleStr = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleStr:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    titleStr:SetText(Col("Twilight Tracker", C_GOLD))

    -- Close (custom button to avoid UIPanelCloseButton taint)
    local closeBtn = CreateFrame("Button", nil, mainFrame)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -2, -2)
    closeBtn:SetNormalFontObject("GameFontNormal")
    closeBtn:SetHighlightFontObject("GameFontHighlight")
    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeTxt:SetPoint("CENTER")
    closeTxt:SetText(Col("X", C_RED))
    closeBtn:SetScript("OnEnter", function() closeTxt:SetText(Col("X", C_WHITE)) end)
    closeBtn:SetScript("OnLeave", function() closeTxt:SetText(Col("X", C_RED)) end)
    closeBtn:SetScript("OnClick", function() mainFrame:Hide(); db.hidden = true end)

    -- Collapse
    local collapseBtn = CreateFrame("Button", nil, mainFrame)
    collapseBtn:SetSize(22, 22)
    collapseBtn:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 2, 0)
    collapseBtn:EnableMouse(true)
    local collLabel = collapseBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    collLabel:SetAllPoints()

    -- Header: current rare + timer
    headerText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerText:SetPoint("TOP", titleBar, "BOTTOM", 0, -4)
    headerText:SetWidth(FRAME_WIDTH - 16)
    headerText:SetJustifyH("CENTER")

    timerText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timerText:SetPoint("TOP", headerText, "BOTTOM", 0, -1)
    timerText:SetWidth(FRAME_WIDTH - 16)
    timerText:SetJustifyH("CENTER")

    -- "Go to" indicator (next unkilled)
    goToText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    goToText:SetPoint("TOP", timerText, "BOTTOM", 0, -1)
    goToText:SetWidth(FRAME_WIDTH - 16)
    goToText:SetJustifyH("CENTER")

    -- Progress bar
    local progFrame = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    progFrame:SetHeight(PROGRESS_HEIGHT + 4)
    progFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", PADDING, -(HEADER_HEIGHT - 2))
    progFrame:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -PADDING, -(HEADER_HEIGHT - 2))
    progFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    progFrame:SetBackdropColor(unpack(PROG_BG))
    progFrame:SetBackdropBorderColor(0.25, 0.25, 0.40, 0.8)

    local progFill = progFrame:CreateTexture(nil, "ARTWORK")
    progFill:SetPoint("TOPLEFT", progFrame, "TOPLEFT", 1, -1)
    progFill:SetHeight(PROGRESS_HEIGHT + 2)
    progFill:SetColorTexture(0.25, 0.75, 1.0, 0.9)
    progressBar = progFill

    progressText = progFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    progressText:SetPoint("CENTER", progFrame, "CENTER", 0, 0)
    progressText:SetFont(progressText:GetFont(), 9, "OUTLINE")

    -- Content frame (rare list)
    contentFrame = CreateFrame("Frame", nil, mainFrame)
    contentFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, -(HEADER_HEIGHT + 4))
    contentFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 0, 0)

    local sep = contentFrame:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(BORDER_C[1], BORDER_C[2], BORDER_C[3], 0.4)
    sep:SetSize(FRAME_WIDTH - 2, 1)
    sep:SetPoint("TOP", contentFrame, "TOP", 0, 0)

    local yOff = -4
    for i, rare in ipairs(ROTATION) do
        rows[i] = CreateRow(contentFrame, i, rare, yOff)
        yOff = yOff - ROW_HEIGHT
    end

    -- Separator
    local sep2 = contentFrame:CreateTexture(nil, "ARTWORK")
    sep2:SetColorTexture(BORDER_C[1], BORDER_C[2], BORDER_C[3], 0.4)
    sep2:SetSize(FRAME_WIDTH - 20, 1)
    sep2:SetPoint("TOP", contentFrame, "TOP", 0, yOff - 2)
    yOff = yOff - 6

    eclipseRow = CreateRow(contentFrame, nil, VOICE_OF_ECLIPSE, yOff)

    -- Collapse logic
    local function SetCollapsed(state)
        isCollapsed = state
        db.collapsed = state
        if state then
            contentFrame:Hide()
            collLabel:SetText(Col("[+]", C_DIM))
            mainFrame:SetHeight(HEADER_HEIGHT + 14)
        else
            contentFrame:Show()
            collLabel:SetText(Col("[-]", C_DIM))
            mainFrame:SetHeight(totalHeight)
        end
    end
    collapseBtn:SetScript("OnClick", function() SetCollapsed(not isCollapsed) end)
    SetCollapsed(db.collapsed or false)
end

-------------------------------------------------------------------------------
-- UI Update
-------------------------------------------------------------------------------
UpdateUI = function()
    if not mainFrame or not mainFrame:IsShown() then return end

    local currentIdx, remaining = GetCurrentRareInfo()
    local nextIdx = (currentIdx % NUM_RARES) + 1

    -- Progress
    local killed, total = GetKillCount()
    local pct = killed / total
    local maxBarW = FRAME_WIDTH - 2 * PADDING - 2
    progressBar:SetWidth(math.max(1, maxBarW * pct))
    if killed == total then
        progressBar:SetColorTexture(0.3, 1.0, 0.3, 1.0)
        progressText:SetText(Col("COMPLETE " .. killed .. "/" .. total, C_GREEN))
    else
        progressBar:SetColorTexture(0.25, 0.70, 1.0, 0.9)
        progressText:SetText(Col(killed .. " / " .. total .. " defeated", C_WHITE))
    end

    -- Current rare header
    local cur = ROTATION[currentIdx]
    local curKilled = IsKilled(cur.npcID)
    local curColor = curKilled and C_GRAY or C_GOLD
    local prefix = curKilled and "" or ">> "
    local suffix = curKilled and "" or " <<"
    headerText:SetText(
        Col("Active:  ", C_DIM) .. Col(prefix .. cur.name .. suffix, curColor)
    )

    -- Timer to next
    local nxt = ROTATION[nextIdx]
    local nxtColor = IsKilled(nxt.npcID) and C_GRAY or C_CYAN
    timerText:SetText(
        Col("Next: ", C_DIM) .. Col(nxt.name, nxtColor) ..
        Col("  in  ", C_DIM) .. Col(FormatTime(remaining), C_GOLD)
    )

    -- "Go to" - find next unkilled rare
    local goToIdx = nil
    if killed < total then
        goToIdx = GetNextUnkilled(currentIdx)
        if goToIdx then
            local goRare = ROTATION[goToIdx]
            if goToIdx == currentIdx then
                goToText:SetText(
                    Col("Go to:  ", C_DIM) ..
                    Col(goRare.name, C_ORANGE) ..
                    Col(string.format("  (%.1f, %.1f)", goRare.x, goRare.y), C_COORD) ..
                    Col("  - Active now!", C_GOLD)
                )
            else
                -- How many slots away?
                local slotsAway = ((goToIdx - currentIdx) % NUM_RARES)
                local secsAway = (slotsAway - 1) * SLOT_SECONDS + remaining
                goToText:SetText(
                    Col("Go to:  ", C_DIM) ..
                    Col(goRare.name, C_ORANGE) ..
                    Col(string.format("  (%.1f, %.1f)", goRare.x, goRare.y), C_COORD) ..
                    Col("  in " .. FormatTime(secsAway), C_GOLD)
                )
            end
        else
            goToText:SetText("")
        end
    else
        goToText:SetText(Col("All rares defeated!", C_GREEN))
    end

    -- Update rows
    for i, row in ipairs(rows) do
        UpdateRow(row, currentIdx, goToIdx)
    end
    UpdateRow(eclipseRow, nil, nil)
end

-------------------------------------------------------------------------------
-- Event handling (multiple kill detection methods)
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")

local TRACKED_EVENTS = {
    "ADDON_LOADED",
    "COMBAT_LOG_EVENT_UNFILTERED",
    "BOSS_KILL",
    "VIGNETTE_MINIMAP_UPDATED",
    "PLAYER_TARGET_CHANGED",
    "UPDATE_MOUSEOVER_UNIT",
    "CRITERIA_EARNED",
}
for _, ev in ipairs(TRACKED_EVENTS) do
    eventFrame:RegisterEvent(ev)
end

eventFrame:SetScript("OnEvent", function(self, event, ...)

    -- ADDON_LOADED: initialize
    if event == "ADDON_LOADED" then
        local name = ...
        if name == ADDON_NAME then
            db = TwilightTrackerDB
            if not db.kills then db.kills = {} end
            BuildUI()
            if db.hidden then mainFrame:Hide() end

            local tomtomNote = HasTomTom()
                and Col("TomTom", C_GREEN) .. Col(" detected - click rows for arrow waypoints", C_DIM)
                or Col("Click any row to set a map waypoint + tracking arrow", C_DIM)
            print(Col("[Twilight Tracker]", C_GOLD) .. " loaded  |  " ..
                Col("/tt", C_CYAN) .. " toggle  |  " ..
                Col("/tt help", C_CYAN) .. " cmds")
            print(Col("[Twilight Tracker]", C_GOLD) .. " " .. tomtomNote)
            self:UnregisterEvent("ADDON_LOADED")
        end

    -- COMBAT_LOG: primary kill detection
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, _, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()
        if (subEvent == "UNIT_DIED" or subEvent == "PARTY_KILL") and destGUID then
            local npcID = GetNPCIDFromGUID(destGUID)
            if npcID and NPC_TO_INDEX[npcID] then
                RegisterKill(npcID)
            end
        end

    -- BOSS_KILL: backup for boss-flagged rares
    elseif event == "BOSS_KILL" then
        local _, encounterName = ...
        if encounterName then
            local npcID = NAME_TO_NPC[encounterName:lower()]
            if npcID then RegisterKill(npcID) end
        end

    -- VIGNETTE: detect rare icon on minimap (not a kill, just awareness)
    elseif event == "VIGNETTE_MINIMAP_UPDATED" then
        local vignetteGUID = ...
        if vignetteGUID and C_VignetteInfo then
            local info = C_VignetteInfo.GetVignetteInfo(vignetteGUID)
            if info and info.objectGUID then
                local npcID = GetNPCIDFromGUID(info.objectGUID)
                if npcID and NPC_TO_INDEX[npcID] then
                    if UpdateUI then UpdateUI() end
                end
            end
        end

    -- TARGET / MOUSEOVER: detect dead rares + general awareness
    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitExists("target") then
            local guid = UnitGUID("target")
            local npcID = GetNPCIDFromGUID(guid)
            if npcID and NPC_TO_INDEX[npcID] and UnitIsDead("target") then
                RegisterKill(npcID)
            end
        end

    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if UnitExists("mouseover") then
            local guid = UnitGUID("mouseover")
            local npcID = GetNPCIDFromGUID(guid)
            if npcID and NPC_TO_INDEX[npcID] and UnitIsDead("mouseover") then
                RegisterKill(npcID)
            end
        end

    elseif event == "CRITERIA_EARNED" then
        if UpdateUI then UpdateUI() end
    end
end)

-- Tick every 0.5 seconds
local tickElapsed = 0
eventFrame:SetScript("OnUpdate", function(self, elapsed)
    tickElapsed = tickElapsed + elapsed
    if tickElapsed >= 0.5 then
        tickElapsed = 0
        if UpdateUI then UpdateUI() end
    end
end)

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------
SLASH_TWILIGHTTRACKER1 = "/tt"
SLASH_TWILIGHTTRACKER2 = "/twilighttracker"

SlashCmdList["TWILIGHTTRACKER"] = function(msg)
    msg = strtrim(msg):lower()

    if msg == "" or msg == "toggle" then
        if mainFrame:IsShown() then
            mainFrame:Hide(); db.hidden = true
        else
            mainFrame:Show(); db.hidden = false
        end

    elseif msg == "show" then
        mainFrame:Show(); db.hidden = false

    elseif msg == "hide" then
        mainFrame:Hide(); db.hidden = true

    elseif msg == "reset" then
        db.kills = {}
        print(Col("[Twilight Tracker]", C_GOLD) .. " Kill data reset.")
        UpdateUI()

    elseif msg == "status" then
        local killed, total = GetKillCount()
        print(Col("[Twilight Tracker]", C_GOLD) ..
            string.format(" Progress: %d / %d", killed, total))
        local missing = {}
        for _, r in ipairs(ROTATION) do
            if not IsKilled(r.npcID) then
                table.insert(missing, string.format("%s (%.1f, %.1f)", r.name, r.x, r.y))
            end
        end
        if not IsKilled(VOICE_OF_ECLIPSE.npcID) then
            table.insert(missing, VOICE_OF_ECLIPSE.name .. " (Hourly)")
        end
        if #missing > 0 then
            print(Col("  Still needed:", C_RED))
            for _, m in ipairs(missing) do
                print("    " .. Col(m, C_WHITE))
            end
        else
            print(Col("  All rares defeated!", C_GREEN))
        end

    elseif msg == "waypoint" or msg == "wp" then
        -- Set waypoint to the next unkilled rare
        local curIdx = GetCurrentRareInfo()
        local goIdx = GetNextUnkilled(curIdx)
        if goIdx then
            local r = ROTATION[goIdx]
            SetWaypoint(r.x, r.y, r.name)
            print(Col("[Twilight Tracker]", C_GOLD) ..
                " Waypoint set: " .. Col(r.name, C_CYAN) ..
                Col(string.format(" (%.1f, %.1f)", r.x, r.y), C_COORD))
        else
            print(Col("[Twilight Tracker]", C_GREEN) .. " All rares defeated!")
        end

    elseif msg == "help" then
        print(Col("[Twilight Tracker] Commands:", C_GOLD))
        print("  " .. Col("/tt", C_CYAN) .. "           Toggle window")
        print("  " .. Col("/tt show", C_CYAN) .. "      Show window")
        print("  " .. Col("/tt hide", C_CYAN) .. "      Hide window")
        print("  " .. Col("/tt wp", C_CYAN) .. "        Set TomTom waypoint to next unkilled")
        print("  " .. Col("/tt status", C_CYAN) .. "    Print progress + missing rares")
        print("  " .. Col("/tt reset", C_CYAN) .. "     Clear all kill data")
        print("  " .. Col("/tt help", C_CYAN) .. "      This help text")
        print(" ")
        print("  " .. Col("Click any row", C_DIM) .. " to set a TomTom waypoint (if installed)")
        print("  " .. Col("Drag title bar", C_DIM) .. " to reposition the window")
    else
        print(Col("[Twilight Tracker]", C_RED) ..
            " Unknown command. " .. Col("/tt help", C_CYAN))
    end
end
