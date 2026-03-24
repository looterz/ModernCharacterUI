local addonName, ns = ...

local container = ns.repContent

local BAR_COLORS = {
    [1] = { r = 0.80, g = 0.13, b = 0.13 },
    [2] = { r = 0.80, g = 0.13, b = 0.13 },
    [3] = { r = 0.93, g = 0.40, b = 0.13 },
    [4] = { r = 0.93, g = 0.80, b = 0.13 },
    [5] = { r = 0.13, g = 0.80, b = 0.13 },
    [6] = { r = 0.13, g = 0.80, b = 0.13 },
    [7] = { r = 0.13, g = 0.80, b = 0.13 },
    [8] = { r = 0.13, g = 0.80, b = 0.13 },
}

local RENOWN_COLOR  = { r = 0.24, g = 0.54, b = 1.0 }
local HEADER_HEIGHT = 26
local ENTRY_HEIGHT  = 30
local INDENT        = 20
local BAR_WIDTH     = 200

local searchBox = CreateFrame("EditBox", nil, container, "SearchBoxTemplate")
searchBox:SetSize(220, 20)
searchBox:SetPoint("TOP", container, "TOP", 6, -6)
searchBox:SetAutoFocus(false)

local searchFilter = ""
searchBox:SetScript("OnTextChanged", function(self)
    SearchBoxTemplate_OnTextChanged(self)
    local text = strtrim(self:GetText() or "")
    searchFilter = strlower(text)
    ns:UpdateReputation()
end)

local _, _, repFilterOpts = ns:CreateFilterDropdown(container, searchBox)

local playerName = UnitName("player") or ""

local SORT_NONE = Enum.ReputationSortType and Enum.ReputationSortType.None or 0
local SORT_ACCOUNT = Enum.ReputationSortType and Enum.ReputationSortType.Account or 1
local SORT_CHARACTER = Enum.ReputationSortType and Enum.ReputationSortType.Character or 2

repFilterOpts.addRadio(
    REPUTATION_SORT_TYPE_SHOW_ALL or "Show All",
    function() return C_Reputation.GetReputationSortType() == SORT_NONE end,
    function()
        C_Reputation.SetReputationSortType(SORT_NONE)
        ns:UpdateReputation()
    end)

repFilterOpts.addRadio(
    REPUTATION_SORT_TYPE_ACCOUNT or "Account-Wide",
    function() return C_Reputation.GetReputationSortType() == SORT_ACCOUNT end,
    function()
        C_Reputation.SetReputationSortType(SORT_ACCOUNT)
        ns:UpdateReputation()
    end)

repFilterOpts.addRadio(
    playerName,
    function() return C_Reputation.GetReputationSortType() == SORT_CHARACTER end,
    function()
        C_Reputation.SetReputationSortType(SORT_CHARACTER)
        ns:UpdateReputation()
    end)

repFilterOpts.addDivider()

if C_Reputation.AreLegacyReputationsShown then
    repFilterOpts.addCheckbox(
        REPUTATION_CHECKBOX_SHOW_LEGACY_REPUTATIONS or "Show Legacy Reputations",
        function() return C_Reputation.AreLegacyReputationsShown() end,
        function(checked)
            C_Reputation.SetLegacyReputationsShown(checked)
            ns:UpdateReputation()
        end)
    repFilterOpts.addDivider()
end

repFilterOpts.addAction(
    EXPAND_ALL or "Expand All",
    function()
        C_Reputation.ExpandAllFactionHeaders()
        ns:UpdateReputation()
    end)

repFilterOpts.addAction(
    COLLAPSE_ALL or "Collapse All",
    function()
        C_Reputation.CollapseAllFactionHeaders()
        ns:UpdateReputation()
    end)

--- Simple fuzzy match: every character in the query must appear in order
--- within the subject string.
local function FuzzyMatch(subject, query)
    if query == "" then return true end
    local si = 1
    for qi = 1, #query do
        local qc = query:sub(qi, qi)
        local found = subject:find(qc, si, true)
        if not found then return false end
        si = found + 1
    end
    return true
end

local scrollFrame = CreateFrame("ScrollFrame", nil, container,
                                "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 8, -34)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetWidth(scrollFrame:GetWidth() or 880)
scrollFrame:SetScrollChild(content)

container:SetScript("OnSizeChanged", function(self)
    local w = self:GetWidth() - 34
    content:SetWidth(w > 0 and w or 880)
end)

local entries = {}

local function CreateEntry()
    local entry = CreateFrame("Button", nil, content)
    entry:SetHeight(ENTRY_HEIGHT)

    local arrow = entry:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(14, 14)
    arrow:SetPoint("LEFT", 2, 0)
    arrow:Hide()
    entry.arrow = arrow

    local star = entry:CreateTexture(nil, "OVERLAY")
    star:SetSize(12, 12)
    star:SetAtlas("auctionhouse-icon-favorite")
    star:Hide()
    entry.star = star

    local name = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    entry.name = name

    local bar = CreateFrame("StatusBar", nil, entry)
    bar:SetHeight(14)
    bar:SetWidth(BAR_WIDTH)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:GetStatusBarTexture():SetHorizTile(false)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:Hide()
    entry.bar = bar

    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetColorTexture(0.08, 0.08, 0.10, 0.9)

    local barText = bar:CreateFontString(nil, "OVERLAY")
    barText:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    barText:SetPoint("CENTER")
    barText:SetTextColor(0.9, 0.9, 0.9, 1)
    entry.barText = barText

    local standing = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    standing:SetPoint("LEFT", bar, "RIGHT", 8, 0)
    standing:SetJustifyH("LEFT")
    standing:SetWidth(100)
    entry.standing = standing

    local paragonGlow = entry:CreateTexture(nil, "OVERLAY")
    paragonGlow:SetSize(16, 16)
    paragonGlow:SetPoint("RIGHT", bar, "LEFT", -4, 0)
    paragonGlow:SetAtlas("ParagonReputation_Bag")
    paragonGlow:Hide()
    entry.paragonGlow = paragonGlow

    local hl = entry:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.05)

    local stripe = entry:CreateTexture(nil, "BACKGROUND", nil, 1)
    stripe:SetAllPoints()
    stripe:SetColorTexture(1, 1, 1, 0.03)
    stripe:Hide()
    entry.stripe = stripe

    local selBar = entry:CreateTexture(nil, "BACKGROUND", nil, 2)
    selBar:SetAllPoints()
    selBar:SetColorTexture(0.35, 0.30, 0.10, 0.35)
    selBar:Hide()
    entry.selBar = selBar

    entry:SetScript("OnEnter", function(self)
        if not self.factionData then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local fd = self.factionData
        GameTooltip:SetText(fd.name, HIGHLIGHT_FONT_COLOR.r,
                            HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
        if fd.description and fd.description ~= "" then
            GameTooltip:AddLine(fd.description, NORMAL_FONT_COLOR.r,
                                NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
        end
        if self.hasParagonReward then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(QUEST_COMPLETE or "Reward available!",
                                GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g,
                                GREEN_FONT_COLOR.b)
        end
        GameTooltip:Show()
    end)

    entry:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    entry:SetScript("OnClick", function(self, button)
        local fd = self.factionData
        if not fd then return end

        if fd.isHeader and not fd.isHeaderWithRep then
            if fd.isCollapsed then
                C_Reputation.ExpandFactionHeader(fd.factionIndex)
            else
                C_Reputation.CollapseFactionHeader(fd.factionIndex)
            end
        else
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            C_Reputation.SetSelectedFaction(fd.factionIndex)
            ns:RefreshReputationDetail()
            ns:UpdateReputation()
        end
    end)

    return entry
end

local function GetFriendshipData(factionID)
    if not C_GossipInfo or not C_GossipInfo.GetFriendshipReputation then return nil end
    local info = C_GossipInfo.GetFriendshipReputation(factionID)
    if info and info.friendshipFactionID and info.friendshipFactionID > 0 then
        return info
    end
    return nil
end

local function IsMajorFaction(factionID)
    return C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(factionID)
end

function ns:UpdateReputation()
    if not container:IsShown() then return end

    for _, e in ipairs(entries) do e:Hide() end

    local numFactions = C_Reputation.GetNumFactions()
    local filtering = (searchFilter ~= "")

    -- Pre-pass: figure out which indices match the search so we can keep
    -- headers that have at least one visible child.
    local matchSet = {}
    if filtering then
        local headerStack = {}  -- indices of headers above the current entry
        for i = 1, numFactions do
            local fd = C_Reputation.GetFactionDataByIndex(i)
            if not fd then break end
            if fd.isHeader and not fd.isHeaderWithRep then
                -- Track header depth; pop deeper/equal headers from stack
                while #headerStack > 0 do
                    local prev = C_Reputation.GetFactionDataByIndex(headerStack[#headerStack])
                    if prev and not fd.isChild and prev.isChild then break end
                    if prev and fd.isChild and not prev.isChild then break end
                    table.remove(headerStack)
                end
                table.insert(headerStack, i)
            else
                if FuzzyMatch(strlower(fd.name or ""), searchFilter) then
                    matchSet[i] = true
                    -- Mark all parent headers as visible too
                    for _, hi in ipairs(headerStack) do
                        matchSet[hi] = true
                    end
                end
            end
        end
    end

    local y   = 0
    local idx = 0
    local visibleIdx = 0  -- for alternating stripes

    for i = 1, numFactions do
        local fd = C_Reputation.GetFactionDataByIndex(i)
        if not fd then break end
        fd.factionIndex = i

        -- Skip entries that don't match the search filter
        if filtering and not matchSet[i] then
            -- skip
        else -- visible entry

        local isPureHeader = fd.isHeader and not fd.isHeaderWithRep

        idx = idx + 1
        local entry = entries[idx]
        if not entry then
            entry = CreateEntry()
            entries[idx] = entry
        end

        local indent = 0
        if fd.isChild then indent = INDENT end
        if not fd.isHeader and not fd.isChild then indent = INDENT end

        local h = isPureHeader and HEADER_HEIGHT or ENTRY_HEIGHT
        entry:SetHeight(h)
        entry:ClearAllPoints()
        entry:SetPoint("TOPLEFT", content, "TOPLEFT", indent, -y)
        entry:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
        entry.factionData = fd
        entry.hasParagonReward = false

        if fd.isHeader then
            entry.arrow:Show()
            entry.arrow:SetAtlas(fd.isCollapsed
                and "campaign_headericon_closed"
                or  "campaign_headericon_open")
        else
            entry.arrow:Hide()
        end

        local nameAnchor = fd.isHeader and entry.arrow or entry
        entry.name:ClearAllPoints()
        if fd.isHeader then
            entry.name:SetPoint("LEFT", entry.arrow, "RIGHT", 4, 0)
            entry.name:SetPoint("RIGHT", entry, "RIGHT", -4, 0)
        else
            entry.name:SetPoint("LEFT", 20, 0)
            entry.name:SetPoint("RIGHT", entry.bar, "LEFT", -8, 0)
        end
        entry.name:SetText(fd.name or "")

        entry.star:SetShown(fd.isWatched and not isPureHeader)
        if fd.isWatched and not isPureHeader then
            entry.star:SetPoint("LEFT", 4, 0)
            entry.name:ClearAllPoints()
            entry.name:SetPoint("LEFT", entry.star, "RIGHT", 2, 0)
            entry.name:SetPoint("RIGHT", entry.bar, "LEFT", -8, 0)
        end

        if isPureHeader then
            entry.name:SetTextColor(1, 0.82, 0, 1)
            entry.bar:Hide()
            entry.standing:SetText("")
            entry.barText:SetText("")
            entry.paragonGlow:Hide()
            entry.stripe:Hide()
        else
            visibleIdx = visibleIdx + 1
            entry.stripe:SetShown(visibleIdx % 2 == 0)
            entry.name:SetTextColor(HIGHLIGHT_FONT_COLOR.r,
                                     HIGHLIGHT_FONT_COLOR.g,
                                     HIGHLIGHT_FONT_COLOR.b)

            local minVal, maxVal, curVal = 0, 1, 0
            local standingText = ""
            local barColor = BAR_COLORS[4]
            local isCapped = false

            local friendship = GetFriendshipData(fd.factionID)
            local isMajor    = IsMajorFaction(fd.factionID)

            if isMajor then
                local mjd = C_MajorFactions and
                            C_MajorFactions.GetMajorFactionData(fd.factionID)
                if mjd then
                    local isMax = C_MajorFactions.HasMaximumRenown(fd.factionID)
                    if isMax then
                        minVal, maxVal, curVal = 0, 1, 1
                        isCapped = true
                    else
                        minVal  = 0
                        maxVal  = mjd.renownLevelThreshold
                        curVal  = mjd.renownReputationEarned
                    end
                    standingText = format(RENOWN_LEVEL_LABEL or "Renown %d",
                                         mjd.renownLevel)
                    barColor = RENOWN_COLOR
                end

            elseif friendship then
                local isMax = (friendship.nextThreshold == nil)
                if isMax then
                    minVal, maxVal, curVal = 0, 1, 1
                    isCapped = true
                else
                    minVal = friendship.reactionThreshold or 0
                    maxVal = friendship.nextThreshold     or 1
                    curVal = friendship.standing           or 0
                end
                standingText = friendship.reaction or ""
                barColor = BAR_COLORS[5]

            else
                isCapped = (fd.reaction == (MAX_REPUTATION_REACTION or 8))
                if isCapped then
                    minVal, maxVal, curVal = 0, 1, 1
                else
                    minVal = fd.currentReactionThreshold or 0
                    maxVal = fd.nextReactionThreshold    or 1
                    curVal = fd.currentStanding          or 0
                end
                local gender = UnitSex("player")
                standingText = GetText(
                    "FACTION_STANDING_LABEL" .. (fd.reaction or 4),
                    gender) or ""
                barColor = BAR_COLORS[fd.reaction or 4] or BAR_COLORS[4]
            end

            entry.standing:ClearAllPoints()
            entry.standing:SetPoint("RIGHT", entry, "RIGHT", -4, 0)

            entry.bar:ClearAllPoints()
            entry.bar:SetPoint("RIGHT", entry, "RIGHT", -114, 0)

            local range = maxVal - minVal
            local fill  = (range > 0) and ((curVal - minVal) / range)
                          or (isCapped and 1 or 0)
            fill = max(0, min(1, fill))
            entry.bar:SetMinMaxValues(0, 1)
            entry.bar:SetValue(fill)
            entry.bar:SetStatusBarColor(barColor.r, barColor.g, barColor.b, 0.85)
            entry.bar:Show()

            if isCapped then
                entry.barText:SetText("")
            else
                local cur   = curVal - minVal
                local total = maxVal - minVal
                entry.barText:SetText(
                    BreakUpLargeNumbers(cur) .. " / " ..
                    BreakUpLargeNumbers(total))
            end

            entry.standing:SetText(standingText)
            entry.standing:SetTextColor(barColor.r, barColor.g, barColor.b)

            local showParagon = false
            if C_Reputation.IsFactionParagon and
               C_Reputation.IsFactionParagon(fd.factionID) then
                local val, threshold, _, hasReward =
                    C_Reputation.GetFactionParagonInfo(fd.factionID)
                if hasReward then
                    showParagon = true
                    entry.hasParagonReward = true
                end
            end
            entry.paragonGlow:SetShown(showParagon)

            local selIdx = C_Reputation.GetSelectedFaction()
            entry.selBar:SetShown(selIdx == fd.factionIndex)
        end

        entry:Show()
        y = y + (isPureHeader and HEADER_HEIGHT or ENTRY_HEIGHT)
        end -- else (visible entry)
    end

    content:SetHeight(max(y, 1))
end

local DETAIL_WIDTH = 260

local detail = CreateFrame("Frame", nil, container, "BackdropTemplate")
detail:SetWidth(DETAIL_WIDTH)
detail:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, -30)
detail:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4, 8)
detail:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
detail:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
detail:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
detail:SetFrameLevel(container:GetFrameLevel() + 10)
detail:Hide()

local detailClose = CreateFrame("Button", nil, detail, "UIPanelCloseButton")
detailClose:SetPoint("TOPRIGHT", -2, -2)
detailClose:SetScript("OnClick", function()
    C_Reputation.SetSelectedFaction(0)
    detail:Hide()
    ns:UpdateReputation()
end)

local detailTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
detailTitle:SetPoint("TOPLEFT", 14, -14)
detailTitle:SetPoint("TOPRIGHT", detailClose, "TOPLEFT", -4, 0)
detailTitle:SetJustifyH("LEFT")
detailTitle:SetTextColor(1, 0.82, 0, 1)

local descScroll = CreateFrame("ScrollFrame", nil, detail,
                               "UIPanelScrollFrameTemplate")
descScroll:SetPoint("TOPLEFT", detailTitle, "BOTTOMLEFT", 0, -6)
descScroll:SetPoint("RIGHT", detail, "RIGHT", -26, 0)
descScroll:SetHeight(120)

local descText = CreateFrame("Frame", nil, descScroll)
descText:SetWidth(DETAIL_WIDTH - 40)
descScroll:SetScrollChild(descText)

local descString = descText:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
descString:SetPoint("TOPLEFT")
descString:SetWidth(DETAIL_WIDTH - 40)
descString:SetJustifyH("LEFT")
descString:SetTextColor(0.8, 0.8, 0.8, 1)
descString:SetSpacing(2)

local detailDivider = detail:CreateTexture(nil, "ARTWORK")
detailDivider:SetHeight(1)
detailDivider:SetPoint("LEFT", detail, "LEFT", 10, 0)
detailDivider:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
detailDivider:SetPoint("TOP", descScroll, "BOTTOM", 0, -6)
detailDivider:SetColorTexture(0.45, 0.40, 0.25, 0.4)

local function CreateDetailCheckbox(parent, labelText, anchor, yOff)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
    cb.text:SetFontObject("GameFontHighlightSmall")
    cb.text:SetText(labelText)
    return cb
end

local watchCheck = CreateDetailCheckbox(detail,
    SHOW_FACTION_ON_MAINSCREEN or "Show as Experience Bar",
    detailDivider, -8)

watchCheck:SetScript("OnClick", function(self)
    local idx = C_Reputation.GetSelectedFaction()
    if self:GetChecked() then
        C_Reputation.SetWatchedFactionByIndex(idx)
    else
        C_Reputation.SetWatchedFactionByIndex(0)
    end
    if StatusTrackingBarManager then
        StatusTrackingBarManager:UpdateBarsShown()
    end
    PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
              or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    ns:UpdateReputation()
end)

local atWarCheck = CreateDetailCheckbox(detail,
    AT_WAR or "At War",
    watchCheck, -2)

atWarCheck:SetScript("OnClick", function(self)
    C_Reputation.ToggleFactionAtWar(C_Reputation.GetSelectedFaction())
    PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
              or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    ns:UpdateReputation()
    ns:RefreshReputationDetail()
end)

local inactiveCheck = CreateDetailCheckbox(detail,
    MOVE_TO_INACTIVE or "Move to Inactive",
    atWarCheck, -2)

inactiveCheck:SetScript("OnClick", function(self)
    local shouldBeActive = not self:GetChecked()
    C_Reputation.SetFactionActive(C_Reputation.GetSelectedFaction(), shouldBeActive)
    PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
              or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    ns:UpdateReputation()
end)

local viewRenownBtn = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
viewRenownBtn:SetSize(140, 22)
viewRenownBtn:SetPoint("BOTTOM", detail, "BOTTOM", 0, 14)
viewRenownBtn:SetText(VIEW_RENOWN_BUTTON_LABEL or "View Renown")
viewRenownBtn:Hide()

viewRenownBtn:SetScript("OnClick", function(self)
    if not self.factionID then return end
    if EncounterJournal_LoadUI then
        if not EncounterJournal then EncounterJournal_LoadUI() end
        if EncounterJournal and not EncounterJournal:IsShown() then
            ShowUIPanel(EncounterJournal)
        end
        if EJ_ContentTab_Select and EncounterJournal and EncounterJournal.JourneysTab then
            EJ_ContentTab_Select(EncounterJournal.JourneysTab:GetID())
        end
        if EncounterJournalJourneysFrame and EncounterJournalJourneysFrame.ResetView then
            EncounterJournalJourneysFrame:ResetView(nil, self.factionID)
        end
    end
end)

function ns:RefreshReputationDetail()
    local selIdx = C_Reputation.GetSelectedFaction()
    if not selIdx or selIdx == 0 then
        detail:Hide()
        return
    end

    local fd = C_Reputation.GetFactionDataByIndex(selIdx)
    if not fd or not fd.factionID or fd.factionID == 0 then
        detail:Hide()
        return
    end

    detailTitle:SetText(fd.name or "")

    descString:SetText(fd.description or "")
    descText:SetHeight(descString:GetStringHeight() + 4)

    watchCheck:SetChecked(fd.isWatched)

    local canWar = fd.canToggleAtWar and not fd.isHeader
    atWarCheck:SetEnabled(canWar)
    atWarCheck:SetChecked(fd.atWarWith)
    if canWar then
        atWarCheck.text:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g,
                                     RED_FONT_COLOR.b)
    else
        atWarCheck.text:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g,
                                     GRAY_FONT_COLOR.b)
    end

    local canInactive = fd.canSetInactive
    inactiveCheck:SetEnabled(canInactive)
    inactiveCheck:SetChecked(not C_Reputation.IsFactionActive(selIdx))
    if canInactive then
        inactiveCheck.text:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g,
                                        NORMAL_FONT_COLOR.b)
    else
        inactiveCheck.text:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g,
                                        GRAY_FONT_COLOR.b)
    end

    local isMajor = IsMajorFaction(fd.factionID)
    if isMajor then
        viewRenownBtn.factionID = fd.factionID
        local mjd = C_MajorFactions and
                    C_MajorFactions.GetMajorFactionData(fd.factionID)
        viewRenownBtn:SetEnabled(mjd and mjd.isUnlocked or false)
        viewRenownBtn:Show()
    else
        viewRenownBtn:Hide()
    end

    detail:Show()
end
