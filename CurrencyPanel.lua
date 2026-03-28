local addonName, ns = ...

local container = ns.currContent

local HEADER_HEIGHT = 28
local ENTRY_HEIGHT  = 28
local INDENT_PER_DEPTH = 20
local ICON_SIZE     = 22
local BAR_HEIGHT    = 22

local CURRENCY_BAR_COLORS = {
    { threshold = 0.00, r = 0.24, g = 0.54, b = 1.00 },  -- Blue
    { threshold = 0.25, r = 0.13, g = 0.80, b = 0.13 },  -- Green
    { threshold = 0.50, r = 0.93, g = 0.80, b = 0.13 },  -- Yellow
    { threshold = 0.75, r = 0.80, g = 0.13, b = 0.13 },  -- Dark Red
}

local function GetCurrencyBarColor(pct)
    pct = max(0, min(1, pct))
    for i = #CURRENCY_BAR_COLORS, 1, -1 do
        if pct >= CURRENCY_BAR_COLORS[i].threshold then
            return CURRENCY_BAR_COLORS[i]
        end
    end
    return CURRENCY_BAR_COLORS[1]
end

local searchBox = CreateFrame("EditBox", nil, container, "SearchBoxTemplate")
searchBox:SetSize(220, 20)
searchBox:SetPoint("TOP", container, "TOP", 6, -6)
searchBox:SetAutoFocus(false)

local searchFilter = ""
searchBox:SetScript("OnTextChanged", function(self)
    SearchBoxTemplate_OnTextChanged(self)
    local text = strtrim(self:GetText() or "")
    searchFilter = strlower(text)
    ns:UpdateCurrency()
end)

local _, _, currFilterOpts = ns:CreateFilterDropdown(container, searchBox)

local playerName = UnitName("player") or ""

if C_CurrencyInfo.GetCurrencyFilter then
    currFilterOpts.addRadio(
        CURRENCY_FILTER_TYPE_TRANSFERABLE or "All Transferable & Discovered",
        function()
            local f = C_CurrencyInfo.GetCurrencyFilter()
            return f == (Enum.CurrencyFilterType and Enum.CurrencyFilterType.DiscoveredAndAllAccountTransferable or 0)
        end,
        function()
            local ft = Enum.CurrencyFilterType and Enum.CurrencyFilterType.DiscoveredAndAllAccountTransferable or 0
            C_CurrencyInfo.SetCurrencyFilter(ft)
            ns:UpdateCurrency()
        end)

    currFilterOpts.addRadio(
        format(CURRENCY_FILTER_TYPE_CHARACTER or "%s Only", playerName),
        function()
            local f = C_CurrencyInfo.GetCurrencyFilter()
            return f == (Enum.CurrencyFilterType and Enum.CurrencyFilterType.DiscoveredOnly or 1)
        end,
        function()
            local ft = Enum.CurrencyFilterType and Enum.CurrencyFilterType.DiscoveredOnly or 1
            C_CurrencyInfo.SetCurrencyFilter(ft)
            ns:UpdateCurrency()
        end)

    currFilterOpts.addDivider()
end

currFilterOpts.addAction(
    EXPAND_ALL or "Expand All",
    function()
        for i = C_CurrencyInfo.GetCurrencyListSize(), 1, -1 do
            local info = C_CurrencyInfo.GetCurrencyListInfo(i)
            if info and info.isHeader and not info.isHeaderExpanded then
                C_CurrencyInfo.ExpandCurrencyList(i, true)
            end
        end
        ns:UpdateCurrency()
    end)

currFilterOpts.addAction(
    COLLAPSE_ALL or "Collapse All",
    function()
        for i = C_CurrencyInfo.GetCurrencyListSize(), 1, -1 do
            local info = C_CurrencyInfo.GetCurrencyListInfo(i)
            if info and info.isHeader and info.isHeaderExpanded then
                C_CurrencyInfo.ExpandCurrencyList(i, false)
            end
        end
        ns:UpdateCurrency()
    end)

local transferLog = CreateFrame("Frame", nil, container, "BackdropTemplate")
transferLog:SetWidth(360)
transferLog:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, -30)
transferLog:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4, 8)
transferLog:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
transferLog:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
transferLog:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
transferLog:SetFrameLevel(container:GetFrameLevel() + 10)
transferLog:Hide()

local logTitle = transferLog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
logTitle:SetPoint("TOPLEFT", 14, -12)
logTitle:SetText(CURRENCY_TRANSFER_LOG or "Currency Transfer Log")
logTitle:SetTextColor(1, 0.82, 0, 1)

local logClose = CreateFrame("Button", nil, transferLog, "UIPanelCloseButton")
logClose:SetPoint("TOPRIGHT", -2, -2)
logClose:SetScript("OnClick", function() transferLog:Hide() end)

local logScroll = CreateFrame("ScrollFrame", nil, transferLog,
                              "UIPanelScrollFrameTemplate")
logScroll:SetPoint("TOPLEFT", 8, -32)
logScroll:SetPoint("BOTTOMRIGHT", -26, 8)

local logContent = CreateFrame("Frame", nil, logScroll)
logContent:SetWidth(310)
logScroll:SetScrollChild(logContent)

local logEmpty = logContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
logEmpty:SetPoint("TOP", 0, -20)
logEmpty:SetText(CURRENCY_TRANSFER_LOG_EMPTY or "No recent transfers.")
logEmpty:SetTextColor(0.5, 0.5, 0.5, 1)
logEmpty:Hide()

local logEntries = {}

local function CreateLogEntry()
    local row = CreateFrame("Frame", nil, logContent)
    row:SetHeight(36)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("TOPLEFT", 4, -4)
    row.icon = icon

    local info = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, 0)
    info:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    info:SetJustifyH("LEFT")
    info:SetWordWrap(false)
    row.info = info

    local detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT", icon, "BOTTOMRIGHT", 6, -2)
    detail:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    detail:SetJustifyH("LEFT")
    detail:SetTextColor(0.6, 0.6, 0.6, 1)
    row.detail = detail

    local stripe = row:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints()
    stripe:SetColorTexture(1, 1, 1, 0.03)
    stripe:Hide()
    row.stripe = stripe

    return row
end

local function RefreshTransferLog()
    for _, e in ipairs(logEntries) do e:Hide() end

    if not C_CurrencyInfo.FetchCurrencyTransferTransactions then
        logEmpty:SetText("Transfer log not available.")
        logEmpty:Show()
        logContent:SetHeight(40)
        return
    end

    local transactions = C_CurrencyInfo.FetchCurrencyTransferTransactions()
    if not transactions or #transactions == 0 then
        logEmpty:Show()
        logContent:SetHeight(40)
        return
    end
    logEmpty:Hide()

    local y = 0
    for i, txn in ipairs(transactions) do
        local entry = logEntries[i]
        if not entry then
            entry = CreateLogEntry()
            logEntries[i] = entry
        end

        entry:ClearAllPoints()
        entry:SetPoint("TOPLEFT", logContent, "TOPLEFT", 0, -y)
        entry:SetPoint("TOPRIGHT", logContent, "TOPRIGHT", 0, -y)

        local currInfo = C_CurrencyInfo.GetBasicCurrencyInfo
            and C_CurrencyInfo.GetBasicCurrencyInfo(txn.currencyType)
        if currInfo and currInfo.icon then
            entry.icon:SetTexture(currInfo.icon)
        else
            entry.icon:SetTexture(136012)
        end

        local sourceName = txn.sourceCharacterName or "?"
        local destName = txn.destinationCharacterName or UnitName("player") or "?"
        local amount = txn.quantityTransferred or txn.quantity or 0
        entry.info:SetText(format("%s  |cff888888>|r  %s   |cffffd100%s|r",
            sourceName, destName, BreakUpLargeNumbers(amount)))

        local age = ""
        if txn.timestamp then
            local seconds = time() - txn.timestamp
            if seconds < 3600 then
                age = format("%dm ago", max(1, floor(seconds / 60)))
            elseif seconds < 86400 then
                age = format("%dh ago", floor(seconds / 3600))
            else
                age = format("%dd ago", floor(seconds / 86400))
            end
        end
        local currName = currInfo and currInfo.name or ""
        entry.detail:SetText(format("%s  %s", currName, age))

        entry.stripe:SetShown(i % 2 == 0)
        entry:Show()
        y = y + 36
    end

    logContent:SetHeight(max(y, 1))
end

currFilterOpts.addDivider()
currFilterOpts.addAction(
    CURRENCY_TRANSFER_LOG or "Currency Transfer Log",
    function()
        if transferLog:IsShown() then
            transferLog:Hide()
        else
            if C_CurrencyInfo.RequestCurrencyDataForAccountCharacters then
                C_CurrencyInfo.RequestCurrencyDataForAccountCharacters()
            end
            RefreshTransferLog()
            transferLog:Show()
        end
    end)

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
ns.currEntries = entries
local selectedIndex = nil

local popup = CreateFrame("Frame", nil, container, "BackdropTemplate")
popup:SetWidth(260)
popup:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, -30)
popup:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4, 8)
popup:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
popup:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
popup:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
popup:SetFrameLevel(container:GetFrameLevel() + 20)
popup:Hide()

local popupClose = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
popupClose:SetPoint("TOPRIGHT", -2, -2)
popupClose:SetScript("OnClick", function()
    selectedIndex = nil
    popup:Hide()
    ns:UpdateCurrency()
end)

local popupTitle = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
popupTitle:SetPoint("TOPLEFT", 14, -14)
popupTitle:SetPoint("TOPRIGHT", popupClose, "TOPLEFT", -4, 0)
popupTitle:SetJustifyH("LEFT")
popupTitle:SetTextColor(1, 0.82, 0, 1)

local backpackCheck = CreateFrame("CheckButton", nil, popup, "UICheckButtonTemplate")
backpackCheck:SetSize(22, 22)
backpackCheck:SetPoint("TOPLEFT", popupTitle, "BOTTOMLEFT", -4, -8)
backpackCheck.text:SetFontObject("GameFontHighlightSmall")
backpackCheck.text:SetText(SHOW_ON_BACKPACK or "Show on Backpack")
backpackCheck.text:SetPoint("RIGHT", popup, "RIGHT", -14, 0)
backpackCheck.text:SetJustifyH("LEFT")
backpackCheck.text:SetJustifyV("TOP")

backpackCheck:SetScript("OnClick", function(self)
    if not popup.currencyIndex then return end
    local watched = self:GetChecked()
    C_CurrencyInfo.SetCurrencyBackpack(popup.currencyIndex, watched)
    PlaySound(watched and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
              or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    ns:UpdateCurrency()
end)

local unusedCheck = CreateFrame("CheckButton", nil, popup, "UICheckButtonTemplate")
unusedCheck:SetSize(22, 22)
unusedCheck:SetPoint("TOPLEFT", backpackCheck, "BOTTOMLEFT", 0, -2)
unusedCheck.text:SetFontObject("GameFontHighlightSmall")
unusedCheck.text:SetText("Move to Unused")
unusedCheck.text:SetPoint("RIGHT", popup, "RIGHT", -14, 0)
unusedCheck.text:SetJustifyH("LEFT")
unusedCheck.text:SetJustifyV("TOP")

unusedCheck:SetScript("OnClick", function(self)
    if not popup.currencyIndex then return end
    C_CurrencyInfo.SetCurrencyUnused(popup.currencyIndex, self:GetChecked())
    PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
              or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    ns:UpdateCurrency()
end)

local function CreateEntry()
    local entry = CreateFrame("Button", nil, content)
    entry:SetHeight(ENTRY_HEIGHT)

    local arrow = entry:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(14, 14)
    arrow:SetPoint("LEFT", 2, 0)
    arrow:Hide()
    entry.arrow = arrow

    local icon = entry:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:Hide()
    entry.icon = icon

    local currFontSize = (ns.db and ns.db.global and ns.db.global.currencyFontSize) or 12

    local name = entry:CreateFontString(nil, "OVERLAY")
    name:SetFont(STANDARD_TEXT_FONT, currFontSize, "")
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    entry.name = name

    local qty = entry:CreateFontString(nil, "OVERLAY")
    qty:SetFont(STANDARD_TEXT_FONT, currFontSize, "")
    qty:SetPoint("RIGHT", -24, 0)
    qty:SetJustifyH("RIGHT")
    entry.qty = qty

    local tracked = entry:CreateTexture(nil, "OVERLAY")
    tracked:SetSize(14, 14)
    tracked:SetPoint("RIGHT", -4, 0)
    tracked:SetAtlas("common-icon-checkmark")
    tracked:Hide()
    entry.tracked = tracked

    local selBar = entry:CreateTexture(nil, "BACKGROUND", nil, 2)
    selBar:SetAllPoints()
    selBar:SetColorTexture(0.35, 0.30, 0.10, 0.35)
    selBar:Hide()
    entry.selBar = selBar

    local stripe = entry:CreateTexture(nil, "BACKGROUND", nil, 1)
    stripe:SetAllPoints()
    stripe:SetColorTexture(1, 1, 1, 0.03)
    stripe:Hide()
    entry.stripe = stripe

    local hl = entry:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.05)

    -- Progress bar for capped currencies
    local bar = CreateFrame("StatusBar", nil, entry)
    bar:SetHeight(BAR_HEIGHT)
    bar:SetPoint("LEFT", entry, "LEFT", 2, 0)
    bar:SetPoint("RIGHT", entry, "RIGHT", -2, 0)
    bar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
    bar:GetStatusBarTexture():SetHorizTile(false)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:EnableMouse(false)
    bar:Hide()

    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetColorTexture(0.08, 0.08, 0.10, 0.85)

    local barBorderTop = bar:CreateTexture(nil, "OVERLAY", nil, -1)
    barBorderTop:SetHeight(1)
    barBorderTop:SetPoint("TOPLEFT", -1, 1)
    barBorderTop:SetPoint("TOPRIGHT", 1, 1)
    barBorderTop:SetColorTexture(0.3, 0.3, 0.3, 0.6)

    local barBorderBot = bar:CreateTexture(nil, "OVERLAY", nil, -1)
    barBorderBot:SetHeight(1)
    barBorderBot:SetPoint("BOTTOMLEFT", -1, -1)
    barBorderBot:SetPoint("BOTTOMRIGHT", 1, -1)
    barBorderBot:SetColorTexture(0.3, 0.3, 0.3, 0.6)

    local barBorderLeft = bar:CreateTexture(nil, "OVERLAY", nil, -1)
    barBorderLeft:SetWidth(1)
    barBorderLeft:SetPoint("TOPLEFT", -1, 1)
    barBorderLeft:SetPoint("BOTTOMLEFT", -1, -1)
    barBorderLeft:SetColorTexture(0.3, 0.3, 0.3, 0.6)

    local barBorderRight = bar:CreateTexture(nil, "OVERLAY", nil, -1)
    barBorderRight:SetWidth(1)
    barBorderRight:SetPoint("TOPRIGHT", 1, 1)
    barBorderRight:SetPoint("BOTTOMRIGHT", 1, -1)
    barBorderRight:SetColorTexture(0.3, 0.3, 0.3, 0.6)

    local barTextFrame = CreateFrame("Frame", nil, bar)
    barTextFrame:SetAllPoints()
    barTextFrame:SetFrameLevel(bar:GetFrameLevel() + 10)
    barTextFrame:EnableMouse(false)

    local barIcon = barTextFrame:CreateTexture(nil, "OVERLAY")
    barIcon:SetSize(18, 18)
    barIcon:SetPoint("LEFT", 6, 0)

    local barName = barTextFrame:CreateFontString(nil, "OVERLAY")
    barName:SetFont(STANDARD_TEXT_FONT, currFontSize, "OUTLINE")
    barName:SetPoint("LEFT", barIcon, "RIGHT", 4, 0)
    barName:SetPoint("RIGHT", barTextFrame, "CENTER", -10, 0)
    barName:SetJustifyH("LEFT")
    barName:SetWordWrap(false)

    local barProgress = barTextFrame:CreateFontString(nil, "OVERLAY")
    barProgress:SetFont(STANDARD_TEXT_FONT, max(8, currFontSize - 1), "OUTLINE")
    barProgress:SetPoint("CENTER", 0, 0)
    barProgress:SetJustifyH("CENTER")
    barProgress:SetTextColor(0.9, 0.9, 0.9, 1)

    local barLabel = barTextFrame:CreateFontString(nil, "OVERLAY")
    barLabel:SetFont(STANDARD_TEXT_FONT, max(8, currFontSize - 1), "OUTLINE")
    barLabel:SetPoint("RIGHT", -8, 0)
    barLabel:SetJustifyH("RIGHT")
    barLabel:SetTextColor(1, 1, 1, 0.9)

    entry.bar = bar
    entry.barIcon = barIcon
    entry.barName = barName
    entry.barProgress = barProgress
    entry.barLabel = barLabel

    entry:SetScript("OnEnter", function(self)
        if self.currencyIndex and not self.isHeader then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetCurrencyToken(self.currencyIndex)
            GameTooltip:Show()
        end
    end)
    entry:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    entry:SetScript("OnClick", function(self, button)
        if self.isHeader then
            local info = C_CurrencyInfo.GetCurrencyListInfo(self.currencyIndex)
            if info then
                C_CurrencyInfo.ExpandCurrencyList(self.currencyIndex,
                    not info.isHeaderExpanded)
                ns:UpdateCurrency()
            end
            return
        end

        if IsModifiedClick("CHATLINK") then
            local link = C_CurrencyInfo.GetCurrencyListLink(self.currencyIndex)
            if link then ChatEdit_InsertLink(link) end
            return
        end
        if IsModifiedClick("TOKENWATCHTOGGLE") then
            local info = C_CurrencyInfo.GetCurrencyListInfo(self.currencyIndex)
            if info then
                C_CurrencyInfo.SetCurrencyBackpack(self.currencyIndex,
                    not info.isShowInBackpack)
                ns:UpdateCurrency()
            end
            return
        end

        if selectedIndex == self.currencyIndex then
            selectedIndex = nil
            popup:Hide()
        else
            selectedIndex = self.currencyIndex
            local info = C_CurrencyInfo.GetCurrencyListInfo(self.currencyIndex)
            if info then
                popupTitle:SetText(info.name or "")
                backpackCheck:SetChecked(info.isShowInBackpack)
                unusedCheck:SetChecked(info.isTypeUnused)
                popup.currencyIndex = self.currencyIndex
                popup:Show()
            end
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ns:UpdateCurrency()
    end)

    return entry
end

function ns:UpdateCurrency()
    if not container:IsShown() then return end

    for _, e in ipairs(entries) do e:Hide() end

    local listSize = C_CurrencyInfo.GetCurrencyListSize()
    local filtering = (searchFilter ~= "")

    -- Pre-pass: determine which indices match so headers with matching
    -- children remain visible.
    local matchSet = {}
    if filtering then
        local headerStack = {}
        for i = 1, listSize do
            local ci = C_CurrencyInfo.GetCurrencyListInfo(i)
            if not ci then break end
            if ci.isHeader then
                headerStack = { i } -- simple: reset to current header
            else
                if FuzzyMatch(strlower(ci.name or ""), searchFilter) then
                    matchSet[i] = true
                    for _, hi in ipairs(headerStack) do
                        matchSet[hi] = true
                    end
                end
            end
        end
    end

    local y = 0
    local idx = 0
    local visibleIdx = 0

    for i = 1, listSize do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if not info then break end

        -- Skip entries that don't match the search filter
        if filtering and not matchSet[i] then
            -- skip
        else -- visible entry

        idx = idx + 1
        local entry = entries[idx]
        if not entry then
            entry = CreateEntry()
            entries[idx] = entry
        end

        local indent = (info.currencyListDepth or 0) * INDENT_PER_DEPTH
        local isHeader = info.isHeader
        local h = isHeader and HEADER_HEIGHT or ENTRY_HEIGHT

        entry:SetHeight(h)
        entry:ClearAllPoints()
        entry:SetPoint("TOPLEFT", content, "TOPLEFT", indent, -y)
        entry:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
        entry.currencyIndex = i
        entry.isHeader = isHeader

        if isHeader then
            entry.arrow:Show()
            entry.arrow:SetAtlas(info.isHeaderExpanded
                and "campaign_headericon_open"
                or  "campaign_headericon_closed")

            entry.name:Show()
            entry.name:ClearAllPoints()
            entry.name:SetPoint("LEFT", entry.arrow, "RIGHT", 4, 0)
            entry.name:SetPoint("RIGHT", entry, "RIGHT", -4, 0)
            local headerFontSize = (ns.db and ns.db.global and ns.db.global.currencyHeaderFontSize) or 20
            entry.name:SetFont(STANDARD_TEXT_FONT, headerFontSize, "")
            entry.name:SetText(info.name or "")
            entry.name:SetTextColor(1, 0.82, 0, 1)

            entry.icon:Hide()
            entry.qty:SetText("")
            entry.tracked:Hide()
            entry.selBar:Hide()
            entry.stripe:Hide()
            entry.bar:Hide()
        else
            visibleIdx = visibleIdx + 1
            entry.arrow:Hide()
            local currFontSize = (ns.db and ns.db.global and ns.db.global.currencyFontSize) or 16

            -- Fetch detailed currency info for accurate weekly/season tracking
            local link = C_CurrencyInfo.GetCurrencyListLink(i)
            local currencyID = link and tonumber(link:match("currency:(%d+)"))
            local detailed = currencyID and C_CurrencyInfo.GetCurrencyInfo(currencyID)

            -- Determine if this currency has a cap
            local capCurrent, capMax, capLabel = 0, 0, nil
            if detailed and (detailed.maxWeeklyQuantity or 0) > 0 then
                capCurrent = detailed.quantityEarnedThisWeek or 0
                capMax = detailed.maxWeeklyQuantity
                capLabel = "Weekly"
            elseif detailed and detailed.useTotalEarnedForMaxQty and (detailed.maxQuantity or 0) > 0 then
                capCurrent = detailed.totalEarned or 0
                capMax = detailed.maxQuantity
                capLabel = "Season"
            elseif (info.maxQuantity or 0) > 0 then
                capCurrent = info.quantity or 0
                capMax = info.maxQuantity
                capLabel = "Max"
            end

            if capMax > 0 then
                -- Bar mode for capped currencies
                entry.icon:Hide()
                entry.name:Hide()
                entry.qty:Hide()
                entry.tracked:Hide()

                entry.bar:Show()
                entry.bar:SetMinMaxValues(0, capMax)
                entry.bar:SetValue(capCurrent)
                local pct = capCurrent / capMax
                local color = GetCurrencyBarColor(pct)
                entry.bar:SetStatusBarColor(color.r, color.g, color.b, 0.85)

                entry.barIcon:SetTexture(info.iconFileID)
                entry.barName:SetFont(STANDARD_TEXT_FONT, currFontSize, "OUTLINE")
                entry.barName:SetText(info.name or "")
                entry.barName:SetTextColor(1, 1, 1, 1)
                local barFontSize = max(8, currFontSize - 1)
                entry.barProgress:SetFont(STANDARD_TEXT_FONT, barFontSize, "OUTLINE")
                entry.barProgress:SetText(format("%s / %s", BreakUpLargeNumbers(capCurrent), BreakUpLargeNumbers(capMax)))
                entry.barLabel:SetFont(STANDARD_TEXT_FONT, barFontSize, "OUTLINE")
                entry.barLabel:SetText(capLabel)

                entry.selBar:SetShown(selectedIndex == i)
                entry.stripe:Hide()
            else
                -- Normal mode for uncapped currencies
                entry.bar:Hide()

                entry.name:Show()
                entry.name:SetFont(STANDARD_TEXT_FONT, currFontSize, "")

                entry.icon:SetTexture(info.iconFileID)
                entry.icon:SetPoint("LEFT", 4, 0)
                entry.icon:Show()

                entry.name:ClearAllPoints()
                entry.name:SetPoint("LEFT", entry.icon, "RIGHT", 6, 0)
                entry.name:SetPoint("RIGHT", entry.qty, "LEFT", -8, 0)
                entry.name:SetText(info.name or "")

                if (info.quantity or 0) == 0 then
                    entry.name:SetTextColor(DISABLED_FONT_COLOR.r,
                        DISABLED_FONT_COLOR.g, DISABLED_FONT_COLOR.b)
                    entry.qty:SetTextColor(DISABLED_FONT_COLOR.r,
                        DISABLED_FONT_COLOR.g, DISABLED_FONT_COLOR.b)
                else
                    entry.name:SetTextColor(HIGHLIGHT_FONT_COLOR.r,
                        HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
                    entry.qty:SetTextColor(HIGHLIGHT_FONT_COLOR.r,
                        HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
                end

                entry.qty:SetText(BreakUpLargeNumbers(info.quantity or 0))
                entry.qty:Show()

                entry.tracked:SetShown(info.isShowInBackpack)

                entry.selBar:SetShown(selectedIndex == i)
                entry.stripe:SetShown(visibleIdx % 2 == 0)
            end
        end

        entry:Show()
        y = y + h
        end -- else (visible entry)
    end

    content:SetHeight(max(y, 1))

    if selectedIndex and popup:IsShown() then
        local found = false
        for _, e in ipairs(entries) do
            if e:IsShown() and e.currencyIndex == selectedIndex then
                found = true
                break
            end
        end
        if not found then
            selectedIndex = nil
            popup:Hide()
        end
    end
end
