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

local function CreateCollectionResetButton(collectionFrame, searchBox, refreshFunc, previewFirstFunc)
    local cp = MCUDressingRoomFrame and MCUDressingRoomFrame.CharacterPreview
    local btnParent = cp or collectionFrame
    local btn = CreateFrame("Button", nil, btnParent, "UIPanelButtonTemplate")
    btn:SetSize(80, 26)
    btn:SetPoint("BOTTOMLEFT", btnParent, "BOTTOMLEFT", 24, 12)
    btn:SetText(RESET or "Reset")
    btn:SetFrameLevel(btnParent:GetFrameLevel() + 50)
    btn:Hide()
    btn:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.UI_TRANSMOG_REVERTING_GEAR_SLOT)
        if searchBox then searchBox:SetText("") end
        if refreshFunc then refreshFunc() end
        if previewFirstFunc then previewFirstFunc() end
    end)
    collectionFrame._resetBtn = btn
    collectionFrame:HookScript("OnShow", function() btn:Show() end)
    collectionFrame:HookScript("OnHide", function() btn:Hide() end)
    return btn
end

local function HideCharacterModeElements()
    if not MCUDressingRoomFrame then return end
    local cp = MCUDressingRoomFrame.CharacterPreview
    if cp then
        if cp.drSlotFrames then
            for _, btn in pairs(cp.drSlotFrames) do btn:Hide() end
        end
        if cp._characterButtons then
            for _, btn in ipairs(cp._characterButtons) do btn:Hide() end
        end
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
    if MCUDressingRoomFrame then PanelTemplates_SetTab(MCUDressingRoomFrame, 2) end
    if not mountID or not C_MountJournal then return end

    local creatureDisplayID, _, _, isSelfMount, _, modelSceneID, animID, spellVisualKitID, disablePlayerMountPreview =
        C_MountJournal.GetMountInfoExtraByID(mountID)
    if not creatureDisplayID or creatureDisplayID == 0 then return end

    ns:ShowMountCollection(mountID)

    -- If already in mount mode, just swap the actor without resetting camera/layout
    local alreadyInMountMode = mountCollectionFrame and mountCollectionFrame:IsShown()
        and MCUDressingRoomFrame.OutfitCollection and not MCUDressingRoomFrame.OutfitCollection:IsShown()
    if alreadyInMountMode then
        C_Timer.After(0.1, function()
            local modelScene = GetModelScene()
            if not modelScene then return end
            if modelScene._mountActor then modelScene._mountActor:ClearModel(); modelScene._mountActor = nil end
            modelScene:TransitionToModelSceneID(modelSceneID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)
            local mountActor = modelScene:CreateActor()
            if mountActor then
                modelScene._mountActor = mountActor
                mountActor:SetModelByCreatureDisplayID(creatureDisplayID, true)
                mountActor:SetUseCenterForOrigin(true, true, true)
                if isSelfMount then
                    mountActor:SetAnimationBlendOperation(Enum.ModelBlendOperation.None)
                    mountActor:SetAnimation(618)
                else
                    mountActor:SetAnimationBlendOperation(Enum.ModelBlendOperation.Anim)
                    mountActor:SetAnimation(0)
                end
                if spellVisualKitID and spellVisualKitID > 0 then
                    mountActor:SetSpellVisualKit(spellVisualKitID)
                end
            end
            local camera = modelScene:GetActiveCamera()
            if camera then
                camera:SetMinZoomDistance(1)
                camera:SetMaxZoomDistance(camera:GetMaxZoomDistance() * 2.5)
                camera:SetZoomDistance(12)
            end
            local cp = MCUDressingRoomFrame.CharacterPreview
            if cp and cp.MountNameLabel then
                local mountName = C_MountJournal.GetMountInfoByID(mountID)
                cp.MountNameLabel:SetText(mountName or "")
            end
        end)
        return
    end

    local earlyScene = GetModelScene()
    if earlyScene then
        if earlyScene._furnitureActor then
            earlyScene._furnitureActor:ClearModel()
            earlyScene._furnitureActor = nil
        end
        local earlyActor = earlyScene:GetPlayerActor()
        if earlyActor then
            earlyActor:ClearModel()
            earlyActor:Hide()
        end
    end

    HideCharacterModeElements()

    local outfitCollection = MCUDressingRoomFrame.OutfitCollection
    local charPreview = MCUDressingRoomFrame.CharacterPreview
    local wardrobeCollection = MCUDressingRoomFrame.WardrobeCollection
    if outfitCollection and charPreview and wardrobeCollection then
        outfitCollection:Hide()
        wardrobeCollection:ClearAllPoints()
        wardrobeCollection:SetPoint("TOPRIGHT", MCUDressingRoomFrame, "TOPRIGHT", -2, -21)
        charPreview:ClearAllPoints()
        charPreview:SetPoint("TOPLEFT", MCUDressingRoomFrame, "TOPLEFT", 2, -21)
        charPreview:SetPoint("TOPRIGHT", wardrobeCollection, "TOPLEFT", 0, 0)
        charPreview:SetHeight(860)
        if charPreview.Background then
            charPreview.Background:ClearAllPoints()
            charPreview.Background:SetAllPoints(charPreview)
        end
    end

    C_Timer.After(0.3, function()
        local modelScene = GetModelScene()
        if not modelScene then return end

        local playerActor = modelScene:GetPlayerActor()
        if playerActor then
            playerActor:ClearModel()
            playerActor:Hide()
        end

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
            local controlFrame = charPreview.ModelScene and charPreview.ModelScene.ControlFrame
            if controlFrame then
                controlFrame:ClearAllPoints()
                controlFrame:SetPoint("TOP", charPreview.MountNameLabel, "BOTTOM", 0, -4)
            end
        end

        modelScene:SetViewInsets(0, 0, 0, 0)
        local forceEvenIfSame = true
        modelScene:TransitionToModelSceneID(modelSceneID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, forceEvenIfSame)

        if modelScene._mountActor then
            modelScene._mountActor:ClearModel()
            modelScene._mountActor = nil
        end

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

        local camera = modelScene:GetActiveCamera()
        if camera then
            camera:SetMinZoomDistance(1)
            camera:SetMaxZoomDistance(camera:GetMaxZoomDistance() * 2.5)
            camera:SetZoomDistance(12)
        end
    end)
end

function ns:PreviewMount(mountID)
    PreviewMount(mountID)
end

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

            if not entry.isCollected then
                model.Border:SetAtlas("transmog-wardrobe-border-uncollected")
            elseif not entry.isUsable then
                model.Border:SetAtlas("transmog-wardrobe-border-unusable")
            else
                model.Border:SetAtlas("transmog-wardrobe-border-collected")
            end

            model.TransmogStateTexture:SetShown(entry.mountID == currentPreviewMountID)

            if model.Favorite then
                model.Favorite.Icon:SetShown(entry.isFavorite or false)
            end

            model.NewString:Hide()
            model.NewGlow:Hide()
            model.SlotInvalidTexture:Hide()
            model.DisabledOverlay:SetShown(not entry.isCollected)
            if not entry.isCollected then model.DisabledOverlay:SetAlpha(0.4) end
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

    local search = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    search:SetSize(260, 20)
    search:SetPoint("TOP", 0, -110)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function(self)
        SearchBoxTemplate_OnTextChanged(self)
        C_MountJournal.SetSearch(self:GetText())
    end)
    mountSearchBox = search

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
    prevBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    prevBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    prevBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    prevBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    prevBtn:SetScript("OnClick", function() pagingFrame:PreviousPage() end)

    local nextBtn = CreateFrame("Button", nil, pagingFrame)
    nextBtn:SetSize(28, 28)
    nextBtn:SetPoint("RIGHT")
    nextBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    nextBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    nextBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    nextBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
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

    frame.OnPageChanged = function() UpdateMountModels() end

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

            model:SetScript("OnMouseDown", function(self, button)
                if button == "LeftButton" and self.mountData then
                    currentPreviewMountID = self.mountData.mountID
                    PreviewMount(self.mountData.mountID)
                end
            end)

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

    frame:RegisterEvent("MOUNT_JOURNAL_SEARCH_UPDATED")
    frame:RegisterEvent("COMPANION_LEARNED")
    frame:RegisterEvent("COMPANION_UNLEARNED")
    frame:SetScript("OnEvent", function() RefreshMountCollection() end)

    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then pagingFrame:PreviousPage() else pagingFrame:NextPage() end
    end)

    CreateCollectionResetButton(frame, search, RefreshMountGrid, function()
        local list = frame.mountList
        if list and #list > 0 then
            currentPreviewMountID = list[1].mountID
            PreviewMount(list[1].mountID)
        end
    end)

    mountCollectionFrame = frame
    return frame
end

function ns:ShowMountCollection(mountID)
    if not mountCollectionFrame then
        CreateMountCollectionFrame()
    end

    local alreadyShowing = mountCollectionFrame:IsShown()
    currentPreviewMountID = mountID

    if not alreadyShowing then
        if ns.HideFurnitureCollection then ns:HideFurnitureCollection(true) end
        if ns.HidePetCollection then ns:HidePetCollection(true) end
        C_MountJournal.SetDefaultFilters()
        C_MountJournal.SetSearch("")
        if mountSearchBox then mountSearchBox:SetText("") end

        if MCUDR_AppearancesFrame then
            MCUDR_AppearancesFrame:Hide()
        end

        mountCollectionFrame:Show()
    end

    RefreshMountCollection()
    if not alreadyShowing then
        NavigateToMount(mountID)
    end
end

function ns:HideMountCollection(skipLayoutRestore)
    if mountCollectionFrame then
        mountCollectionFrame:Hide()
        if mountSearchBox then
            mountSearchBox:SetText("")
            C_MountJournal.SetSearch("")
        end
    end
    currentPreviewMountID = nil

    if not skipLayoutRestore then
        if MCUDressingRoomFrame then
            local outfitCollection = MCUDressingRoomFrame.OutfitCollection
            local charPreview = MCUDressingRoomFrame.CharacterPreview
            local wardrobeCollection = MCUDressingRoomFrame.WardrobeCollection
            if outfitCollection and charPreview then
                outfitCollection:Show()
                charPreview:ClearAllPoints()
                charPreview:SetPoint("TOPLEFT", outfitCollection, "TOPRIGHT", 0, 0)
                charPreview:SetSize(658, 860)
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

        if MCUDR_AppearancesFrame and MCUDressingRoomFrame and MCUDressingRoomFrame:IsShown() then
            MCUDR_AppearancesFrame:Show()
        end
    end
end

local function GetPetInfoFromLink(link)
    if not link or not C_PetJournal then return nil end
    local linkType, linkOptions = LinkUtil.ExtractLink(link)
    local linkID = linkOptions and LinkUtil.SplitLinkOptions(linkOptions)
    if linkType == "battlepet" then
        local speciesID = tonumber(linkID)
        if speciesID then
            local name, icon, petType, creatureID, sourceText, description, _, _, _, _, _, displayID = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
            if creatureID and displayID then
                return { speciesID = speciesID, creatureID = creatureID, displayID = displayID, name = name, icon = icon }
            end
        end
    elseif linkType == "item" then
        local itemID = tonumber(linkID)
        if itemID and C_PetJournal.GetPetInfoByItemID then
            local _, _, _, creatureID, _, _, _, _, _, _, _, displayID, speciesID = C_PetJournal.GetPetInfoByItemID(itemID)
            if creatureID and displayID then
                local name, icon = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
                return { speciesID = speciesID, creatureID = creatureID, displayID = displayID, name = name, icon = icon }
            end
        end
    end
    return nil
end

local function PreviewPet(speciesID)
    ShowOurDressingRoom()
    if MCUDressingRoomFrame then PanelTemplates_SetTab(MCUDressingRoomFrame, 3) end
    if not speciesID or not C_PetJournal then return end

    local name, icon, petType, creatureID, sourceText, description, _, _, _, _, _, displayID = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
    if not creatureID or not displayID then return end

    ns:ShowPetCollection(speciesID)

    -- If already in pet mode, just swap the actor without resetting camera/layout
    local alreadyInPetMode = petCollectionFrame and petCollectionFrame:IsShown()
        and MCUDressingRoomFrame.OutfitCollection and not MCUDressingRoomFrame.OutfitCollection:IsShown()
    if alreadyInPetMode then
        C_Timer.After(0.1, function()
            local modelScene = GetModelScene()
            if not modelScene then return end
            if modelScene._petActor then modelScene._petActor:ClearModel(); modelScene._petActor = nil end
            local _, loadoutSceneID = C_PetJournal.GetPetModelSceneInfoBySpeciesID(speciesID)
            if loadoutSceneID then
                modelScene:SetViewInsets(0, 0, 50, 0)
                modelScene:TransitionToModelSceneID(loadoutSceneID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)
            end
            local petActor = modelScene:CreateActor()
            if petActor then
                modelScene._petActor = petActor
                petActor:SetModelByCreatureDisplayID(displayID, true)
                petActor:SetAnimationBlendOperation(Enum.ModelBlendOperation.None)
                petActor:SetUseCenterForOrigin(true, true, true)
            end
            local camera = modelScene:GetActiveCamera()
            if camera then
                camera:SetMinZoomDistance(0)
                camera:SetMaxZoomDistance(camera:GetMaxZoomDistance() * 10)
                camera:SetZoomDistance(12)
            end
            local cp = MCUDressingRoomFrame.CharacterPreview
            if cp and cp.PetNameLabel then
                cp.PetNameLabel:SetText(name or "")
            end
        end)
        return
    end

    local earlyScene = GetModelScene()
    if earlyScene then
        if earlyScene._mountActor then earlyScene._mountActor:ClearModel(); earlyScene._mountActor = nil end
        if earlyScene._furnitureActor then earlyScene._furnitureActor:ClearModel(); earlyScene._furnitureActor = nil end
        if earlyScene._petActor then earlyScene._petActor:ClearModel(); earlyScene._petActor = nil end
        local earlyActor = earlyScene:GetPlayerActor()
        if earlyActor then earlyActor:ClearModel(); earlyActor:Hide() end
    end

    HideCharacterModeElements()

    local outfitCollection = MCUDressingRoomFrame.OutfitCollection
    local charPreview = MCUDressingRoomFrame.CharacterPreview
    local wardrobeCollection = MCUDressingRoomFrame.WardrobeCollection
    if outfitCollection and charPreview and wardrobeCollection then
        outfitCollection:Hide()
        wardrobeCollection:ClearAllPoints()
        wardrobeCollection:SetPoint("TOPRIGHT", MCUDressingRoomFrame, "TOPRIGHT", -2, -21)
        charPreview:ClearAllPoints()
        charPreview:SetPoint("TOPLEFT", MCUDressingRoomFrame, "TOPLEFT", 2, -21)
        charPreview:SetPoint("TOPRIGHT", wardrobeCollection, "TOPLEFT", 0, 0)
        charPreview:SetHeight(860)
        if charPreview.Background then
            charPreview.Background:ClearAllPoints()
            charPreview.Background:SetAllPoints(charPreview)
        end
    end

    C_Timer.After(0.3, function()
        local modelScene = GetModelScene()
        if not modelScene then return end

        local playerActor = modelScene:GetPlayerActor()
        if playerActor then playerActor:ClearModel(); playerActor:Hide() end

        local cp = MCUDressingRoomFrame.CharacterPreview
        if cp then
            if cp.drSlotFrames then
                for _, btn in pairs(cp.drSlotFrames) do btn:Hide() end
            end
            if not cp.PetNameLabel then
                local label = cp:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
                label:SetPoint("TOP", cp, "TOP", 0, -12)
                label:SetTextColor(1, 0.82, 0, 1)
                cp.PetNameLabel = label
            end
            cp.PetNameLabel:SetText(name or "")
            cp.PetNameLabel:Show()
            if cp.MountNameLabel then cp.MountNameLabel:Hide() end
            if cp.FurnitureNameLabel then cp.FurnitureNameLabel:Hide() end
            local controlFrame = cp.ModelScene and cp.ModelScene.ControlFrame
            if controlFrame then
                controlFrame:ClearAllPoints()
                controlFrame:SetPoint("TOP", cp.PetNameLabel, "BOTTOM", 0, -4)
            end
        end

        local _, loadoutSceneID = C_PetJournal.GetPetModelSceneInfoBySpeciesID(speciesID)
        if loadoutSceneID then
            modelScene:SetViewInsets(0, 0, 50, 0)
            modelScene:TransitionToModelSceneID(loadoutSceneID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)
        end

        if modelScene._petActor then modelScene._petActor:ClearModel(); modelScene._petActor = nil end

        local petActor = modelScene:CreateActor()
        if petActor then
            modelScene._petActor = petActor
            petActor:SetModelByCreatureDisplayID(displayID, true)
            petActor:SetAnimationBlendOperation(Enum.ModelBlendOperation.None)
            petActor:SetUseCenterForOrigin(true, true, true)
        end

        local camera = modelScene:GetActiveCamera()
        if camera then
            camera:SetMinZoomDistance(1)
            camera:SetMaxZoomDistance(camera:GetMaxZoomDistance() * 10)
            camera:SetZoomDistance(12)
        end
    end)
end

function ns:PreviewPet(speciesID)
    PreviewPet(speciesID)
end

local petCollectionFrame = nil
local petSearchBox = nil
local currentPreviewPetID = nil

local PET_NUM_ROWS = 5
local PET_NUM_COLS = 6
local PET_PAGE_SIZE = PET_NUM_ROWS * PET_NUM_COLS

local function GetPetList()
    if not C_PetJournal then return {} end
    local list = {}
    local numPets = C_PetJournal.GetNumPets()
    for i = 1, numPets do
        local petID, speciesID, isOwned, customName, level, favorite, isRevoked, petName, icon, petType = C_PetJournal.GetPetInfoByIndex(i)
        if speciesID then
            local _, _, _, creatureID, sourceText, description, _, _, _, _, _, displayID = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
            list[#list + 1] = {
                speciesID = speciesID,
                petID = petID,
                name = customName and customName ~= "" and format("%s (%s)", customName, petName) or petName or "",
                displayName = petName or "",
                customName = customName,
                icon = icon,
                isOwned = isOwned,
                isFavorite = favorite,
                level = level,
                creatureID = creatureID or 0,
                displayID = displayID or 0,
                sourceText = sourceText or "",
                description = description or "",
            }
        end
    end
    return list
end

local UpdatePetModels
local RefreshPetCollection

UpdatePetModels = function()
    if not petCollectionFrame or not petCollectionFrame:IsShown() then return end
    local frame = petCollectionFrame
    local page = frame.PagingFrame:GetCurrentPage()
    local offset = (page - 1) * PET_PAGE_SIZE

    for i = 1, PET_PAGE_SIZE do
        local model = frame.Models[i]
        local entry = frame.petList[offset + i]
        if entry then
            model:Show()
            if model._petSpeciesID ~= entry.speciesID then
                if entry.displayID and entry.displayID > 0 then
                    model:SetDisplayInfo(entry.displayID)
                else
                    model:SetCreature(entry.creatureID)
                end
                model._petSpeciesID = entry.speciesID
            end
            model.petData = entry

            if not entry.isOwned then
                model.Border:SetAtlas("transmog-wardrobe-border-uncollected")
            else
                model.Border:SetAtlas("transmog-wardrobe-border-collected")
            end

            model.TransmogStateTexture:SetShown(currentPreviewPetID ~= nil and entry.speciesID == currentPreviewPetID)
            if model.Favorite then model.Favorite.Icon:SetShown(entry.isFavorite or false) end
            model.NewString:Hide()
            model.NewGlow:Hide()
            model.SlotInvalidTexture:Hide()
            model.DisabledOverlay:SetShown(not entry.isOwned)
            if not entry.isOwned then model.DisabledOverlay:SetAlpha(0.4) end
            if model.HideVisual then model.HideVisual.Icon:Hide() end
        else
            model:Hide()
            model._petSpeciesID = nil
            model.petData = nil
        end
    end
end

RefreshPetCollection = function()
    if not petCollectionFrame or not petCollectionFrame:IsShown() then return end
    local frame = petCollectionFrame
    frame.petList = GetPetList()
    frame.PagingFrame:SetMaxPages(max(1, ceil(#frame.petList / PET_PAGE_SIZE)))
    UpdatePetModels()
end

local function NavigateToPet(speciesID)
    if not petCollectionFrame or not speciesID then return end
    local frame = petCollectionFrame
    if not frame.petList then return end
    for i, entry in ipairs(frame.petList) do
        if entry.speciesID == speciesID then
            frame.PagingFrame:SetCurrentPage(ceil(i / PET_PAGE_SIZE))
            break
        end
    end
    UpdatePetModels()
end

local function CreatePetCollectionFrame()
    if petCollectionFrame then return petCollectionFrame end
    local parent = MCUDressingRoomFrame.WardrobeCollection

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:SetFrameLevel(parent:GetFrameLevel() + 2)
    frame:Hide()
    frame.petList = {}

    local search = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    search:SetSize(260, 20)
    search:SetPoint("TOP", 0, -110)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function(self)
        SearchBoxTemplate_OnTextChanged(self)
        C_PetJournal.SetSearchFilter(strtrim(self:GetText() or ""))
        RefreshPetCollection()
    end)
    petSearchBox = search

    local pagingFrame = CreateFrame("Frame", nil, frame)
    pagingFrame:SetSize(120, 28)
    pagingFrame:SetPoint("BOTTOM", 0, 8)
    Mixin(pagingFrame, MCUDR_PagingMixin)
    pagingFrame:OnLoad()

    local pageText = pagingFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pageText:SetPoint("CENTER")
    pagingFrame.PageText = pageText

    local prevBtn = CreateFrame("Button", nil, pagingFrame)
    prevBtn:SetSize(28, 28); prevBtn:SetPoint("LEFT")
    prevBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    prevBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    prevBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    prevBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    prevBtn:SetScript("OnClick", function() pagingFrame:PreviousPage() end)

    local nextBtn = CreateFrame("Button", nil, pagingFrame)
    nextBtn:SetSize(28, 28); nextBtn:SetPoint("RIGHT")
    nextBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    nextBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    nextBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    nextBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    nextBtn:SetScript("OnClick", function() pagingFrame:NextPage() end)

    pagingFrame.PrevPageButton = prevBtn; pagingFrame.NextPageButton = nextBtn
    local origUpdate = pagingFrame.Update
    pagingFrame.Update = function(self)
        if origUpdate then origUpdate(self) end
        self.PageText:SetText(self.currentPage .. " / " .. self.maxPages)
        self.PrevPageButton:SetEnabled(self.currentPage > 1)
        self.NextPageButton:SetEnabled(self.currentPage < self.maxPages)
    end
    frame.PagingFrame = pagingFrame
    frame.OnPageChanged = function() UpdatePetModels() end

    frame.Models = {}
    local gridWidth = PET_NUM_COLS * 78 + (PET_NUM_COLS - 1) * 16
    local gridHeight = PET_NUM_ROWS * 104 + (PET_NUM_ROWS - 1) * 24
    local panelHeight = parent:GetHeight() or 860
    local topReserved = 135; local bottomReserved = 40
    local availableHeight = panelHeight - topReserved - bottomReserved
    local gridOffsetY = -topReserved - max(0, (availableHeight - gridHeight) / 2)
    local gridOffsetX = max(0, ((parent:GetWidth() or 644) - gridWidth) / 2)

    for row = 0, PET_NUM_ROWS - 1 do
        for col = 0, PET_NUM_COLS - 1 do
            local idx = row * PET_NUM_COLS + col + 1
            local model = CreateFrame("DressUpModel", nil, frame, "MCUDR_WardrobeModelTemplate")
            model:SetPoint("TOPLEFT", frame, "TOPLEFT",
                gridOffsetX + col * (78 + 16), gridOffsetY - row * (104 + 24))
            model:Hide()

            model:SetScript("OnMouseDown", function(self, button)
                if button == "LeftButton" and self.petData then
                    currentPreviewPetID = self.petData.speciesID
                    PreviewPet(self.petData.speciesID)
                end
            end)

            model:SetScript("OnEnter", function(self)
                if not self.petData then return end
                local d = self.petData
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(d.name or "", 1, 0.82, 0)
                if d.description and d.description ~= "" then
                    GameTooltip:AddLine(d.description, 1, 1, 1, true)
                end
                if d.sourceText and d.sourceText ~= "" then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(d.sourceText, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
                end
                if d.isOwned then
                    if d.level then GameTooltip:AddLine(format("Level %d", d.level), 0.0, 1.0, 0.0) end
                else
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(NOT_COLLECTED or "Not Collected", RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
                end
                GameTooltip:Show()
            end)
            model:SetScript("OnLeave", function() GameTooltip:Hide() end)

            frame.Models[idx] = model
        end
    end

    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then pagingFrame:PreviousPage() else pagingFrame:NextPage() end
    end)

    frame:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
    frame:RegisterEvent("PET_JOURNAL_PET_DELETED")
    frame:RegisterEvent("COMPANION_LEARNED")
    frame:RegisterEvent("COMPANION_UNLEARNED")
    frame:SetScript("OnEvent", function() RefreshPetCollection() end)

    CreateCollectionResetButton(frame, search, RefreshPetCollection, function()
        local list = frame.petList
        if list and #list > 0 then
            currentPreviewPetID = list[1].speciesID
            PreviewPet(list[1].speciesID)
        end
    end)

    petCollectionFrame = frame
    return frame
end

function ns:ShowPetCollection(speciesID)
    if not petCollectionFrame then CreatePetCollectionFrame() end

    local alreadyShowing = petCollectionFrame:IsShown()
    currentPreviewPetID = speciesID

    if not alreadyShowing then
        if ns.HideMountCollection then ns:HideMountCollection(true) end
        if ns.HideFurnitureCollection then ns:HideFurnitureCollection(true) end
        if MCUDR_AppearancesFrame then MCUDR_AppearancesFrame:Hide() end
        if petSearchBox then petSearchBox:SetText(""); C_PetJournal.SetSearchFilter("") end
        petCollectionFrame:Show()
    end

    RefreshPetCollection()
    if speciesID then NavigateToPet(speciesID) end
end

function ns:EnterPetMode()
    ShowOurDressingRoom()
    if MCUDressingRoomFrame then PanelTemplates_SetTab(MCUDressingRoomFrame, 3) end

    ns:ShowPetCollection(nil)

    HideCharacterModeElements()

    local outfitCollection = MCUDressingRoomFrame.OutfitCollection
    local charPreview = MCUDressingRoomFrame.CharacterPreview
    local wardrobeCollection = MCUDressingRoomFrame.WardrobeCollection
    if outfitCollection and charPreview and wardrobeCollection then
        outfitCollection:Hide()
        wardrobeCollection:ClearAllPoints()
        wardrobeCollection:SetPoint("TOPRIGHT", MCUDressingRoomFrame, "TOPRIGHT", -2, -21)
        charPreview:ClearAllPoints()
        charPreview:SetPoint("TOPLEFT", MCUDressingRoomFrame, "TOPLEFT", 2, -21)
        charPreview:SetPoint("TOPRIGHT", wardrobeCollection, "TOPLEFT", 0, 0)
        charPreview:SetHeight(860)
        if charPreview.Background then
            charPreview.Background:ClearAllPoints()
            charPreview.Background:SetAllPoints(charPreview)
        end
    end

    local earlyScene = GetModelScene()
    if earlyScene then
        local earlyActor = earlyScene:GetPlayerActor()
        if earlyActor then earlyActor:ClearModel(); earlyActor:Hide() end
    end

    C_Timer.After(0.3, function()
        local cp = MCUDressingRoomFrame and MCUDressingRoomFrame.CharacterPreview
        if cp then
            if cp.drSlotFrames then
                for _, btn in pairs(cp.drSlotFrames) do btn:Hide() end
            end
            if not cp.PetNameLabel then
                local label = cp:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
                label:SetPoint("TOP", cp, "TOP", 0, -12)
                label:SetTextColor(1, 0.82, 0, 1)
                cp.PetNameLabel = label
            end
            cp.PetNameLabel:SetText("Pet Collection")
            cp.PetNameLabel:Show()
            if cp.MountNameLabel then cp.MountNameLabel:Hide() end
            if cp.FurnitureNameLabel then cp.FurnitureNameLabel:Hide() end
            local controlFrame = cp.ModelScene and cp.ModelScene.ControlFrame
            if controlFrame then
                controlFrame:ClearAllPoints()
                controlFrame:SetPoint("TOP", cp.PetNameLabel, "BOTTOM", 0, -4)
            end
        end

        if not currentPreviewPetID and petCollectionFrame and petCollectionFrame.petList
           and #petCollectionFrame.petList > 0 then
            local first = petCollectionFrame.petList[1]
            PreviewPet(first.speciesID)
        end
    end)
end

function ns:HidePetCollection(skipLayoutRestore)
    if petCollectionFrame then
        petCollectionFrame:Hide()
        if petSearchBox then petSearchBox:SetText(""); C_PetJournal.SetSearchFilter("") end
    end
    currentPreviewPetID = nil

    if not skipLayoutRestore then
        if MCUDressingRoomFrame then
            local outfitCollection = MCUDressingRoomFrame.OutfitCollection
            local charPreview = MCUDressingRoomFrame.CharacterPreview
            local wardrobeCollection = MCUDressingRoomFrame.WardrobeCollection
            if outfitCollection and charPreview then
                outfitCollection:Show()
                charPreview:ClearAllPoints()
                charPreview:SetPoint("TOPLEFT", outfitCollection, "TOPRIGHT", 0, 0)
                charPreview:SetSize(658, 860)
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

        if MCUDR_AppearancesFrame and MCUDressingRoomFrame and MCUDressingRoomFrame:IsShown() then
            MCUDR_AppearancesFrame:Show()
        end
    end
end

local FURNITURE_SIZE_SCENE = {
    [65] = 1333,  -- Tiny
    [66] = 1334,  -- Small
    [67] = 1335,  -- Medium
    [68] = 1336,  -- Large
    [69] = 1337,  -- Huge
}
local FURNITURE_DEFAULT_SCENE = 1317

local function GetFurnitureInfoFromLink(link)
    if not link or not C_HousingCatalog or not C_HousingCatalog.GetCatalogEntryInfoByItem then return nil end
    local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, link, true)
    if ok and info and info.entryID then
        return info
    end
    local linkType, linkOptions = LinkUtil.ExtractLink(link)
    local linkID = linkOptions and LinkUtil.SplitLinkOptions(linkOptions)
    linkID = tonumber(linkID)
    if linkID then
        ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, linkID, true)
        if ok and info and info.entryID then
            return info
        end
    end
    if link then
        local itemName = (linkID and C_Item.GetItemNameByID(linkID))
            or (linkID and select(1, C_Item.GetItemInfo(linkID)))
            or link:match("%|h%[(.-)%]%|h")
        if itemName then
            local furnitureName = itemName:match("^Formula:%s*(.+)")
                or itemName:match("^Recipe:%s*(.+)")
                or itemName:match("^Pattern:%s*(.+)")
                or itemName:match("^Schematic:%s*(.+)")
                or itemName:match("^Design:%s*(.+)")
                or itemName:match("^Blueprint:%s*(.+)")
            if furnitureName then
                ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, furnitureName, true)
                if ok and info and info.entryID then
                    return info
                end
            end
        end
    end
    return nil
end

local function PreviewFurniture(entryID)
    ShowOurDressingRoom()
    if MCUDressingRoomFrame then PanelTemplates_SetTab(MCUDressingRoomFrame, 4) end
    if not entryID or not C_HousingCatalog then return end

    local info = C_HousingCatalog.GetCatalogEntryInfo(entryID)
    if not info then return end

    ns:ShowFurnitureCollection(entryID)

    local alreadyInFurnitureMode = furnitureCollectionFrame and furnitureCollectionFrame:IsShown()
        and MCUDressingRoomFrame.OutfitCollection and not MCUDressingRoomFrame.OutfitCollection:IsShown()
    if alreadyInFurnitureMode then
        C_Timer.After(0.3, function()
            local modelScene = GetModelScene()
            if not modelScene then return end

            if modelScene._furnitureActor then
                modelScene._furnitureActor:ClearModel()
                modelScene._furnitureActor = nil
            end

            local sceneID = info.uiModelSceneID
            if not sceneID or sceneID == 0 then
                sceneID = info.size and FURNITURE_SIZE_SCENE[info.size] or FURNITURE_DEFAULT_SCENE
            end
            modelScene:TransitionToModelSceneID(sceneID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)

            local cp = MCUDressingRoomFrame.CharacterPreview
            if cp and cp.FurnitureIconFallback then cp.FurnitureIconFallback:Hide() end

            if info.asset then
                local actor = modelScene:CreateActor()
                if actor then
                    modelScene._furnitureActor = actor
                    actor:SetModelByFileID(info.asset)
                    if actor.SetPreferModelCollisionBounds then
                        actor:SetPreferModelCollisionBounds(true)
                    end
                    actor:SetUseCenterForOrigin(true, true, true)
                end
            elseif cp and cp.FurnitureIconFallback then
                if info.iconAtlas then
                    cp.FurnitureIconFallback:SetAtlas(info.iconAtlas)
                elseif info.iconTexture then
                    cp.FurnitureIconFallback:SetTexture(info.iconTexture)
                end
                cp.FurnitureIconFallback:Show()
            end

            if cp and cp.FurnitureNameLabel then
                local nameColor = ITEM_QUALITY_COLORS[info.quality or 1] or ITEM_QUALITY_COLORS[1]
                cp.FurnitureNameLabel:SetTextColor(nameColor.r, nameColor.g, nameColor.b, 1)
                cp.FurnitureNameLabel:SetText(info.name or "")
            end

            local camera = modelScene:GetActiveCamera()
            if camera then
                camera:SetMaxZoomDistance(camera:GetMaxZoomDistance() * 5)
            end
        end)
        return
    end

    local earlyScene = GetModelScene()
    if earlyScene then
        if earlyScene._mountActor then
            earlyScene._mountActor:ClearModel()
            earlyScene._mountActor = nil
        end
        if earlyScene._furnitureActor then
            earlyScene._furnitureActor:ClearModel()
            earlyScene._furnitureActor = nil
        end
        local earlyActor = earlyScene:GetPlayerActor()
        if earlyActor then
            earlyActor:ClearModel()
            earlyActor:Hide()
        end
    end

    HideCharacterModeElements()

    local outfitCollection = MCUDressingRoomFrame.OutfitCollection
    local charPreview = MCUDressingRoomFrame.CharacterPreview
    local wardrobeCollection = MCUDressingRoomFrame.WardrobeCollection
    if outfitCollection and charPreview and wardrobeCollection then
        outfitCollection:Hide()
        wardrobeCollection:ClearAllPoints()
        wardrobeCollection:SetPoint("TOPRIGHT", MCUDressingRoomFrame, "TOPRIGHT", -2, -21)
        charPreview:ClearAllPoints()
        charPreview:SetPoint("TOPLEFT", MCUDressingRoomFrame, "TOPLEFT", 2, -21)
        charPreview:SetPoint("TOPRIGHT", wardrobeCollection, "TOPLEFT", 0, 0)
        charPreview:SetHeight(860)
        if charPreview.Background then
            charPreview.Background:ClearAllPoints()
            charPreview.Background:SetAllPoints(charPreview)
        end
    end

    C_Timer.After(0.3, function()
        local modelScene = GetModelScene()
        if not modelScene then return end

        local playerActor = modelScene:GetPlayerActor()
        if playerActor then
            playerActor:ClearModel()
            playerActor:Hide()
        end

        local cp = MCUDressingRoomFrame.CharacterPreview
        if cp then
            if cp.drSlotFrames then
                for _, btn in pairs(cp.drSlotFrames) do btn:Hide() end
            end
            if not cp.FurnitureNameLabel then
                local label = cp:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
                label:SetPoint("TOP", cp, "TOP", 0, -12)
                cp.FurnitureNameLabel = label
            end
            local nameColor = ITEM_QUALITY_COLORS[info.quality or 1] or ITEM_QUALITY_COLORS[1]
            cp.FurnitureNameLabel:SetTextColor(nameColor.r, nameColor.g, nameColor.b, 1)
            cp.FurnitureNameLabel:SetText(info.name or "")
            cp.FurnitureNameLabel:Show()
            if cp.MountNameLabel then cp.MountNameLabel:Hide() end
            local controlFrame = cp.ModelScene and cp.ModelScene.ControlFrame
            if controlFrame then
                controlFrame:ClearAllPoints()
                controlFrame:SetPoint("TOP", cp.FurnitureNameLabel, "BOTTOM", 0, -4)
            end
        end

        local sceneID = info.uiModelSceneID
        if not sceneID or sceneID == 0 then
            sceneID = info.size and FURNITURE_SIZE_SCENE[info.size] or FURNITURE_DEFAULT_SCENE
        end

        modelScene:SetViewInsets(0, 0, 0, 0)
        modelScene:TransitionToModelSceneID(sceneID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)

        if modelScene._furnitureActor then
            modelScene._furnitureActor:ClearModel()
            modelScene._furnitureActor = nil
        end

        if cp then
            if not cp.FurnitureIconFallback then
                local fb = cp:CreateTexture(nil, "ARTWORK")
                fb:SetSize(256, 256)
                fb:SetPoint("CENTER", cp, "CENTER", 0, 0)
                fb:Hide()
                cp.FurnitureIconFallback = fb
            end
        end

        if info.asset then
            if cp and cp.FurnitureIconFallback then cp.FurnitureIconFallback:Hide() end
            local actor = modelScene:CreateActor()
            if actor then
                modelScene._furnitureActor = actor
                actor:SetModelByFileID(info.asset)
                if actor.SetPreferModelCollisionBounds then
                    actor:SetPreferModelCollisionBounds(true)
                end
                actor:SetUseCenterForOrigin(true, true, true)
            end
        else
            if cp and cp.FurnitureIconFallback then
                if info.iconAtlas then
                    cp.FurnitureIconFallback:SetAtlas(info.iconAtlas)
                elseif info.iconTexture then
                    cp.FurnitureIconFallback:SetTexture(info.iconTexture)
                end
                cp.FurnitureIconFallback:Show()
            end
        end

        local camera = modelScene:GetActiveCamera()
        if camera then
            camera:SetMaxZoomDistance(camera:GetMaxZoomDistance() * 5)
        end
    end)
end

function ns:PreviewFurniture(entryID)
    PreviewFurniture(entryID)
end

local furnitureCollectionFrame = nil
local furnitureSearchBox = nil
local currentPreviewFurnitureKey = nil
local furnitureCatalogSearcher = nil

-- entryID is a table type, so == fails between different instances.
-- We use the entry's name as a stable key since itemID may be nil.
local function FurnitureKey(entryIDOrInfo)
    if entryIDOrInfo == nil then return nil end
    if type(entryIDOrInfo) == "table" and entryIDOrInfo.name then
        return entryIDOrInfo.name
    end
    if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfo then
        local info = C_HousingCatalog.GetCatalogEntryInfo(entryIDOrInfo)
        if info and info.name then
            return info.name
        end
    end
    return tostring(entryIDOrInfo)
end

local RefreshFurnitureCollection
local RunFurnitureSearch
local UpdateFurnitureModels

local FURN_NUM_ROWS = 5
local FURN_NUM_COLS = 6
local FURN_PAGE_SIZE = FURN_NUM_ROWS * FURN_NUM_COLS
local FURN_MODEL_WIDTH = 78
local FURN_MODEL_HEIGHT = 104
local FURN_COL_GAP = 16
local FURN_ROW_GAP = 24

local FURNITURE_SIZE_NAMES = {
    [65] = "Tiny", [66] = "Small", [67] = "Medium", [68] = "Large", [69] = "Huge",
}

local function EnsureFurnitureSearcher()
    if furnitureCatalogSearcher then return furnitureCatalogSearcher end
    if not C_HousingCatalog or not C_HousingCatalog.CreateCatalogSearcher then return nil end
    furnitureCatalogSearcher = C_HousingCatalog.CreateCatalogSearcher()
    if furnitureCatalogSearcher then
        furnitureCatalogSearcher:SetOwnedOnly(false)
        furnitureCatalogSearcher:SetAutoUpdateOnParamChanges(false)
        if Enum.HouseEditorMode and furnitureCatalogSearcher.SetEditorModeContext then
            furnitureCatalogSearcher:SetEditorModeContext(Enum.HouseEditorMode.BasicDecor)
        end
        furnitureCatalogSearcher:SetResultsUpdatedCallback(function()
            if furnitureCollectionFrame and furnitureCollectionFrame:IsShown() then
                RefreshFurnitureCollection()
                if not currentPreviewFurnitureKey and furnitureCollectionFrame.furnitureList
                   and #furnitureCollectionFrame.furnitureList > 0 then
                    local firstEntry = furnitureCollectionFrame.furnitureList[1]
                    PreviewFurniture(firstEntry.entryID)
                end
            end
        end)
    end
    return furnitureCatalogSearcher
end

RunFurnitureSearch = function()
    local searcher = EnsureFurnitureSearcher()
    if not searcher then return end

    local searchText = furnitureSearchBox and furnitureSearchBox:GetText() or ""
    searcher:SetSearchText(searchText)

    if furnitureCollectionFrame and furnitureCollectionFrame.activeCategoryID and searcher.SetFilteredCategoryID then
        searcher:SetFilteredCategoryID(furnitureCollectionFrame.activeCategoryID)
    end

    searcher:RunSearch()
end

local function BuildFurnitureListFromResults()
    if not furnitureCatalogSearcher then return {} end

    local entryIDs = furnitureCatalogSearcher:GetCatalogSearchResults()
    if not entryIDs or #entryIDs == 0 then
        entryIDs = furnitureCatalogSearcher:GetAllSearchItems()
    end
    if not entryIDs then return {} end

    local list = {}
    for _, eid in ipairs(entryIDs) do
        local eInfo = C_HousingCatalog.GetCatalogEntryInfo(eid)
        if eInfo then
            list[#list + 1] = {
                entryID = eInfo.entryID,
                key = eInfo.name or tostring(eInfo.entryID),
                name = eInfo.name or "",
                asset = eInfo.asset,
                iconTexture = eInfo.iconTexture,
                iconAtlas = eInfo.iconAtlas,
                size = eInfo.size,
                quality = eInfo.quality,
                quantity = (eInfo.quantity or 0) + (eInfo.remainingRedeemable or 0),
                sourceText = eInfo.sourceText or "",
                isAllowedIndoors = eInfo.isAllowedIndoors,
                isAllowedOutdoors = eInfo.isAllowedOutdoors,
                uiModelSceneID = eInfo.uiModelSceneID,
            }
        end
    end

    table.sort(list, function(a, b)
        local aOwned = (a.quantity > 0) and 1 or 0
        local bOwned = (b.quantity > 0) and 1 or 0
        if aOwned ~= bOwned then return aOwned > bOwned end
        return a.name < b.name
    end)

    return list
end

UpdateFurnitureModels = function()
    if not furnitureCollectionFrame or not furnitureCollectionFrame:IsShown() then return end

    local frame = furnitureCollectionFrame
    local page = frame.PagingFrame:GetCurrentPage()
    local offset = (page - 1) * FURN_PAGE_SIZE

    for i = 1, FURN_PAGE_SIZE do
        local model = frame.Models[i]
        local entry = frame.furnitureList[offset + i]
        if entry then
            model:Show()
            if model._furnitureEntryID ~= entry.entryID then
                if entry.asset then
                    model:SetModel(entry.asset)
                    if model.FurnitureIcon then model.FurnitureIcon:Hide() end
                else
                    model:ClearModel()
                    if not model.FurnitureIcon then
                        local ic = model:CreateTexture(nil, "ARTWORK")
                        ic:SetSize(48, 48)
                        ic:SetPoint("CENTER")
                        model.FurnitureIcon = ic
                    end
                    if entry.iconAtlas then
                        model.FurnitureIcon:SetAtlas(entry.iconAtlas)
                    elseif entry.iconTexture then
                        model.FurnitureIcon:SetTexture(entry.iconTexture)
                    end
                    model.FurnitureIcon:Show()
                end
                model._furnitureEntryID = entry.entryID
            end
            model.furnitureData = entry

            local isOwned = entry.quantity > 0
            if not isOwned then
                model.Border:SetAtlas("transmog-wardrobe-border-uncollected")
            elseif entry.quality and ITEM_QUALITY_COLORS[entry.quality] then
                model.Border:SetAtlas("transmog-wardrobe-border-collected")
            else
                model.Border:SetAtlas("transmog-wardrobe-border-collected")
            end

            model.TransmogStateTexture:SetShown(currentPreviewFurnitureKey ~= nil and entry.key == currentPreviewFurnitureKey)
            if model.Favorite then model.Favorite.Icon:Hide() end
            model.NewString:Hide()
            model.NewGlow:Hide()
            model.SlotInvalidTexture:Hide()
            model.DisabledOverlay:SetShown(not isOwned)
            if not isOwned then model.DisabledOverlay:SetAlpha(0.4) end
            if model.HideVisual then model.HideVisual.Icon:Hide() end
        else
            model:Hide()
            model._furnitureEntryID = nil
            model.furnitureData = nil
        end
    end
end

RefreshFurnitureCollection = function()
    if not furnitureCollectionFrame or not furnitureCollectionFrame:IsShown() then return end
    local frame = furnitureCollectionFrame
    frame.furnitureList = BuildFurnitureListFromResults()
    frame.PagingFrame:SetMaxPages(max(1, ceil(#frame.furnitureList / FURN_PAGE_SIZE)))
    UpdateFurnitureModels()
end

local function NavigateToFurniture(entryID)
    if not furnitureCollectionFrame or not entryID then return end
    local frame = furnitureCollectionFrame
    if not frame.furnitureList then return end
    for i, entry in ipairs(frame.furnitureList) do
        if entry.key == FurnitureKey(entryID) then
            local page = ceil(i / FURN_PAGE_SIZE)
            frame.PagingFrame:SetCurrentPage(page)
            break
        end
    end
    UpdateFurnitureModels()
end

local function CreateFurnitureCollectionFrame()
    if furnitureCollectionFrame then return furnitureCollectionFrame end
    local parent = MCUDressingRoomFrame.WardrobeCollection

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:SetFrameLevel(parent:GetFrameLevel() + 2)
    frame:Hide()
    frame.furnitureList = {}
    local allCategoryID = Constants and Constants.HousingCatalogConsts
        and Constants.HousingCatalogConsts.HOUSING_CATALOG_ALL_CATEGORY_ID or 18
    frame.activeCategoryID = allCategoryID

    local search = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    search:SetSize(260, 20)
    search:SetPoint("TOP", 0, -110)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function(self)
        SearchBoxTemplate_OnTextChanged(self)
        RunFurnitureSearch()
    end)
    furnitureSearchBox = search

    if C_HousingCatalog.SearchCatalogCategories then
        local catDropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
        catDropdown:SetSize(150, 22)
        catDropdown:SetPoint("TOPLEFT", 48, -10)
        frame.CategoryDropdown = catDropdown

        catDropdown:SetupMenu(function(_dropdown, rootDescription)
            rootDescription:SetTag("MENU_MCUDR_FURNITURE_CATEGORY")

            local function IsSelected(catID)
                return frame.activeCategoryID == catID
            end
            local function SetSelected(catID)
                frame.activeCategoryID = catID
                RunFurnitureSearch()
            end

            local categoryIDs = C_HousingCatalog.SearchCatalogCategories({ withOwnedEntriesOnly = false })
            if categoryIDs then
                for _, catID in ipairs(categoryIDs) do
                    local catInfo = C_HousingCatalog.GetCatalogCategoryInfo(catID)
                    if catInfo and catInfo.name then
                        rootDescription:CreateRadio(catInfo.name, IsSelected, SetSelected, catID)
                    end
                end
            end
        end)
    end

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
    prevBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    prevBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    prevBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    prevBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    prevBtn:SetScript("OnClick", function() pagingFrame:PreviousPage() end)

    local nextBtn = CreateFrame("Button", nil, pagingFrame)
    nextBtn:SetSize(28, 28)
    nextBtn:SetPoint("RIGHT")
    nextBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    nextBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    nextBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    nextBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
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
    frame.OnPageChanged = function() UpdateFurnitureModels() end

    frame.Models = {}
    local gridWidth = FURN_NUM_COLS * FURN_MODEL_WIDTH + (FURN_NUM_COLS - 1) * FURN_COL_GAP
    local gridHeight = FURN_NUM_ROWS * FURN_MODEL_HEIGHT + (FURN_NUM_ROWS - 1) * FURN_ROW_GAP
    local panelHeight = parent:GetHeight() or 860
    local topReserved = 135
    local bottomReserved = 40
    local availableHeight = panelHeight - topReserved - bottomReserved
    local gridOffsetY = -topReserved - max(0, (availableHeight - gridHeight) / 2)
    local gridOffsetX = max(0, ((parent:GetWidth() or 644) - gridWidth) / 2)

    for row = 0, FURN_NUM_ROWS - 1 do
        for col = 0, FURN_NUM_COLS - 1 do
            local idx = row * FURN_NUM_COLS + col + 1
            local model = CreateFrame("DressUpModel", nil, frame, "MCUDR_WardrobeModelTemplate")
            model:SetPoint("TOPLEFT", frame, "TOPLEFT",
                gridOffsetX + col * (FURN_MODEL_WIDTH + FURN_COL_GAP),
                gridOffsetY - row * (FURN_MODEL_HEIGHT + FURN_ROW_GAP))
            model:Hide()

            model:SetScript("OnMouseDown", function(self, button)
                if button == "LeftButton" and self.furnitureData then
                    currentPreviewFurnitureKey = self.furnitureData.key
                    PreviewFurniture(self.furnitureData.entryID)
                end
            end)

            model:SetScript("OnEnter", function(self)
                if not self.furnitureData then return end
                local d = self.furnitureData
                local qColor = ITEM_QUALITY_COLORS[d.quality or 1] or ITEM_QUALITY_COLORS[1]
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(d.name or "", qColor.r, qColor.g, qColor.b)
                if d.sourceText and d.sourceText ~= "" then
                    GameTooltip:AddLine(d.sourceText, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
                end
                local sizeName = FURNITURE_SIZE_NAMES[d.size]
                if sizeName then
                    GameTooltip:AddLine("Size: " .. sizeName, 0.7, 0.7, 0.7)
                end
                local flags = {}
                if d.isAllowedIndoors then flags[#flags + 1] = "Indoor" end
                if d.isAllowedOutdoors then flags[#flags + 1] = "Outdoor" end
                if #flags > 0 then
                    GameTooltip:AddLine(table.concat(flags, " | "), 0.7, 0.7, 0.7)
                end
                if d.quantity > 0 then
                    GameTooltip:AddLine(format("Owned: %d", d.quantity), 0.0, 1.0, 0.0)
                else
                    GameTooltip:AddLine("Not Collected", RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
                end
                GameTooltip:Show()
            end)
            model:SetScript("OnLeave", function() GameTooltip:Hide() end)

            frame.Models[idx] = model
        end
    end

    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then pagingFrame:PreviousPage() else pagingFrame:NextPage() end
    end)

    CreateCollectionResetButton(frame, search, RefreshFurnitureCollection, function()
        local list = frame.furnitureList
        if list and #list > 0 then
            currentPreviewFurnitureKey = FurnitureKey(list[1].entryID)
            PreviewFurniture(list[1].entryID)
        end
    end)

    furnitureCollectionFrame = frame
    return frame
end

function ns:ShowFurnitureCollection(entryID)
    if not C_HousingCatalog then return end
    if not furnitureCollectionFrame then
        CreateFurnitureCollectionFrame()
    end

    local alreadyShowing = furnitureCollectionFrame:IsShown()
    currentPreviewFurnitureKey = FurnitureKey(entryID)

    if not alreadyShowing then
        if MCUDR_AppearancesFrame then MCUDR_AppearancesFrame:Hide() end
        if mountCollectionFrame and mountCollectionFrame:IsShown() then ns:HideMountCollection(true) end
        if petCollectionFrame and petCollectionFrame:IsShown() then ns:HidePetCollection(true) end
        if furnitureSearchBox then furnitureSearchBox:SetText("") end
        furnitureCollectionFrame:Show()

        EnsureFurnitureSearcher()
        RunFurnitureSearch()
    end

    -- Results may be empty if async callback hasn't fired yet
    RefreshFurnitureCollection()
    if entryID then
        NavigateToFurniture(entryID)
    end
    UpdateFurnitureModels()
end

function ns:HideFurnitureCollection(skipLayoutRestore)
    if furnitureCollectionFrame then
        furnitureCollectionFrame:Hide()
        if furnitureSearchBox then furnitureSearchBox:SetText("") end
    end
    currentPreviewFurnitureKey = nil

    if not skipLayoutRestore then
        if MCUDressingRoomFrame then
            local outfitCollection = MCUDressingRoomFrame.OutfitCollection
            local charPreview = MCUDressingRoomFrame.CharacterPreview
            local wardrobeCollection = MCUDressingRoomFrame.WardrobeCollection
            if outfitCollection and charPreview then
                outfitCollection:Show()
                charPreview:ClearAllPoints()
                charPreview:SetPoint("TOPLEFT", outfitCollection, "TOPRIGHT", 0, 0)
                charPreview:SetSize(658, 860)
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

        if MCUDR_AppearancesFrame and MCUDressingRoomFrame and MCUDressingRoomFrame:IsShown() then
            MCUDR_AppearancesFrame:Show()
        end
    end
end

function ns:EnterFurnitureMode()
    if not C_HousingCatalog then return end
    ShowOurDressingRoom()
    if MCUDressingRoomFrame then PanelTemplates_SetTab(MCUDressingRoomFrame, 4) end

    ns:ShowFurnitureCollection(nil)

    HideCharacterModeElements()

    local outfitCollection = MCUDressingRoomFrame.OutfitCollection
    local charPreview = MCUDressingRoomFrame.CharacterPreview
    local wardrobeCollection = MCUDressingRoomFrame.WardrobeCollection
    if outfitCollection and charPreview and wardrobeCollection then
        outfitCollection:Hide()
        wardrobeCollection:ClearAllPoints()
        wardrobeCollection:SetPoint("TOPRIGHT", MCUDressingRoomFrame, "TOPRIGHT", -2, -21)
        charPreview:ClearAllPoints()
        charPreview:SetPoint("TOPLEFT", MCUDressingRoomFrame, "TOPLEFT", 2, -21)
        charPreview:SetPoint("TOPRIGHT", wardrobeCollection, "TOPLEFT", 0, 0)
        charPreview:SetHeight(860)
        if charPreview.Background then
            charPreview.Background:ClearAllPoints()
            charPreview.Background:SetAllPoints(charPreview)
        end
    end

    local earlyScene = GetModelScene()
    if earlyScene then
        local earlyActor = earlyScene:GetPlayerActor()
        if earlyActor then
            earlyActor:ClearModel()
            earlyActor:Hide()
        end
    end

    C_Timer.After(0.3, function()
        local cp = MCUDressingRoomFrame and MCUDressingRoomFrame.CharacterPreview
        if cp then
            if cp.drSlotFrames then
                for _, btn in pairs(cp.drSlotFrames) do btn:Hide() end
            end
            if not cp.FurnitureNameLabel then
                local label = cp:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
                label:SetPoint("TOP", cp, "TOP", 0, -12)
                cp.FurnitureNameLabel = label
            end
            cp.FurnitureNameLabel:SetTextColor(1, 0.82, 0, 1)
            cp.FurnitureNameLabel:SetText("Furniture Collection")
            cp.FurnitureNameLabel:Show()
            if cp.MountNameLabel then cp.MountNameLabel:Hide() end
            local controlFrame = cp.ModelScene and cp.ModelScene.ControlFrame
            if controlFrame then
                controlFrame:ClearAllPoints()
                controlFrame:SetPoint("TOP", cp.FurnitureNameLabel, "BOTTOM", 0, -4)
            end
        end
    end)
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
        -- Item may not be cached yet; GetItemInfoInstant doesn't require cache
        local _, _, _, itemEquipLoc, itemIcon = C_Item.GetItemInfoInstant(link)
        if itemEquipLoc and itemEquipLoc ~= "" then
            slotID = EQUIP_LOC_TO_SLOT[itemEquipLoc]
            icon = icon or itemIcon
        end
    end

    if not slotID then return end

    local numericSourceID
    if C_TransmogCollection and C_TransmogCollection.GetItemInfo then
        local ok, appearanceID, srcID = pcall(C_TransmogCollection.GetItemInfo, link)
        if ok and srcID and type(srcID) == "number" then
            numericSourceID = srcID
        end
    end

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

    StorePreviewSlot(link)

    -- If item isn't cached yet, request load and retry after a delay
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

    -- Deferred: model scene needs time to finish its OnShow transition
    C_Timer.After(0.5, function()
        local actor = GetPlayerActor()
        if actor then
            actor:TryOn(link)
            RefreshSlotsAfterTryOn()
        end
    end)
end

function ns:InitDressingRoomHooks()
    if MCUDressingRoomFrame then
        MCUDressingRoomFrame._addonNS = ns;
    end

    -- Must pre-initialize: GetCatalogEntryInfoByItem fails on first use otherwise.
    -- Also re-run on zone transitions (instance changes invalidate catalog data).
    local function RefreshFurnitureCatalog()
        if not C_HousingCatalog then return end
        EnsureFurnitureSearcher()
        if furnitureCatalogSearcher then
            furnitureCatalogSearcher:RunSearch()
        end
    end
    RefreshFurnitureCatalog()

    local catalogRefreshFrame = CreateFrame("Frame")
    catalogRefreshFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    catalogRefreshFrame:SetScript("OnEvent", function()
        RefreshFurnitureCatalog()
    end)

    -- Pre-hook pattern: replace DressUp globals so Blizzard's DressUpFrame is
    -- never opened via ShowUIPanel. Post-hooks (hooksecurefunc) caused taint
    -- because hiding DressUpFrame from addon code taints UI-panel state.

    local function HandleDressUpLink(link)
        local mountID = GetMountIDFromLink(link)
        if mountID then
            PreviewMount(mountID)
            return true
        end
        local petInfo = GetPetInfoFromLink(link)
        if petInfo then
            PreviewPet(petInfo.speciesID)
            return true
        end
        local furnitureInfo = GetFurnitureInfoFromLink(link)
        if furnitureInfo then
            PreviewFurniture(furnitureInfo.entryID)
            return true
        end
        return false
    end

    if DressUpLink then
        local original = DressUpLink
        DressUpLink = function(link)
            if ShouldPassThrough() or not link then return original(link) end
            if not HandleDressUpLink(link) then
                TryOnItem(link)
            end
        end
    end

    if DressUpItemLink then
        local original = DressUpItemLink
        DressUpItemLink = function(link)
            if ShouldPassThrough() or not link then return original(link) end
            if not HandleDressUpLink(link) then
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
        DressUpBattlePet = function(creatureID, displayID, speciesID, ...)
            if ShouldPassThrough() then return original(creatureID, displayID, speciesID, ...) end
            if speciesID then
                PreviewPet(speciesID)
            else
                ShowOurDressingRoom()
            end
        end
    end

    if DressUpTransmogSet then
        local original = DressUpTransmogSet
        DressUpTransmogSet = function(itemModifiedAppearanceIDs)
            if ShouldPassThrough() then return original(itemModifiedAppearanceIDs) end
            -- Blizzard may recycle this table after the call returns
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
            -- transmogLocation table may be recycled by Blizzard after return
            local slotID = transmogLocation and transmogLocation.GetSlot
                and transmogLocation:GetSlot()
            if not MCUDressingRoomFrame or not MCUDressingRoomFrame:IsShown() then
                ShowOurDressingRoom()
            end
            C_Timer.After(0.5, function()
                local actor = GetPlayerActor()
                if actor and appearanceID then
                    actor:TryOn(appearanceID)

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
            -- Blizzard may recycle this table after the call returns
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

