local addonName, ns = ...

local container = ns.statsContainer

local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 0, 0)
scrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)
scrollFrame.ScrollBar:Hide()
scrollFrame.ScrollBar:SetScript("OnShow", scrollFrame.ScrollBar.Hide)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetWidth(scrollFrame:GetWidth() or 270)
scrollFrame:SetScrollChild(content)

container:SetScript("OnSizeChanged", function(self)
    local w = self:GetWidth()
    content:SetWidth(w > 0 and w or 270)
end)

local yOffset = -8

local function NextY(height)
    local y = yOffset
    yOffset = yOffset - height
    return y
end

ns.statHeaderFontStrings = {}

local function CreateSectionHeader(text)
    NextY(6)
    local headerFontSize = (ns.db and ns.db.global and ns.db.global.statsHeaderFontSize) or 13
    local labelY = NextY(16)
    local label = content:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT, headerFontSize, "")
    label:SetPoint("TOP", content, "TOP", 0, labelY)
    label:SetText(text)
    label:SetTextColor(1, 0.82, 0, 1)
    table.insert(ns.statHeaderFontStrings, label)

    local lineY = NextY(8)
    local line = content:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", content, "TOPLEFT", 4, lineY)
    line:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, lineY)
    line:SetColorTexture(0.45, 0.40, 0.25, 0.4)

    NextY(4)
    return label
end

--- Create a stat row: left-aligned label, right-aligned value.
--- Returns a table { label, value, frame } so the value can be updated.
ns.statFontStrings = ns.statFontStrings or {}

local function CreateStatLine(labelText, tooltipText)
    local ROW_HEIGHT = 20
    local y = NextY(ROW_HEIGHT)
    local fontSize = (ns.db and ns.db.global and ns.db.global.statsFontSize) or 12

    local row = CreateFrame("Frame", nil, content)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
    row:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, y)

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT, fontSize, "")
    label:SetPoint("LEFT", 4, 0)
    label:SetText(labelText)
    label:SetTextColor(0.8, 0.8, 0.8, 1)

    local value = row:CreateFontString(nil, "OVERLAY")
    value:SetFont(STANDARD_TEXT_FONT, fontSize, "")
    value:SetPoint("RIGHT", -4, 0)
    value:SetTextColor(1, 1, 1, 1)

    table.insert(ns.statFontStrings, { label = label, value = value })

    if tooltipText then
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(labelText, 1, 0.82, 0)
            GameTooltip:AddLine(tooltipText, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    return { label = label, value = value, frame = row }
end

local nameBtn = CreateFrame("Button", nil, content)
nameBtn:SetHeight(22)
nameBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 4, NextY(22))
nameBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, 0)

local charName = nameBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
charName:SetPoint("LEFT", 14, 0)
charName:SetPoint("RIGHT", -14, 0)
charName:SetJustifyH("CENTER")
charName:SetWordWrap(false)
charName:SetTextColor(1, 0.82, 0, 1)

if charName.SetMaxLines then charName:SetMaxLines(1) end

local nameArrow = nameBtn:CreateTexture(nil, "OVERLAY")
nameArrow:SetSize(8, 8)
nameArrow:SetPoint("RIGHT", nameBtn, "RIGHT", -2, 0)
nameArrow:SetAtlas("common-dropdown-icon-open")
nameArrow:SetAlpha(0)

local nameHL = nameBtn:CreateTexture(nil, "HIGHLIGHT")
nameHL:SetHeight(1)
nameHL:SetPoint("BOTTOMLEFT", nameBtn, "BOTTOMLEFT", 4, 0)
nameHL:SetPoint("BOTTOMRIGHT", nameBtn, "BOTTOMRIGHT", -4, 0)
nameHL:SetColorTexture(1, 0.82, 0, 0.5)

nameBtn:SetScript("OnEnter", function(self)
    nameArrow:SetAlpha(1)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Click to change title", NORMAL_FONT_COLOR.r,
                        NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    GameTooltip:Show()
end)
nameBtn:SetScript("OnLeave", function(self)
    nameArrow:SetAlpha(0)
    GameTooltip:Hide()
end)

local charSubtitle = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
charSubtitle:SetPoint("TOP", content, "TOP", 0, NextY(16))
NextY(4)

local ilvlFrame = CreateFrame("Frame", nil, content)
local ilvlFrameY = NextY(26)
ilvlFrame:SetHeight(26)
ilvlFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 4, ilvlFrameY)
ilvlFrame:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, ilvlFrameY)
ilvlFrame:EnableMouse(true)

local ilvlValue = ilvlFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge2")
ilvlValue:SetPoint("CENTER", 0, 4)
ilvlValue:SetTextColor(1, 0.82, 0, 1)

local ilvlPvPLabel = ilvlFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
ilvlPvPLabel:SetPoint("TOP", ilvlValue, "BOTTOM", 0, -1)
ilvlPvPLabel:SetText("PvP")
ilvlPvPLabel:SetTextColor(0.0, 1.0, 0.0, 1)
ilvlPvPLabel:Hide()

ilvlFrame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

    local avgItemLevel, avgItemLevelEquipped, avgItemLevelPvP = GetAverageItemLevel()
    avgItemLevel        = avgItemLevel or 0
    avgItemLevelEquipped = avgItemLevelEquipped or 0
    avgItemLevelPvP     = avgItemLevelPvP or 0

    local header = format("%s %d", STAT_AVERAGE_ITEM_LEVEL or "Item Level",
                          floor(avgItemLevelEquipped))
    if floor(avgItemLevel) ~= floor(avgItemLevelEquipped) then
        header = header .. "  " .. format(
            STAT_AVERAGE_ITEM_LEVEL_EQUIPPED or "(Equipped: %d)",
            floor(avgItemLevelEquipped))
    end
    GameTooltip:SetText(header, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g,
                        HIGHLIGHT_FONT_COLOR.b)

    local body = STAT_AVERAGE_ITEM_LEVEL_TOOLTIP
              or "Calculated from the item levels of all your equipped gear."

    if floor(avgItemLevelPvP) ~= floor(avgItemLevelEquipped) then
        local pvpLine = (STAT_AVERAGE_PVP_ITEM_LEVEL or "PvP Item Level: %d")
        body = body .. "\n\n" .. format(pvpLine, floor(avgItemLevelPvP))
    end

    GameTooltip:AddLine(body, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g,
                        NORMAL_FONT_COLOR.b, true)
    GameTooltip:Show()
end)

ilvlFrame:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

NextY(4)

local titleDropdown = CreateFrame("Frame", "ModernCharacterUITitleDropdown",
                                  UIParent, "BackdropTemplate")
titleDropdown:SetSize(270, 320)
titleDropdown:SetFrameStrata("DIALOG")
titleDropdown:SetFrameLevel(200)
titleDropdown:SetClampedToScreen(true)
titleDropdown:Hide()
titleDropdown:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
titleDropdown:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
titleDropdown:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
tinsert(UISpecialFrames, "ModernCharacterUITitleDropdown")
ns.frame:HookScript("OnHide", function()
    titleDropdown:Hide()
end)

local dropScroll = CreateFrame("ScrollFrame", nil, titleDropdown,
                               "UIPanelScrollFrameTemplate")
dropScroll:SetPoint("TOPLEFT", 6, -6)
dropScroll:SetPoint("BOTTOMRIGHT", -26, 6)

local dropContent = CreateFrame("Frame", nil, dropScroll)
dropContent:SetWidth(230)
dropScroll:SetScrollChild(dropContent)

local titleButtons = {}

local function CreateTitleEntryButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(20)
    btn:SetPoint("LEFT")
    btn:SetPoint("RIGHT")

    local stripe = btn:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints()
    stripe:SetColorTexture(1, 1, 1, 0.04)
    stripe:Hide()
    btn.stripe = stripe

    local check = btn:CreateTexture(nil, "ARTWORK")
    check:SetSize(14, 14)
    check:SetPoint("LEFT", 4, 0)
    check:SetAtlas("common-icon-checkmark")
    check:Hide()
    btn.check = check

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", 22, 0)
    text:SetPoint("RIGHT", -4, 0)
    text:SetJustifyH("LEFT")
    btn.text = text

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.1)

    btn:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        SetCurrentTitle(self.titleId)
        titleDropdown:Hide()
    end)

    return btn
end

local function GetSortedTitles()
    local titles = {}
    -- Leading spaces ensure "No Title" sorts first
    titles[1] = { name = "       ", id = -1 }
    for i = 1, GetNumTitles() do
        if IsTitleKnown(i) then
            local tempName = GetTitleName(i)
            if tempName then
                titles[#titles + 1] = { name = strtrim(tempName), id = i }
            end
        end
    end
    table.sort(titles, function(a, b) return a.name < b.name end)
    titles[1].name = PLAYER_TITLE_NONE or "No Title"
    return titles
end

function ns:UpdateTitleDropdown()
    if titleDropdown:IsShown() then
        ns:PopulateTitleList()
    end
end

function ns:PopulateTitleList()
    local titles = GetSortedTitles()
    local currentTitle = GetCurrentTitle() or -1

    for _, btn in ipairs(titleButtons) do
        btn:Hide()
    end

    local y = 0
    for i, entry in ipairs(titles) do
        local btn = titleButtons[i]
        if not btn then
            btn = CreateTitleEntryButton(dropContent)
            titleButtons[i] = btn
        end
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", dropContent, "TOPLEFT", 0, -y)
        btn:SetPoint("TOPRIGHT", dropContent, "TOPRIGHT", 0, -y)
        btn.text:SetText(entry.name)
        btn.titleId = entry.id

        local isSelected
        if entry.id == -1 then
            isSelected = (currentTitle <= 0)
        else
            isSelected = (currentTitle == entry.id)
        end
        btn.check:SetShown(isSelected)

        btn.stripe:SetShown(i % 2 == 0)

        btn:Show()
        y = y + 20
    end

    dropContent:SetHeight(max(y, 1))
end

nameBtn:SetScript("OnClick", function(self)
    if titleDropdown:IsShown() then
        titleDropdown:Hide()
    else
        ns:PopulateTitleList()
        titleDropdown:ClearAllPoints()
        titleDropdown:SetPoint("TOP", self, "BOTTOM", 0, -2)
        titleDropdown:Show()
    end
end)

NextY(16)
CreateSectionHeader(STAT_CATEGORY_GENERAL or "General")

local statLines = {}

statLines.health = CreateStatLine(HEALTH or "Health", nil)
statLines.power = CreateStatLine(MANA or "Power", nil)
statLines.movespeed = CreateStatLine(STAT_MOVEMENT_SPEED or "Movement Speed", nil)
statLines.movespeed.frame:EnableMouse(true)
statLines.movespeed.frame:SetScript("OnEnter", function(self)
    local _, runSpeed, flightSpeed, swimSpeed = GetUnitSpeed("player")
    local base = 7
    local runPct = (runSpeed / base) * 100
    local flyPct = (flightSpeed / base) * 100
    local swimPct = (swimSpeed / base) * 100
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(STAT_MOVEMENT_SPEED or "Movement Speed", 1, 0.82, 0)
    GameTooltip:AddLine(format("Run Speed: %.0f%%", runPct), 1, 1, 1)
    GameTooltip:AddLine(format("Flight Speed: %.0f%%", flyPct), 1, 1, 1)
    GameTooltip:AddLine(format("Swim Speed: %.0f%%", swimPct), 1, 1, 1)
    GameTooltip:Show()
end)
statLines.movespeed.frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

function ns:UpdateMovementSpeed()
    local currentSpeed, runSpeed, flightSpeed, swimSpeed = GetUnitSpeed("player")
    local baseSpeed = 7
    -- Use actual speed when moving (accounts for swimming/flying context),
    -- fall back to run speed when standing still
    local speed = currentSpeed > 0 and currentSpeed or runSpeed
    local speedPct = (speed / baseSpeed) * 100
    statLines.movespeed.value:SetText(format("%.0f%%", speedPct))
    statLines.movespeed.label:SetTextColor(0.9, 0.9, 0.9, 1)
    statLines.movespeed.value:SetTextColor(0.9, 0.9, 0.9, 1)
end

-- Poll movement speed every second while the character panel is open
local speedElapsed = 0
container:HookScript("OnUpdate", function(self, elapsed)
    speedElapsed = speedElapsed + elapsed
    if speedElapsed >= 1 then
        speedElapsed = 0
        ns:UpdateMovementSpeed()
    end
end)

CreateSectionHeader(STAT_CATEGORY_ATTRIBUTES or "Attributes")

statLines.strength  = CreateStatLine(SPELL_STAT1_NAME  or "Strength", nil)
statLines.agility   = CreateStatLine(SPELL_STAT2_NAME  or "Agility", nil)
statLines.intellect = CreateStatLine(SPELL_STAT4_NAME  or "Intellect", nil)
statLines.stamina   = CreateStatLine(SPELL_STAT3_NAME  or "Stamina", nil)
statLines.armor     = CreateStatLine(ARMOR              or "Armor", nil)

CreateSectionHeader(STAT_CATEGORY_ENHANCEMENTS or "Enhancements")

statLines.crit = CreateStatLine(STAT_CRITICAL_STRIKE or "Critical Strike", nil)
statLines.haste = CreateStatLine(STAT_HASTE or "Haste", nil)
statLines.mastery = CreateStatLine(STAT_MASTERY or "Mastery", nil)
statLines.versatility = CreateStatLine(STAT_VERSATILITY or "Versatility", nil)

CreateSectionHeader("Tertiary")

statLines.lifesteal = CreateStatLine(STAT_LIFESTEAL or "Lifesteal", nil)
statLines.avoidance = CreateStatLine(STAT_AVOIDANCE or "Avoidance", nil)
statLines.speed = CreateStatLine(STAT_SPEED or "Speed", nil)

CreateSectionHeader(STAT_CATEGORY_DEFENSE or "Defense")

statLines.dodge = CreateStatLine(STAT_DODGE or "Dodge", nil)
statLines.parry = CreateStatLine(STAT_PARRY or "Parry", nil)
statLines.block = CreateStatLine(STAT_BLOCK or "Block", nil)

content:SetHeight(math.abs(yOffset) + 10)

---------------------------------------------------------------------------
-- Dynamic stat tooltips (matching Blizzard's character panel detail level)
---------------------------------------------------------------------------
local function SetDynamicTooltip(statLine, onEnterFunc)
    statLine.frame:EnableMouse(true)
    statLine.frame:SetScript("OnEnter", onEnterFunc)
    statLine.frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function AddRatingLine(rating, bonus, template)
    if template then
        GameTooltip:AddLine(format(template, BreakUpLargeNumbers(rating), bonus),
            NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
    end
end

-- Health
SetDynamicTooltip(statLines.health, function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(format("%s %s", HEALTH or "Health", BreakUpLargeNumbers(UnitHealthMax("player"))), 1, 0.82, 0)
    GameTooltip:AddLine(STAT_HEALTH_TOOLTIP or "Your maximum health pool.", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
    GameTooltip:Show()
end)

-- Power
SetDynamicTooltip(statLines.power, function(self)
    local powerType, powerToken = UnitPowerType("player")
    local maxPower = UnitPowerMax("player")
    local powerName = _G[powerToken] or MANA or "Power"
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(format("%s %s", powerName, BreakUpLargeNumbers(maxPower)), 1, 0.82, 0)
    local tooltipKey = "STAT_" .. powerToken .. "_TOOLTIP"
    local tooltipText = _G[tooltipKey] or "Your primary resource."
    GameTooltip:AddLine(tooltipText, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
    GameTooltip:Show()
end)

-- Strength
SetDynamicTooltip(statLines.strength, function(self)
    local base, effectiveStat, posBuff, negBuff = UnitStat("player", 1)
    local attackPower = effectiveStat
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(format("%s %s", SPELL_STAT1_NAME, BreakUpLargeNumbers(effectiveStat)), 1, 0.82, 0)
    GameTooltip:AddLine(format("Attack Power: %s", BreakUpLargeNumbers(attackPower)), 1, 1, 1, true)
    if posBuff > 0 or negBuff < 0 then
        local buffs = ""
        if posBuff > 0 then buffs = GREEN_FONT_COLOR_CODE .. "+" .. BreakUpLargeNumbers(posBuff) .. FONT_COLOR_CODE_CLOSE end
        if negBuff < 0 then buffs = buffs .. " " .. RED_FONT_COLOR_CODE .. BreakUpLargeNumbers(negBuff) .. FONT_COLOR_CODE_CLOSE end
        GameTooltip:AddLine(format("Base: %s %s", BreakUpLargeNumbers(base), buffs), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    end
    GameTooltip:Show()
end)

-- Agility
SetDynamicTooltip(statLines.agility, function(self)
    local base, effectiveStat, posBuff, negBuff = UnitStat("player", 2)
    local attackPower = effectiveStat
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(format("%s %s", SPELL_STAT2_NAME, BreakUpLargeNumbers(effectiveStat)), 1, 0.82, 0)
    GameTooltip:AddLine(format("Attack Power: %s", BreakUpLargeNumbers(attackPower)), 1, 1, 1, true)
    if posBuff > 0 or negBuff < 0 then
        local buffs = ""
        if posBuff > 0 then buffs = GREEN_FONT_COLOR_CODE .. "+" .. BreakUpLargeNumbers(posBuff) .. FONT_COLOR_CODE_CLOSE end
        if negBuff < 0 then buffs = buffs .. " " .. RED_FONT_COLOR_CODE .. BreakUpLargeNumbers(negBuff) .. FONT_COLOR_CODE_CLOSE end
        GameTooltip:AddLine(format("Base: %s %s", BreakUpLargeNumbers(base), buffs), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    end
    GameTooltip:Show()
end)

-- Intellect
SetDynamicTooltip(statLines.intellect, function(self)
    local base, effectiveStat, posBuff, negBuff = UnitStat("player", 4)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(format("%s %s", SPELL_STAT4_NAME, BreakUpLargeNumbers(effectiveStat)), 1, 0.82, 0)
    GameTooltip:AddLine(format("Spell Power: %s", BreakUpLargeNumbers(effectiveStat)), 1, 1, 1, true)
    if posBuff > 0 or negBuff < 0 then
        local buffs = ""
        if posBuff > 0 then buffs = GREEN_FONT_COLOR_CODE .. "+" .. BreakUpLargeNumbers(posBuff) .. FONT_COLOR_CODE_CLOSE end
        if negBuff < 0 then buffs = buffs .. " " .. RED_FONT_COLOR_CODE .. BreakUpLargeNumbers(negBuff) .. FONT_COLOR_CODE_CLOSE end
        GameTooltip:AddLine(format("Base: %s %s", BreakUpLargeNumbers(base), buffs), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    end
    GameTooltip:Show()
end)

-- Stamina
SetDynamicTooltip(statLines.stamina, function(self)
    local base, effectiveStat, posBuff, negBuff = UnitStat("player", 3)
    local healthFromStam = effectiveStat * (UnitHPPerStamina and UnitHPPerStamina("player") or 20)
    if GetUnitMaxHealthModifier then healthFromStam = healthFromStam * GetUnitMaxHealthModifier("player") end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(format("%s %s", SPELL_STAT3_NAME, BreakUpLargeNumbers(effectiveStat)), 1, 0.82, 0)
    GameTooltip:AddLine(format("Health from Stamina: %s", BreakUpLargeNumbers(healthFromStam)), 1, 1, 1, true)
    if posBuff > 0 or negBuff < 0 then
        local buffs = ""
        if posBuff > 0 then buffs = GREEN_FONT_COLOR_CODE .. "+" .. BreakUpLargeNumbers(posBuff) .. FONT_COLOR_CODE_CLOSE end
        if negBuff < 0 then buffs = buffs .. " " .. RED_FONT_COLOR_CODE .. BreakUpLargeNumbers(negBuff) .. FONT_COLOR_CODE_CLOSE end
        GameTooltip:AddLine(format("Base: %s %s", BreakUpLargeNumbers(base), buffs), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    end
    GameTooltip:Show()
end)

-- Armor
SetDynamicTooltip(statLines.armor, function(self)
    local _, effectiveArmor = UnitArmor("player")
    local armorReduction = PaperDollFrame_GetArmorReduction(effectiveArmor, UnitEffectiveLevel("player"))
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(format("%s %s", ARMOR, BreakUpLargeNumbers(effectiveArmor)), 1, 0.82, 0)
    GameTooltip:AddLine(format(STAT_ARMOR_TOOLTIP or "Reduces physical damage taken from level %d enemies by %s%%.",
        UnitEffectiveLevel("player"), format("%.2f", armorReduction)), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
    if PaperDollFrame_GetArmorReductionAgainstTarget then
        local armorVsTarget = PaperDollFrame_GetArmorReductionAgainstTarget(effectiveArmor)
        if armorVsTarget then
            GameTooltip:AddLine(format(STAT_ARMOR_TARGET_TOOLTIP or "Reduces physical damage from your target by %s%%.",
                format("%.2f", armorVsTarget)), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
        end
    end
    GameTooltip:Show()
end)

-- Critical Strike
SetDynamicTooltip(statLines.crit, function(self)
    local critRating = GetCombatRating(CR_CRIT_SPELL)
    local critBonus = GetCombatRatingBonus(CR_CRIT_SPELL)
    local critChance = max(GetSpellCritChance(), GetRangedCritChance(), GetCritChance())
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(format("%s %.2f%%", STAT_CRITICAL_STRIKE, critChance), 1, 0.82, 0)
    GameTooltip:AddLine("Chance for attacks and healing to be significantly more effective.", 1, 1, 1, true)
    GameTooltip:AddLine(format("Rating: %s (+%.2f%%)", BreakUpLargeNumbers(critRating), critBonus),
        NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    GameTooltip:Show()
end)

-- Haste
SetDynamicTooltip(statLines.haste, function(self)
    local hasteRating = GetCombatRating(CR_HASTE_SPELL)
    local hasteBonus = GetCombatRatingBonus(CR_HASTE_SPELL)
    local hastePercent = UnitSpellHaste and UnitSpellHaste("player") or GetHaste()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(format("%s %.2f%%", STAT_HASTE, hastePercent), 1, 0.82, 0)
    GameTooltip:AddLine("Increases attack speed, casting speed, and some resource regeneration.", 1, 1, 1, true)
    GameTooltip:AddLine(format("Rating: %s (+%.2f%%)", BreakUpLargeNumbers(hasteRating), hasteBonus),
        NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    GameTooltip:Show()
end)

-- Mastery
SetDynamicTooltip(statLines.mastery, function(self)
    local masteryRating = GetCombatRating(CR_MASTERY)
    local masteryBonus = GetCombatRatingBonus(CR_MASTERY)
    local masteryEffect = GetMasteryEffect()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(format("%s %.2f%%", STAT_MASTERY, masteryEffect), 1, 0.82, 0)
    -- Show mastery spell description if available
    local spec = GetSpecialization()
    if spec and C_SpecializationInfo and C_SpecializationInfo.GetSpecializationMasterySpells then
        local masterySpells = C_SpecializationInfo.GetSpecializationMasterySpells(spec)
        if masterySpells then
            for _, spellID in ipairs(masterySpells) do
                local spellName = C_Spell.GetSpellName(spellID)
                local spellDesc = C_Spell.GetSpellDescription(spellID)
                if spellName then
                    GameTooltip:AddLine(spellName, 1, 1, 1)
                end
                if spellDesc then
                    GameTooltip:AddLine(spellDesc, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
                end
            end
        end
    end
    GameTooltip:AddLine(format("Rating: %s (+%.2f%%)", BreakUpLargeNumbers(masteryRating), masteryBonus),
        NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    GameTooltip:Show()
end)

-- Versatility
SetDynamicTooltip(statLines.versatility, function(self)
    local versatility = GetCombatRating(CR_VERSATILITY_DAMAGE_DONE)
    local damageBonus = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)
    local damageTakenReduction = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_TAKEN) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_TAKEN)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(format("%s %.2f%%", STAT_VERSATILITY, damageBonus), 1, 0.82, 0)
    GameTooltip:AddLine(format("Increases damage and healing by %.2f%%", damageBonus), 1, 1, 1, true)
    GameTooltip:AddLine(format("Reduces damage taken by %.2f%%", damageTakenReduction), 1, 1, 1, true)
    GameTooltip:AddLine(format("Rating: %s", BreakUpLargeNumbers(versatility)),
        NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    GameTooltip:Show()
end)

-- Lifesteal
SetDynamicTooltip(statLines.lifesteal, function(self)
    local lifesteal = GetLifesteal()
    local rating = GetCombatRating(CR_LIFESTEAL)
    local bonus = GetCombatRatingBonus(CR_LIFESTEAL)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(format("%s %.2f%%", STAT_LIFESTEAL, lifesteal), 1, 0.82, 0)
    GameTooltip:AddLine("Percentage of damage dealt that heals you.", 1, 1, 1, true)
    GameTooltip:AddLine(format("Rating: %s (+%.2f%%)", BreakUpLargeNumbers(rating), bonus),
        NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    GameTooltip:Show()
end)

-- Avoidance
SetDynamicTooltip(statLines.avoidance, function(self)
    local avoidance = GetAvoidance()
    local rating = GetCombatRating(CR_AVOIDANCE)
    local bonus = GetCombatRatingBonus(CR_AVOIDANCE)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(format("%s %.2f%%", STAT_AVOIDANCE, avoidance), 1, 0.82, 0)
    GameTooltip:AddLine("Reduces damage taken from area-of-effect attacks.", 1, 1, 1, true)
    GameTooltip:AddLine(format("Rating: %s (+%.2f%%)", BreakUpLargeNumbers(rating), bonus),
        NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    GameTooltip:Show()
end)

-- Speed
SetDynamicTooltip(statLines.speed, function(self)
    local speedBonus = GetSpeed()
    local rating = GetCombatRating(CR_SPEED)
    local bonus = GetCombatRatingBonus(CR_SPEED)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(format("%s %.2f%%", STAT_SPEED, speedBonus), 1, 0.82, 0)
    GameTooltip:AddLine("Increases movement speed from gear.", 1, 1, 1, true)
    GameTooltip:AddLine(format("Rating: %s (+%.2f%%)", BreakUpLargeNumbers(rating), bonus),
        NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    GameTooltip:Show()
end)

-- Dodge
SetDynamicTooltip(statLines.dodge, function(self)
    local dodgeChance = GetDodgeChance()
    local rating = GetCombatRating(CR_DODGE)
    local bonus = GetCombatRatingBonus(CR_DODGE)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(format("%s %.2f%%", STAT_DODGE, dodgeChance), 1, 0.82, 0)
    GameTooltip:AddLine("Chance to dodge incoming melee attacks.", 1, 1, 1, true)
    GameTooltip:AddLine(format("Rating: %s (+%.2f%%)", BreakUpLargeNumbers(rating), bonus),
        NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    GameTooltip:Show()
end)

-- Parry
SetDynamicTooltip(statLines.parry, function(self)
    local parryChance = GetParryChance()
    local rating = GetCombatRating(CR_PARRY)
    local bonus = GetCombatRatingBonus(CR_PARRY)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(format("%s %.2f%%", STAT_PARRY, parryChance), 1, 0.82, 0)
    GameTooltip:AddLine("Chance to parry incoming melee attacks.", 1, 1, 1, true)
    GameTooltip:AddLine(format("Rating: %s (+%.2f%%)", BreakUpLargeNumbers(rating), bonus),
        NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    GameTooltip:Show()
end)

-- Block
SetDynamicTooltip(statLines.block, function(self)
    local blockChance = GetBlockChance()
    local shieldBlockValue = GetShieldBlock()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(format("%s %.2f%%", STAT_BLOCK, blockChance), 1, 0.82, 0)
    GameTooltip:AddLine("Chance to block incoming attacks with a shield.", 1, 1, 1, true)
    if shieldBlockValue and shieldBlockValue > 0 then
        GameTooltip:AddLine(format("Blocks %d%% of incoming damage.", shieldBlockValue),
            NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
    end
    GameTooltip:Show()
end)


function ns:UpdateStats()
    local name = UnitPVPName("player") or UnitName("player") or ""
    charName:SetText(name)

    local level = UnitLevel("player") or 0
    local raceName = UnitRace("player") or ""
    local className, classFile = UnitClass("player")
    className = className or ""
    classFile = classFile or "WARRIOR"
    local classColor = RAID_CLASS_COLORS[classFile]
    if classColor then
        charSubtitle:SetTextColor(classColor.r, classColor.g, classColor.b)
    end

    local specName = ""
    local spec = GetSpecialization and GetSpecialization()
    if spec then
        specName = select(2, GetSpecializationInfo(spec)) or ""
    end
    if specName ~= "" then
        charSubtitle:SetText(format("Level %d %s %s", level, specName, className))
    else
        charSubtitle:SetText(format("Level %d %s", level, className))
    end

    self:UpdateTitleDropdown()

    statLines.health.value:SetText(ns:FormatStat(UnitHealthMax("player")))
    statLines.health.label:SetTextColor(0.9, 0.9, 0.9, 1)
    statLines.health.value:SetTextColor(0.9, 0.9, 0.9, 1)

    local powerType, powerToken = UnitPowerType("player")
    local powerLabel = _G[powerToken] or MANA or "Power"
    statLines.power.label:SetText(powerLabel)
    statLines.power.value:SetText(ns:FormatStat(UnitPowerMax("player")))
    statLines.power.label:SetTextColor(0.9, 0.9, 0.9, 1)
    statLines.power.value:SetTextColor(0.9, 0.9, 0.9, 1)

    ns:UpdateMovementSpeed()

    local avgItemLevel, avgItemLevelEquipped, avgItemLevelPvP = GetAverageItemLevel()
    if ns:IsInPvPZone() and avgItemLevelPvP and avgItemLevelPvP > 0
       and floor(avgItemLevelPvP) ~= floor(avgItemLevelEquipped or 0) then
        ilvlValue:SetText(format("%.1f", avgItemLevelPvP))
        ilvlValue:SetTextColor(0.0, 1.0, 0.0, 1)
        ilvlPvPLabel:Show()
    else
        ilvlValue:SetText(format("%.1f", avgItemLevelEquipped or 0))
        ilvlValue:SetTextColor(1, 0.82, 0, 1)
        ilvlPvPLabel:Hide()
    end

    local _, str = UnitStat("player", 1)
    local _, agi = UnitStat("player", 2)
    local _, sta = UnitStat("player", 3)
    local _, int = UnitStat("player", 4)

    local primaryIndex = 1
    local primaryVal = str or 0
    if (agi or 0) > primaryVal then primaryIndex = 2; primaryVal = agi end
    if (int or 0) > primaryVal then primaryIndex = 4; primaryVal = int end

    local function SetStatVal(line, val, isPrimary)
        line.value:SetText(ns:FormatStat(val))
        if isPrimary then
            line.label:SetTextColor(1, 1, 1, 1)
            line.value:SetTextColor(1, 1, 1, 1)
        else
            line.label:SetTextColor(0.6, 0.6, 0.6, 1)
            line.value:SetTextColor(0.6, 0.6, 0.6, 1)
        end
    end

    SetStatVal(statLines.strength,  str, primaryIndex == 1)
    SetStatVal(statLines.agility,   agi, primaryIndex == 2)
    SetStatVal(statLines.intellect,  int, primaryIndex == 4)

    statLines.stamina.value:SetText(ns:FormatStat(sta))
    statLines.stamina.label:SetTextColor(0.9, 0.9, 0.9, 1)
    statLines.stamina.value:SetTextColor(0.9, 0.9, 0.9, 1)

    local _, effectiveArmor = UnitArmor("player")
    statLines.armor.value:SetText(ns:FormatStat(effectiveArmor))
    statLines.armor.label:SetTextColor(0.9, 0.9, 0.9, 1)
    statLines.armor.value:SetTextColor(0.9, 0.9, 0.9, 1)

    local critChance = GetCritChance() or 0
    statLines.crit.value:SetText(ns:FormatPercent(critChance))

    local haste = GetHaste() or 0
    statLines.haste.value:SetText(ns:FormatPercent(haste))

    local mastery, masteryBonus = GetMasteryEffect()
    statLines.mastery.value:SetText(ns:FormatPercent(mastery or 0))

    local versatilityDmg = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) or 0
    local versatilityDef = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_TAKEN) or 0
    statLines.versatility.value:SetText(format("%.2f%% / %.2f%%", versatilityDmg, versatilityDef))
    statLines.versatility.value:SetTextColor(1, 1, 1, 1)

    local lifesteal = GetLifesteal() or 0
    statLines.lifesteal.value:SetText(ns:FormatPercent(lifesteal))

    local avoidance = GetAvoidance() or 0
    statLines.avoidance.value:SetText(ns:FormatPercent(avoidance))

    local speed = GetSpeed() or 0
    statLines.speed.value:SetText(ns:FormatPercent(speed))

    local dodge = GetDodgeChance() or 0
    statLines.dodge.value:SetText(ns:FormatPercent(dodge))

    local parry = GetParryChance() or 0
    statLines.parry.value:SetText(ns:FormatPercent(parry))

    local block = GetBlockChance() or 0
    statLines.block.value:SetText(ns:FormatPercent(block))
end
