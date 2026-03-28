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
        roundedIcons = false,
        slotFontSize = 10,
        slotOverlayStyle = "gradient",
        statsFontSize = 14,
        statsHeaderFontSize = 16,
        repFontSize = 16,
        repHeaderFontSize = 20,
        currencyFontSize = 16,
        currencyHeaderFontSize = 20,
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
    elseif (input == "pets" or input == "pet") then
        if ns.EnterPetMode then
            ns:EnterPetMode()
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
    local order = 0
    local function O() order = order + 1; return order end

    return {
        type = "group",
        name = "Modern Character UI",
        args = {
            -- General
            generalHeader = { order = O(), type = "header", name = "General" },
            overrideLegacyPanel = {
                order = O(), type = "toggle", width = "full",
                name = "Override Legacy Character Panel",
                desc = "Replace the default character panel with Modern Character UI.",
                get = function() return self.db.global.overrideLegacyPanel end,
                set = function(_, v) self.db.global.overrideLegacyPanel = v; MCU:Print("Please type /reload for this change to take effect.") end,
            },
            overrideDressingRoom = {
                order = O(), type = "toggle", width = "full",
                name = "Override Legacy Dressing Room",
                desc = "Replace the default item preview with the enhanced dressing room.",
                get = function() return self.db.global.overrideDressingRoom end,
                set = function(_, v) self.db.global.overrideDressingRoom = v end,
            },
            overrideInspect = {
                order = O(), type = "toggle", width = "full",
                name = "Override Legacy Inspect Window",
                desc = "Replace the default inspect window with the enhanced version.",
                get = function() return self.db.global.overrideInspect end,
                set = function(_, v) self.db.global.overrideInspect = v end,
            },
            blockInCombat = {
                order = O(), type = "toggle", width = "full",
                name = "Block Opening in Combat",
                desc = "Prevents the character panel from opening during combat.",
                get = function() return self.db.global.blockInCombat end,
                set = function(_, v) self.db.global.blockInCombat = v end,
            },

            -- Character Panel
            charHeader = { order = O(), type = "header", name = "Character Panel" },
            statsFontSize = {
                order = O(), type = "range", width = "full",
                name = "Stats Font Size", desc = "Font size for stat labels and values.",
                min = 8, max = 18, step = 1,
                get = function() return self.db.global.statsFontSize end,
                set = function(_, v) self.db.global.statsFontSize = v; ns:ApplyStatsFontSize() end,
            },
            statsHeaderFontSize = {
                order = O(), type = "range", width = "full",
                name = "Stats Header Font Size", desc = "Font size for section headers (Attributes, Enhancements, etc.).",
                min = 8, max = 20, step = 1,
                get = function() return self.db.global.statsHeaderFontSize end,
                set = function(_, v) self.db.global.statsHeaderFontSize = v; ns:ApplyStatsFontSize() end,
            },
            characterScale = {
                order = O(), type = "range", width = "full",
                name = "Window Scale", desc = "Scale the Character Panel window size.",
                min = 50, max = 200, step = 5,
                get = function() return self.db.global.characterScale end,
                set = function(_, v)
                    self.db.global.characterScale = v; self.db.global.position = nil
                    if ModernCharacterUIFrame then ModernCharacterUIFrame:ClearAllPoints(); ModernCharacterUIFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -104) end
                    ns:ApplyFrameScale()
                end,
            },

            -- Reputation Tab
            repHeader = { order = O(), type = "header", name = "Reputation Tab" },
            repFontSize = {
                order = O(), type = "range", width = "full",
                name = "Font Size", desc = "Font size for faction names, standing, and bar text.",
                min = 8, max = 18, step = 1,
                get = function() return self.db.global.repFontSize end,
                set = function(_, v) self.db.global.repFontSize = v; ns:ApplyRepFontSize(); if ns.UpdateReputation then ns:UpdateReputation() end end,
            },
            repHeaderFontSize = {
                order = O(), type = "range", width = "full",
                name = "Category Font Size", desc = "Font size for reputation category headers.",
                min = 8, max = 24, step = 1,
                get = function() return self.db.global.repHeaderFontSize end,
                set = function(_, v) self.db.global.repHeaderFontSize = v; ns:ApplyRepFontSize(); if ns.UpdateReputation then ns:UpdateReputation() end end,
            },

            -- Currency Tab
            currHeader = { order = O(), type = "header", name = "Currency Tab" },
            currencyFontSize = {
                order = O(), type = "range", width = "full",
                name = "Font Size", desc = "Font size for currency names and quantities.",
                min = 8, max = 18, step = 1,
                get = function() return self.db.global.currencyFontSize end,
                set = function(_, v) self.db.global.currencyFontSize = v; ns:ApplyCurrencyFontSize(); if ns.UpdateCurrency then ns:UpdateCurrency() end end,
            },
            currencyHeaderFontSize = {
                order = O(), type = "range", width = "full",
                name = "Category Font Size", desc = "Font size for currency category headers.",
                min = 8, max = 24, step = 1,
                get = function() return self.db.global.currencyHeaderFontSize end,
                set = function(_, v) self.db.global.currencyHeaderFontSize = v; ns:ApplyCurrencyFontSize(); if ns.UpdateCurrency then ns:UpdateCurrency() end end,
            },

            -- Equipment Slots
            slotsHeader = { order = O(), type = "header", name = "Equipment Slots" },
            showEnchantStatus = {
                order = O(), type = "toggle", width = "full",
                name = "Show Enchant Status",
                desc = "Displays an indicator on enchanted equipment slots.",
                get = function() return self.db.global.showEnchantStatus end,
                set = function(_, v) self.db.global.showEnchantStatus = v; if ns.RefreshAll then ns:RefreshAll() end end,
            },
            showUpgradeTrack = {
                order = O(), type = "toggle", width = "full",
                name = "Show Upgrade Track",
                desc = "Displays upgrade progress (e.g. 2/6) on equipment slots.",
                get = function() return self.db.global.showUpgradeTrack end,
                set = function(_, v) self.db.global.showUpgradeTrack = v; if ns.RefreshAll then ns:RefreshAll() end end,
            },
            roundedIcons = {
                order = O(), type = "toggle", width = "full",
                name = "Rounded Equipment Icons",
                desc = "Applies rounded corners to equipment slot icons.",
                get = function() return self.db.global.roundedIcons end,
                set = function(_, v) self.db.global.roundedIcons = v; if ns.ApplyIconStyle then ns:ApplyIconStyle() end end,
            },
            slotOverlayStyle = {
                order = O(), type = "select", width = "full",
                name = "Overlay Readability Style",
                desc = "Background style to improve readability of slot overlay text.",
                values = { ["none"] = "None", ["thick_outline"] = "Thick Outline", ["gradient"] = "Gradient Strips", ["darken"] = "Darkened Icon", ["corners"] = "Corner Darkening", ["shadow"] = "Drop Shadow" },
                sorting = { "none", "thick_outline", "gradient", "darken", "corners", "shadow" },
                get = function() return self.db.global.slotOverlayStyle end,
                set = function(_, v) self.db.global.slotOverlayStyle = v; ns:ApplySlotOverlayStyle(); ns:ApplySlotFontSize(); if ns.RefreshAll then ns:RefreshAll() end end,
            },
            slotFontSize = {
                order = O(), type = "range", width = "full",
                name = "Slot Overlay Font Size", desc = "Font size for item level, upgrade track, and other slot text.",
                min = 8, max = 16, step = 1,
                get = function() return self.db.global.slotFontSize end,
                set = function(_, v) self.db.global.slotFontSize = v; ns:ApplySlotFontSize(); if ns.RefreshAll then ns:RefreshAll() end end,
            },

            -- Dressing Room
            drHeader = { order = O(), type = "header", name = "Dressing Room" },
            dressingRoomScale = {
                order = O(), type = "range", width = "full",
                name = "Window Scale", desc = "Scale the Dressing Room window size.",
                min = 50, max = 200, step = 5,
                get = function() return self.db.global.dressingRoomScale end,
                set = function(_, v)
                    self.db.global.dressingRoomScale = v; self.db.global.dressingRoomPosition = nil
                    if MCUDressingRoomFrame then MCUDressingRoomFrame:ClearAllPoints(); MCUDressingRoomFrame:SetPoint("TOP", UIParent, "TOP", 0, -41) end
                    ns:ApplyFrameScale()
                end,
            },

            -- Inspect Window
            inspHeader = { order = O(), type = "header", name = "Inspect Window" },
            inspectScale = {
                order = O(), type = "range", width = "full",
                name = "Window Scale", desc = "Scale the Inspect Window size.",
                min = 50, max = 200, step = 5,
                get = function() return self.db.global.inspectScale end,
                set = function(_, v)
                    self.db.global.inspectScale = v; self.db.global.inspectPosition = nil
                    if MCUInspectFrame then MCUInspectFrame:ClearAllPoints(); MCUInspectFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -124) end
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
