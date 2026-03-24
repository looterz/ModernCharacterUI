local addonName, ns = ...

local container = ns.currContent

local HEADER_HEIGHT = 26
local ENTRY_HEIGHT  = 24
local INDENT_PER_DEPTH = 20
local ICON_SIZE     = 18

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

    local name = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    entry.name = name

    local qty = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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

            entry.name:ClearAllPoints()
            entry.name:SetPoint("LEFT", entry.arrow, "RIGHT", 4, 0)
            entry.name:SetPoint("RIGHT", entry, "RIGHT", -4, 0)
            entry.name:SetText(info.name or "")
            entry.name:SetTextColor(1, 0.82, 0, 1)

            entry.icon:Hide()
            entry.qty:SetText("")
            entry.tracked:Hide()
            entry.selBar:Hide()
            entry.stripe:Hide()
        else
            visibleIdx = visibleIdx + 1
            entry.arrow:Hide()

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

            entry.tracked:SetShown(info.isShowInBackpack)

            entry.selBar:SetShown(selectedIndex == i)
            entry.stripe:SetShown(visibleIdx % 2 == 0)
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
