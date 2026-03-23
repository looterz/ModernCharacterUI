local addonName, ns = ...

local MCU = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
ns.aceAddon = MCU

local defaults = {
    global = {
        overrideLegacyPanel = true,
        overrideDressingRoom = true,
        overrideInspect = true,
        blockInCombat = true,
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
    input = strtrim(input or "")
    if input == "settings" or input == "config" then
        LibStub("AceConfigDialog-3.0"):Open(addonName)
    else
        ns:TogglePanel()
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
            ns:TogglePanel()
            return
        end
        return originalToggleCharacter(tab, ...)
    end
end
