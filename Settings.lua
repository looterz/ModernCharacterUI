local addonName, ns = ...

local MCU = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
ns.aceAddon = MCU

local defaults = {
    global = {
        overrideLegacyPanel = true,
        overrideDressingRoom = true,
        overrideInspect = true,
        blockInCombat = true,
        showEnchantStatus = false,
        showUpgradeTrack = false,
        slotFontSize = 10,
        slotOverlayStyle = "gradient",
        characterScale = 100,
        inspectScale = 100,
        dressingRoomScale = 100,
        position = nil,  -- { point, relativePoint, x, y }
        dressingRoomPosition = nil,
        inspectPosition = nil,
    },
}

function MCU:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("ModernCharacterUIDB", defaults, true)
    ns.db = self.db

    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, self:GetOptions())
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(
        addonName, "Modern Character UI")

    self:RegisterChatCommand("mcu", "ChatCommand")
    self:RegisterChatCommand("moderncharacterui", "ChatCommand")
end

function MCU:OnEnable()
    self:HookCharacterPanel()
    if ns.InitDressingRoomHooks then
        ns:InitDressingRoomHooks()
    end
    if ns.InitInspectHooks then
        ns:InitInspectHooks()
    end
end

function MCU:ChatCommand(input)
    input = strlower(strtrim(input or ""))
    if input == "character" or input == "char" then
        ns:TogglePanel()
    elseif input == "dress" or input == "dressup" then
        if MCUDressingRoomFrame then
            if MCUDressingRoomFrame:IsShown() then
                MCUDressingRoomFrame:Hide()
            else
                MCUDressingRoomFrame:Show()
            end
        end
    elseif input == "mounts" or input == "mount" then
        if ns.PreviewMount then
            local defaultMountID
            for i = 1, C_MountJournal.GetNumDisplayedMounts() do
                local _, _, _, _, _, _, _, _, _, _, isCollected, mountID = C_MountJournal.GetDisplayedMountInfo(i)
                if isCollected then
                    defaultMountID = mountID
                    break
                end
            end
            if not defaultMountID then
                defaultMountID = C_MountJournal.GetDisplayedMountID(1)
            end
            if defaultMountID then
                ns:PreviewMount(defaultMountID)
            end
        end
    elseif (input == "furniture" or input == "housing" or input == "decor") then
        if ns.EnterFurnitureMode and C_HousingCatalog then
            ns:EnterFurnitureMode()
        end
    else
        LibStub("AceConfigDialog-3.0"):Open(addonName)
    end
end

function MCU:GetOptions()
    return {
        type = "group",
        name = "Modern Character UI",
        args = {
            overrideLegacyPanel = {
                order = 1,
                type = "toggle",
                name = "Override Legacy Character Panel",
                desc = "When enabled, pressing 'C' or clicking the Character "
                    .. "micro-button opens Modern Character UI instead of "
                    .. "the default character panel.",
                width = "full",
                get = function()
                    return self.db.global.overrideLegacyPanel
                end,
                set = function(_, value)
                    self.db.global.overrideLegacyPanel = value
                end,
            },
            overrideDressingRoom = {
                order = 2,
                type = "toggle",
                name = "Override Legacy Dressing Room",
                desc = "When enabled, Ctrl+clicking items opens the enhanced "
                    .. "dressing room instead of the default preview.",
                width = "full",
                get = function()
                    return self.db.global.overrideDressingRoom
                end,
                set = function(_, value)
                    self.db.global.overrideDressingRoom = value
                end,
            },
            overrideInspect = {
                order = 3,
                type = "toggle",
                name = "Override Legacy Inspect Window",
                desc = "When enabled, right-click Inspect opens the enhanced "
                    .. "inspect window instead of the default.",
                width = "full",
                get = function()
                    return self.db.global.overrideInspect
                end,
                set = function(_, value)
                    self.db.global.overrideInspect = value
                end,
            },
            blockInCombat = {
                order = 4,
                type = "toggle",
                name = "Block Opening in Combat",
                desc = "Prevents the character panel from opening while you "
                    .. "are in combat.",
                width = "full",
                get = function()
                    return self.db.global.blockInCombat
                end,
                set = function(_, value)
                    self.db.global.blockInCombat = value
                end,
            },
            overlayHeader = {
                order = 5,
                type = "header",
                name = "Slot Overlays",
            },
            showEnchantStatus = {
                order = 6,
                type = "toggle",
                name = "Show Enchant Status",
                desc = "Displays a warning indicator on equipment slots "
                    .. "that are missing an enchant.",
                width = "full",
                get = function()
                    return self.db.global.showEnchantStatus
                end,
                set = function(_, value)
                    self.db.global.showEnchantStatus = value
                    if ns.RefreshAll then ns:RefreshAll() end
                end,
            },
            showUpgradeTrack = {
                order = 7,
                type = "toggle",
                name = "Show Upgrade Track",
                desc = "Displays the upgrade progress (e.g. 2/6) on "
                    .. "equipment slots that support upgrading.",
                width = "full",
                get = function()
                    return self.db.global.showUpgradeTrack
                end,
                set = function(_, value)
                    self.db.global.showUpgradeTrack = value
                    if ns.RefreshAll then ns:RefreshAll() end
                end,
            },
            slotFontSize = {
                order = 8,
                type = "range",
                name = "Slot Overlay Font Size",
                desc = "Adjust the font size for item level, upgrade track, "
                    .. "and other text on equipment slots.",
                min = 8,
                max = 16,
                step = 1,
                width = "full",
                get = function()
                    return self.db.global.slotFontSize
                end,
                set = function(_, value)
                    self.db.global.slotFontSize = value
                    ns:ApplySlotFontSize()
                    if ns.RefreshAll then ns:RefreshAll() end
                end,
            },
            slotOverlayStyle = {
                order = 9,
                type = "select",
                name = "Overlay Readability Style",
                desc = "Choose a background style to improve readability of "
                    .. "text and icons overlaid on equipment slot icons.",
                width = "full",
                values = {
                    ["none"] = "None",
                    ["thick_outline"] = "Thick Outline",
                    ["gradient"] = "Gradient Strips",
                    ["darken"] = "Darkened Icon",
                    ["corners"] = "Corner Darkening",
                    ["shadow"] = "Drop Shadow",
                },
                sorting = { "none", "thick_outline", "gradient", "darken", "corners", "shadow" },
                get = function()
                    return self.db.global.slotOverlayStyle
                end,
                set = function(_, value)
                    self.db.global.slotOverlayStyle = value
                    ns:ApplySlotOverlayStyle()
                    ns:ApplySlotFontSize()
                    if ns.RefreshAll then ns:RefreshAll() end
                end,
            },
            scaleHeader = {
                order = 10,
                type = "header",
                name = "Window Scale",
            },
            characterScale = {
                order = 11,
                type = "range",
                name = "Character Panel Scale",
                desc = "Adjust the size of the Character Panel window.",
                min = 50,
                max = 200,
                step = 5,
                width = "full",
                get = function()
                    return self.db.global.characterScale
                end,
                set = function(_, value)
                    self.db.global.characterScale = value
                    self.db.global.position = nil
                    if ModernCharacterUIFrame then
                        ModernCharacterUIFrame:ClearAllPoints()
                        ModernCharacterUIFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -104)
                    end
                    ns:ApplyFrameScale()
                end,
            },
            inspectScale = {
                order = 12,
                type = "range",
                name = "Inspect Window Scale",
                desc = "Adjust the size of the Inspect window.",
                min = 50,
                max = 200,
                step = 5,
                width = "full",
                get = function()
                    return self.db.global.inspectScale
                end,
                set = function(_, value)
                    self.db.global.inspectScale = value
                    self.db.global.inspectPosition = nil
                    if MCUInspectFrame then
                        MCUInspectFrame:ClearAllPoints()
                        MCUInspectFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -124)
                    end
                    ns:ApplyFrameScale()
                end,
            },
            dressingRoomScale = {
                order = 13,
                type = "range",
                name = "Dressing Room Scale",
                desc = "Adjust the size of the Dressing Room window.",
                min = 50,
                max = 200,
                step = 5,
                width = "full",
                get = function()
                    return self.db.global.dressingRoomScale
                end,
                set = function(_, value)
                    self.db.global.dressingRoomScale = value
                    self.db.global.dressingRoomPosition = nil
                    if MCUDressingRoomFrame then
                        MCUDressingRoomFrame:ClearAllPoints()
                        MCUDressingRoomFrame:SetPoint("TOP", UIParent, "TOP", 0, -41)
                    end
                    ns:ApplyFrameScale()
                end,
            },
        },
    }
end

function MCU:HookCharacterPanel()
    -- Replace ToggleCharacter entirely so we intercept BEFORE the
    -- secure CharacterFrame ever opens.  This avoids all taint because
    -- we never call :Hide() on a secure frame, we simply prevent it
    -- from showing in the first place.
    local originalToggleCharacter = ToggleCharacter
    ToggleCharacter = function(tab, ...)
        if MCU.db.global.blockInCombat and InCombatLockdown() then
            MCU:Print("Character panel blocked while in combat.")
            return
        end
        if MCU.db.global.overrideLegacyPanel then
            -- If the panel is already shown and something is on the cursor
            -- (e.g. enchant scroll, item use), keep it open so the
            -- interaction isn't interrupted.
            if ModernCharacterUIFrame and ModernCharacterUIFrame:IsShown() then
                if SpellIsTargeting() or CursorHasItem() or CursorHasSpell() then
                    return
                end
            end
            ns:TogglePanel()
            return
        end
        return originalToggleCharacter(tab, ...)
    end
end
