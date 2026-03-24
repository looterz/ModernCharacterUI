local addonName, ns = ...

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------
local SLOT_SIZE    = ns.SLOT_SIZE
local SLOT_SPACING = ns.SLOT_SPACING
local STATS_WIDTH  = ns.STATS_WIDTH
local MAX_SOCKETS  = 3
local SOCKET_SIZE  = 12

local EQUIP_ROW_HEIGHT = 26
local EQUIP_ICON_SIZE  = 22

---------------------------------------------------------------------------
-- Main Frame
---------------------------------------------------------------------------
local frame = CreateFrame("Frame", "MCUInspectFrame", UIParent, "PortraitFrameTemplate")
frame:SetSize(ns.FRAME_WIDTH, ns.FRAME_HEIGHT)
frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -124)
frame:SetFrameStrata("HIGH")
frame:SetClampedToScreen(true)
frame:Hide()
ns.inspectFrame = frame

tinsert(UISpecialFrames, "MCUInspectFrame")

frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")

frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    if ns.db and ns.db.global then
        ns.db.global.inspectPosition = { point, relativePoint, xOfs, yOfs }
    end
end)

---------------------------------------------------------------------------
-- Backgrounds — identical to our character panel
---------------------------------------------------------------------------
local SW = STATS_WIDTH

if frame.Bg then frame.Bg:Hide() end

local modelBg = frame:CreateTexture(nil, "BACKGROUND")
modelBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -21)
modelBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(SW + 2), 2)
modelBg:SetAtlas("transmog-locationbg")

local statsBg = frame:CreateTexture(nil, "BACKGROUND")
statsBg:SetPoint("TOPLEFT", modelBg, "TOPRIGHT")
statsBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
statsBg:SetAtlas("transmog-outfit-darkbg")

local statsFillBg = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
statsFillBg:SetPoint("TOPLEFT", statsBg, "TOPLEFT", 4, -4)
statsFillBg:SetPoint("BOTTOMRIGHT", statsBg, "BOTTOMRIGHT", -4, 4)
statsFillBg:SetAtlas("transmog-tabs-frame-bg")

local statsBorder = frame:CreateTexture(nil, "OVERLAY", nil, -1)
statsBorder:SetPoint("TOPLEFT", statsBg, "TOPLEFT", -11, 12)
statsBorder:SetPoint("BOTTOMRIGHT", statsBg, "BOTTOMRIGHT", 7, -10)
statsBorder:SetAtlas("transmog-tabs-frame")

local leftGrad = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
leftGrad:SetWidth(123)
leftGrad:SetPoint("TOPLEFT", modelBg, "TOPLEFT")
leftGrad:SetPoint("BOTTOMLEFT", modelBg, "BOTTOMLEFT")
leftGrad:SetAtlas("transmog-outfit-darkbg-gradient")

local rightGrad = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
rightGrad:SetWidth(123)
rightGrad:SetPoint("TOPRIGHT", modelBg, "TOPRIGHT")
rightGrad:SetPoint("BOTTOMRIGHT", modelBg, "BOTTOMRIGHT")
rightGrad:SetAtlas("transmog-outfit-darkbg-gradient")
rightGrad:SetRotation(math.rad(180))

local cornerLine = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
cornerLine:SetWidth(6)
cornerLine:SetPoint("TOPRIGHT", modelBg, "TOPRIGHT", 2, 0)
cornerLine:SetPoint("BOTTOMRIGHT", modelBg, "BOTTOMRIGHT", 2, 0)
cornerLine:SetAtlas("transmog-outfit-darkbg-cornerline")

---------------------------------------------------------------------------
-- Bottom Tabs
---------------------------------------------------------------------------
local TAB_CHARACTER = 1
local TAB_PVP       = 2
local TAB_GUILD     = 3

local tabs = {}
local currentTab = TAB_CHARACTER

-- Tab content containers
local characterPage = CreateFrame("Frame", nil, frame)
characterPage:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -21)
characterPage:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)

local pvpPage = CreateFrame("Frame", nil, frame)
pvpPage:SetAllPoints(characterPage)
pvpPage:Hide()

local guildPage = CreateFrame("Frame", nil, frame)
guildPage:SetAllPoints(characterPage)
guildPage:Hide()

local function SetTab(tabIndex)
    currentTab = tabIndex
    characterPage:SetShown(tabIndex == TAB_CHARACTER)
    pvpPage:SetShown(tabIndex == TAB_PVP)
    guildPage:SetShown(tabIndex == TAB_GUILD)
    -- Hide character tab backgrounds when on other tabs
    modelBg:SetShown(tabIndex == TAB_CHARACTER)
    statsBg:SetShown(tabIndex == TAB_CHARACTER)
    statsFillBg:SetShown(tabIndex == TAB_CHARACTER)
    statsBorder:SetShown(tabIndex == TAB_CHARACTER)
    leftGrad:SetShown(tabIndex == TAB_CHARACTER)
    rightGrad:SetShown(tabIndex == TAB_CHARACTER)
    cornerLine:SetShown(tabIndex == TAB_CHARACTER)
    PanelTemplates_SetTab(frame, tabIndex)
end

local tabData = {
    { text = CHARACTER },
    { text = PVP or "PvP" },
    { text = GUILD or "Guild" },
}

for i, data in ipairs(tabData) do
    local tab = CreateFrame("Button", "MCUInspectFrameTab" .. i, frame, "PanelTabButtonTemplate")
    tab:SetID(i)
    tab:SetText(data.text)
    tab:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        SetTab(self:GetID())
    end)
    if i == 1 then
        tab:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, -30)
    else
        tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", -15, 0)
    end
    PanelTemplates_TabResize(tab, 0, nil, 36, 88)
    tabs[i] = tab
end

frame.numTabs = #tabs
PanelTemplates_SetNumTabs(frame, #tabs)
PanelTemplates_SetTab(frame, TAB_CHARACTER)

---------------------------------------------------------------------------
-- Equipment Slot Columns (children of characterPage)
---------------------------------------------------------------------------
local SLOT_COL_INSET = 28

local leftColumn = CreateFrame("Frame", nil, characterPage)
leftColumn:SetWidth(SLOT_SIZE)
leftColumn:SetPoint("TOPLEFT", modelBg, "TOPLEFT", SLOT_COL_INSET, -50)
leftColumn:SetPoint("BOTTOMLEFT", modelBg, "BOTTOMLEFT", SLOT_COL_INSET, 0)

local rightColumn = CreateFrame("Frame", nil, characterPage)
rightColumn:SetWidth(SLOT_SIZE)
rightColumn:SetPoint("TOPRIGHT", modelBg, "TOPRIGHT", -SLOT_COL_INSET, -50)
rightColumn:SetPoint("BOTTOMRIGHT", modelBg, "BOTTOMRIGHT", -SLOT_COL_INSET, 0)

local bottomSlots = CreateFrame("Frame", nil, characterPage)
bottomSlots:SetSize(SLOT_SIZE * 2 + SLOT_SPACING, SLOT_SIZE)
bottomSlots:SetPoint("BOTTOM", modelBg, "BOTTOM", 0, 48)

---------------------------------------------------------------------------
-- 3D Model
---------------------------------------------------------------------------
local model = CreateFrame("DressUpModel", nil, characterPage)
model:SetPoint("TOPLEFT", leftColumn, "TOPRIGHT", 10, 10)
model:SetPoint("BOTTOMRIGHT", rightColumn, "BOTTOMLEFT", -10, 40)
model:SetFrameLevel(frame:GetFrameLevel() + 1)
model:SetKeepModelOnHide(false)

model:EnableMouse(true)
model:EnableMouseWheel(true)
model.rotation = 0
model.zoomLevel = 0

model:SetScript("OnMouseWheel", function(self, delta)
    local zoom = self.zoomLevel or 0
    zoom = zoom - delta * 0.05
    zoom = max(0.5, min(2.0, zoom))
    self.zoomLevel = zoom
    self:SetCamDistanceScale(zoom)
end)

model:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        self.isRotating = true
        self.rotateStartX = GetCursorPosition()
    end
end)

model:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
        self.isRotating = false
    end
end)

model:SetScript("OnUpdate", function(self)
    if self.isRotating then
        local x = GetCursorPosition()
        local diff = (x - (self.rotateStartX or x)) * 0.01
        self.rotateStartX = x
        self.rotation = (self.rotation or 0) + diff
        self:SetFacing(self.rotation)
    end
end)

frame.model = model

---------------------------------------------------------------------------
-- Create Equipment Slot Button (inspect version)
---------------------------------------------------------------------------
local slotButtons = {}

local function CreateInspectSlot(parent, slotInfo, index, anchorPoint, xOff, yOff)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(SLOT_SIZE, SLOT_SIZE)

    local yPos = -(index - 1) * (SLOT_SIZE + SLOT_SPACING) + (yOff or 0)
    if anchorPoint == "TOPRIGHT" then
        btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", xOff or 0, yPos)
    elseif anchorPoint == "TOPLEFT" then
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff or 0, yPos)
    else
        btn:SetPoint(anchorPoint, parent, anchorPoint, xOff or 0, yOff or 0)
    end

    btn.slotID   = slotInfo.id
    btn.slotName = slotInfo.name
    btn.slotLabel = slotInfo.label

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.08, 0.1, 0.9)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    local bSize = 2
    local function MakeBorderEdge(point1, point2, isHoriz)
        local t = btn:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(0.3, 0.3, 0.3, 0.8)
        if isHoriz then
            t:SetHeight(bSize); t:SetPoint(point1); t:SetPoint(point2)
        else
            t:SetWidth(bSize); t:SetPoint(point1); t:SetPoint(point2)
        end
        return t
    end

    btn.borderTop    = MakeBorderEdge("TOPLEFT", "TOPRIGHT", true)
    btn.borderBottom = MakeBorderEdge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    btn.borderLeft   = MakeBorderEdge("TOPLEFT", "BOTTOMLEFT", false)
    btn.borderRight  = MakeBorderEdge("TOPRIGHT", "BOTTOMRIGHT", false)
    btn.borderTextures = { btn.borderTop, btn.borderBottom, btn.borderLeft, btn.borderRight }

    local ilvlText = btn:CreateFontString(nil, "OVERLAY")
    ilvlText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    ilvlText:SetPoint("BOTTOMRIGHT", -3, 3)
    ilvlText:SetTextColor(1, 0.82, 0, 1)
    btn.ilvlText = ilvlText

    btn.sockets = {}
    for i = 1, MAX_SOCKETS do
        local gem = btn:CreateTexture(nil, "OVERLAY", nil, 2)
        gem:SetSize(SOCKET_SIZE, SOCKET_SIZE)
        gem:SetPoint("TOPLEFT", btn, "TOPRIGHT", 2, -(i - 1) * (SOCKET_SIZE + 1) - 2)
        gem:Hide()
        btn.sockets[i] = gem
    end

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.12)

    btn:SetScript("OnEnter", function(self)
        if not frame.unit then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local hasItem = GameTooltip:SetInventoryItem(frame.unit, self.slotID)
        if not hasItem then
            GameTooltip:SetText(self.slotLabel, 1, 1, 1)
        end
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:RegisterForClicks("LeftButtonUp")
    btn:SetScript("OnClick", function(self)
        if not frame.unit then return end
        if IsModifiedClick("DRESSUP") then
            local link = GetInventoryItemLink(frame.unit, self.slotID)
            if link then DressUpItemLink(link) end
        elseif IsModifiedClick("CHATLINK") then
            local link = GetInventoryItemLink(frame.unit, self.slotID)
            if link then ChatEdit_InsertLink(link) end
        end
    end)

    slotButtons[slotInfo.id] = btn
    return btn
end

for i, slotInfo in ipairs(ns.LEFT_SLOTS) do
    CreateInspectSlot(leftColumn, slotInfo, i, "TOPLEFT")
end
for i, slotInfo in ipairs(ns.RIGHT_SLOTS) do
    CreateInspectSlot(rightColumn, slotInfo, i, "TOPRIGHT")
end
for i, slotInfo in ipairs(ns.BOTTOM_SLOTS) do
    local xOff = (i - 1) * (SLOT_SIZE + SLOT_SPACING)
    CreateInspectSlot(bottomSlots, slotInfo, 1, "TOPLEFT", xOff, 0)
end

---------------------------------------------------------------------------
-- Right Side — Info Panel (child of characterPage)
---------------------------------------------------------------------------
local infoContainer = CreateFrame("Frame", nil, characterPage)
infoContainer:SetPoint("TOPLEFT", statsBg, "TOPLEFT", 14, -14)
infoContainer:SetPoint("BOTTOMRIGHT", statsBg, "BOTTOMRIGHT", -14, 14)

-- Character name
local nameText = infoContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
nameText:SetPoint("TOP", infoContainer, "TOP", 0, -8)
nameText:SetWidth(STATS_WIDTH - 40)
nameText:SetJustifyH("CENTER")
nameText:SetWordWrap(false)
frame.nameText = nameText

-- Level & class
local levelText = infoContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
levelText:SetPoint("TOP", nameText, "BOTTOM", 0, -4)
levelText:SetWidth(STATS_WIDTH - 40)
levelText:SetJustifyH("CENTER")
levelText:SetWordWrap(false)
frame.levelText = levelText

-- Specialization
local specText = infoContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
specText:SetPoint("TOP", levelText, "BOTTOM", 0, -2)
specText:SetWidth(STATS_WIDTH - 40)
specText:SetJustifyH("CENTER")
specText:SetTextColor(0.8, 0.8, 0.8)
frame.specText = specText

-- Guild
local guildText = infoContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
guildText:SetPoint("TOP", specText, "BOTTOM", 0, -4)
guildText:SetWidth(STATS_WIDTH - 40)
guildText:SetJustifyH("CENTER")
guildText:SetTextColor(0.25, 0.78, 0.92)
frame.guildText = guildText

-- Divider 1
local divider1 = infoContainer:CreateTexture(nil, "ARTWORK")
divider1:SetHeight(1)
divider1:SetPoint("LEFT", infoContainer, "LEFT", 0, 0)
divider1:SetPoint("RIGHT", infoContainer, "RIGHT", 0, 0)
divider1:SetPoint("TOP", guildText, "BOTTOM", 0, -10)
divider1:SetColorTexture(0.4, 0.4, 0.4, 0.4)

-- Item Level header
local ilvlHeader = infoContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
ilvlHeader:SetPoint("TOP", divider1, "BOTTOM", 0, -10)
ilvlHeader:SetText(STAT_AVERAGE_ITEM_LEVEL or "Item Level")
ilvlHeader:SetTextColor(1, 0.82, 0)

-- Item Level value
local ilvlValue = infoContainer:CreateFontString(nil, "OVERLAY")
ilvlValue:SetFont(STANDARD_TEXT_FONT, 28, "OUTLINE")
ilvlValue:SetPoint("TOP", ilvlHeader, "BOTTOM", 0, -4)
ilvlValue:SetTextColor(1, 0.82, 0)
frame.ilvlValue = ilvlValue

-- View in Dressing Room button (uses same API as legacy inspect: transmog info list)
local dressUpBtn = CreateFrame("Button", nil, infoContainer, "UIPanelButtonTemplate")
dressUpBtn:SetSize(STATS_WIDTH - 50, 26)
dressUpBtn:SetPoint("TOP", ilvlValue, "BOTTOM", 0, -10)
dressUpBtn:SetText(INSPECT_PAPERDOLL_VIEW or "View in Dressing Room")
dressUpBtn:SetScript("OnClick", function()
    if not frame.unit then return end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    local infoList = C_TransmogCollection.GetInspectItemTransmogInfoList()
    if not infoList then return end

    -- Open our dressing room directly (bypass DressUpItemTransmogInfoList which
    -- triggers ShowUIPanel on Blizzard's DressUpFrame and disturbs panel layout)
    if MCUDressingRoomFrame then
        MCUDressingRoomFrame:Show()
        -- Also collect item links for slots without transmog
        local unit = frame.unit
        local itemLinks = {}
        if unit then
            local allSlots = {}
            for _, s in ipairs(ns.LEFT_SLOTS)   do table.insert(allSlots, s) end
            for _, s in ipairs(ns.RIGHT_SLOTS)  do table.insert(allSlots, s) end
            for _, s in ipairs(ns.BOTTOM_SLOTS) do table.insert(allSlots, s) end
            for _, slotInfo in ipairs(allSlots) do
                local link = GetInventoryItemLink(unit, slotInfo.id)
                if link then
                    itemLinks[slotInfo.id] = link
                end
            end
        end

        MCUDR_PreviewedSlots = {}

        C_Timer.After(0.6, function()
            local actor = MCUDressingRoomFrame.CharacterPreview
                and MCUDressingRoomFrame.CharacterPreview.ModelScene
                and MCUDressingRoomFrame.CharacterPreview.ModelScene:GetPlayerActor()
            if not actor then return end

            -- Undress first so the player's own gear doesn't show through
            actor:Undress()

            -- Apply transmog info for each slot and populate preview slots
            for slotID, info in pairs(infoList) do
                local ignoreChildItems = slotID ~= INVSLOT_MAINHAND
                actor:SetItemTransmogInfo(info, slotID, ignoreChildItems)

                if info.appearanceID and info.appearanceID > 0 then
                    local sourceInfo = C_TransmogCollection.GetSourceInfo(info.appearanceID)
                    if sourceInfo then
                        local itemIcon
                        local itemID = sourceInfo.itemID or C_TransmogCollection.GetSourceItemID(info.appearanceID)
                        if itemID then
                            itemIcon = C_Item.GetItemIconByID(itemID) or select(5, C_Item.GetItemInfoInstant(itemID))
                        end
                        MCUDR_PreviewedSlots[slotID] = {
                            icon = itemIcon or sourceInfo.icon or sourceInfo.texture,
                            name = sourceInfo.name or "",
                            quality = sourceInfo.quality,
                            sourceID = info.appearanceID,
                        }
                    end
                end
            end

            -- For slots where transmog is "none" (showing base item), TryOn the actual item
            for slotID, link in pairs(itemLinks) do
                local info = infoList[slotID]
                if not info or (info.appearanceID and info.appearanceID == 0) then
                    actor:TryOn(link)
                    local itemName, _, quality, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(link)
                    if not itemIcon then
                        itemIcon = select(5, C_Item.GetItemInfoInstant(link))
                    end
                    MCUDR_PreviewedSlots[slotID] = {
                        link = link,
                        icon = itemIcon,
                        name = itemName or "",
                        quality = quality,
                    }
                end
            end

            if MCUDressingRoomFrame.CharacterPreview.RefreshDressingRoomSlots then
                C_Timer.After(0.3, function()
                    MCUDressingRoomFrame.CharacterPreview:RefreshDressingRoomSlots()
                end)
            end
        end)
    end
end)

-- View Talents button (uses same code path as legacy inspect)
local talentsBtn = CreateFrame("Button", nil, infoContainer, "UIPanelButtonTemplate")
talentsBtn:SetSize(STATS_WIDTH - 50, 26)
talentsBtn:SetPoint("TOP", dressUpBtn, "BOTTOM", 0, -4)
talentsBtn:SetText(TALENTS or "Talents")
talentsBtn:SetScript("OnClick", function()
    if not frame.unit then return end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    if PlayerSpellsUtil and PlayerSpellsUtil.OpenToClassTalentsTab then
        PlayerSpellsUtil.OpenToClassTalentsTab(frame.unit)
    elseif ClassTalentFrame and ClassTalentFrame.LoadUI then
        ClassTalentFrame.LoadUI()
    end
end)
frame.talentsBtn = talentsBtn

-- Divider 2
local divider2 = infoContainer:CreateTexture(nil, "ARTWORK")
divider2:SetHeight(1)
divider2:SetPoint("LEFT", infoContainer, "LEFT", 0, 0)
divider2:SetPoint("RIGHT", infoContainer, "RIGHT", 0, 0)
divider2:SetPoint("TOP", talentsBtn, "BOTTOM", 0, -10)
divider2:SetColorTexture(0.4, 0.4, 0.4, 0.4)

-- Equipment header
local equipHeader = infoContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
equipHeader:SetPoint("TOPLEFT", divider2, "BOTTOMLEFT", 0, -8)
equipHeader:SetText("Equipment")
equipHeader:SetTextColor(1, 0.82, 0)

-- Equipment list — scrollable
local equipScroll = CreateFrame("ScrollFrame", nil, infoContainer, "UIPanelScrollFrameTemplate")
equipScroll:SetPoint("TOPLEFT", equipHeader, "BOTTOMLEFT", 0, -6)
equipScroll:SetPoint("BOTTOMRIGHT", infoContainer, "BOTTOMRIGHT", -22, 4)

local equipContent = CreateFrame("Frame", nil, equipScroll)
equipContent:SetWidth(STATS_WIDTH - 60)
equipScroll:SetScrollChild(equipContent)
frame.equipContent = equipContent
frame.equipRows = {}

---------------------------------------------------------------------------
-- PvP Page Content
---------------------------------------------------------------------------
local pvpContainer = CreateFrame("Frame", nil, pvpPage)
pvpContainer:SetPoint("TOPLEFT", characterPage, "TOPLEFT")
pvpContainer:SetPoint("BOTTOMRIGHT", characterPage, "BOTTOMRIGHT")

-- Background
local pvpBaseBg = pvpContainer:CreateTexture(nil, "BACKGROUND")
pvpBaseBg:SetAllPoints()
pvpBaseBg:SetAtlas("transmog-outfit-darkbg")

local pvpFillBg = pvpContainer:CreateTexture(nil, "BACKGROUND", nil, 1)
pvpFillBg:SetPoint("TOPLEFT", 4, -4)
pvpFillBg:SetPoint("BOTTOMRIGHT", -4, 4)
pvpFillBg:SetAtlas("transmog-tabs-frame-bg")

local pvpBorder = pvpContainer:CreateTexture(nil, "OVERLAY", nil, -1)
pvpBorder:SetPoint("TOPLEFT", -11, 12)
pvpBorder:SetPoint("BOTTOMRIGHT", 7, -10)
pvpBorder:SetAtlas("transmog-tabs-frame")

-- Honor level badge (large, centered)
local pvpHonorBadge = pvpContainer:CreateTexture(nil, "ARTWORK")
pvpHonorBadge:SetSize(64, 64)
pvpHonorBadge:SetPoint("TOP", pvpContainer, "TOP", 0, -30)
frame.pvpHonorBadge = pvpHonorBadge

-- Honor level number (overlaid on badge)
local pvpHonorLevelNum = pvpContainer:CreateFontString(nil, "OVERLAY")
pvpHonorLevelNum:SetFont(STANDARD_TEXT_FONT, 22, "OUTLINE")
pvpHonorLevelNum:SetPoint("CENTER", pvpHonorBadge, "CENTER", 0, 0)
pvpHonorLevelNum:SetTextColor(1, 0.82, 0)
frame.pvpHonorLevelNum = pvpHonorLevelNum

-- Honor level label below badge
local pvpHonorLabel = pvpContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
pvpHonorLabel:SetPoint("TOP", pvpHonorBadge, "BOTTOM", 0, -4)
pvpHonorLabel:SetJustifyH("CENTER")
frame.pvpHonorLabel = pvpHonorLabel

-- HKs below honor label
local pvpHKs = pvpContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
pvpHKs:SetPoint("TOP", pvpHonorLabel, "BOTTOM", 0, -6)
pvpHKs:SetWidth(600)
pvpHKs:SetJustifyH("CENTER")
frame.pvpHKs = pvpHKs

-- Divider
local pvpDivider = pvpContainer:CreateTexture(nil, "ARTWORK")
pvpDivider:SetHeight(1)
pvpDivider:SetPoint("LEFT", pvpContainer, "LEFT", 40, 0)
pvpDivider:SetPoint("RIGHT", pvpContainer, "RIGHT", -40, 0)
pvpDivider:SetPoint("TOP", pvpHKs, "BOTTOM", 0, -12)
pvpDivider:SetColorTexture(0.4, 0.4, 0.4, 0.4)

-- PvP stat block helper (left-aligned within block, matching legacy layout)
local function CreatePvPStatBlock(parent, labelText)
    local block = CreateFrame("Frame", nil, parent)
    block:SetSize(280, 58)

    block.title = block:CreateFontString(nil, "OVERLAY", "Game13FontShadow")
    block.title:SetPoint("TOPLEFT", 0, 0)
    block.title:SetText(labelText or "")
    block.title:SetTextColor(1, 1, 1)

    block.ratingLabel = block:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    block.ratingLabel:SetPoint("TOPLEFT", block.title, "BOTTOMLEFT", 0, -4)
    block.ratingLabel:SetText(RATING or "Rating")

    block.rating = block:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    block.rating:SetPoint("LEFT", block.ratingLabel, "RIGHT", 4, 0)

    block.recordLabel = block:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    block.recordLabel:SetPoint("TOPLEFT", block.ratingLabel, "BOTTOMLEFT", 0, -2)
    block.recordLabel:SetText(RECORD or "Record")

    block.record = block:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    block.record:SetPoint("LEFT", block.recordLabel, "RIGHT", 4, 0)

    return block
end

-- Left column of stat blocks
local pvpArena2v2 = CreatePvPStatBlock(pvpContainer, ARENA_2V2 or "Arena 2v2")
pvpArena2v2:SetPoint("TOPLEFT", pvpDivider, "BOTTOMLEFT", 20, -16)
frame.pvpArena2v2 = pvpArena2v2

local pvpArena3v3 = CreatePvPStatBlock(pvpContainer, ARENA_3V3 or "Arena 3v3")
pvpArena3v3:SetPoint("TOPLEFT", pvpArena2v2, "BOTTOMLEFT", 0, -8)
frame.pvpArena3v3 = pvpArena3v3

local pvpSoloShuffle = CreatePvPStatBlock(pvpContainer, RATED_SOLO_SHUFFLE or "Solo Shuffle")
pvpSoloShuffle:SetPoint("TOPLEFT", pvpArena3v3, "BOTTOMLEFT", 0, -8)
frame.pvpSoloShuffle = pvpSoloShuffle

-- Right column of stat blocks
local pvpRatedBG = CreatePvPStatBlock(pvpContainer, BATTLEGROUND_RATING or "Rated BG")
pvpRatedBG:SetPoint("TOPLEFT", pvpDivider, "BOTTOMLEFT", 340, -16)
frame.pvpRatedBG = pvpRatedBG

local pvpBGBlitz = CreatePvPStatBlock(pvpContainer, "BG Blitz")
pvpBGBlitz:SetPoint("TOPLEFT", pvpRatedBG, "BOTTOMLEFT", 0, -8)
frame.pvpBGBlitz = pvpBGBlitz

-- No PvP data message
local pvpNoData = pvpContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
pvpNoData:SetPoint("CENTER", pvpContainer, "CENTER", 0, -40)
pvpNoData:SetText("No PvP data available")
pvpNoData:SetTextColor(0.5, 0.5, 0.5)
pvpNoData:Hide()
frame.pvpNoData = pvpNoData

frame.pvpContainer = pvpContainer

---------------------------------------------------------------------------
-- Guild Page Content — full-page layout with guild background
---------------------------------------------------------------------------
local guildContainer = CreateFrame("Frame", nil, guildPage)
guildContainer:SetPoint("TOPLEFT", characterPage, "TOPLEFT")
guildContainer:SetPoint("BOTTOMRIGHT", characterPage, "BOTTOMRIGHT")

-- Full-page dark background + fill + border (matches our stats panel style)
local guildBaseBg = guildContainer:CreateTexture(nil, "BACKGROUND")
guildBaseBg:SetAllPoints()
guildBaseBg:SetAtlas("transmog-outfit-darkbg")

local guildFillBg = guildContainer:CreateTexture(nil, "BACKGROUND", nil, 1)
guildFillBg:SetPoint("TOPLEFT", 4, -4)
guildFillBg:SetPoint("BOTTOMRIGHT", -4, 4)
guildFillBg:SetAtlas("transmog-tabs-frame-bg")

local guildBorderFrame = guildContainer:CreateTexture(nil, "OVERLAY", nil, -1)
guildBorderFrame:SetPoint("TOPLEFT", -11, 12)
guildBorderFrame:SetPoint("BOTTOMRIGHT", 7, -10)
guildBorderFrame:SetAtlas("transmog-tabs-frame")

-- Guild tabard banner
local guildBanner = guildContainer:CreateTexture(nil, "ARTWORK", nil, 0)
guildBanner:SetTexture("Interface\\GuildFrame\\GuildInspect-Parts")
guildBanner:SetSize(118, 144)
guildBanner:SetPoint("TOP", guildContainer, "TOP", 0, -30)
guildBanner:SetTexCoord(0.23632813, 0.46679688, 0.70117188, 0.98242188)
frame.guildBanner = guildBanner

-- Banner border
local guildBannerBorder = guildContainer:CreateTexture(nil, "ARTWORK", nil, 1)
guildBannerBorder:SetTexture("Interface\\GuildFrame\\GuildInspect-Parts")
guildBannerBorder:SetSize(118, 144)
guildBannerBorder:SetPoint("TOPLEFT", guildBanner, "TOPLEFT")
guildBannerBorder:SetTexCoord(0.00195313, 0.23242188, 0.70117188, 0.98242188)

-- Tabard icons (mirrored pair)
local tabardLeftIcon = guildContainer:CreateTexture(nil, "ARTWORK", nil, 2)
tabardLeftIcon:SetSize(50, 125)
tabardLeftIcon:SetPoint("TOPLEFT", guildBanner, "TOPLEFT", 10, -1)
tabardLeftIcon:SetTexCoord(1, 0, 0, 1)
frame.tabardLeftIcon = tabardLeftIcon

local tabardRightIcon = guildContainer:CreateTexture(nil, "ARTWORK", nil, 2)
tabardRightIcon:SetSize(50, 125)
tabardRightIcon:SetPoint("LEFT", tabardLeftIcon, "RIGHT", -1, 0)
frame.tabardRightIcon = tabardRightIcon

-- Guild name (below the banner)
local guildNameText = guildContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
guildNameText:SetPoint("TOP", guildBanner, "BOTTOM", 0, -16)
guildNameText:SetWidth(600)
guildNameText:SetJustifyH("CENTER")
frame.guildNameText = guildNameText

-- Guild realm
local guildRealmText = guildContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
guildRealmText:SetPoint("TOP", guildNameText, "BOTTOM", 0, -10)
guildRealmText:SetWidth(600)
guildRealmText:SetJustifyH("CENTER")
frame.guildRealmText = guildRealmText

-- Guild faction
local guildFactionText = guildContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
guildFactionText:SetPoint("TOP", guildRealmText, "BOTTOM", 0, -4)
guildFactionText:SetWidth(600)
guildFactionText:SetJustifyH("CENTER")
frame.guildFactionText = guildFactionText

-- Guild members
local guildMembersText = guildContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
guildMembersText:SetPoint("TOP", guildFactionText, "BOTTOM", 0, -26)
guildMembersText:SetWidth(600)
guildMembersText:SetJustifyH("CENTER")
frame.guildMembersText = guildMembersText

-- No guild message
local noGuildText = guildContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
noGuildText:SetPoint("CENTER", guildContainer, "CENTER", 0, 0)
noGuildText:SetText(NO_GUILD or "No Guild")
noGuildText:SetTextColor(0.5, 0.5, 0.5)
noGuildText:Hide()
frame.noGuildText = noGuildText

---------------------------------------------------------------------------
-- Update Functions
---------------------------------------------------------------------------
local function SetBorderColor(btn, r, g, b)
    for _, tex in ipairs(btn.borderTextures) do
        tex:SetColorTexture(r, g, b, 0.9)
    end
end

local function UpdateSlot(btn, unit)
    local slotID = btn.slotID
    local texture = GetInventoryItemTexture(unit, slotID)
    local quality = GetInventoryItemQuality(unit, slotID)
    local link    = GetInventoryItemLink(unit, slotID)

    if texture then
        btn.icon:SetTexture(texture)
        btn.icon:SetDesaturated(false)
        btn.icon:SetAlpha(1)
    else
        btn.icon:SetTexture(ns:GetEmptySlotTexture(slotID, btn.slotName))
        btn.icon:SetDesaturated(true)
        btn.icon:SetAlpha(0.3)
    end

    if quality and quality > 1 then
        local r, g, b = ns:GetQualityColor(quality)
        SetBorderColor(btn, r, g, b)
    else
        SetBorderColor(btn, 0.3, 0.3, 0.3)
    end

    if link then
        local effectiveILvl = GetDetailedItemLevelInfo(link)
        if effectiveILvl and effectiveILvl > 0 then
            btn.ilvlText:SetText(effectiveILvl)
            btn.ilvlText:Show()
        else
            btn.ilvlText:Hide()
        end
    else
        btn.ilvlText:Hide()
    end

    for i = 1, MAX_SOCKETS do btn.sockets[i]:Hide() end
    if link then
        local stats = C_Item.GetItemStats(link)
        if stats then
            local socketIdx = 1
            for stat, _ in pairs(stats) do
                if stat:find("SOCKET") and socketIdx <= MAX_SOCKETS then
                    btn.sockets[socketIdx]:SetTexture(458977)
                    btn.sockets[socketIdx]:Show()
                    socketIdx = socketIdx + 1
                end
            end
        end
    end
end

local function UpdateAllSlots()
    local unit = frame.unit
    if not unit then return end
    for _, btn in pairs(slotButtons) do
        UpdateSlot(btn, unit)
    end
end

local function UpdateModel()
    local unit = frame.unit
    if not unit then return end
    model:SetUnit(unit)
    model.rotation = 0
    model.zoomLevel = 0
    model:SetCamDistanceScale(1.15)
    model:SetFacing(0)
end

local function UpdateCharacterInfo()
    local unit = frame.unit
    if not unit then return end

    local name = UnitName(unit)
    local _, classFile = UnitClass(unit)
    local classColor = RAID_CLASS_COLORS[classFile]
    if classColor and name then
        frame.nameText:SetText(classColor:WrapTextInColorCode(name))
    else
        frame.nameText:SetText(name or "")
    end

    local level = UnitLevel(unit)
    local className = UnitClass(unit)
    local raceName = UnitRace(unit)
    frame.levelText:SetText(format("Level %d %s %s", level or 0, raceName or "", className or ""))

    local specID = GetInspectSpecialization(unit)
    if specID and specID > 0 then
        local _, specName = GetSpecializationInfoByID(specID, UnitSex(unit))
        if specName then
            frame.specText:SetText(specName)
            frame.specText:Show()
        else
            frame.specText:Hide()
        end
    else
        frame.specText:Hide()
    end

    local guildName, guildRankName = GetGuildInfo(unit)
    if guildName then
        frame.guildText:SetText("<" .. guildName .. ">")
        frame.guildText:Show()
    else
        frame.guildText:Hide()
    end

    local avgIlvl = C_PaperDollInfo.GetInspectItemLevel(unit)
    if avgIlvl and avgIlvl > 0 then
        frame.ilvlValue:SetText(format("%.1f", avgIlvl))
    else
        frame.ilvlValue:SetText("--")
    end

    SetPortraitTexture(frame:GetPortrait(), unit)
    frame:SetTitle(name or "Inspect")
end

local function UpdateEquipmentList()
    local unit = frame.unit
    if not unit then return end

    for _, row in ipairs(frame.equipRows) do row:Hide() end

    local allSlots = {}
    for _, s in ipairs(ns.LEFT_SLOTS)   do table.insert(allSlots, s) end
    for _, s in ipairs(ns.RIGHT_SLOTS)  do table.insert(allSlots, s) end
    for _, s in ipairs(ns.BOTTOM_SLOTS) do table.insert(allSlots, s) end

    local yOff = 0
    local rowIndex = 0

    for _, slotInfo in ipairs(allSlots) do
        local link = GetInventoryItemLink(unit, slotInfo.id)
        if link then
            rowIndex = rowIndex + 1
            local row = frame.equipRows[rowIndex]
            if not row then
                row = CreateFrame("Frame", nil, frame.equipContent)
                row:SetHeight(EQUIP_ROW_HEIGHT)

                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(EQUIP_ICON_SIZE, EQUIP_ICON_SIZE)
                row.icon:SetPoint("LEFT", 0, 0)
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

                row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
                row.nameText:SetPoint("RIGHT", row, "RIGHT", -36, 0)
                row.nameText:SetJustifyH("LEFT")
                row.nameText:SetWordWrap(false)

                row.ilvlText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.ilvlText:SetPoint("RIGHT", row, "RIGHT", 0, 0)
                row.ilvlText:SetJustifyH("RIGHT")
                row.ilvlText:SetTextColor(1, 0.82, 0)

                frame.equipRows[rowIndex] = row
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame.equipContent, "TOPLEFT", 0, yOff)
            row:SetPoint("RIGHT", frame.equipContent, "RIGHT", 0, 0)

            local itemName, _, quality, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(link)
            row.icon:SetTexture(itemTexture or GetInventoryItemTexture(unit, slotInfo.id))

            if itemName then
                local r, g, b = ns:GetQualityColor(quality)
                row.nameText:SetText(itemName)
                row.nameText:SetTextColor(r, g, b)
            else
                row.nameText:SetText(slotInfo.label)
                row.nameText:SetTextColor(0.5, 0.5, 0.5)
            end

            local effectiveILvl = GetDetailedItemLevelInfo(link)
            row.ilvlText:SetText(effectiveILvl or "")

            row:Show()
            yOff = yOff - EQUIP_ROW_HEIGHT
        end
    end

    frame.equipContent:SetHeight(math.abs(yOff) + 10)
end

local function UpdatePvPStatBlock(block, rating, won, played)
    rating = rating or 0
    won = won or 0
    played = played or 0
    local lost = played - won
    block.rating:SetText(tostring(rating))
    block.record:SetText(format("%d - %d", won, lost))
end

local function UpdatePvPPage()
    local unit = frame.unit
    if not unit then return end

    local hasData = false

    -- Honor data
    if GetInspectHonorData then
        local _, _, _, _, lifetimeHKs, _, honorLevel = GetInspectHonorData()
        honorLevel = honorLevel or 0
        lifetimeHKs = lifetimeHKs or 0

        if honorLevel > 0 then
            hasData = true
            -- Honor badge icon
            local badgeFileID = C_PvP and C_PvP.GetHonorRewardInfo and C_PvP.GetHonorRewardInfo(honorLevel)
            if badgeFileID then
                frame.pvpHonorBadge:SetTexture(badgeFileID)
            else
                frame.pvpHonorBadge:SetAtlas("honorsystem-icon-prestige-0")
            end
            frame.pvpHonorBadge:Show()
            frame.pvpHonorLevelNum:SetText(honorLevel)
            frame.pvpHonorLevelNum:Show()
            frame.pvpHonorLabel:SetText(format(HONOR_LEVEL_LABEL or "Honor Level %d", honorLevel))
            frame.pvpHonorLabel:Show()
        else
            frame.pvpHonorBadge:Hide()
            frame.pvpHonorLevelNum:Hide()
            frame.pvpHonorLabel:Hide()
        end

        if lifetimeHKs > 0 then
            hasData = true
            frame.pvpHKs:SetText(format("%s: %s", LIFETIME_HONORABLE_KILLS or "Lifetime Honorable Kills", BreakUpLargeNumbers(lifetimeHKs)))
            frame.pvpHKs:Show()
        else
            frame.pvpHKs:Hide()
        end
    end

    -- Arena 2v2 / 3v3
    if GetInspectArenaData then
        local r2, p2, w2 = GetInspectArenaData(1)
        UpdatePvPStatBlock(frame.pvpArena2v2, r2, w2, p2)
        if (r2 or 0) > 0 or (p2 or 0) > 0 then hasData = true end

        local r3, p3, w3 = GetInspectArenaData(2)
        UpdatePvPStatBlock(frame.pvpArena3v3, r3, w3, p3)
        if (r3 or 0) > 0 or (p3 or 0) > 0 then hasData = true end
    end

    -- Solo Shuffle
    if C_PaperDollInfo.GetInspectRatedSoloShuffleData then
        local data = C_PaperDollInfo.GetInspectRatedSoloShuffleData()
        if data then
            UpdatePvPStatBlock(frame.pvpSoloShuffle, data.rating, data.roundsWon, data.roundsPlayed)
            if (data.rating or 0) > 0 or (data.roundsPlayed or 0) > 0 then hasData = true end
        end
    end

    -- Rated BG
    if C_PaperDollInfo.GetInspectRatedBGData then
        local data = C_PaperDollInfo.GetInspectRatedBGData()
        if data then
            UpdatePvPStatBlock(frame.pvpRatedBG, data.rating, data.won, data.played)
            if (data.rating or 0) > 0 or (data.played or 0) > 0 then hasData = true end
        end
    end

    -- BG Blitz
    if C_PaperDollInfo.GetInspectRatedBGBlitzData then
        local data = C_PaperDollInfo.GetInspectRatedBGBlitzData()
        if data then
            UpdatePvPStatBlock(frame.pvpBGBlitz, data.rating, data.gamesWon, data.gamesPlayed)
            if (data.rating or 0) > 0 or (data.gamesPlayed or 0) > 0 then hasData = true end
        end
    end

    frame.pvpNoData:SetShown(not hasData)
end

local function UpdateGuildPage()
    local unit = frame.unit
    if not unit then return end

    local guildName, guildRankName = GetGuildInfo(unit)
    local hasGuild = guildName and guildName ~= ""

    -- Toggle visibility
    frame.guildBanner:SetShown(hasGuild)
    frame.tabardLeftIcon:SetShown(hasGuild)
    frame.tabardRightIcon:SetShown(hasGuild)
    frame.guildNameText:SetShown(hasGuild)
    frame.guildRealmText:SetShown(hasGuild)
    frame.guildFactionText:SetShown(hasGuild)
    frame.guildMembersText:SetShown(hasGuild)
    frame.noGuildText:SetShown(not hasGuild)

    if not hasGuild then return end

    frame.guildNameText:SetText(guildName)

    -- Faction
    local _, factionName = UnitFactionGroup(unit)
    frame.guildFactionText:SetText(factionName or "")

    -- Tabard textures
    if SetDoubleGuildTabardTextures then
        SetDoubleGuildTabardTextures(unit, frame.tabardLeftIcon, frame.tabardRightIcon, frame.guildBanner, nil)
    end

    -- Inspect guild info (member count, realm)
    local realmName, numMembers
    if C_PaperDollInfo and C_PaperDollInfo.GetInspectGuildInfo then
        local guildPoints, members, apiName, realm = C_PaperDollInfo.GetInspectGuildInfo(unit)
        numMembers = members
        realmName = realm
    end

    if realmName and realmName ~= "" then
        frame.guildRealmText:SetText(realmName)
        frame.guildRealmText:Show()
    else
        frame.guildRealmText:Hide()
    end

    if numMembers and numMembers > 0 then
        frame.guildMembersText:SetText(format(INSPECT_GUILD_NUM_MEMBERS or "%d Members", numMembers))
    else
        frame.guildMembersText:SetText("")
    end
end

local function UpdateTalentsButton()
    if frame.talentsBtn then
        local canView = C_Traits and C_Traits.HasValidInspectData and C_Traits.HasValidInspectData()
        frame.talentsBtn:SetEnabled(canView or false)
        if not canView then
            frame.talentsBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(TALENTS or "Talents")
                GameTooltip:AddLine(INSPECT_TALENT_DATA_UNAVAILABLE or "Talent data not available", 1, 0, 0)
                GameTooltip:Show()
            end)
            frame.talentsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        else
            frame.talentsBtn:SetScript("OnEnter", nil)
            frame.talentsBtn:SetScript("OnLeave", nil)
        end
    end
end

local function RefreshAll()
    if not frame.unit or not frame:IsShown() then return end
    UpdateCharacterInfo()
    UpdateAllSlots()
    UpdateEquipmentList()
    UpdatePvPPage()
    UpdateGuildPage()
    UpdateTalentsButton()
end

---------------------------------------------------------------------------
-- Inspect retry logic
---------------------------------------------------------------------------
local pendingInspect = nil
local INSPECT_TIMEOUT = 2
local MAX_RETRIES = 3

local function CancelPendingInspect()
    if pendingInspect and pendingInspect.timer then
        pendingInspect.timer:Cancel()
    end
    pendingInspect = nil
end

local function ScheduleInspectRetry()
    if not pendingInspect then return end

    if pendingInspect.retries >= MAX_RETRIES then
        -- Give up — show the frame with whatever data we have
        CancelPendingInspect()
        frame:Show()
        UpdateModel()
        RefreshAll()
        return
    end

    local unit = pendingInspect.unit
    local guid = pendingInspect.guid

    if not UnitExists(unit) or UnitGUID(unit) ~= guid or not CanInspect(unit, true) then
        CancelPendingInspect()
        return
    end

    pendingInspect.retries = pendingInspect.retries + 1
    NotifyInspect(unit)
    pendingInspect.timer = C_Timer.NewTimer(INSPECT_TIMEOUT, ScheduleInspectRetry)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
frame:RegisterEvent("INSPECT_READY")
frame:RegisterEvent("INSPECT_HONOR_UPDATE")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("UNIT_NAME_UPDATE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "INSPECT_READY" then
        local guid = ...
        if self.unit and UnitGUID(self.unit) == guid then
            local ilevel = C_PaperDollInfo.GetInspectItemLevel(self.unit)
            if (not ilevel or ilevel == 0) and pendingInspect and pendingInspect.guid == guid then
                -- Data didn't fully load; cancel current timer and retry
                if pendingInspect.timer then pendingInspect.timer:Cancel() end
                ScheduleInspectRetry()
                return
            end
            CancelPendingInspect()
            self:Show()
            UpdateModel()
            RefreshAll()
        end
    elseif event == "INSPECT_HONOR_UPDATE" then
        if self:IsShown() then
            UpdatePvPPage()
        end
    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if self.unit and UnitIsUnit(unit, self.unit) and self:IsShown() then
            RefreshAll()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if self:IsShown() and self.unit == "target" and not UnitExists("target") then
            self:Hide()
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if self:IsShown() and self.unit and not UnitExists(self.unit) then
            self:Hide()
        end
    elseif event == "UNIT_NAME_UPDATE" then
        local unit = ...
        if self.unit and UnitIsUnit(unit, self.unit) and self:IsShown() then
            UpdateCharacterInfo()
        end
    end
end)

frame:SetScript("OnHide", function(self)
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    CancelPendingInspect()
    self.unit = nil
    ClearInspectPlayer()
end)

frame:SetScript("OnShow", function(self)
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
    SetTab(TAB_CHARACTER)
    if ns.db and ns.db.global and ns.db.global.inspectPosition then
        local pos = ns.db.global.inspectPosition
        self:ClearAllPoints()
        self:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end
end)

---------------------------------------------------------------------------
-- Public: Show inspect for a unit
---------------------------------------------------------------------------
function ns:ShowInspect(unit)
    if not unit then return end

    CancelPendingInspect()
    local guid = UnitGUID(unit)
    if not guid then return end

    frame.unit = unit
    pendingInspect = { guid = guid, unit = unit, retries = 0 }
    NotifyInspect(unit)
    pendingInspect.timer = C_Timer.NewTimer(INSPECT_TIMEOUT, ScheduleInspectRetry)
end

---------------------------------------------------------------------------
-- Hook the inspect system
---------------------------------------------------------------------------
-- Same pattern as HookCharacterPanel: replace the global function so
-- Blizzard's InspectFrame never opens in the first place. This avoids
-- taint and panel system conflicts entirely.
function ns:InitInspectHooks()
    local originalInspectUnit = InspectUnit
    InspectUnit = function(unit, ...)
        if ns.db and ns.db.global and ns.db.global.overrideInspect then
            if unit and CanInspect(unit, true) then
                ns:ShowInspect(unit)
            end
            return
        end
        return originalInspectUnit(unit, ...)
    end
end
