local addonName, ns = ...

local frame = CreateFrame("Frame", "ModernCharacterUIFrame", UIParent, "PortraitFrameTemplate")
frame:SetSize(ns.FRAME_WIDTH, ns.FRAME_HEIGHT)
frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -104)
frame:SetFrameStrata("HIGH")
frame:SetClampedToScreen(true)
frame:Hide()
ns.frame = frame

tinsert(UISpecialFrames, "ModernCharacterUIFrame")

frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")

frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    if ns.db and ns.db.global then
        ns.db.global.position = { point, relativePoint, xOfs, yOfs }
    end
end)

-- Hide the default PortraitFrameTemplate tiled-rock background and layer
-- our own atlases using the same sublevels Blizzard's Transmog panel uses:
--   0 = base backgrounds, 1 = gradient overlays, 2 = edge details
local SW = ns.STATS_WIDTH

if frame.Bg then frame.Bg:Hide() end

local modelBg = frame:CreateTexture(nil, "BACKGROUND")
modelBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -21)
modelBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(SW + 2), 2)
modelBg:SetAtlas("transmog-locationbg")
ns.modelBg = modelBg

-- Stats panel uses the same layered approach as the Transmog WardrobeCollection:
-- dark base, then transmog-tabs-frame-bg fill, then transmog-tabs-frame border
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
statsBorder:SetPoint("BOTTOMRIGHT", statsBg, "BOTTOMRIGHT", 12, -10)
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

local SLOT_COL_INSET = 28

local leftColumn = CreateFrame("Frame", nil, frame)
leftColumn:SetSize(ns.SLOT_SIZE, (ns.SLOT_SIZE + ns.SLOT_SPACING) * 8)
leftColumn:SetPoint("TOPLEFT", modelBg, "TOPLEFT", SLOT_COL_INSET, -50)
ns.leftColumn = leftColumn

local rightColumn = CreateFrame("Frame", nil, frame)
rightColumn:SetSize(ns.SLOT_SIZE, (ns.SLOT_SIZE + ns.SLOT_SPACING) * 8)
rightColumn:SetPoint("TOPRIGHT", modelBg, "TOPRIGHT", -SLOT_COL_INSET, -50)
ns.rightColumn = rightColumn

local bottomSlots = CreateFrame("Frame", nil, frame)
bottomSlots:SetSize((ns.SLOT_SIZE * 2) + ns.SLOT_SPACING, ns.SLOT_SIZE)
bottomSlots:SetPoint("BOTTOM", modelBg, "BOTTOM", 0, 48)
ns.bottomSlots = bottomSlots

local TAB_HEIGHT = 24

local tabBar = CreateFrame("Frame", nil, frame)
tabBar:SetHeight(TAB_HEIGHT)
tabBar:SetPoint("TOPLEFT", statsBg, "TOPLEFT", 6, -6)
tabBar:SetPoint("TOPRIGHT", statsBg, "TOPRIGHT", -6, -6)

local tabDivider = frame:CreateTexture(nil, "ARTWORK")
tabDivider:SetHeight(1)
tabDivider:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT")
tabDivider:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT")
tabDivider:SetColorTexture(0.45, 0.40, 0.25, 0.4)

local function CreateTabButton(parent, text, anchor1, anchor2)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetPoint(unpack(anchor1))
    btn:SetPoint(unpack(anchor2))

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", 0, 1)
    label:SetText(text)
    btn.label = label

    local indicator = btn:CreateTexture(nil, "OVERLAY")
    indicator:SetHeight(2)
    indicator:SetPoint("BOTTOMLEFT", 4, 0)
    indicator:SetPoint("BOTTOMRIGHT", -4, 0)
    indicator:SetColorTexture(0.9, 0.75, 0.3, 1)
    indicator:Hide()
    btn.indicator = indicator

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.05)
    return btn
end

local statsTab = CreateTabButton(tabBar,
    STAT_CATEGORY_ATTRIBUTES or "Stats",
    {"TOPLEFT"}, {"BOTTOMRIGHT", tabBar, "BOTTOM"})

local equipTab = CreateTabButton(tabBar,
    EQUIPMENT_MANAGER or "Equipment Sets",
    {"TOPRIGHT"}, {"BOTTOMLEFT", tabBar, "BOTTOM"})

local statsContainer = CreateFrame("Frame", nil, frame)
statsContainer:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -4)
statsContainer:SetPoint("BOTTOMRIGHT", statsBg, "BOTTOMRIGHT", -6, 4)
ns.statsContainer = statsContainer

local equipContainer = CreateFrame("Frame", nil, frame)
equipContainer:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -4)
equipContainer:SetPoint("BOTTOMRIGHT", statsBg, "BOTTOMRIGHT", -6, 4)
equipContainer:Hide()
ns.equipContainer = equipContainer

local activeTab = "stats"
local function SetActiveTab(tabName)
    activeTab = tabName
    if tabName == "stats" then
        statsContainer:Show()
        equipContainer:Hide()
        statsTab.label:SetTextColor(1, 0.82, 0, 1)
        statsTab.indicator:Show()
        equipTab.label:SetTextColor(0.6, 0.6, 0.6, 1)
        equipTab.indicator:Hide()
    else
        statsContainer:Hide()
        equipContainer:Show()
        statsTab.label:SetTextColor(0.6, 0.6, 0.6, 1)
        statsTab.indicator:Hide()
        equipTab.label:SetTextColor(1, 0.82, 0, 1)
        equipTab.indicator:Show()
        if ns.UpdateEquipmentSets then ns:UpdateEquipmentSets() end
    end
end
statsTab:SetScript("OnClick", function() SetActiveTab("stats") end)
equipTab:SetScript("OnClick", function() SetActiveTab("equip") end)
SetActiveTab("stats")
ns.SetActiveTab = SetActiveTab

local function UpdateTitle()
    local name = UnitPVPName("player") or UnitName("player") or ""
    frame:SetTitle(name)
    frame:SetPortraitToUnit("player")
end

local function IsBlockedByCombat()
    return ns.db and ns.db.global and ns.db.global.blockInCombat
           and InCombatLockdown()
end

function ns:ShowPanel()
    if IsBlockedByCombat() then return end
    frame:Show()
end

function ns:HidePanel()
    frame:Hide()
end

function ns:TogglePanel()
    if frame:IsShown() then
        frame:Hide()
    else
        if IsBlockedByCombat() then return end
        frame:Show()
    end
end

function ns:RefreshAll()
    UpdateTitle()
    if self.UpdateAllSlots then self:UpdateAllSlots() end
    if self.UpdateModel then self:UpdateModel() end
    if self.UpdateStats then self:UpdateStats() end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

local UNIT_EVENTS = {
    "UNIT_STATS",
    "UNIT_AURA",
    "UNIT_ATTACK_SPEED",
    "UNIT_MAXHEALTH",
    "UNIT_MODEL_CHANGED",
    "UNIT_NAME_UPDATE",
}

local GLOBAL_EVENTS = {
    "PLAYER_EQUIPMENT_CHANGED",
    "COMBAT_RATING_UPDATE",
    "PLAYER_AVG_ITEM_LEVEL_UPDATE",
    "PLAYER_DAMAGE_DONE_MODS",
    "PLAYER_SPECIALIZATION_CHANGED",
    "UNIT_INVENTORY_CHANGED",
    "KNOWN_TITLES_UPDATE",
    "EQUIPMENT_SETS_CHANGED",
    "EQUIPMENT_SWAP_FINISHED",
    "ZONE_CHANGED_NEW_AREA",
    "UPDATE_FACTION",
    "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
    "CURRENCY_DISPLAY_UPDATE",
}

frame:SetScript("OnShow", function(self)
    ns:RefreshAll()
    for _, ev in ipairs(UNIT_EVENTS) do
        self:RegisterUnitEvent(ev, "player")
    end
    for _, ev in ipairs(GLOBAL_EVENTS) do
        self:RegisterEvent(ev)
    end
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
end)

frame:SetScript("OnHide", function(self)
    for _, ev in ipairs(UNIT_EVENTS) do
        self:UnregisterEvent(ev)
    end
    for _, ev in ipairs(GLOBAL_EVENTS) do
        self:UnregisterEvent(ev)
    end
    if ns._SetMainTab then ns._SetMainTab("character") end
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
end)

frame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "PLAYER_LOGIN" then
        local pos = ns.db and ns.db.global and ns.db.global.position
        if pos then
            self:ClearAllPoints()
            self:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
        end
        ns:ApplyFrameScale()
        ns:ApplySlotFontSize()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        if self:IsShown() then
            ns:RefreshAll()
        end
        return
    end

    if not self:IsShown() then return end

    if event == "PLAYER_EQUIPMENT_CHANGED" then
        local slotID = arg1
        if ns.UpdateSlot then ns:UpdateSlot(slotID) end
        if ns.UpdateModel then ns:UpdateModel() end
        if ns.UpdateStats then ns:UpdateStats() end
        if ns.UpdateEquipmentSets then ns:UpdateEquipmentSets() end
    elseif event == "UNIT_MODEL_CHANGED" then
        if ns.UpdateModel then ns:UpdateModel() end
    elseif event == "UNIT_NAME_UPDATE" or event == "KNOWN_TITLES_UPDATE" then
        UpdateTitle()
        if ns.UpdateTitleDropdown then ns:UpdateTitleDropdown() end
        if ns.UpdateStats then ns:UpdateStats() end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        ns:RefreshAll()
    elseif event == "EQUIPMENT_SETS_CHANGED" or event == "EQUIPMENT_SWAP_FINISHED" then
        if ns.UpdateEquipmentSets then ns:UpdateEquipmentSets() end
    elseif event == "UPDATE_FACTION" or event == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" then
        if ns.UpdateReputation then ns:UpdateReputation() end
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        if ns.UpdateCurrency then ns:UpdateCurrency() end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        ns:RefreshAll()
    else
        if ns.UpdateStats then ns:UpdateStats() end
    end
end)

local mainCharTab = CreateFrame("Button", "ModernCharacterUITab1", frame,
                                "PanelTabButtonTemplate")
mainCharTab:SetID(1)
mainCharTab:SetText(CHARACTER or "Character")
mainCharTab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 11, 2)
PanelTemplates_TabResize(mainCharTab, 0)

local mainRepTab = CreateFrame("Button", "ModernCharacterUITab2", frame,
                               "PanelTabButtonTemplate")
mainRepTab:SetID(2)
mainRepTab:SetText(REPUTATION or "Reputation")
mainRepTab:SetPoint("TOPLEFT", mainCharTab, "TOPRIGHT", 1, 0)
PanelTemplates_TabResize(mainRepTab, 0)

local mainCurrTab = CreateFrame("Button", "ModernCharacterUITab3", frame,
                                "PanelTabButtonTemplate")
mainCurrTab:SetID(3)
mainCurrTab:SetText(CURRENCY or "Currency")
mainCurrTab:SetPoint("TOPLEFT", mainRepTab, "TOPRIGHT", 1, 0)
PanelTemplates_TabResize(mainCurrTab, 0)

frame.numTabs = 3
frame.Tabs = { mainCharTab, mainRepTab, mainCurrTab }
PanelTemplates_SetNumTabs(frame, 3)
PanelTemplates_SetTab(frame, 1)

local function CreateFullContentFrame()
    local f = CreateFrame("Frame", nil, frame)
    f:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -21)
    f:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2)
    f:SetFrameLevel(frame:GetFrameLevel() + 1)
    f:Hide()

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetAtlas("transmog-outfit-darkbg")

    local fillBg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    fillBg:SetPoint("TOPLEFT", 4, -4)
    fillBg:SetPoint("BOTTOMRIGHT", -4, 4)
    fillBg:SetAtlas("transmog-tabs-frame-bg")

    local border = f:CreateTexture(nil, "OVERLAY", nil, -1)
    border:SetPoint("TOPLEFT", -11, 12)
    border:SetPoint("BOTTOMRIGHT", 10, -10)
    border:SetAtlas("transmog-tabs-frame")

    return f
end

local repContent = CreateFullContentFrame()
ns.repContent = repContent

local currContent = CreateFullContentFrame()
ns.currContent = currContent

local charTextures = {
    modelBg, statsBg, statsFillBg, statsBorder,
    leftGrad, rightGrad, cornerLine,
}

local function HideCharacterElements()
    for _, tex in ipairs(charTextures) do tex:Hide() end
    ns.leftColumn:Hide()
    ns.rightColumn:Hide()
    ns.bottomSlots:Hide()
    if ns.model then ns.model:Hide() end
    if ns.controlBar then ns.controlBar:Hide() end
    tabBar:Hide()
    tabDivider:Hide()
    statsContainer:Hide()
    equipContainer:Hide()
end

local function ShowCharacterElements()
    for _, tex in ipairs(charTextures) do tex:Show() end
    ns.leftColumn:Show()
    ns.rightColumn:Show()
    ns.bottomSlots:Show()
    if ns.model then ns.model:Show() end
    if ns.controlBar then ns.controlBar:Show() end
    tabBar:Show()
    tabDivider:Show()
    SetActiveTab(activeTab)
end

local activeMainTab = "character"

local function SetMainTab(tabName)
    activeMainTab = tabName
    repContent:Hide()
    currContent:Hide()

    if tabName == "character" then
        PanelTemplates_SetTab(frame, 1)
        ShowCharacterElements()
    elseif tabName == "reputation" then
        PanelTemplates_SetTab(frame, 2)
        HideCharacterElements()
        repContent:Show()
        if ns.UpdateReputation then ns:UpdateReputation() end
    elseif tabName == "currency" then
        PanelTemplates_SetTab(frame, 3)
        HideCharacterElements()
        currContent:Show()
        if ns.UpdateCurrency then ns:UpdateCurrency() end
    end
end
ns._SetMainTab = SetMainTab

mainCharTab:SetScript("OnClick", function()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    SetMainTab("character")
end)
mainRepTab:SetScript("OnClick", function()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    SetMainTab("reputation")
end)
mainCurrTab:SetScript("OnClick", function()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    SetMainTab("currency")
end)
SetMainTab("character")
ns.SetMainTab = SetMainTab

