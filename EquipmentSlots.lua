local addonName, ns = ...

local SLOT_SIZE    = ns.SLOT_SIZE
local SLOT_SPACING = ns.SLOT_SPACING
local MAX_SOCKETS  = 3
local SOCKET_SIZE  = 12

ns.slotButtons = {}

-- Ensure native CharacterFrame is loaded so we can reparent its slot buttons
if C_AddOns and C_AddOns.LoadAddOn then
    C_AddOns.LoadAddOn("Blizzard_CharacterFrame")
elseif LoadAddOn then
    LoadAddOn("Blizzard_CharacterFrame")
end

local function CreateSlotButton(parent, slotInfo, index, anchorPoint, xOff, yOff)
    -- Reparent the native Blizzard slot button for secure click handling
    -- (enchants, weapon oils, armor kits, drag-and-drop all work natively)
    local nativeName = "Character" .. slotInfo.name
    local btn = _G[nativeName]

    if not btn then
        -- Fallback: create our own if native doesn't exist
        btn = CreateFrame("Button", "ModernCharacterUISlot" .. slotInfo.id, parent)
    else
        btn:SetParent(parent)
    end

    btn:ClearAllPoints()
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

    -- Hide native visual elements we replace with our own
    if btn.NormalTexture then btn.NormalTexture:SetAlpha(0) end
    if btn.IconBorder then btn.IconBorder:SetAlpha(0) end
    if btn.IconOverlay2 then btn.IconOverlay2:SetAlpha(0) end

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.08, 0.1, 0.9)

    -- Use the native icon if available, otherwise create our own
    local icon = btn.icon or btn.Icon
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 3, -3)
        icon:SetPoint("BOTTOMRIGHT", -3, 3)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 3, -3)
        icon:SetPoint("BOTTOMRIGHT", -3, 3)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    btn.icon = icon

    local bSize = 2
    local function MakeBorderEdge(point1, point2, isHoriz)
        local t = btn:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(0.3, 0.3, 0.3, 0.8)
        if isHoriz then
            t:SetHeight(bSize)
            t:SetPoint(point1)
            t:SetPoint(point2)
        else
            t:SetWidth(bSize)
            t:SetPoint(point1)
            t:SetPoint(point2)
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

    local cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawEdge(false)
    btn.cooldown = cooldown

    -- Enchant status indicator (top-left corner, shown when enchanted)
    local enchantWarning = btn:CreateTexture(nil, "OVERLAY", nil, 3)
    enchantWarning:SetSize(14, 14)
    enchantWarning:SetPoint("TOPLEFT", 2, -2)
    enchantWarning:SetAtlas("Professions-Icon-Quality-Tier3-Small")
    enchantWarning:Hide()
    btn.enchantWarning = enchantWarning

    -- Upgrade track text (top-right corner, small)
    local upgradeText = btn:CreateFontString(nil, "OVERLAY")
    upgradeText:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    upgradeText:SetPoint("TOPRIGHT", -2, -4)
    upgradeText:SetTextColor(1, 0.82, 0, 1)
    upgradeText:Hide()
    btn.upgradeText = upgradeText

    -- Overlay readability elements (created once, toggled by style)
    local overlays = {}

    -- Full darken overlay
    local darken = btn:CreateTexture(nil, "ARTWORK", nil, 7)
    darken:SetPoint("TOPLEFT", icon)
    darken:SetPoint("BOTTOMRIGHT", icon)
    darken:SetColorTexture(0, 0, 0, 0.35)
    darken:Hide()
    overlays.darken = darken

    -- Gradient strip: bottom
    local gradBot = btn:CreateTexture(nil, "ARTWORK", nil, 7)
    gradBot:SetPoint("BOTTOMLEFT", icon)
    gradBot:SetPoint("BOTTOMRIGHT", icon)
    gradBot:SetHeight(20)
    gradBot:SetTexture("Interface\\Buttons\\WHITE8x8")
    gradBot:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.7), CreateColor(0, 0, 0, 0))
    gradBot:Hide()
    overlays.gradBot = gradBot

    -- Gradient strip: top
    local gradTop = btn:CreateTexture(nil, "ARTWORK", nil, 7)
    gradTop:SetPoint("TOPLEFT", icon)
    gradTop:SetPoint("TOPRIGHT", icon)
    gradTop:SetHeight(18)
    gradTop:SetTexture("Interface\\Buttons\\WHITE8x8")
    gradTop:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.7))
    gradTop:Hide()
    overlays.gradTop = gradTop

    -- Gradient strip: top-left (enchant icon area)
    local gradTL = btn:CreateTexture(nil, "ARTWORK", nil, 7)
    gradTL:SetPoint("TOPLEFT", icon)
    gradTL:SetSize(20, 20)
    gradTL:SetTexture("Interface\\Buttons\\WHITE8x8")
    gradTL:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.6), CreateColor(0, 0, 0, 0))
    gradTL:Hide()
    overlays.gradTL = gradTL

    -- Corner darken: bottom-right
    local cornerBR = btn:CreateTexture(nil, "ARTWORK", nil, 7)
    cornerBR:SetPoint("BOTTOMRIGHT", icon)
    cornerBR:SetSize(28, 16)
    cornerBR:SetTexture("Interface\\Buttons\\WHITE8x8")
    cornerBR:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.6))
    cornerBR:Hide()
    overlays.cornerBR = cornerBR

    -- Corner darken: top-right
    local cornerTR = btn:CreateTexture(nil, "ARTWORK", nil, 7)
    cornerTR:SetPoint("TOPRIGHT", icon)
    cornerTR:SetSize(28, 14)
    cornerTR:SetTexture("Interface\\Buttons\\WHITE8x8")
    cornerTR:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.6))
    cornerTR:Hide()
    overlays.cornerTR = cornerTR

    -- Corner darken: top-left (enchant icon area)
    local cornerTL = btn:CreateTexture(nil, "ARTWORK", nil, 7)
    cornerTL:SetPoint("TOPLEFT", icon)
    cornerTL:SetSize(20, 20)
    cornerTL:SetTexture("Interface\\Buttons\\WHITE8x8")
    cornerTL:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.6), CreateColor(0, 0, 0, 0))
    cornerTL:Hide()
    overlays.cornerTL = cornerTL

    -- Drop shadow behind ilvlText
    local shadowIlvl = btn:CreateFontString(nil, "ARTWORK")
    shadowIlvl:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    shadowIlvl:SetPoint("BOTTOMRIGHT", -2, 2)
    shadowIlvl:SetTextColor(0, 0, 0, 0.8)
    shadowIlvl:Hide()
    overlays.shadowIlvl = shadowIlvl

    -- Drop shadow behind upgradeText
    local shadowUpgrade = btn:CreateFontString(nil, "ARTWORK")
    shadowUpgrade:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    shadowUpgrade:SetPoint("TOPRIGHT", -1, -3)
    shadowUpgrade:SetTextColor(0, 0, 0, 0.8)
    shadowUpgrade:Hide()
    overlays.shadowUpgrade = shadowUpgrade

    btn.overlays = overlays

    btn.sockets = {}
    for i = 1, MAX_SOCKETS do
        local gem = btn:CreateTexture(nil, "OVERLAY", nil, 2)
        gem:SetSize(SOCKET_SIZE, SOCKET_SIZE)
        gem:SetPoint("TOPLEFT", btn, "TOPRIGHT", 2, -(i - 1) * (SOCKET_SIZE + 1) - 2)
        gem:Hide()
        btn.sockets[i] = gem
    end

    if not btn:GetHighlightTexture() then
        local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.12)
    end

    -- Use HookScript so we don't override the native button's tooltip/click behavior
    if not btn._mcuTooltipHooked then
        btn._mcuTooltipHooked = true
        btn:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local hasItem = GameTooltip:SetInventoryItem("player", self.slotID)
            if not hasItem then
                GameTooltip:SetText(self.slotLabel, 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        btn:HookScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    -- Native Blizzard button handles OnClick, OnReceiveDrag, and all
    -- secure actions (enchants, weapon oils, armor kits, item equip/pickup).
    -- We only hook OnEnter/OnLeave for our enhanced tooltips above.

    -- Hook the native search/context overlays to fade our custom elements
    -- when an enchant or targeting spell is active
    if not btn._mcuOverlayHooked then
        btn._mcuOverlayHooked = true
        local function UpdateOverlayAlpha()
            local isTargeting = false
            if btn.searchOverlay and btn.searchOverlay:IsShown() then isTargeting = true end
            if btn.ItemContextOverlay and btn.ItemContextOverlay:IsShown() then isTargeting = true end
            local alpha = isTargeting and 0.2 or 1
            if btn.ilvlText then btn.ilvlText:SetAlpha(alpha) end
            if btn.upgradeText then btn.upgradeText:SetAlpha(alpha) end
            if btn.enchantWarning then btn.enchantWarning:SetAlpha(alpha) end
            for i = 1, MAX_SOCKETS do
                if btn.sockets and btn.sockets[i] then btn.sockets[i]:SetAlpha(alpha) end
            end
            for _, t in ipairs(btn.borderTextures) do t:SetAlpha(alpha) end
            if btn.overlays then
                for _, o in pairs(btn.overlays) do
                    if o.SetAlpha then o:SetAlpha(alpha) end
                end
            end
        end
        if btn.searchOverlay then
            hooksecurefunc(btn.searchOverlay, "Show", UpdateOverlayAlpha)
            hooksecurefunc(btn.searchOverlay, "Hide", UpdateOverlayAlpha)
            hooksecurefunc(btn.searchOverlay, "SetShown", UpdateOverlayAlpha)
        end
        if btn.ItemContextOverlay then
            hooksecurefunc(btn.ItemContextOverlay, "Show", function()
                btn.ItemContextOverlay:SetAlpha(0)
                UpdateOverlayAlpha()
            end)
            hooksecurefunc(btn.ItemContextOverlay, "Hide", UpdateOverlayAlpha)
            hooksecurefunc(btn.ItemContextOverlay, "SetShown", function()
                btn.ItemContextOverlay:SetAlpha(0)
                UpdateOverlayAlpha()
            end)
        end
    end

    ns.slotButtons[slotInfo.id] = btn
    return btn
end

local function BuildSlots()
    for i, info in ipairs(ns.LEFT_SLOTS) do
        CreateSlotButton(ns.leftColumn, info, i, "TOPLEFT", 0, 0)
    end
    for i, info in ipairs(ns.RIGHT_SLOTS) do
        CreateSlotButton(ns.rightColumn, info, i, "TOPRIGHT", 0, 0)
    end
    for i, info in ipairs(ns.BOTTOM_SLOTS) do
        local GAP = 5
        local xOff = (i - 1) * (SLOT_SIZE + GAP)
        local btn = CreateSlotButton(ns.bottomSlots, info, 1, "BOTTOMLEFT", xOff, 0)
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOMLEFT", ns.bottomSlots, "BOTTOMLEFT", xOff, 0)
    end
end

function ns:UpdateSlot(slotID)
    local btn = self.slotButtons[slotID]
    if not btn then return end

    local texture = GetInventoryItemTexture("player", slotID)

    if texture then
        btn.icon:SetTexture(texture)

        local isBroken = GetInventoryItemBroken("player", slotID)
        local isUnusable = C_PlayerInfo and C_PlayerInfo.IsPlayerUnusableItem
            and C_PlayerInfo.IsPlayerUnusableItem(slotID)
            or false
        -- fallback for older API
        if not isUnusable and GetInventoryItemEquippedUnusable then
            isUnusable = GetInventoryItemEquippedUnusable("player", slotID)
        end

        if isBroken or isUnusable then
            btn.icon:SetVertexColor(0.9, 0.0, 0.0, 1)
            btn.icon:SetDesaturated(false)
        else
            btn.icon:SetVertexColor(1, 1, 1, 1)
            btn.icon:SetDesaturated(false)
        end

        if IsInventoryItemLocked(slotID) then
            btn.icon:SetDesaturated(true)
        end

        local quality = GetInventoryItemQuality("player", slotID)
        local r, g, b = self:GetQualityColor(quality)
        for _, t in ipairs(btn.borderTextures) do
            t:SetColorTexture(r, g, b, 0.9)
        end

        local itemLink = GetInventoryItemLink("player", slotID)
        if itemLink then
            local effectiveILvl
            if C_Item and C_Item.GetDetailedItemLevelInfo then
                effectiveILvl = C_Item.GetDetailedItemLevelInfo(itemLink)
            elseif GetDetailedItemLevelInfo then
                effectiveILvl = GetDetailedItemLevelInfo(itemLink)
            end

            local pvpIlvl = ns:IsInPvPZone() and ns:GetPvPItemLevel(slotID) or nil
            if pvpIlvl and pvpIlvl > 0 and pvpIlvl ~= effectiveILvl then
                btn.ilvlText:SetText(pvpIlvl)
                btn.ilvlText:SetTextColor(0.0, 1.0, 0.0, 1)
            elseif effectiveILvl and effectiveILvl > 0 then
                btn.ilvlText:SetText(effectiveILvl)
                btn.ilvlText:SetTextColor(1, 0.82, 0, 1)
            else
                btn.ilvlText:SetText("")
                btn.ilvlText:SetTextColor(1, 0.82, 0, 1)
            end
        else
            btn.ilvlText:SetText("")
            btn.ilvlText:SetTextColor(1, 0.82, 0, 1)
        end

        local start, duration, enable = GetInventoryItemCooldown("player", slotID)
        if start and duration and duration > 0 then
            CooldownFrame_Set(btn.cooldown, start, duration, enable)
            btn.cooldown:Show()
        else
            btn.cooldown:Hide()
        end

        -- GetNumSockets expects an item link; wrap in pcall for API safety
        local numSockets = 0
        if itemLink then
            local ok, result = pcall(function()
                if C_Item and C_Item.GetItemNumSockets then
                    return C_Item.GetItemNumSockets(itemLink) or 0
                end
                return 0
            end)
            if ok then numSockets = result or 0 end
        end
        for i = 1, MAX_SOCKETS do
            local gem = btn.sockets[i]
            if i <= numSockets then
                local gemName, gemLink = GetItemGem(itemLink, i)
                if gemLink then
                    local _, _, gemIcon = C_Item.GetItemInfoInstant(gemLink)
                    if gemIcon then
                        gem:SetTexture(gemIcon)
                        gem:SetDesaturated(false)
                        gem:SetAlpha(1)
                    else
                        gem:SetAtlas("character-emptysocket")
                        gem:SetAlpha(0.7)
                    end
                else
                    gem:SetAtlas("character-emptysocket")
                    gem:SetDesaturated(false)
                    gem:SetAlpha(0.7)
                end
                gem:Show()
            else
                gem:Hide()
            end
        end

        -- Enchant status overlay
        btn.enchantWarning:Hide()
        local isEnchanted = false
        if ns.db and ns.db.global and ns.db.global.showEnchantStatus and itemLink then
            local enchantID = itemLink:match("item:%d+:(%d+)")
            if enchantID and tonumber(enchantID) > 0 then
                btn.enchantWarning:Show()
                isEnchanted = true
            end
        end
        -- Show enchant area overlay only when enchant icon is visible
        if btn.overlays then
            local style = (ns.db and ns.db.global and ns.db.global.slotOverlayStyle) or "none"
            if btn.overlays.gradTL then btn.overlays.gradTL:SetShown(style == "gradient" and isEnchanted) end
            btn.overlays.cornerTL:SetShown(style == "corners" and isEnchanted)
        end

        -- Upgrade track overlay
        btn.upgradeText:Hide()
        if ns.db and ns.db.global and ns.db.global.showUpgradeTrack and itemLink then
            if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
                local data = C_TooltipInfo.GetInventoryItem("player", slotID)
                if data and data.lines then
                    for _, line in ipairs(data.lines) do
                        if line.leftText then
                            -- Match "Upgrade: TrackName X/Y" format
                            local current, maximum = line.leftText:match("(%d+)/(%d+)")
                            if current and maximum and line.leftText:lower():find("upgrade") then
                                btn.upgradeText:SetText(current .. "/" .. maximum)
                                if tonumber(current) >= tonumber(maximum) then
                                    btn.upgradeText:SetTextColor(0.0, 1.0, 0.0, 1)
                                else
                                    btn.upgradeText:SetTextColor(1, 0.82, 0, 1)
                                end
                                btn.upgradeText:Show()
                                break
                            end
                        end
                    end
                end
            end
        end

    else
        local emptyTex = self:GetEmptySlotTexture(slotID, btn.slotName)
        btn.icon:SetTexture(emptyTex)
        btn.icon:SetDesaturated(true)
        btn.icon:SetVertexColor(0.6, 0.6, 0.6, 0.5)
        for _, t in ipairs(btn.borderTextures) do
            t:SetColorTexture(0.2, 0.2, 0.2, 0.5)
        end
        btn.ilvlText:SetText("")
        btn.cooldown:Hide()
        btn.enchantWarning:Hide()
        btn.upgradeText:Hide()
        for i = 1, MAX_SOCKETS do
            btn.sockets[i]:Hide()
        end
    end

    -- Sync overlay style (shadow text etc.)
    if btn.overlays then
        local style = (ns.db and ns.db.global and ns.db.global.slotOverlayStyle) or "none"
        local showShadow = (style == "shadow")
        if showShadow then
            btn.overlays.shadowIlvl:SetText(btn.ilvlText:GetText() or "")
            btn.overlays.shadowIlvl:SetShown(btn.ilvlText:GetText() ~= nil and btn.ilvlText:GetText() ~= "")
            btn.overlays.shadowUpgrade:SetText(btn.upgradeText:GetText() or "")
            btn.overlays.shadowUpgrade:SetShown(btn.upgradeText:IsShown())
        else
            btn.overlays.shadowIlvl:Hide()
            btn.overlays.shadowUpgrade:Hide()
        end
    end
end

function ns:UpdateAllSlots()
    for _, list in ipairs({ ns.LEFT_SLOTS, ns.RIGHT_SLOTS, ns.BOTTOM_SLOTS }) do
        for _, info in ipairs(list) do
            self:UpdateSlot(info.id)
        end
    end
end

BuildSlots()
