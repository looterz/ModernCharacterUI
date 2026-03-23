local addonName, ns = ...

local container = ns.equipContainer

StaticPopupDialogs["MCU_NEW_EQUIPMENT_SET"] = {
    text = GEARSETS_POPUP_TEXT or "Enter a name for this equipment set:",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    OnAccept = function(self)
        local name = strtrim(self.editBox:GetText() or "")
        if name ~= "" then
            local icon = ns._pendingSetIcon or 132762
            C_EquipmentSet.CreateEquipmentSet(name, icon)
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local name = strtrim(self:GetText() or "")
        if name ~= "" then
            local icon = ns._pendingSetIcon or 132762
            C_EquipmentSet.CreateEquipmentSet(name, icon)
        end
        parent:Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["MCU_RENAME_EQUIPMENT_SET"] = {
    text = GEARSETS_POPUP_TEXT or "Enter a new name for this equipment set:",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    OnShow = function(self)
        local data = self.data
        if data then
            self.editBox:SetText(data.name or "")
            self.editBox:HighlightText()
        end
    end,
    OnAccept = function(self, data)
        local newName = strtrim(self.editBox:GetText() or "")
        if newName ~= "" and data then
            C_EquipmentSet.ModifyEquipmentSet(data.setID, newName, data.icon)
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local data = parent.data
        local newName = strtrim(self:GetText() or "")
        if newName ~= "" and data then
            C_EquipmentSet.ModifyEquipmentSet(data.setID, newName, data.icon)
        end
        parent:Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["MCU_CONFIRM_DELETE_SET"] = {
    text = CONFIRM_DELETE_EQUIPMENT_SET or "Delete equipment set \"%s\"?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        C_EquipmentSet.DeleteEquipmentSet(data)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["MCU_CONFIRM_SAVE_SET"] = {
    text = CONFIRM_SAVE_EQUIPMENT_SET or "Save current equipment to \"%s\"?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        C_EquipmentSet.SaveEquipmentSet(data)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local ENTRY_HEIGHT   = 44
local BUTTON_AREA_H  = 34

local scrollFrame = CreateFrame("ScrollFrame", nil, container,
                                "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 0, 0)
scrollFrame:SetPoint("BOTTOMRIGHT", -22, BUTTON_AREA_H)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetWidth(scrollFrame:GetWidth() or 240)
scrollFrame:SetScrollChild(content)

container:SetScript("OnSizeChanged", function(self)
    local w = self:GetWidth() - 24
    content:SetWidth(w > 0 and w or 240)
end)

local equipBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
equipBtn:SetSize(110, 26)
equipBtn:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 2)
equipBtn:SetText(EQUIP or "Equip")
equipBtn:Disable()

local saveBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
saveBtn:SetSize(110, 26)
saveBtn:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 2)
saveBtn:SetText(SAVE or "Save")
saveBtn:Disable()

local selectedSetID = nil
local pendingEquipSetID = nil

local setButtons = {}

local function CreateSetEntryButton()
    local btn = CreateFrame("Button", nil, content)
    btn:SetHeight(ENTRY_HEIGHT)

    local stripe = btn:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints()
    stripe:SetColorTexture(1, 1, 1, 0.04)
    stripe:Hide()
    btn.stripe = stripe

    local selBar = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
    selBar:SetAllPoints()
    selBar:SetColorTexture(0.35, 0.30, 0.10, 0.35)
    selBar:Hide()
    btn.selBar = selBar

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("LEFT", 4, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    local name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    name:SetPoint("RIGHT", -24, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    btn.name = name

    local check = btn:CreateTexture(nil, "OVERLAY")
    check:SetSize(14, 14)
    check:SetPoint("TOPRIGHT", -2, -2)
    check:SetAtlas("common-icon-checkmark")
    check:Hide()
    btn.check = check

    local specIcon = btn:CreateTexture(nil, "OVERLAY")
    specIcon:SetSize(16, 16)
    specIcon:SetPoint("RIGHT", check, "LEFT", -2, 0)
    specIcon:Hide()
    btn.specIcon = specIcon

    local delBtn = CreateFrame("Button", nil, btn)
    delBtn:SetSize(16, 16)
    delBtn:SetPoint("BOTTOMRIGHT", -2, 4)
    delBtn:SetNormalAtlas("common-icon-redx")
    delBtn:SetHighlightAtlas("common-icon-redx")
    delBtn:GetHighlightTexture():SetAlpha(0.5)
    delBtn:Hide()
    delBtn:SetScript("OnClick", function(self)
        local setID = self:GetParent().setID
        if setID then
            local setName = C_EquipmentSet.GetEquipmentSetInfo(setID)
            StaticPopup_Show("MCU_CONFIRM_DELETE_SET", setName, nil, setID)
        end
    end)
    btn.delBtn = delBtn

    local editBtn = CreateFrame("Button", nil, btn)
    editBtn:SetSize(16, 16)
    editBtn:SetPoint("RIGHT", delBtn, "LEFT", -2, 0)
    editBtn:SetNormalAtlas("common-icon-settings")
    editBtn:SetHighlightAtlas("common-icon-settings")
    editBtn:GetHighlightTexture():SetAlpha(0.5)
    editBtn:Hide()
    editBtn:SetScript("OnClick", function(self)
        local parent = self:GetParent()
        if parent.setID then
            local setName, setIcon = C_EquipmentSet.GetEquipmentSetInfo(parent.setID)
            StaticPopup_Show("MCU_RENAME_EQUIPMENT_SET", nil, nil,
                { setID = parent.setID, name = setName, icon = setIcon })
        end
    end)
    btn.editBtn = editBtn

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.07)

    btn:SetScript("OnEnter", function(self)
        if self.setID then
            self.delBtn:Show()
            self.editBtn:Show()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetEquipmentSet(self.setID)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        self.delBtn:Hide()
        self.editBtn:Hide()
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", function(self)
        if self.setID then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            selectedSetID = self.setID
            ns:UpdateEquipmentSets()
        elseif self.isNewSetBtn then
            local headTex = GetInventoryItemTexture("player", 1)
                         or GetInventoryItemTexture("player", 5)
            ns._pendingSetIcon = headTex or 132762
            StaticPopup_Show("MCU_NEW_EQUIPMENT_SET")
        end
    end)

    btn:SetScript("OnDoubleClick", function(self)
        if self.setID then
            EquipmentManager_EquipSet(self.setID)
        end
    end)

    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        if self.setID then
            C_EquipmentSet.PickupEquipmentSet(self.setID)
        end
    end)

    return btn
end

local function SortSetIDs(ids)
    table.sort(ids, function(a, b)
        local specA = C_EquipmentSet.GetEquipmentSetAssignedSpec(a)
        local specB = C_EquipmentSet.GetEquipmentSetAssignedSpec(b)
        if specA and not specB then return true end
        if not specA and specB then return false end
        local nameA = select(1, C_EquipmentSet.GetEquipmentSetInfo(a)) or ""
        local nameB = select(1, C_EquipmentSet.GetEquipmentSetInfo(b)) or ""
        return nameA < nameB
    end)
    return ids
end

function ns:UpdateEquipmentSets()
    local setIDs = SortSetIDs(C_EquipmentSet.GetEquipmentSetIDs())

    for _, btn in ipairs(setButtons) do
        btn:Hide()
    end

    local y = 0
    local idx = 0

    for _, setID in ipairs(setIDs) do
        local setName, setTexture, _, isEquipped, _, _, _, numLost =
            C_EquipmentSet.GetEquipmentSetInfo(setID)

        idx = idx + 1
        local btn = setButtons[idx]
        if not btn then
            btn = CreateSetEntryButton()
            setButtons[idx] = btn
        end

        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        btn:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
        btn.setID = setID
        btn.isNewSetBtn = false

        btn.icon:SetTexture(setTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
        btn.icon:SetSize(36, 36)
        btn.icon:SetDesaturated(false)

        btn.name:SetText(setName or "")
        if numLost and numLost > 0 then
            btn.name:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
        else
            btn.name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g,
                                  NORMAL_FONT_COLOR.b)
        end

        btn.check:SetShown(isEquipped or (pendingEquipSetID == setID))

        local specIndex = C_EquipmentSet.GetEquipmentSetAssignedSpec(setID)
        if specIndex then
            local _, _, _, specTex = GetSpecializationInfo(specIndex)
            if specTex then
                btn.specIcon:SetTexture(specTex)
                btn.specIcon:Show()
            else
                btn.specIcon:Hide()
            end
        else
            btn.specIcon:Hide()
        end

        btn.selBar:SetShown(selectedSetID == setID)
        btn.stripe:SetShown(idx % 2 == 0)

        btn:Show()
        y = y + ENTRY_HEIGHT
    end

    local maxSets = MAX_EQUIPMENT_SETS_PER_PLAYER or 10
    if #setIDs < maxSets then
        idx = idx + 1
        local btn = setButtons[idx]
        if not btn then
            btn = CreateSetEntryButton()
            setButtons[idx] = btn
        end
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        btn:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
        btn.setID = nil
        btn.isNewSetBtn = true
        btn.icon:SetTexture("Interface\\PaperDollInfoFrame\\Character-Plus")
        btn.icon:SetSize(30, 30)
        btn.icon:SetDesaturated(false)
        btn.name:SetText(PAPERDOLL_NEWEQUIPMENTSET or "New Equipment Set")
        btn.name:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g,
                              GREEN_FONT_COLOR.b)
        btn.check:Hide()
        btn.specIcon:Hide()
        btn.selBar:Hide()
        btn.stripe:SetShown(idx % 2 == 0)
        btn:Show()
        y = y + ENTRY_HEIGHT
    end

    content:SetHeight(max(y, 1))

    if selectedSetID then
        local _, _, _, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(selectedSetID)
        local effectivelyEquipped = isEquipped or (pendingEquipSetID == selectedSetID)
        if isEquipped and pendingEquipSetID == selectedSetID then
            pendingEquipSetID = nil
        end
        equipBtn:SetEnabled(not effectivelyEquipped)
        saveBtn:Enable()
    else
        equipBtn:Disable()
        saveBtn:Disable()
    end
end

equipBtn:SetScript("OnClick", function()
    if selectedSetID then
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        pendingEquipSetID = selectedSetID
        EquipmentManager_EquipSet(selectedSetID)
        ns:UpdateEquipmentSets()
    end
end)

saveBtn:SetScript("OnClick", function()
    if selectedSetID then
        local setName = C_EquipmentSet.GetEquipmentSetInfo(selectedSetID)
        StaticPopup_Show("MCU_CONFIRM_SAVE_SET", setName, nil, selectedSetID)
    end
end)
