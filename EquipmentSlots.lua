local addonName, ns = ...

local SLOT_SIZE    = ns.SLOT_SIZE
local SLOT_SPACING = ns.SLOT_SPACING
local MAX_SOCKETS  = 3
local SOCKET_SIZE  = 12

ns.slotButtons = {}

local function CreateSlotButton(parent, slotInfo, index, anchorPoint, xOff, yOff)
    local btn = CreateFrame("Button", "ModernCharacterUISlot" .. slotInfo.id, parent)
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
    enchantWarning:SetSize(11, 11)
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
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local hasItem = GameTooltip:SetInventoryItem("player", self.slotID)
        if not hasItem then
            GameTooltip:SetText(self.slotLabel, 1, 1, 1)
        end
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, button)
        if IsModifiedClick("EXPANDITEM") then
            if SocketInventoryItem then
                SocketInventoryItem(self.slotID)
            end
            return
        end
        if IsModifiedClick("CHATLINK") then
            local itemLink = GetInventoryItemLink("player", self.slotID)
            if itemLink then
                ChatEdit_InsertLink(itemLink)
            end
            return
        end
        if button == "RightButton" then
            UseInventoryItem(self.slotID)
            return
        end
        PickupInventoryItem(self.slotID)
    end)

    btn:SetScript("OnReceiveDrag", function(self)
        PickupInventoryItem(self.slotID)
    end)

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
        if ns.db and ns.db.global and ns.db.global.showEnchantStatus and itemLink then
            -- Parse enchant ID from item link: item:id:enchantID:...
            local enchantID = itemLink:match("item:%d+:(%d+)")
            if enchantID and tonumber(enchantID) > 0 then
                btn.enchantWarning:Show()
            end
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
end

function ns:UpdateAllSlots()
    for _, list in ipairs({ ns.LEFT_SLOTS, ns.RIGHT_SLOTS, ns.BOTTOM_SLOTS }) do
        for _, info in ipairs(list) do
            self:UpdateSlot(info.id)
        end
    end
end

BuildSlots()
