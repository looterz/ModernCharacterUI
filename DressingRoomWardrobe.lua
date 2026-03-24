-- DressingRoomWardrobe.lua
-- Standalone appearances browser for MCU dressing room.
-- Adapted from Blizzard_Wardrobe (WardrobeItemsCollectionMixin / WardrobeItemModelMixin).

-- Simple paging mixin (replaces CollectionsPagingMixin which is load-on-demand)
MCUDR_PagingMixin = {};

function MCUDR_PagingMixin:OnLoad()
	self.currentPage = 1;
	self.maxPages = 1;
end

function MCUDR_PagingMixin:SetMaxPages(maxPages)
	self.maxPages = math.max(1, maxPages);
	if self.currentPage > self.maxPages then
		self.currentPage = self.maxPages;
	end
	self:Update();
end

function MCUDR_PagingMixin:GetMaxPages()
	return self.maxPages;
end

function MCUDR_PagingMixin:SetCurrentPage(page, userAction)
	page = math.max(1, math.min(page, self.maxPages));
	if self.currentPage ~= page then
		self.currentPage = page;
		self:Update();
		if self:GetParent().OnPageChanged then
			self:GetParent():OnPageChanged(userAction);
		end
	end
end

function MCUDR_PagingMixin:GetCurrentPage()
	return self.currentPage;
end

function MCUDR_PagingMixin:NextPage()
	self:SetCurrentPage(self.currentPage + 1, true);
end

function MCUDR_PagingMixin:PreviousPage()
	self:SetCurrentPage(self.currentPage - 1, true);
end

function MCUDR_PagingMixin:OnMouseWheel(delta)
	if delta > 0 then
		self:PreviousPage();
	else
		self:NextPage();
	end
end

function MCUDR_PagingMixin:Update()
	self.PageText:SetFormattedText("%d / %d", self.currentPage, self.maxPages);
	self.PrevPageButton:SetEnabled(self.currentPage > 1);
	self.NextPageButton:SetEnabled(self.currentPage < self.maxPages);
end

---------------------------------------------------------------------------
-- Utility namespace
---------------------------------------------------------------------------
MCUDR_WardrobeUtil = {};

function MCUDR_WardrobeUtil.GetSortedAppearanceSources(visualID, category, transmogLocation)
	local locationData = transmogLocation and transmogLocation:GetData() or nil;
	local sources = C_TransmogCollection.GetAppearanceSources(visualID, category, locationData);
	if sources == nil then
		return {};
	end
	return MCUDR_WardrobeUtil.SortSources(sources);
end

function MCUDR_WardrobeUtil.GetSortedAppearanceSourcesForClass(visualID, classID, category, transmogLocation)
	local locationData = transmogLocation and transmogLocation:GetData() or nil;
	local sources = C_TransmogCollection.GetValidAppearanceSourcesForClass(visualID, classID, category, locationData);
	if sources == nil then
		return {};
	end
	return MCUDR_WardrobeUtil.SortSources(sources);
end

function MCUDR_WardrobeUtil.SortSources(sources)
	local comparison = function(source1, source2)
		if source1.isCollected ~= source2.isCollected then
			return source1.isCollected;
		end
		if source1.isValidSourceForPlayer ~= source2.isValidSourceForPlayer then
			return source1.isValidSourceForPlayer;
		end
		if source1.quality and source2.quality then
			if source1.quality ~= source2.quality then
				return source1.quality > source2.quality;
			end
		else
			return source1.quality;
		end
		return source1.sourceID > source2.sourceID;
	end
	table.sort(sources, comparison);
	return sources;
end

function MCUDR_WardrobeUtil.GetSlotFromCategoryID(categoryID)
	local slot;
	for key, transmogSlot in pairs(MCUDR_TRANSMOG_SLOTS) do
		if categoryID == transmogSlot.armorCategoryID then
			slot = transmogSlot.location:GetSlotName();
			break;
		end
	end
	if not slot then
		local name, isWeapon, canEnchant, canMainHand, canOffHand = C_TransmogCollection.GetCategoryInfo(categoryID);
		if canMainHand then
			slot = "MAINHANDSLOT";
		elseif canOffHand then
			slot = "SECONDARYHANDSLOT";
		end
	end
	return slot;
end

function MCUDR_WardrobeUtil.GetPage(entryIndex, pageSize)
	return ceil(entryIndex / pageSize);
end

function MCUDR_WardrobeUtil.GetAppearanceNameTextAndColor(appearanceInfo)
	local text, color;
	if appearanceInfo.name then
		text = appearanceInfo.name;
		if appearanceInfo.quality then
			local r, g, b = GetItemQualityColor(appearanceInfo.quality);
			color = CreateColor(r, g, b);
		else
			color = WHITE_FONT_COLOR;
		end
	else
		text = RETRIEVING_ITEM_INFO;
		color = RED_FONT_COLOR;
	end
	return text, color;
end

function MCUDR_WardrobeUtil.GetAppearanceSourceTextAndColor(appearanceInfo)
	local text, color;
	if appearanceInfo.isCollected then
		text = TRANSMOG_COLLECTED;
		color = GREEN_FONT_COLOR;
	else
		if appearanceInfo.sourceType then
			text = _G["TRANSMOG_SOURCE_"..appearanceInfo.sourceType];
		elseif not appearanceInfo.name then
			text = "";
		end
		color = HIGHLIGHT_FONT_COLOR;
	end
	return text, color;
end

---------------------------------------------------------------------------
-- MCUDR_AppearancesSearchBoxMixin
---------------------------------------------------------------------------
MCUDR_AppearancesSearchBoxMixin = {};

function MCUDR_AppearancesSearchBoxMixin:OnLoad()
	SearchBoxTemplate_OnLoad(self);
end

function MCUDR_AppearancesSearchBoxMixin:OnTextChanged()
	SearchBoxTemplate_OnTextChanged(self);
	local text = self:GetText();
	local parent = self:GetParent();
	if text == "" then
		C_TransmogCollection.ClearSearch(Enum.TransmogSearchType.Items);
	else
		C_TransmogCollection.SetSearch(Enum.TransmogSearchType.Items, text);
	end
	-- Refresh after a short delay to allow search results to populate
	if parent and parent.searchTimer then
		parent.searchTimer:Cancel();
	end
	if parent then
		parent.searchTimer = C_Timer.NewTimer(0.3, function()
			if parent:IsVisible() then
				parent:RefreshVisualsList();
				parent:UpdateItems();
			end
		end);
	end
end

---------------------------------------------------------------------------
-- MCUDR_AppearancesMixin
---------------------------------------------------------------------------
MCUDR_AppearancesMixin = {};

function MCUDR_AppearancesMixin:OnLoad()
	self.NUM_ROWS = 3;
	self.NUM_COLS = 6;
	self.PAGE_SIZE = self.NUM_ROWS * self.NUM_COLS;

	self.chosenVisualSources = {};
	self.visualsList = {};
	self.filteredVisualsList = {};

	-- Initialize the paging frame (mixin OnLoad not auto-called from XML)
	if self.PagingFrame and self.PagingFrame.OnLoad then
		self.PagingFrame:OnLoad();
	end

	-- Hide all models by default (they'll be shown by UpdateItems when data is ready)
	if self.Models then
		for i = 1, #self.Models do
			self.Models[i]:Hide();
		end
	end

	-- Filter button setup
	self.FilterButton:SetWidth(90);
	self:InitFilterButton();

	-- Set default filter state: show everything for preview purposes
	C_TransmogCollection.SetCollectedShown(true);
	C_TransmogCollection.SetUncollectedShown(true);
	C_TransmogCollection.SetAllFactionsShown(true);
	C_TransmogCollection.SetAllRacesShown(true);
	-- Show all source types
	if C_TransmogCollection.SetAllSourceTypeFilters then
		C_TransmogCollection.SetAllSourceTypeFilters(true);
	end
end

function MCUDR_AppearancesMixin:OnShow()
	self:RegisterEvent("TRANSMOG_COLLECTION_UPDATED");
	self:RegisterEvent("TRANSMOG_SEARCH_UPDATED");
	self:RegisterUnitEvent("UNIT_FORM_CHANGED", "player");

	-- Ensure filters are wide open for dressing room preview
	C_TransmogCollection.SetCollectedShown(true);
	C_TransmogCollection.SetUncollectedShown(true);
	C_TransmogCollection.SetAllFactionsShown(true);
	C_TransmogCollection.SetAllRacesShown(true);

	if self.transmogLocation and self.activeCategory then
		self:RefreshVisualsList();
		self:UpdateItems();
	end
end

function MCUDR_AppearancesMixin:OnHide()
	self:UnregisterEvent("TRANSMOG_COLLECTION_UPDATED");
	self:UnregisterEvent("TRANSMOG_SEARCH_UPDATED");
	self:UnregisterEvent("UNIT_FORM_CHANGED");
	C_TransmogCollection.EndSearch();

	for i = 1, #self.Models do
		self.Models[i]:SetKeepModelOnHide(false);
	end

	self.visualsList = nil;
	self.filteredVisualsList = nil;
end

function MCUDR_AppearancesMixin:OnEvent(event, ...)
	if event == "TRANSMOG_COLLECTION_UPDATED" then
		if self:IsVisible() then
			self:RefreshVisualsList();
			self:UpdateItems();
			self:ExecutePendingNavigation();
		end
	elseif event == "TRANSMOG_SEARCH_UPDATED" then
		local searchType, category = ...;
		if searchType == Enum.TransmogSearchType.Items and category == self.activeCategory then
			self:RefreshVisualsList();
			self:UpdateItems();
			self:ExecutePendingNavigation();
		end
	elseif event == "UNIT_FORM_CHANGED" then
		if self:IsVisible() then
			self:RefreshVisualsList();
			self:UpdateItems();
		end
	end
end

function MCUDR_AppearancesMixin:OnMouseWheel(delta)
	self.PagingFrame:OnMouseWheel(delta);
end

function MCUDR_AppearancesMixin:OnPageChanged(userAction)
	PlaySound(SOUNDKIT.UI_TRANSMOG_PAGE_TURN);
	if userAction then
		self:UpdateItems();
	end
end

-- Fallback mapping from inventory slot ID to transmog collection category ID
-- Used when MCUDR_TRANSMOG_SLOTS hasn't been fully populated at addon load
local SLOT_ID_TO_ARMOR_CATEGORY = {
	[1]  = 1,   -- Head
	[3]  = 2,   -- Shoulder
	[15] = 3,   -- Back
	[5]  = 4,   -- Chest
	[4]  = 5,   -- Shirt
	[19] = 6,   -- Tabard
	[9]  = 7,   -- Wrist
	[10] = 8,   -- Hands
	[6]  = 9,   -- Waist
	[7]  = 10,  -- Legs
	[8]  = 11,  -- Feet
};

function MCUDR_AppearancesMixin:IsValidWeaponCategoryForSlot(categoryID)
	local name, isWeapon, canEnchant, canMainHand, canOffHand = C_TransmogCollection.GetCategoryInfo(categoryID);
	if not name or not isWeapon then
		return false;
	end
	if self.transmogLocation:IsMainHand() and canMainHand then
		return true;
	end
	if self.transmogLocation:IsOffHand() then
		-- Offhand only shows shields and held-in-offhand items
		return (categoryID == Enum.TransmogCollectionType.Shield)
			or (categoryID == Enum.TransmogCollectionType.Holdable);
	end
	return false;
end

function MCUDR_AppearancesMixin:SetActiveSlot(transmogLocation, category)
	self.transmogLocation = transmogLocation;

	if not category then
		if transmogLocation:IsAppearance() then
			if transmogLocation:IsEitherHand() then
				-- Prefer last weapon category if valid for this slot
				if self.lastWeaponCategory and self:IsValidWeaponCategoryForSlot(self.lastWeaponCategory) then
					category = self.lastWeaponCategory;
				else
					-- Find the first valid weapon category
					if FIRST_TRANSMOG_COLLECTION_WEAPON_TYPE and LAST_TRANSMOG_COLLECTION_WEAPON_TYPE then
						for categoryID = FIRST_TRANSMOG_COLLECTION_WEAPON_TYPE, LAST_TRANSMOG_COLLECTION_WEAPON_TYPE do
							if self:IsValidWeaponCategoryForSlot(categoryID) then
								category = categoryID;
								break;
							end
						end
					end
				end
			else
				category = transmogLocation:GetArmorCategoryID();
				-- Fallback: derive category from slot ID directly
				if not category then
					local slotID = transmogLocation:GetSlotID();
					category = slotID and SLOT_ID_TO_ARMOR_CATEGORY[slotID];
				end
			end
		end
	end

	self:SetActiveCategory(category);
	self:RefreshWeaponDropdown();
	self:RefreshClassDropdown();
end

function MCUDR_AppearancesMixin:SetActiveCategory(category)
	self.activeCategory = category;

	if category then
		local name, isWeapon = C_TransmogCollection.GetCategoryInfo(category);
		if isWeapon then
			self.lastWeaponCategory = category;
		end
	end

	if category and self.transmogLocation and self.transmogLocation:IsAppearance() then
		C_TransmogCollection.SetSearchAndFilterCategory(category);
	end

	self:RefreshVisualsList();
	self.PagingFrame:SetCurrentPage(1);
	self:UpdateItems();
end

function MCUDR_AppearancesMixin:GetActiveCategory()
	return self.activeCategory;
end

function MCUDR_AppearancesMixin:NavigateToSource(sourceID, itemName)
	if not self.filteredVisualsList or #self.filteredVisualsList == 0 then
		-- Data not ready yet — store for when TRANSMOG_SEARCH_UPDATED fires
		self:SetPendingNavigation(sourceID, itemName);
		return;
	end

	local targetVisualID;

	-- Fast path: numeric sourceID → direct lookup
	if type(sourceID) == "number" then
		local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID);
		if sourceInfo and sourceInfo.visualID then
			targetVisualID = sourceInfo.visualID;
		end
	end

	-- Fallback: search by item name across all visuals in this category
	if not targetVisualID and itemName then
		local locationData = self.transmogLocation and self.transmogLocation:GetData() or nil;
		for _, visualInfo in ipairs(self.filteredVisualsList) do
			local sources = C_TransmogCollection.GetAppearanceSources(visualInfo.visualID, self.activeCategory, locationData);
			if sources then
				for _, src in ipairs(sources) do
					if src.name == itemName then
						targetVisualID = visualInfo.visualID;
						break;
					end
				end
			end
			if targetVisualID then break; end
		end
	end

	if not targetVisualID then
		-- Target not found in current data — may arrive with next update
		self:SetPendingNavigation(sourceID, itemName);
		return;
	end

	-- Found it — clear any pending navigation
	self.pendingNavSourceID = nil;
	self.pendingNavItemName = nil;
	self.activeVisualID = targetVisualID;

	-- Find the index and navigate to its page
	for i, visualInfo in ipairs(self.filteredVisualsList) do
		if visualInfo.visualID == targetVisualID then
			local page = ceil(i / self.PAGE_SIZE);
			self.PagingFrame:SetCurrentPage(page);
			break;
		end
	end

	self:UpdateItems();
end

function MCUDR_AppearancesMixin:ClearActiveVisual()
	self.activeVisualID = nil;
	self.pendingNavSourceID = nil;
	self.pendingNavItemName = nil;
end

function MCUDR_AppearancesMixin:SetPendingNavigation(sourceID, itemName)
	self.pendingNavSourceID = sourceID;
	self.pendingNavItemName = itemName;
end

function MCUDR_AppearancesMixin:ExecutePendingNavigation()
	if self.pendingNavSourceID or self.pendingNavItemName then
		local srcID = self.pendingNavSourceID;
		local name = self.pendingNavItemName;
		self.pendingNavSourceID = nil;
		self.pendingNavItemName = nil;
		self:NavigateToSource(srcID, name);
	end
end

function MCUDR_AppearancesMixin:RefreshVisualsList()
	if not self.transmogLocation or not self.activeCategory then
		self.visualsList = {};
		self.filteredVisualsList = {};
		self.PagingFrame:SetMaxPages(1);
		return;
	end

	local locationData = self.transmogLocation:GetData();

	self.visualsList = C_TransmogCollection.GetCategoryAppearances(self.activeCategory, locationData);
	if not self.visualsList then
		self.visualsList = {};
	end

	self:FilterVisuals();
	self:SortVisuals();
	self.PagingFrame:SetMaxPages(max(1, ceil(#self.filteredVisualsList / self.PAGE_SIZE)));
end

function MCUDR_AppearancesMixin:FilterVisuals()
	local visualsList = self.visualsList;
	local filteredVisualsList = {};
	for i, visualInfo in ipairs(visualsList) do
		if not visualInfo.isHideVisual then
			table.insert(filteredVisualsList, visualInfo);
		end
	end
	self.filteredVisualsList = filteredVisualsList;
end

function MCUDR_AppearancesMixin:SortVisuals()
	local comparison = function(source1, source2)
		if source1.isCollected ~= source2.isCollected then
			return source1.isCollected;
		end
		if source1.isUsable ~= source2.isUsable then
			return source1.isUsable;
		end
		if source1.isFavorite ~= source2.isFavorite then
			return source1.isFavorite;
		end
		if source1.canDisplayOnPlayer ~= source2.canDisplayOnPlayer then
			return source1.canDisplayOnPlayer;
		end
		if source1.isHideVisual ~= source2.isHideVisual then
			return source1.isHideVisual;
		end
		if source1.hasActiveRequiredHoliday ~= source2.hasActiveRequiredHoliday then
			return source1.hasActiveRequiredHoliday;
		end
		if source1.uiOrder and source2.uiOrder then
			return source1.uiOrder > source2.uiOrder;
		end
		return source1.sourceID > source2.sourceID;
	end
	table.sort(self.filteredVisualsList, comparison);
end

function MCUDR_AppearancesMixin:GetFilteredVisualsList()
	return self.filteredVisualsList;
end

function MCUDR_AppearancesMixin:GetAnAppearanceSourceFromVisual(visualID, mustBeUsable, categoryOverride)
	local sourceID = self:GetChosenVisualSource(visualID);
	if sourceID == Constants.Transmog.NoTransmogID then
		local category = categoryOverride or self.activeCategory;
		local sources = MCUDR_WardrobeUtil.GetSortedAppearanceSources(visualID, category, self.transmogLocation);
		for i = 1, #sources do
			if not mustBeUsable or not sources[i].useError then
				sourceID = sources[i].sourceID;
				break;
			end
		end
	end
	return sourceID;
end

function MCUDR_AppearancesMixin:GetChosenVisualSource(visualID)
	return self.chosenVisualSources[visualID] or Constants.Transmog.NoTransmogID;
end

function MCUDR_AppearancesMixin:UpdateItems()
	if not self.filteredVisualsList or not self.transmogLocation then
		return;
	end

	local isArmor;
	local cameraID;
	if self.transmogLocation:IsAppearance() and self.activeCategory then
		local _, isWeapon = C_TransmogCollection.GetCategoryInfo(self.activeCategory);
		isArmor = not isWeapon;
	end

	local cameraVariation = nil;
	if TransmogUtil and TransmogUtil.GetCameraVariation then
		cameraVariation = TransmogUtil.GetCameraVariation(self.transmogLocation);
	end

	local indexOffset = (self.PagingFrame:GetCurrentPage() - 1) * self.PAGE_SIZE;
	for i = 1, self.PAGE_SIZE do
		local model = self.Models[i];
		local index = i + indexOffset;
		local visualInfo = self.filteredVisualsList[index];
		if visualInfo then
			model:Show();

			-- camera
			if self.transmogLocation:IsAppearance() then
				cameraID = C_TransmogCollection.GetAppearanceCameraID(visualInfo.visualID, cameraVariation);
			end
			if model.cameraID ~= cameraID then
				Model_ApplyUICamera(model, cameraID);
				model.cameraID = cameraID;
			end

			if visualInfo ~= model.visualInfo then
				if isArmor then
					local sourceID = self:GetAnAppearanceSourceFromVisual(visualInfo.visualID, nil, visualInfo._categoryID);
					model:SetUnit("player");
					model:Undress();
					model:TryOn(sourceID);
				else
					model:SetItemAppearance(visualInfo.visualID);
				end
			end
			model.visualInfo = visualInfo;

			-- border
			if not visualInfo.isCollected then
				model.Border:SetAtlas("transmog-wardrobe-border-uncollected");
			elseif not visualInfo.isUsable then
				model.Border:SetAtlas("transmog-wardrobe-border-unusable");
			else
				model.Border:SetAtlas("transmog-wardrobe-border-collected");
			end

			-- new appearance
			if C_TransmogCollection.IsNewAppearance(visualInfo.visualID) then
				model.NewString:Show();
				model.NewGlow:Show();
			else
				model.NewString:Hide();
				model.NewGlow:Hide();
			end

			-- favorite
			model.Favorite.Icon:SetShown(visualInfo.isFavorite);
			-- hide visual option
			model.HideVisual.Icon:Hide();
			-- highlight currently previewed item
			local isActiveVisual = self.activeVisualID and (visualInfo.visualID == self.activeVisualID);
			model.TransmogStateTexture:SetShown(isActiveVisual or false);
			-- slot invalid / disabled overlay
			local canDisplayVisuals = visualInfo.canDisplayOnPlayer;
			model.SlotInvalidTexture:SetShown(not canDisplayVisuals);
			model.DisabledOverlay:SetShown(not canDisplayVisuals);

			if GameTooltip:GetOwner() == model then
				model:OnEnter();
			end
		else
			model:Hide();
			model.visualInfo = nil;
		end
	end
end

function MCUDR_AppearancesMixin:InitFilterButton()
	local function CreateSourceFilters(description)
		description:CreateButton(CHECK_ALL, function()
			C_TransmogCollection.SetAllSourceTypeFilters(true);
			return MenuResponse.Refresh;
		end);

		description:CreateButton(UNCHECK_ALL, function()
			C_TransmogCollection.SetAllSourceTypeFilters(false);
			return MenuResponse.Refresh;
		end);

		local function IsChecked(filter)
			return C_TransmogCollection.IsSourceTypeFilterChecked(filter);
		end

		local function SetChecked(filter)
			C_TransmogCollection.SetSourceTypeFilter(filter, not IsChecked(filter));
		end

		for filterIndex = 1, C_TransmogCollection.GetNumTransmogSources() do
			if C_TransmogCollection.IsValidTransmogSource(filterIndex) then
				description:CreateCheckbox(_G["TRANSMOG_SOURCE_"..filterIndex], IsChecked, SetChecked, filterIndex);
			end
		end
	end

	-- Hide the reset button (red X) — not needed in our standalone grid
	if self.FilterButton.ResetButton then
		self.FilterButton.ResetButton:Hide();
		self.FilterButton.ResetButton:SetScript("OnShow", self.FilterButton.ResetButton.Hide);
	end

	self.FilterButton:SetupMenu(function(dropdown, rootDescription)
		rootDescription:SetTag("MENU_MCUDR_WARDROBE_FILTER");

		rootDescription:CreateCheckbox(COLLECTED, C_TransmogCollection.GetCollectedShown, function()
			C_TransmogCollection.SetCollectedShown(not C_TransmogCollection.GetCollectedShown());
			if self:IsVisible() then
				self:RefreshVisualsList();
				self:UpdateItems();
			end
		end);

		rootDescription:CreateCheckbox(NOT_COLLECTED, C_TransmogCollection.GetUncollectedShown, function()
			C_TransmogCollection.SetUncollectedShown(not C_TransmogCollection.GetUncollectedShown());
			if self:IsVisible() then
				self:RefreshVisualsList();
				self:UpdateItems();
			end
		end);

		rootDescription:CreateCheckbox(TRANSMOG_SHOW_ALL_FACTIONS, C_TransmogCollection.GetAllFactionsShown, function()
			C_TransmogCollection.SetAllFactionsShown(not C_TransmogCollection.GetAllFactionsShown());
			if self:IsVisible() then
				self:RefreshVisualsList();
				self:UpdateItems();
			end
		end);

		rootDescription:CreateCheckbox(TRANSMOG_SHOW_ALL_RACES, C_TransmogCollection.GetAllRacesShown, function()
			C_TransmogCollection.SetAllRacesShown(not C_TransmogCollection.GetAllRacesShown());
			if self:IsVisible() then
				self:RefreshVisualsList();
				self:UpdateItems();
			end
		end);

		local submenu = rootDescription:CreateButton(SOURCES);
		CreateSourceFilters(submenu);
	end);
end

function MCUDR_AppearancesMixin:RefreshWeaponDropdown()
	if not self.WeaponDropdown then return; end

	if not self.transmogLocation or not self.transmogLocation:IsEitherHand() or not self.activeCategory then
		self.WeaponDropdown:Hide();
		return;
	end

	local _, isWeapon = C_TransmogCollection.GetCategoryInfo(self.activeCategory);
	if not isWeapon then
		self.WeaponDropdown:Hide();
		return;
	end

	self.WeaponDropdown:Show();

	local function IsSelected(categoryID)
		return categoryID == self.activeCategory;
	end

	local function SetSelected(categoryID)
		if categoryID ~= self.activeCategory then
			self:SetActiveCategory(categoryID);
			self:RefreshVisualsList();
			self.PagingFrame:SetCurrentPage(1);
			self:UpdateItems();
			self:RefreshWeaponDropdown();
		end
	end

	self.WeaponDropdown:SetupMenu(function(_dropdown, rootDescription)
		rootDescription:SetTag("MENU_MCUDR_WEAPONS_FILTER");

		for categoryID = FIRST_TRANSMOG_COLLECTION_WEAPON_TYPE, LAST_TRANSMOG_COLLECTION_WEAPON_TYPE do
			if self:IsValidWeaponCategoryForSlot(categoryID) then
				local name = C_TransmogCollection.GetCategoryInfo(categoryID);
				if name then
					rootDescription:CreateRadio(name, IsSelected, SetSelected, categoryID);
				end
			end
		end
	end);
end

function MCUDR_AppearancesMixin:RefreshClassDropdown()
	if not self.ClassDropdown then return; end

	if not C_TransmogCollection.GetClassFilter then
		self.ClassDropdown:Hide();
		return;
	end

	self.ClassDropdown:Show();

	local function IsSelected(classID)
		return classID == C_TransmogCollection.GetClassFilter();
	end

	local function SetSelected(classID)
		C_TransmogCollection.SetClassFilter(classID);
		-- Re-run SetActiveSlot to re-evaluate valid categories for the new class
		if self.transmogLocation then
			self.lastWeaponCategory = nil;
			self:SetActiveSlot(self.transmogLocation);
		else
			self:RefreshVisualsList();
			self.PagingFrame:SetCurrentPage(1);
			self:UpdateItems();
		end
		self:RefreshClassDropdown();
	end

	self.ClassDropdown:SetupMenu(function(_dropdown, rootDescription)
		rootDescription:SetTag("MENU_MCUDR_CLASS_FILTER");

		for classID = 1, GetNumClasses() do
			local classInfo = C_CreatureInfo.GetClassInfo(classID);
			if classInfo then
				local classColor = GetClassColorObj(classInfo.classFile) or HIGHLIGHT_FONT_COLOR;
				local coloredName = classColor:WrapTextInColorCode(classInfo.className);
				rootDescription:CreateRadio(coloredName, IsSelected, SetSelected, classID);
			end
		end
	end);
end

---------------------------------------------------------------------------
-- MCUDR_WardrobeModelMixin
---------------------------------------------------------------------------
MCUDR_WardrobeModelMixin = {};

function MCUDR_WardrobeModelMixin:OnLoad()
	self:SetAutoDress(false);
end

function MCUDR_WardrobeModelMixin:OnModelLoaded()
	if self.cameraID then
		Model_ApplyUICamera(self, self.cameraID);
	end
end

function MCUDR_WardrobeModelMixin:OnMouseDown(button)
	if button ~= "LeftButton" then
		return;
	end

	local visualInfo = self.visualInfo;
	if not visualInfo then
		return;
	end

	local parentFrame = self:GetParent();
	if not parentFrame then
		return;
	end

	-- Get the sourceID for this visual
	local sourceID = parentFrame:GetAnAppearanceSourceFromVisual(visualInfo.visualID, nil);
	if not sourceID or sourceID == Constants.Transmog.NoTransmogID then
		return;
	end

	-- Try on the item on the dressing room model
	local dressingRoomFrame = MCUDressingRoomFrame;
	if not dressingRoomFrame or not dressingRoomFrame.CharacterPreview or not dressingRoomFrame.CharacterPreview.ModelScene then
		return;
	end

	local actor = dressingRoomFrame.CharacterPreview.ModelScene:GetPlayerActor();
	if not actor then
		return;
	end

	actor:TryOn(sourceID);
	PlaySound(SOUNDKIT.UI_TRANSMOG_APPLY);

	-- Highlight this visual in the grid
	parentFrame.activeVisualID = visualInfo.visualID;
	parentFrame:UpdateItems();

	-- Update MCUDR_PreviewedSlots using the currently selected slot
	local appliedSlotID
	if MCUDR_PreviewedSlots then
		local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID);
		if sourceInfo then
			-- Use the slot the user actually selected, not the item's default slot
			local charPreview = dressingRoomFrame.CharacterPreview
			if charPreview and charPreview.selectedSlotData and charPreview.selectedSlotData.transmogLocation then
				appliedSlotID = charPreview.selectedSlotData.transmogLocation:GetSlotID()
			end
			if not appliedSlotID then
				local slotName = MCUDR_WardrobeUtil.GetSlotFromCategoryID(sourceInfo.categoryID or parentFrame.activeCategory);
				if slotName then
					appliedSlotID = GetInventorySlotInfo(slotName);
				end
			end
			if appliedSlotID then
				local itemIcon = nil;
				if sourceInfo.itemID then
					itemIcon = C_Item.GetItemIconByID(sourceInfo.itemID);
				end
				MCUDR_PreviewedSlots[appliedSlotID] = {
					icon = itemIcon,
					sourceID = sourceID,
					name = sourceInfo.name,
					quality = sourceInfo.quality,
				};
			end
		end
	end

	local function IsTwoHandCategory(catID)
		return catID and (
			(catID == Enum.TransmogCollectionType.TwoHAxe)
			or (catID == Enum.TransmogCollectionType.TwoHSword)
			or (catID == Enum.TransmogCollectionType.TwoHMace)
			or (catID == Enum.TransmogCollectionType.Staff)
			or (catID == Enum.TransmogCollectionType.Polearm)
			or (catID == Enum.TransmogCollectionType.Bow)
			or (catID == Enum.TransmogCollectionType.Gun)
			or (catID == Enum.TransmogCollectionType.Crossbow)
		);
	end

	-- If a two-handed weapon was equipped to mainhand, clear the offhand preview
	if MCUDR_PreviewedSlots and appliedSlotID == 16 then -- MAINHANDSLOT
		if IsTwoHandCategory(parentFrame.activeCategory) then
			MCUDR_PreviewedSlots[17] = nil; -- SECONDARYHANDSLOT
		end
	end

	-- If an offhand item was equipped, clear mainhand if it was a two-hander
	if MCUDR_PreviewedSlots and appliedSlotID == 17 then -- SECONDARYHANDSLOT
		local mainPreview = MCUDR_PreviewedSlots[16];
		if mainPreview and mainPreview.sourceID then
			local mainSourceInfo = C_TransmogCollection.GetSourceInfo(mainPreview.sourceID);
			if mainSourceInfo and IsTwoHandCategory(mainSourceInfo.categoryID) then
				MCUDR_PreviewedSlots[16] = nil; -- MAINHANDSLOT
			end
		end
	end

	-- Refresh dressing room slots display
	if dressingRoomFrame.CharacterPreview and dressingRoomFrame.CharacterPreview.RefreshDressingRoomSlots then
		C_Timer.After(0.3, function()
			if dressingRoomFrame.CharacterPreview:IsVisible() then
				dressingRoomFrame.CharacterPreview:RefreshDressingRoomSlots();
			end
		end);
	end
end

function MCUDR_WardrobeModelMixin:OnEnter()
	if not self.visualInfo then
		return;
	end

	local parentFrame = self:GetParent();
	if not parentFrame then
		return;
	end

	-- Clear new appearance flag on hover
	if C_TransmogCollection.IsNewAppearance(self.visualInfo.visualID) then
		C_TransmogCollection.ClearNewAppearance(self.visualInfo.visualID);
		self.NewString:Hide();
		self.NewGlow:Hide();
	end

	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");

	local visualID = self.visualInfo.visualID;
	local sources = MCUDR_WardrobeUtil.GetSortedAppearanceSources(visualID, parentFrame.activeCategory, parentFrame.transmogLocation);

	if #sources == 0 then
		GameTooltip:SetText(RETRIEVING_ITEM_INFO, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
		GameTooltip:Show();
		return;
	end

	-- Use first source for primary display
	local primarySource = sources[1];

	-- Name with quality color
	local nameText, nameColor = MCUDR_WardrobeUtil.GetAppearanceNameTextAndColor(primarySource);
	GameTooltip:SetText(nameText, nameColor.r, nameColor.g, nameColor.b);

	-- Collected/uncollected status or source type
	local sourceText, sourceColor = MCUDR_WardrobeUtil.GetAppearanceSourceTextAndColor(primarySource);
	if sourceText then
		GameTooltip:AddLine(sourceText, sourceColor.r, sourceColor.g, sourceColor.b);
	end

	-- Use error
	if primarySource.useError then
		GameTooltip:AddLine(primarySource.useError, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true);
	end

	-- Show all sources if there are multiple
	if #sources > 1 then
		GameTooltip:AddLine(" ");
		for i, sourceInfo in ipairs(sources) do
			local text, color = MCUDR_WardrobeUtil.GetAppearanceNameTextAndColor(sourceInfo);
			if sourceInfo.isCollected then
				GameTooltip:AddLine(text, color.r, color.g, color.b);
			else
				local sText, sColor = MCUDR_WardrobeUtil.GetAppearanceSourceTextAndColor(sourceInfo);
				if sText then
					GameTooltip:AddDoubleLine(text, sText, color.r, color.g, color.b, sColor.r, sColor.g, sColor.b);
				else
					GameTooltip:AddLine(text, color.r, color.g, color.b);
				end
			end
		end
	end

	-- Left-click instruction
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine(WARDROBE_TOOLTIP_CLICK_TO_PREVIEW or "Click to preview", GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b);

	GameTooltip:Show();
end

function MCUDR_WardrobeModelMixin:OnLeave()
	GameTooltip:Hide();
	ResetCursor();
end

function MCUDR_WardrobeModelMixin:OnShow()
	-- No-op; kept for XML script handler
end

function MCUDR_WardrobeModelMixin:OnHide()
	self.visualInfo = nil;
end
