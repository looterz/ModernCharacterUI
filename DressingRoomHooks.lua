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

local function GetModelScene()
    if not MCUDressingRoomFrame then return nil end
    local charPreview = MCUDressingRoomFrame.CharacterPreview
    return charPreview and charPreview.ModelScene or nil
end

local function GetMountIDFromLink(link)
    if not link or not C_MountJournal then return nil end
    local linkType, linkOptions = LinkUtil.ExtractLink(link)
    local linkID = linkOptions and LinkUtil.SplitLinkOptions(linkOptions)
    linkID = tonumber(linkID)
    if not linkID then return nil end
    local mountID
    if linkType == "item" then
        mountID = C_MountJournal.GetMountFromItem(linkID)
    elseif linkType == "spell" or linkType == "mount" then
        mountID = C_MountJournal.GetMountFromSpell(linkID)
    end
    return (mountID and mountID > 0) and mountID or nil
end

local function PreviewMount(mountID)
    ShowOurDressingRoom()
    if not mountID or not C_MountJournal then return end

    local creatureDisplayID, _, _, isSelfMount, _, modelSceneID, animID, spellVisualKitID, disablePlayerMountPreview =
        C_MountJournal.GetMountInfoExtraByID(mountID)
    if not creatureDisplayID or creatureDisplayID == 0 then return end

    -- Show mount collection on the right sidebar
    ns:ShowMountCollection(mountID)

    -- Switch to two-column layout: hide left sidebar, expand preview to fill
    local outfitCollection = MCUDressingRoomFrame.OutfitCollection
    local charPreview = MCUDressingRoomFrame.CharacterPreview
    local wardrobeCollection = MCUDressingRoomFrame.WardrobeCollection
    if outfitCollection and charPreview and wardrobeCollection then
        outfitCollection:Hide()
        -- Break the anchor chain: anchor collection to the frame directly
        wardrobeCollection:ClearAllPoints()
        wardrobeCollection:SetPoint("TOPRIGHT", MCUDressingRoomFrame, "TOPRIGHT", -2, -21)
        -- Preview fills from left edge to collection
        charPreview:ClearAllPoints()
        charPreview:SetPoint("TOPLEFT", MCUDressingRoomFrame, "TOPLEFT", 2, -21)
        charPreview:SetPoint("TOPRIGHT", wardrobeCollection, "TOPLEFT", 0, 0)
        charPreview:SetHeight(860)
        -- Stretch the background texture to fill the wider area
        if charPreview.Background then
            charPreview.Background:ClearAllPoints()
            charPreview.Background:SetAllPoints(charPreview)
        end
    end

    C_Timer.After(0.3, function()
        local modelScene = GetModelScene()
        if not modelScene then return end

        -- Hide the player actor so only the mount is visible
        local playerActor = modelScene:GetPlayerActor()
        if playerActor then
            playerActor:ClearModel()
        end

        -- Hide equipment slots and show mount name during mount preview
        local charPreview = MCUDressingRoomFrame.CharacterPreview
        if charPreview then
            if charPreview.drSlotFrames then
                for _, btn in pairs(charPreview.drSlotFrames) do
                    btn:Hide()
                end
            end
            if not charPreview.MountNameLabel then
                local label = charPreview:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
                label:SetPoint("TOP", charPreview, "TOP", 0, -12)
                label:SetTextColor(1, 0.82, 0, 1)
                charPreview.MountNameLabel = label
            end
            local mountName = C_MountJournal.GetMountInfoByID(mountID)
            charPreview.MountNameLabel:SetText(mountName or "")
            charPreview.MountNameLabel:Show()
            -- Move camera controls below the mount name
            local controlFrame = charPreview.ModelScene and charPreview.ModelScene.ControlFrame
            if controlFrame then
                controlFrame:ClearAllPoints()
                controlFrame:SetPoint("TOP", charPreview.MountNameLabel, "BOTTOM", 0, -4)
            end
        end

        -- Transition to the mount's own scene for proper camera framing
        modelScene:SetViewInsets(0, 0, 0, 0)
        local forceEvenIfSame = true
        modelScene:TransitionToModelSceneID(modelSceneID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, forceEvenIfSame)

        -- Clean up any previous mount actor we created
        if modelScene._mountActor then
            modelScene._mountActor:ClearModel()
            modelScene._mountActor = nil
        end

        -- Create a new actor for the mount
        local mountActor = modelScene:CreateActor()
        if not mountActor then return end
        modelScene._mountActor = mountActor

        mountActor:SetModelByCreatureDisplayID(creatureDisplayID, true)
        mountActor:SetUseCenterForOrigin(true, true, true)

        if isSelfMount then
            mountActor:SetAnimationBlendOperation(Enum.ModelBlendOperation.None)
            mountActor:SetAnimation(618) -- MountSelfIdle
        else
            mountActor:SetAnimationBlendOperation(Enum.ModelBlendOperation.Anim)
            mountActor:SetAnimation(0)
        end

        if spellVisualKitID and spellVisualKitID > 0 then
            mountActor:SetSpellVisualKit(spellVisualKitID)
        end

        -- Extend zoom range for large mounts
        local camera = modelScene:GetActiveCamera()
        if camera then
            camera:SetMaxZoomDistance(camera:GetMaxZoomDistance() * 2.5)
        end
    end)
end

function ns:PreviewMount(mountID)
    PreviewMount(mountID)
end

---------------------------------------------------------------------------
-- Mount Collection Grid (model-based, paged — matches item collection)
---------------------------------------------------------------------------
local mountCollectionFrame = nil
local mountSearchBox = nil
local currentPreviewMountID = nil

local MOUNT_NUM_ROWS = 5
local MOUNT_NUM_COLS = 6
local MOUNT_PAGE_SIZE = MOUNT_NUM_ROWS * MOUNT_NUM_COLS
local MOUNT_MODEL_WIDTH = 78
local MOUNT_MODEL_HEIGHT = 104
local MOUNT_COL_GAP = 16
local MOUNT_ROW_GAP = 24

local function GetMountList()
    local list = {}
    for i = 1, C_MountJournal.GetNumDisplayedMounts() do
        local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite,
              isFactionSpecific, faction, isFiltered, isCollected, mountID = C_MountJournal.GetDisplayedMountInfo(i)
        if mountID then
            local creatureDisplayID, descriptionText, sourceText = C_MountJournal.GetMountInfoExtraByID(mountID)
            list[#list + 1] = {
                mountID = mountID,
                name = creatureName,
                icon = icon,
                isCollected = isCollected,
                isUsable = isUsable,
                isFavorite = isFavorite,
                creatureDisplayID = creatureDisplayID or 0,
                description = descriptionText or "",
                source = sourceText or "",
            }
        end
    end
    return list
end

local function UpdateMountModels()
    if not mountCollectionFrame or not mountCollectionFrame:IsShown() then return end

    local frame = mountCollectionFrame
    local page = frame.PagingFrame:GetCurrentPage()
    local offset = (page - 1) * MOUNT_PAGE_SIZE

    for i = 1, MOUNT_PAGE_SIZE do
        local model = frame.Models[i]
        local entry = frame.mountList[offset + i]
        if entry then
            model:Show()
            if model._mountID ~= entry.mountID then
                model:SetDisplayInfo(entry.creatureDisplayID)
                model._mountID = entry.mountID
            end
            model.mountData = entry

            -- Border
            if not entry.isCollected then
                model.Border:SetAtlas("transmog-wardrobe-border-uncollected")
            elseif not entry.isUsable then
                model.Border:SetAtlas("transmog-wardrobe-border-unusable")
            else
                model.Border:SetAtlas("transmog-wardrobe-border-collected")
            end

            -- Highlight the currently previewed mount
            model.TransmogStateTexture:SetShown(entry.mountID == currentPreviewMountID)

            -- Favorite
            if model.Favorite then
                model.Favorite.Icon:SetShown(entry.isFavorite or false)
            end

            model.NewString:Hide()
            model.NewGlow:Hide()
            model.SlotInvalidTexture:Hide()
            model.DisabledOverlay:SetShown(not entry.isCollected)
            if model.HideVisual then model.HideVisual.Icon:Hide() end
        else
            model:Hide()
            model._mountID = nil
            model.mountData = nil
        end
    end
end

local function RefreshMountCollection()
    if not mountCollectionFrame or not mountCollectionFrame:IsShown() then return end
    local frame = mountCollectionFrame
    frame.mountList = GetMountList()
    frame.PagingFrame:SetMaxPages(max(1, ceil(#frame.mountList / MOUNT_PAGE_SIZE)))
    UpdateMountModels()
end

local function NavigateToMount(mountID)
    if not mountCollectionFrame or not mountID then return end
    local frame = mountCollectionFrame
    if not frame.mountList then return end
    for i, entry in ipairs(frame.mountList) do
        if entry.mountID == mountID then
            local page = ceil(i / MOUNT_PAGE_SIZE)
            frame.PagingFrame:SetCurrentPage(page)
            break
        end
    end
    UpdateMountModels()
end

local function CreateMountCollectionFrame()
    local parent = MCUDressingRoomFrame.WardrobeCollection

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:SetFrameLevel(parent:GetFrameLevel() + 2)
    frame:Hide()
    frame.mountList = {}

    -- Search box
    local search = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    search:SetSize(260, 20)
    search:SetPoint("TOP", 0, -110)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function(self)
        SearchBoxTemplate_OnTextChanged(self)
        C_MountJournal.SetSearch(self:GetText())
    end)
    mountSearchBox = search

    -- Paging frame (reuse the same mixin pattern)
    local pagingFrame = CreateFrame("Frame", nil, frame)
    pagingFrame:SetSize(120, 28)
    pagingFrame:SetPoint("BOTTOM", 0, 8)
    Mixin(pagingFrame, MCUDR_PagingMixin)
    pagingFrame:OnLoad()

    local pageText = pagingFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pageText:SetPoint("CENTER")
    pagingFrame.PageText = pageText

    local prevBtn = CreateFrame("Button", nil, pagingFrame)
    prevBtn:SetSize(28, 28)
    prevBtn:SetPoint("LEFT")
    prevBtn:SetNormalAtlas("common-icon-rotateleft")
    prevBtn:SetHighlightAtlas("common-icon-rotateleft")
    prevBtn:GetHighlightTexture():SetAlpha(0.4)
    prevBtn:SetScript("OnClick", function() pagingFrame:PreviousPage() end)

    local nextBtn = CreateFrame("Button", nil, pagingFrame)
    nextBtn:SetSize(28, 28)
    nextBtn:SetPoint("RIGHT")
    nextBtn:SetNormalAtlas("common-icon-rotateright")
    nextBtn:SetHighlightAtlas("common-icon-rotateright")
    nextBtn:GetHighlightTexture():SetAlpha(0.4)
    nextBtn:SetScript("OnClick", function() pagingFrame:NextPage() end)

    pagingFrame.PrevPageButton = prevBtn
    pagingFrame.NextPageButton = nextBtn

    local origUpdate = pagingFrame.Update
    pagingFrame.Update = function(self)
        if origUpdate then origUpdate(self) end
        self.PageText:SetText(self.currentPage .. " / " .. self.maxPages)
        self.PrevPageButton:SetEnabled(self.currentPage > 1)
        self.NextPageButton:SetEnabled(self.currentPage < self.maxPages)
    end

    frame.PagingFrame = pagingFrame

    -- OnPageChanged triggers model refresh
    frame.OnPageChanged = function() UpdateMountModels() end

    -- Create model grid
    frame.Models = {}
    local gridWidth = MOUNT_NUM_COLS * MOUNT_MODEL_WIDTH + (MOUNT_NUM_COLS - 1) * MOUNT_COL_GAP
    local gridHeight = MOUNT_NUM_ROWS * MOUNT_MODEL_HEIGHT + (MOUNT_NUM_ROWS - 1) * MOUNT_ROW_GAP
    local panelHeight = parent:GetHeight() or 860
    local topReserved = 135  -- title + divider + search
    local bottomReserved = 40  -- paging
    local availableHeight = panelHeight - topReserved - bottomReserved
    local gridOffsetY = -topReserved - max(0, (availableHeight - gridHeight) / 2)
    local gridOffsetX = max(0, ((parent:GetWidth() or 644) - gridWidth) / 2)

    for row = 0, MOUNT_NUM_ROWS - 1 do
        for col = 0, MOUNT_NUM_COLS - 1 do
            local idx = row * MOUNT_NUM_COLS + col + 1
            local model = CreateFrame("DressUpModel", nil, frame, "MCUDR_WardrobeModelTemplate")
            model:SetPoint("TOPLEFT", frame, "TOPLEFT",
                gridOffsetX + col * (MOUNT_MODEL_WIDTH + MOUNT_COL_GAP),
                gridOffsetY - row * (MOUNT_MODEL_HEIGHT + MOUNT_ROW_GAP))
            model:Hide()

            -- Override click to preview mount
            model:SetScript("OnMouseDown", function(self, button)
                if button == "LeftButton" and self.mountData then
                    currentPreviewMountID = self.mountData.mountID
                    PreviewMount(self.mountData.mountID)
                end
            end)

            -- Override tooltip
            model:SetScript("OnEnter", function(self)
                if not self.mountData then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.mountData.name or "", 1, 0.82, 0)
                if self.mountData.description and self.mountData.description ~= "" then
                    GameTooltip:AddLine(self.mountData.description, 1, 1, 1, true)
                end
                if self.mountData.source and self.mountData.source ~= "" then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(self.mountData.source, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
                end
                if not self.mountData.isCollected then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(NOT_COLLECTED or "Not Collected", RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
                end
                GameTooltip:Show()
            end)
            model:SetScript("OnLeave", function() GameTooltip:Hide() end)

            frame.Models[idx] = model
        end
    end

    -- Events
    frame:RegisterEvent("MOUNT_JOURNAL_SEARCH_UPDATED")
    frame:RegisterEvent("COMPANION_LEARNED")
    frame:RegisterEvent("COMPANION_UNLEARNED")
    frame:SetScript("OnEvent", function() RefreshMountCollection() end)

    -- Mouse wheel paging
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then pagingFrame:PreviousPage() else pagingFrame:NextPage() end
    end)

    mountCollectionFrame = frame
    return frame
end

function ns:ShowMountCollection(mountID)
    if not mountCollectionFrame then
        CreateMountCollectionFrame()
    end
    currentPreviewMountID = mountID

    -- Reset mount journal filters to show all mounts
    C_MountJournal.SetDefaultFilters()
    C_MountJournal.SetSearch("")
    if mountSearchBox then mountSearchBox:SetText("") end

    -- Hide the normal appearances grid
    if MCUDR_AppearancesFrame then
        MCUDR_AppearancesFrame:Hide()
    end

    mountCollectionFrame:Show()
    RefreshMountCollection()
    NavigateToMount(mountID)
end

function ns:HideMountCollection()
    if mountCollectionFrame then
        mountCollectionFrame:Hide()
        if mountSearchBox then
            mountSearchBox:SetText("")
            C_MountJournal.SetSearch("")
        end
    end
    currentPreviewMountID = nil

    -- Restore three-column layout
    if MCUDressingRoomFrame then
        local outfitCollection = MCUDressingRoomFrame.OutfitCollection
        local charPreview = MCUDressingRoomFrame.CharacterPreview
        local wardrobeCollection = MCUDressingRoomFrame.WardrobeCollection
        if outfitCollection and charPreview then
            outfitCollection:Show()
            charPreview:ClearAllPoints()
            charPreview:SetPoint("TOPLEFT", outfitCollection, "TOPRIGHT", 0, 0)
            charPreview:SetSize(658, 860)
            -- Restore background to atlas size anchored at TOPLEFT
            if charPreview.Background then
                charPreview.Background:ClearAllPoints()
                charPreview.Background:SetPoint("TOPLEFT")
            end
            if wardrobeCollection then
                wardrobeCollection:ClearAllPoints()
                wardrobeCollection:SetPoint("TOPLEFT", charPreview, "TOPRIGHT", 0, 0)
            end
        end
    end

    -- Restore the normal appearances grid
    if MCUDR_AppearancesFrame and MCUDressingRoomFrame and MCUDressingRoomFrame:IsShown() then
        MCUDR_AppearancesFrame:Show()
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
        local itemID = C_Item.GetItemInfoInstant(link)
        if itemID then
            C_Item.RequestLoadItemDataByID(itemID)
        end
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
    -- Replace DressUp globals with wrappers (pre-hook pattern) so that
    -- Blizzard's DressUpFrame is never opened via ShowUIPanel when we
    -- override.  This is the same approach used for ToggleCharacter
    -- (Settings.lua) and InspectUnit (InspectFrame.lua).
    --
    -- The previous approach used hooksecurefunc (post-hooks) which let the
    -- original function run first — opening DressUpFrame through ShowUIPanel.
    -- We then had to call DressUpFrame:Hide() from addon code, which tainted
    -- the UI-panel management state and broke the ESC / game-menu.
    ---------------------------------------------------------------------------

    if DressUpLink then
        local original = DressUpLink
        DressUpLink = function(link)
            if ShouldPassThrough() or not link then return original(link) end
            local mountID = GetMountIDFromLink(link)
            if mountID then
                PreviewMount(mountID)
            else
                TryOnItem(link)
            end
        end
    end

    if DressUpItemLink then
        local original = DressUpItemLink
        DressUpItemLink = function(link)
            if ShouldPassThrough() or not link then return original(link) end
            local mountID = GetMountIDFromLink(link)
            if mountID then
                PreviewMount(mountID)
            else
                TryOnItem(link)
            end
        end
    end

    if DressUpVisual then
        local original = DressUpVisual
        DressUpVisual = function(link, ...)
            if ShouldPassThrough() then return original(link, ...) end
            TryOnItem(link)
        end
    end

    if DressUpVisualLink then
        local original = DressUpVisualLink
        DressUpVisualLink = function(forcedFrame, link, ...)
            if ShouldPassThrough() then return original(forcedFrame, link, ...) end
            TryOnItem(link)
        end
    end

    if DressUpItemLocation then
        local original = DressUpItemLocation
        DressUpItemLocation = function(itemLocation)
            if ShouldPassThrough() then return original(itemLocation) end
            if itemLocation then
                local link = C_Item.GetItemLink(itemLocation)
                if link then
                    TryOnItem(link)
                end
            end
        end
    end

    if DressUpMount then
        local original = DressUpMount
        DressUpMount = function(mountID, ...)
            if ShouldPassThrough() then return original(mountID, ...) end
            PreviewMount(mountID)
        end
    end

    if DressUpBattlePet then
        local original = DressUpBattlePet
        DressUpBattlePet = function(...)
            if ShouldPassThrough() then return original(...) end
            ShowOurDressingRoom()
        end
    end

    if DressUpTransmogSet then
        local original = DressUpTransmogSet
        DressUpTransmogSet = function(itemModifiedAppearanceIDs)
            if ShouldPassThrough() then return original(itemModifiedAppearanceIDs) end
            -- Copy the IDs table since it may be recycled
            local ids = {}
            if itemModifiedAppearanceIDs then
                for i, id in ipairs(itemModifiedAppearanceIDs) do
                    ids[i] = id
                end
            end
            ShowOurDressingRoom()
            C_Timer.After(0.5, function()
                local actor = GetPlayerActor()
                if actor and #ids > 0 then
                    for _, id in ipairs(ids) do
                        actor:TryOn(id)
                    end
                    RefreshSlotsAfterTryOn()
                end
            end)
        end
    end

    if DressUpCollectionAppearance then
        local original = DressUpCollectionAppearance
        DressUpCollectionAppearance = function(appearanceID, transmogLocation, categoryID)
            if ShouldPassThrough() then return original(appearanceID, transmogLocation, categoryID) end
            -- Capture slot (transmogLocation table may be recycled)
            local slotID = transmogLocation and transmogLocation.GetSlot
                and transmogLocation:GetSlot()
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
        end
    end

    if DressUpItemTransmogInfoList then
        local original = DressUpItemTransmogInfoList
        DressUpItemTransmogInfoList = function(itemTransmogInfoList, showDetails, forceRefresh)
            if ShouldPassThrough() then return original(itemTransmogInfoList, showDetails, forceRefresh) end
            -- Copy the info list since it may be recycled
            local infoCopy = {}
            if itemTransmogInfoList then
                for slotID, info in pairs(itemTransmogInfoList) do
                    infoCopy[slotID] = info
                end
            end
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
        end
    end
end

