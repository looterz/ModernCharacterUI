local addonName, ns = ...

local function ShouldPassThrough()
    if not (ns.db and ns.db.global and ns.db.global.overrideDressingRoom) then
        return true
    end
    if SideDressUpFrame and SideDressUpFrame.parentFrame
       and SideDressUpFrame.parentFrame:IsShown() then
        return true
    end
    return false
end

local function GetPlayerActor()
    if not MCUDressingRoomFrame then return nil end
    local charPreview = MCUDressingRoomFrame.CharacterPreview
    if charPreview and charPreview.ModelScene then
        return charPreview.ModelScene:GetPlayerActor()
    end
    return nil
end

-- Track previewed items per slot so we can update slot icons independently
-- of the transmog system. Keys are invSlotIDs, values are { link, icon, name, quality, sourceID }
MCUDR_PreviewedSlots = MCUDR_PreviewedSlots or {}

local EQUIP_LOC_TO_SLOT = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3,
    INVTYPE_BODY = 4, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
    INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8,
    INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11,
    INVTYPE_TRINKET = 13, INVTYPE_CLOAK = 15,
    INVTYPE_WEAPON = 16, INVTYPE_WEAPONMAINHAND = 16, INVTYPE_2HWEAPON = 16,
    INVTYPE_WEAPONOFFHAND = 17, INVTYPE_SHIELD = 17, INVTYPE_HOLDABLE = 17,
    INVTYPE_RANGED = 16, INVTYPE_RANGEDRIGHT = 16, INVTYPE_THROWN = 16,
    INVTYPE_TABARD = 19,
}

local function ShowOurDressingRoom()
    if MCUDressingRoomFrame then
        MCUDressingRoomFrame:Show()
    end
end

local function HideBlizzardDressUp()
    if DressUpFrame and DressUpFrame:IsShown() then
        DressUpFrame:Hide()
    end
end

local function RefreshSlotsAfterTryOn()
    C_Timer.After(0.3, function()
        if MCUDressingRoomFrame and MCUDressingRoomFrame.CharacterPreview
           and MCUDressingRoomFrame.CharacterPreview.RefreshDressingRoomSlots then
            MCUDressingRoomFrame.CharacterPreview:RefreshDressingRoomSlots()
        end
    end)
end

local function StorePreviewSlot(link)
    if not link then return end
    local itemName, _, quality, _, _, _, _, _, equipLoc, icon = C_Item.GetItemInfo(link)
    local slotID = equipLoc and EQUIP_LOC_TO_SLOT[equipLoc]

    if not slotID then
        -- Item not cached yet — try GetItemInfoInstant for equipLoc
        local _, _, _, itemEquipLoc, itemIcon = C_Item.GetItemInfoInstant(link)
        if itemEquipLoc and itemEquipLoc ~= "" then
            slotID = EQUIP_LOC_TO_SLOT[itemEquipLoc]
            icon = icon or itemIcon
        end
    end

    if not slotID then return end

    -- Resolve numeric transmog sourceID from the item link
    local numericSourceID
    if C_TransmogCollection and C_TransmogCollection.GetItemInfo then
        local ok, appearanceID, srcID = pcall(C_TransmogCollection.GetItemInfo, link)
        if ok and srcID and type(srcID) == "number" then
            numericSourceID = srcID
        end
    end

    -- Fallback icon from GetItemInfoInstant if GetItemInfo didn't have it
    if not icon then
        local _, _, _, _, itemIcon = C_Item.GetItemInfoInstant(link)
        icon = itemIcon
    end

    MCUDR_PreviewedSlots[slotID] = {
        link = link,
        icon = icon,
        name = itemName or "",
        quality = quality,
        sourceID = numericSourceID,
    }
end

local function TryOnItem(link)
    if not link then return end
    ShowOurDressingRoom()
    ns.drLastLink = link

    -- Store preview slot data immediately
    StorePreviewSlot(link)

    -- If item wasn't cached, retry when it becomes available
    if not C_Item.GetItemInfo(link) then
        C_Item.RequestLoadItemData(C_Item.GetItemInfoInstant(link))
        C_Timer.After(0.5, function()
            StorePreviewSlot(link)
            RefreshSlotsAfterTryOn()
        end)
    end

    -- Defer TryOn so the model scene finishes its transition from OnShow
    C_Timer.After(0.5, function()
        local actor = GetPlayerActor()
        if actor then
            actor:TryOn(link)
            RefreshSlotsAfterTryOn()
        end
    end)
end

function ns:InitDressingRoomHooks()
    -- Store ns reference on the frame so DressingRoomFrame.lua can access preview state
    if MCUDressingRoomFrame then
        MCUDressingRoomFrame._addonNS = ns;
    end

    ---------------------------------------------------------------------------
    -- Use hooksecurefunc for ALL hooks to avoid tainting secure execution.
    -- Post-hooks run AFTER the original Blizzard function completes.
    -- When we should override, we defer to next frame (C_Timer.After(0))
    -- to cleanly break out of the secure context, then hide Blizzard's
    -- DressUpFrame and show ours.
    ---------------------------------------------------------------------------

    if DressUpLink then
        hooksecurefunc("DressUpLink", function(link)
            if ShouldPassThrough() or not link then return end
            C_Timer.After(0, function()
                HideBlizzardDressUp()
                TryOnItem(link)
            end)
        end)
    end

    if DressUpItemLink then
        hooksecurefunc("DressUpItemLink", function(link)
            if ShouldPassThrough() or not link then return end
            C_Timer.After(0, function()
                HideBlizzardDressUp()
                TryOnItem(link)
            end)
        end)
    end

    if DressUpVisual then
        hooksecurefunc("DressUpVisual", function(link, ...)
            if ShouldPassThrough() then return end
            C_Timer.After(0, function()
                HideBlizzardDressUp()
                TryOnItem(link)
            end)
        end)
    end

    if DressUpVisualLink then
        hooksecurefunc("DressUpVisualLink", function(forcedFrame, link, ...)
            if ShouldPassThrough() then return end
            C_Timer.After(0, function()
                HideBlizzardDressUp()
                TryOnItem(link)
            end)
        end)
    end

    if DressUpItemLocation then
        hooksecurefunc("DressUpItemLocation", function(itemLocation)
            if ShouldPassThrough() then return end
            if itemLocation then
                local link = C_Item.GetItemLink(itemLocation)
                if link then
                    C_Timer.After(0, function()
                        HideBlizzardDressUp()
                        TryOnItem(link)
                    end)
                end
            end
        end)
    end

    if DressUpMount then
        hooksecurefunc("DressUpMount", function(mountID, ...)
            if ShouldPassThrough() then return end
            C_Timer.After(0, function()
                HideBlizzardDressUp()
                ShowOurDressingRoom()
            end)
        end)
    end

    if DressUpBattlePet then
        hooksecurefunc("DressUpBattlePet", function(...)
            if ShouldPassThrough() then return end
            C_Timer.After(0, function()
                HideBlizzardDressUp()
                ShowOurDressingRoom()
            end)
        end)
    end

    if DressUpTransmogSet then
        hooksecurefunc("DressUpTransmogSet", function(itemModifiedAppearanceIDs)
            if ShouldPassThrough() then return end
            -- Copy the IDs table since it may be recycled
            local ids = {}
            if itemModifiedAppearanceIDs then
                for i, id in ipairs(itemModifiedAppearanceIDs) do
                    ids[i] = id
                end
            end
            C_Timer.After(0, function()
                HideBlizzardDressUp()
                ShowOurDressingRoom()
                local actor = GetPlayerActor()
                if actor and #ids > 0 then
                    for _, id in ipairs(ids) do
                        actor:TryOn(id)
                    end
                    RefreshSlotsAfterTryOn()
                end
            end)
        end)
    end

    if DressUpCollectionAppearance then
        hooksecurefunc("DressUpCollectionAppearance", function(appearanceID, transmogLocation, categoryID)
            if ShouldPassThrough() then return end
            -- Capture slot before deferring (transmogLocation table may be recycled)
            local slotID = transmogLocation and transmogLocation.GetSlot
                and transmogLocation:GetSlot()
            C_Timer.After(0, function()
                HideBlizzardDressUp()
                if not MCUDressingRoomFrame or not MCUDressingRoomFrame:IsShown() then
                    ShowOurDressingRoom()
                end
                C_Timer.After(0.5, function()
                    local actor = GetPlayerActor()
                    if actor and appearanceID then
                        actor:TryOn(appearanceID)

                        -- Track preview state
                        if slotID then
                            local sources = C_TransmogCollection.GetAppearanceSources(appearanceID)
                            if sources and #sources > 0 then
                                local best = sources[1]
                                for _, s in ipairs(sources) do
                                    if s.isCollected then best = s; break end
                                end
                                local itemIcon
                                local itemID = best.itemID or C_TransmogCollection.GetSourceItemID(best.sourceID or appearanceID)
                                if itemID then
                                    itemIcon = C_Item.GetItemIconByID(itemID) or select(5, C_Item.GetItemInfoInstant(itemID))
                                end
                                MCUDR_PreviewedSlots[slotID] = {
                                    icon = itemIcon or best.icon or best.texture,
                                    name = best.name,
                                    quality = best.quality,
                                    sourceID = best.sourceID or appearanceID,
                                }
                            end
                        end
                        RefreshSlotsAfterTryOn()
                    end
                end)
            end)
        end)
    end

    if DressUpItemTransmogInfoList then
        hooksecurefunc("DressUpItemTransmogInfoList", function(itemTransmogInfoList, showDetails, forceRefresh)
            if ShouldPassThrough() then return end
            -- Copy the info list before deferring
            local infoCopy = {}
            if itemTransmogInfoList then
                for slotID, info in pairs(itemTransmogInfoList) do
                    infoCopy[slotID] = info
                end
            end
            C_Timer.After(0, function()
                HideBlizzardDressUp()
                ShowOurDressingRoom()
                MCUDR_PreviewedSlots = {}
                C_Timer.After(0.5, function()
                    local actor = GetPlayerActor()
                    if actor then
                        for slotID, info in pairs(infoCopy) do
                            actor:SetItemTransmogInfo(info, slotID)
                            -- Track each slot
                            if info.appearanceID and info.appearanceID > 0 then
                                local sourceInfo = C_TransmogCollection.GetSourceInfo(info.appearanceID)
                                if sourceInfo and sourceInfo.name then
                                    local itemIcon
                                    local itemID = sourceInfo.itemID or C_TransmogCollection.GetSourceItemID(info.appearanceID)
                                    if itemID then
                                        itemIcon = C_Item.GetItemIconByID(itemID) or select(5, C_Item.GetItemInfoInstant(itemID))
                                    end
                                    MCUDR_PreviewedSlots[slotID] = {
                                        icon = itemIcon,
                                        name = sourceInfo.name,
                                        quality = sourceInfo.quality,
                                        sourceID = info.appearanceID,
                                    }
                                end
                            end
                        end
                        RefreshSlotsAfterTryOn()
                    end
                end)
            end)
        end)
    end
end

