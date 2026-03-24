local addonName, ns = ...
ns.addonName = addonName

ns.FRAME_WIDTH  = 940
ns.FRAME_HEIGHT = 700
ns.SLOT_SIZE    = 52
ns.SLOT_SPACING = 5

ns.STATS_WIDTH  = 290

ns.LEFT_SLOTS = {
    { id = 1,  name = "HeadSlot",     label = HEADSLOT      or "Head" },
    { id = 2,  name = "NeckSlot",     label = NECKSLOT      or "Neck" },
    { id = 3,  name = "ShoulderSlot", label = SHOULDERSLOT  or "Shoulders" },
    { id = 15, name = "BackSlot",     label = BACKSLOT      or "Back" },
    { id = 5,  name = "ChestSlot",    label = CHESTSLOT     or "Chest" },
    { id = 4,  name = "ShirtSlot",    label = SHIRTSLOT     or "Shirt" },
    { id = 19, name = "TabardSlot",   label = TABARDSLOT    or "Tabard" },
    { id = 9,  name = "WristSlot",    label = WRISTSLOT     or "Wrists" },
}

ns.RIGHT_SLOTS = {
    { id = 10, name = "HandsSlot",          label = HANDSSLOT    or "Hands" },
    { id = 6,  name = "WaistSlot",          label = WAISTSLOT    or "Waist" },
    { id = 7,  name = "LegsSlot",           label = LEGSSLOT     or "Legs" },
    { id = 8,  name = "FeetSlot",           label = FEETSLOT     or "Feet" },
    { id = 11, name = "Finger0Slot",        label = FINGER0SLOT  or "Ring 1" },
    { id = 12, name = "Finger1Slot",        label = FINGER1SLOT  or "Ring 2" },
    { id = 13, name = "Trinket0Slot",       label = TRINKET0SLOT or "Trinket 1" },
    { id = 14, name = "Trinket1Slot",       label = TRINKET1SLOT or "Trinket 2" },
}

ns.BOTTOM_SLOTS = {
    { id = 16, name = "MainHandSlot",       label = MAINHANDSLOT      or "Main Hand" },
    { id = 17, name = "SecondaryHandSlot",  label = SECONDARYHANDSLOT or "Off Hand" },
}

-- Fallback texture file IDs for when GetInventorySlotInfo
-- no longer returns a texture in modern WoW clients
ns.EMPTY_SLOT_TEXTURES = {
    [1]  = 136516,
    [2]  = 136519,
    [3]  = 136526,
    [4]  = 136525,
    [5]  = 136512,
    [6]  = 136529,
    [7]  = 136517,
    [8]  = 136513,
    [9]  = 136530,
    [10] = 136515,
    [11] = 136514,
    [12] = 136514,
    [13] = 136528,
    [14] = 136528,
    [15] = 136512,
    [16] = 136518,
    [17] = 136524,
    [19] = 136527,
}

--- Try the two-return form of GetInventorySlotInfo first; fall back to the
--- pre-baked file-ID table above.
function ns:GetEmptySlotTexture(slotID, slotName)
    local id, texture = GetInventorySlotInfo(slotName)
    if texture and texture ~= 0 then
        return texture
    end
    return self.EMPTY_SLOT_TEXTURES[slotID] or 136516
end

function ns:FormatPercent(value)
    return format("%.2f%%", value or 0)
end

function ns:FormatStat(value)
    if not value then return "0" end
    return BreakUpLargeNumbers(floor(value))
end

--- Return r, g, b for an item quality (0-8). Falls back to white.
function ns:GetQualityColor(quality)
    if quality then
        local r, g, b = GetItemQualityColor(quality)
        return r, g, b
    end
    return 1, 1, 1
end

--- Returns true when the player is in a PvP context where PvP item levels apply.
function ns:IsInPvPZone()
    if C_PvP then
        if C_PvP.IsPVPMap and C_PvP.IsPVPMap() then return true end
        if C_PvP.IsWarModeActive and C_PvP.IsWarModeActive() then return true end
    end
    if IsActiveBattlefieldArena and IsActiveBattlefieldArena() then return true end
    return false
end

--- Get the PvP item level for an equipped slot by scanning tooltip data.
--- Returns the PvP ilvl number, or nil if the item has no PvP ilvl.
function ns:GetPvPItemLevel(slotID)
    if not C_TooltipInfo or not C_TooltipInfo.GetInventoryItem then return nil end
    local data = C_TooltipInfo.GetInventoryItem("player", slotID)
    if not data or not data.lines then return nil end
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if text then
            -- Match the localized "PvP Item Level %d" string if available
            if PVP_ITEM_LEVEL_TOOLTIP then
                local pattern = PVP_ITEM_LEVEL_TOOLTIP:gsub("%%d", "(%%d+)")
                local pvpIlvl = text:match(pattern)
                if pvpIlvl then return tonumber(pvpIlvl) end
            end
            -- Fallback: match English "PvP Item Level 123"
            local pvpIlvl = text:match("PvP Item Level (%d+)")
            if pvpIlvl then return tonumber(pvpIlvl) end
        end
    end
    return nil
end

--- Create a filter/gear button and its dropdown panel.
--- Returns filterBtn, dropdown, and helper functions.
---   addRadio(label, isChecked, onClick)
---   addCheckbox(label, isChecked, onClick)
---   addAction(label, onClick)
---   addDivider()
---   refreshAll()   -- call after options change to update checks
local filterDropdownCount = 0
function ns:CreateFilterDropdown(parent, anchorFrame)
    filterDropdownCount = filterDropdownCount + 1
    local ddName = "ModernCharacterUIFilterDD" .. filterDropdownCount

    local filterBtn = CreateFrame("Button", nil, parent)
    filterBtn:SetSize(28, 28)
    filterBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, -2)

    local fbNormal = filterBtn:CreateTexture(nil, "ARTWORK")
    fbNormal:SetAllPoints()
    fbNormal:SetAtlas("common-button-square-gray-up")
    filterBtn:SetNormalTexture(fbNormal)

    local fbHL = filterBtn:CreateTexture(nil, "HIGHLIGHT")
    fbHL:SetAllPoints()
    fbHL:SetAtlas("common-button-square-gray-up")
    fbHL:SetAlpha(0.4)
    filterBtn:SetHighlightTexture(fbHL)

    local fbPushed = filterBtn:CreateTexture(nil, "ARTWORK")
    fbPushed:SetAllPoints()
    fbPushed:SetAtlas("common-button-square-gray-down")
    filterBtn:SetPushedTexture(fbPushed)

    local fbIcon = filterBtn:CreateTexture(nil, "OVERLAY")
    fbIcon:SetSize(14, 14)
    fbIcon:SetPoint("CENTER")
    fbIcon:SetAtlas("common-icon-settings")
    filterBtn.icon = fbIcon

    local dropdown = CreateFrame("Frame", ddName, UIParent, "BackdropTemplate")
    dropdown:SetWidth(240)
    dropdown:SetFrameStrata("DIALOG")
    dropdown:SetFrameLevel(200)
    dropdown:SetClampedToScreen(true)
    dropdown:Hide()
    dropdown:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    dropdown:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
    dropdown:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
    tinsert(UISpecialFrames, ddName)

    if ns.frame then
        ns.frame:HookScript("OnHide", function()
            dropdown:Hide()
        end)
    end

    local options = {}
    local yOffset = -8
    local refreshAll  -- forward declaration so closures below can reference it

    local function AddOption(opt)
        options[#options + 1] = opt
    end

    local function RebuildLayout()
        yOffset = -8
        for _, opt in ipairs(options) do
            if opt.frame then
                opt.frame:ClearAllPoints()
                opt.frame:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 8, yOffset)
                opt.frame:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", -8, yOffset)
                yOffset = yOffset - opt.height
            end
        end
        dropdown:SetHeight(math.abs(yOffset) + 8)
    end

    local function addRadio(label, isCheckedFn, onClick)
        local row = CreateFrame("Button", nil, dropdown)
        row:SetHeight(20)

        local check = row:CreateTexture(nil, "ARTWORK")
        check:SetSize(12, 12)
        check:SetPoint("LEFT", 2, 0)
        check:SetAtlas("common-icon-checkmark")
        row.check = check

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", 18, 0)
        text:SetPoint("RIGHT", -4, 0)
        text:SetJustifyH("LEFT")
        text:SetText(label)
        row.text = text

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)

        row:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            onClick()
            refreshAll()
        end)

        AddOption({ frame = row, height = 20, refresh = function()
            row.check:SetShown(isCheckedFn())
        end })
    end

    local function addCheckbox(label, isCheckedFn, onClick)
        local row = CreateFrame("Button", nil, dropdown)
        row:SetHeight(20)

        local check = row:CreateTexture(nil, "ARTWORK")
        check:SetSize(12, 12)
        check:SetPoint("LEFT", 2, 0)
        row.check = check

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", 18, 0)
        text:SetPoint("RIGHT", -4, 0)
        text:SetJustifyH("LEFT")
        text:SetText(label)
        row.text = text

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)

        row.isChecked = false

        row:SetScript("OnClick", function(self)
            self.isChecked = not self.isChecked
            PlaySound(self.isChecked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
                      or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            onClick(self.isChecked)
            refreshAll()
        end)

        AddOption({ frame = row, height = 20, refresh = function()
            row.isChecked = isCheckedFn()
            if row.isChecked then
                check:SetAtlas("common-icon-checkmark")
                check:Show()
            else
                check:Hide()
            end
        end })
    end

    local function addAction(label, onClick)
        local row = CreateFrame("Button", nil, dropdown)
        row:SetHeight(20)

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", 18, 0)
        text:SetPoint("RIGHT", -4, 0)
        text:SetJustifyH("LEFT")
        text:SetText(label)

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)

        row:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            onClick()
            dropdown:Hide()
        end)

        AddOption({ frame = row, height = 20 })
    end

    local function addDivider()
        local row = CreateFrame("Frame", nil, dropdown)
        row:SetHeight(10)
        local line = row:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("LEFT", 4, 0)
        line:SetPoint("RIGHT", -4, 0)
        line:SetPoint("CENTER")
        line:SetColorTexture(0.4, 0.4, 0.4, 0.4)
        AddOption({ frame = row, height = 10 })
    end

    function refreshAll()
        for _, opt in ipairs(options) do
            if opt.refresh then opt.refresh() end
        end
    end

    parent:HookScript("OnHide", function()
        dropdown:Hide()
    end)

    filterBtn:SetScript("OnClick", function(self)
        if dropdown:IsShown() then
            dropdown:Hide()
        else
            refreshAll()
            RebuildLayout()
            dropdown:ClearAllPoints()
            dropdown:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -2)
            dropdown:Show()
        end
    end)

    return filterBtn, dropdown, {
        addRadio    = addRadio,
        addCheckbox = addCheckbox,
        addAction   = addAction,
        addDivider  = addDivider,
        refresh     = refreshAll,
    }
end

