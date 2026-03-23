MCUDR_OutfitEntryMixin = {
	DYNAMIC_EVENTS = {
		"SPELL_UPDATE_COOLDOWN"
	};
};

function MCUDR_OutfitEntryMixin:OnLoad()
	self.OutfitIcon:RegisterForDrag("LeftButton");

	self.OutfitIcon:SetScript("OnEnter", function()
		local elementData = self:GetElementData();
		if not elementData then
			return;
		end

		GameTooltip:SetOwner(self.OutfitIcon, "ANCHOR_RIGHT");
		GameTooltip:SetText(elementData.name or "", 1, 0.82, 0);
		GameTooltip:AddLine("Click to load appearance", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
		GameTooltip:Show();
	end);

	self.OutfitIcon:SetScript("OnLeave", GameTooltip_Hide);

	self.OutfitIcon:SetScript("OnDragStart", function()
		self:PickupOutfit();
	end);

	self.OutfitButton:SetScript("OnClick", function(_button, buttonName)
		if buttonName == "LeftButton" then
			PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);
			self:SelectEntry();
		elseif buttonName == "RightButton" then
			MenuUtil.CreateContextMenu(self, function(_owner, rootDescription)
				rootDescription:SetTag("MENU_MCUDR_OUTFIT_ENTRY");

				rootDescription:CreateButton(EDIT or "Rename", function()
					self:OpenEditPopup();
				end);

				rootDescription:CreateButton(DELETE or "Delete", function()
					if self.elementData and self.elementData.outfitID then
						local setName = self.elementData.name or "";
						StaticPopup_Show("MCU_DR_DELETE_CUSTOM_SET", setName, nil, self.elementData.outfitID);
					end
				end);
			end);
		end
	end);

	local hideCountdownNumbers = true;
	self.OutfitIcon.Cooldown:SetHideCountdownNumbers(hideCountdownNumbers);

	local drawBling = false;
	self.OutfitIcon.Cooldown:SetDrawBling(drawBling);
end

function MCUDR_OutfitEntryMixin:OnShow()
	FrameUtil.RegisterFrameForEvents(self, self.DYNAMIC_EVENTS);
	self:UpdateCooldown();
end

function MCUDR_OutfitEntryMixin:OnHide()
	FrameUtil.UnregisterFrameForEvents(self, self.DYNAMIC_EVENTS);
end

function MCUDR_OutfitEntryMixin:OnEvent(event, ...)
	if event == "SPELL_UPDATE_COOLDOWN" then
		self:UpdateCooldown();
	end
end

function MCUDR_OutfitEntryMixin:Init(elementData)
	self.elementData = elementData;

	self.OutfitIcon:SetScript("OnClick", function(_button, buttonName)
		-- Click icon to load the appearance
		if elementData.onClickCallback then
			elementData.onClickCallback();
		end
	end);

	self.OutfitIcon.Icon:SetTexture(elementData.icon or 136516);
	self.OutfitIcon.OverlayActive:SetShown(false);

	if self.OutfitIcon.OverlayLocked then
		self.OutfitIcon.OverlayLocked:SetShown(false);
	end

	self.OutfitIcon:SetEnabled(true);
	self.OutfitIcon.Icon:SetDesaturated(inTransmogEvent and not elementData.isEventOutfit);

	local normalAtlas = "transmog-outfit-card";
	if elementData.isEventOutfit then
		normalAtlas = "transmog-outfit-card-tofs";
	end
	self.OutfitButton.NormalTexture:SetAtlas(normalAtlas, TextureKitConstants.IgnoreAtlasSize);

	-- Text
	local textContent = self.OutfitButton.TextContent;
	textContent.Name:SetText(elementData.name);

	local situationText = "";
	if elementData.situationCategories then
		for index, situationCategory in ipairs(elementData.situationCategories) do
			situationText = situationText..situationCategory;

			if index ~= #elementData.situationCategories then
				situationText = situationText..TRANSMOG_SITUATION_CATEGORY_LIST_SEPARATOR;
			end
		end
	end
	textContent.SituationInfo:SetShown(situationText ~= "");
	textContent.SituationInfo:SetText(situationText);
	textContent:Layout();

	-- Selected state
	local viewedOutfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID();
	self:SetSelected(elementData.outfitID == viewedOutfitID);
end

function MCUDR_OutfitEntryMixin:SetSelected(selected)
	self.OutfitButton.Selected:SetShown(selected);
	self.OutfitButton.TextContent.Name:SetFontObject(selected and "GameFontHighlight" or "GameFontNormal");
end

function MCUDR_OutfitEntryMixin:PickupOutfit()
	local elementData = self:GetElementData();
	if not elementData then
		return;
	end

	C_TransmogOutfitInfo.PickupOutfit(elementData.outfitID);
end

function MCUDR_OutfitEntryMixin:SelectEntry()
	local elementData = self:GetElementData();
	if not elementData then
		return;
	end

	-- If in a transmog event (trial of style), selecting an outfit entry applies that appearance to the event outfit.
	if C_TransmogOutfitInfo.InTransmogEvent() then
		if not elementData.isEventOutfit then
			C_TransmogOutfitInfo.SetOutfitToOutfit(elementData.outfitID);
		end
		return;
	end

	local function SelectCallback()
		-- Call the click callback regardless, for things like changing tabs even if selecting the same outfit.
		elementData.onClickCallback();

		local viewedOutfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID();
		if elementData.outfitID == viewedOutfitID then
			return;
		end

		C_TransmogOutfitInfo.ChangeViewedOutfit(elementData.outfitID);
	end;

	local includeViewedOutfit = false;
	self:CheckPendingAction(SelectCallback, includeViewedOutfit);
end

function MCUDR_OutfitEntryMixin:OpenEditPopup()
	local elementData = self:GetElementData();
	if not elementData then
		return;
	end

	elementData.onEditCallback();
end

function MCUDR_OutfitEntryMixin:CheckPendingAction(callback, includeViewedOutfit)
	local elementData = self:GetElementData();
	if not elementData or not callback then
		return;
	end

	local viewedOutfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID();
	local checkPending = includeViewedOutfit or elementData.outfitID ~= viewedOutfitID;

	if checkPending and (C_TransmogOutfitInfo.HasPendingOutfitTransmogs() or C_TransmogOutfitInfo.HasPendingOutfitSituations()) then
		local dialogData = {
			confirmCallback = callback
		};
		StaticPopup_Show("MCU_DR_PENDING_CHANGES", nil, nil, dialogData);
	else
		callback();
	end
end

function MCUDR_OutfitEntryMixin:UpdateCooldown()
	local cooldownInfo = C_Spell.GetSpellCooldown(Constants.TransmogOutfitDataConsts.EQUIP_TRANSMOG_OUTFIT_MANUAL_SPELL_ID);
	if cooldownInfo then
		CooldownFrame_Set(self.OutfitIcon.Cooldown, cooldownInfo.startTime, cooldownInfo.duration, cooldownInfo.isEnabled);
	else
		CooldownFrame_Clear(self.OutfitIcon.Cooldown);
	end
end


MCUDR_SlotMixin = {};

function MCUDR_SlotMixin:OnClick(buttonName)
	if not self.slotData then
		return;
	end

	local slotID = self.slotData.transmogLocation and self.slotData.transmogLocation.GetSlot
		and self.slotData.transmogLocation:GetSlot();

	if buttonName == "LeftButton" then
		PlaySound(SOUNDKIT.UI_TRANSMOG_GEAR_SLOT_CLICK);
		self:OnSelect();

		-- Navigate the embedded Wardrobe to this slot's category
		if WardrobeCollectionFrame and WardrobeCollectionFrame.ItemsCollectionFrame
		   and self.slotData.transmogLocation then
			WardrobeCollectionFrame.ItemsCollectionFrame:SetActiveSlot(self.slotData.transmogLocation);

			-- If this slot has a previewed item, navigate to it using our tracked data
			local preview = MCUDR_PreviewedSlots and slotID and MCUDR_PreviewedSlots[slotID];
			if preview and preview.sourceID then
				C_Timer.After(0.3, function()
					pcall(function()
						if WardrobeCollectionFrame.GoToItem then
							WardrobeCollectionFrame:GoToItem(preview.sourceID);
						end
					end);
				end);
			end
		end
	elseif buttonName == "RightButton" then
		-- Right-click: remove preview and re-equip this slot
		if slotID then
			local actor = MCUDressingRoomFrame and MCUDressingRoomFrame.CharacterPreview
				and MCUDressingRoomFrame.CharacterPreview.ModelScene
				and MCUDressingRoomFrame.CharacterPreview.ModelScene:GetPlayerActor();
			if actor then
				PlaySound(SOUNDKIT.UI_TRANSMOG_REVERTING_GEAR_SLOT);
				-- Re-dress this slot with equipped gear instead of undressing
				actor:DressPlayerSlot(slotID);
				-- Clear preview tracking for this slot
				if MCUDR_PreviewedSlots then
					MCUDR_PreviewedSlots[slotID] = nil;
				end
				C_Timer.After(0.3, function()
					if MCUDressingRoomFrame and MCUDressingRoomFrame.CharacterPreview
					   and MCUDressingRoomFrame.CharacterPreview.RefreshDressingRoomSlots then
						MCUDressingRoomFrame.CharacterPreview:RefreshDressingRoomSlots();
					end
				end);
			end
		end
	end

	self:OnEnter();
end

function MCUDR_SlotMixin:OnEnter()
	if not self.slotData or not self.slotData.transmogLocation then
		return;
	end

	-- Dressing room: show simple slot info instead of transmog pending state
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	local loc = self.slotData.transmogLocation;
	local slotName = loc.GetSlotName and loc:GetSlotName() or "";
	local slotID = loc.GetSlot and loc:GetSlot();
	if slotID then
		GameTooltip:SetInventoryItem("player", slotID);
	else
		GameTooltip:SetText(slotName);
	end
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("Click to browse appearances for this slot", 0.5, 0.5, 0.5);
	GameTooltip:AddLine("Right-click to undress this slot", 0.5, 0.5, 0.5);
	GameTooltip:Show();
end

function MCUDR_SlotMixin:OnLeave()
	if self.itemDataLoadedCancelFunc then
		self.itemDataLoadedCancelFunc();
		self.itemDataLoadedCancelFunc = nil;
	end

	GameTooltip:Hide();
end

function MCUDR_SlotMixin:OnSelect()
	local forceRefresh = false;
	self.slotData.transmogFrame:SelectSlot(self, forceRefresh);
end

function MCUDR_SlotMixin:Init(slotData)
	self.slotData = slotData;
	self.lastOutfitSlotInfo = nil;
end

function MCUDR_SlotMixin:Release()
	self:SetSelected(false);
	self:SetParent(nil);
end

function MCUDR_SlotMixin:GetEffectiveTransmogID()
	local outfitSlotInfo = self:GetSlotInfo();
	if not outfitSlotInfo then
		return Constants.Transmog.NoTransmogID;
	end

	return outfitSlotInfo.transmogID;
end

function MCUDR_SlotMixin:GetSlotInfo()
	if not self.slotData or not self.slotData.transmogLocation then
		return nil;
	end

	local slotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(self.slotData.transmogLocation:GetSlot(), self.slotData.transmogLocation:GetType(), self.slotData.currentWeaponOptionInfo.weaponOption);

	-- Some specific weapons may not be able to support illusions.
	if self.slotData.transmogLocation:IsIllusion() then
		local appearanceType = Enum.TransmogType.Appearance;
		local appearanceSlotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(self.slotData.transmogLocation:GetSlot(), appearanceType, self.slotData.currentWeaponOptionInfo.weaponOption);
		if appearanceSlotInfo then
			-- If we have a valid warning state, make sure it can show relative to other possible warnings.
			local cannotSupportIllusions = appearanceSlotInfo.transmogID ~= Constants.Transmog.NoTransmogID and not TransmogUtil.CanEnchantSource(appearanceSlotInfo.transmogID);
			if cannotSupportIllusions and slotInfo.warning < Enum.TransmogOutfitSlotWarning.WeaponDoesNotSupportIllusions then
				slotInfo.warning = Enum.TransmogOutfitSlotWarning.WeaponDoesNotSupportIllusions;
				slotInfo.warningText = TRANSMOGRIFY_ILLUSION_INVALID_ITEM;
			end
		end
	end

	return slotInfo;
end

function MCUDR_SlotMixin:GetSlot()
	if not self.slotData or not self.slotData.transmogLocation then
		return nil;
	end

	return self.slotData.transmogLocation:GetSlot();
end

function MCUDR_SlotMixin:GetTransmogLocation()
	if not self.slotData then
		return nil;
	end

	return self.slotData.transmogLocation;
end

function MCUDR_SlotMixin:GetCurrentWeaponOptionInfo()
	if not self.slotData then
		return nil;
	end

	return self.slotData.currentWeaponOptionInfo;
end

function MCUDR_SlotMixin:SetCurrentWeaponOptionInfo(weaponOptionInfo)
	if not self.slotData or not weaponOptionInfo.enabled then
		return;
	end

	self.slotData.currentWeaponOptionInfo = weaponOptionInfo;
	if self.slotData.transmogLocation:IsAppearance() then
		C_TransmogOutfitInfo.SetViewedWeaponOptionForSlot(self.slotData.transmogLocation:GetSlot(), weaponOptionInfo.weaponOption);
	end
end

function MCUDR_SlotMixin:SetCurrentWeaponOption(weaponOption)
	if not self.slotData then
		return false;
	end

	-- If weaponOption is not set, set to the first valid option.
	local foundWeaponOption;
	for _index, weaponOptionInfo in ipairs(self.slotData.weaponOptionsInfo) do
		if weaponOptionInfo.enabled and (not weaponOption or weaponOptionInfo.weaponOption == weaponOption) then
			self:SetCurrentWeaponOptionInfo(weaponOptionInfo);
			foundWeaponOption = true;
			break;
		end
	end

	if not foundWeaponOption and self.slotData.artifactOptionsInfo then
		for _index, artifactOptionInfo in ipairs(self.slotData.artifactOptionsInfo) do
			if artifactOptionInfo.enabled and (not weaponOption or artifactOptionInfo.weaponOption == weaponOption) then
				self:SetCurrentWeaponOptionInfo(artifactOptionInfo);
				foundWeaponOption = true;
				break;
			end
		end
	end

	return foundWeaponOption;
end


MCUDR_AppearanceSlotMixin = CreateFromMixins(MCUDR_SlotMixin);

MCUDR_AppearanceSlotMixin.DEFAULT_WEAPON_OPTION_INFO = {
	weaponOption = Enum.TransmogOutfitSlotOption.None,
	name = "",
	enabled = true
};

MCUDR_AppearanceSlotMixin.DEFAULT_ICON_SIZE = 45;

function MCUDR_AppearanceSlotMixin:OnLoad()
	self.SavedFrame.Anim:SetScript("OnFinished", function()
		self.SavedFrame:Hide();
		self:Update();
	end);
end

function MCUDR_AppearanceSlotMixin:OnShow()
	self:Update();
end

function MCUDR_AppearanceSlotMixin:OnTransmogrifySuccess()
	-- Don't do anything if already animating.
	if not self.slotData or self.SavedFrame:IsShown() then
		return;
	end

	self.SavedFrame:Show();
	self.SavedFrame.Anim:Restart();
end

-- Overridden.
function MCUDR_AppearanceSlotMixin:Init(slotData)
	MCUDR_SlotMixin.Init(self, slotData);

	self:RefreshWeaponOptions();

	self.FlyoutDropdown:SetupMenu(function(_dropdown, rootDescription)
		rootDescription:SetTag("MENU_TRANSMOG_WEAPON_OPTIONS");

		local function IsChecked(optionInfo)
			return optionInfo.weaponOption == self.slotData.currentWeaponOptionInfo.weaponOption;
		end

		local function SetChecked(optionInfo)
			if optionInfo == self.slotData.currentWeaponOptionInfo then
				return;
			end

			self:SetCurrentWeaponOptionInfo(optionInfo);

			if self.illusionSlotFrame then
				self.illusionSlotFrame:SetCurrentWeaponOptionInfo(self.slotData.currentWeaponOptionInfo);
			end

			-- Force update selected slot data and refresh visuals based on new weapon option.
			local forceRefresh = true;
			self.slotData.transmogFrame:SelectSlot(self, forceRefresh);
		end

		local function CreateWarningIcon(frame, option)
			-- Do not check this option if it is the current weapon option.
			if self.slotData.currentWeaponOptionInfo.weaponOption == option then
				return;
			end

			if not self.slotData.transmogLocation then
				return;
			end

			-- Only create warning if this weapon option (or any associated illusion slot) has pending changes.
			local outfitSlotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(self.slotData.transmogLocation:GetSlot(), self.slotData.transmogLocation:GetType(), option);
			local hasSlotChanges = outfitSlotInfo and (outfitSlotInfo.hasPending or outfitSlotInfo.isTransmogrified);

			local hasIllusionSlotChanges = false;
			if self.illusionSlotFrame then
				local outfitIllusionSlotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(self.illusionSlotFrame:GetTransmogLocation():GetSlot(), self.illusionSlotFrame:GetTransmogLocation():GetType(), option);
				hasIllusionSlotChanges = outfitIllusionSlotInfo and (outfitIllusionSlotInfo.hasPending or outfitIllusionSlotInfo.isTransmogrified);
			end

			if not hasSlotChanges and not hasIllusionSlotChanges then
				return;
			end

			local warningIcon = frame:AttachTexture();
			warningIcon:SetPoint("RIGHT");
			warningIcon:SetAtlas("transmog-icon-warning-small", TextureKitConstants.UseAtlasSize);
		end

		for _index, weaponOptionInfo in ipairs(self.slotData.weaponOptionsInfo) do
			local elementDescription = rootDescription:CreateRadio(weaponOptionInfo.name, IsChecked, SetChecked, weaponOptionInfo);
			elementDescription:AddInitializer(function(frame, _description, _menu)
				CreateWarningIcon(frame, weaponOptionInfo.weaponOption);
			end);
			elementDescription:SetEnabled(weaponOptionInfo.enabled);
		end

		if self.slotData.artifactOptionsInfo and #self.slotData.artifactOptionsInfo > 0 then
			rootDescription:CreateDivider();
			rootDescription:CreateTitle(TRANSMOG_ARTIFACT_OPTIONS_HEADER);

			for _index, artifactOptionInfo in ipairs(self.slotData.artifactOptionsInfo) do
				local elementDescription = rootDescription:CreateRadio(artifactOptionInfo.name, IsChecked, SetChecked, artifactOptionInfo);
				elementDescription:AddInitializer(function(frame, _description, _menu)
					CreateWarningIcon(frame, artifactOptionInfo.weaponOption);
				end);
				elementDescription:SetEnabled(artifactOptionInfo.enabled);
			end
		end
	end);
end

-- Overridden.
function MCUDR_AppearanceSlotMixin:Release()
	MCUDR_SlotMixin.Release(self);
	self:SetIllusionSlotFrame(nil);
end

function MCUDR_AppearanceSlotMixin:SetIllusionSlotFrame(illusionSlotFrame)
	self.illusionSlotFrame = illusionSlotFrame;
end

function MCUDR_AppearanceSlotMixin:GetIllusionSlotFrame()
	return self.illusionSlotFrame;
end

function MCUDR_AppearanceSlotMixin:SetSelected(selected)
	if not self.slotData then
		return;
	end

	self.SelectedFrame:SetShown(selected);

	if selected then
		local totalOptions = 0;
		if self.slotData.weaponOptionsInfo then
			totalOptions = totalOptions + #self.slotData.weaponOptionsInfo;
		end

		if self.slotData.artifactOptionsInfo then
			totalOptions = totalOptions + #self.slotData.artifactOptionsInfo;
		end

		self.FlyoutDropdown:SetShown(totalOptions > 1);
	else
		self.FlyoutDropdown:Hide();
	end
end

function MCUDR_AppearanceSlotMixin:RefreshWeaponOptions()
	if not self.slotData or not self.slotData.transmogLocation then
		return;
	end

	-- A weapon slot can have several weapon or artifact options associated with them, and players can select which option they are editing for an outfit via a dropdown.
	-- For example the main hand weapon slot may have both 1 handed and 2 handed weapon options.
	self.slotData.weaponOptionsInfo, self.slotData.artifactOptionsInfo = C_TransmogOutfitInfo.GetWeaponOptionsForSlot(self.slotData.transmogLocation:GetSlot());

	if (not self.slotData.weaponOptionsInfo or #self.slotData.weaponOptionsInfo == 0) and (not self.slotData.artifactOptionsInfo or #self.slotData.artifactOptionsInfo == 0) then
		self:SetCurrentWeaponOptionInfo(self.DEFAULT_WEAPON_OPTION_INFO);
	else
		-- See if the current weapon option still exists and is enabled. If it is, use that, otherwise select new option.
		local foundWeaponOption;
		if self.slotData.currentWeaponOptionInfo then
			foundWeaponOption = self:SetCurrentWeaponOption(self.slotData.currentWeaponOptionInfo);
		end

		-- Current option not found, select the preferred first option based on equipped gear for this slot.
		if not foundWeaponOption then
			local equippedWeaponOption = C_TransmogOutfitInfo.GetEquippedSlotOptionFromTransmogSlot(self.slotData.transmogLocation:GetSlot());
			if equippedWeaponOption then
				foundWeaponOption = self:SetCurrentWeaponOption(equippedWeaponOption);
			end
		end

		-- No current or preferred option found, select the first valid option instead.
		if not foundWeaponOption then
			local weaponOption = nil;
			foundWeaponOption = self:SetCurrentWeaponOption(weaponOption);
		end

		-- No valid options found, set to default.
		if not foundWeaponOption then
			self:SetCurrentWeaponOptionInfo(self.DEFAULT_WEAPON_OPTION_INFO);
		end
	end

	if self.illusionSlotFrame then
		self.illusionSlotFrame:SetCurrentWeaponOptionInfo(self.slotData.currentWeaponOptionInfo);
	end

	-- Close menu as it could show outdated data.
	self.FlyoutDropdown:CloseMenu();
end

function MCUDR_AppearanceSlotMixin:Update()
	if not self.slotData or not self.slotData.transmogLocation or not self:IsShown() then
		return;
	end

	local outfitSlotInfo = self:GetSlotInfo();
	if not outfitSlotInfo then
		return;
	end

	self:SetEnabled(outfitSlotInfo.canTransmogrify);

	-- Base icon texture.
	-- The texture will either be whatever is set in outfitSlotInfo, or the default slot texture if unset.
	if outfitSlotInfo.texture then
		self.Icon:SetTexture(outfitSlotInfo.texture);
		self.Icon:SetSize(self.DEFAULT_ICON_SIZE, self.DEFAULT_ICON_SIZE);
	else
		local unassignedAtlas = C_TransmogOutfitInfo.GetUnassignedAtlasForSlot(self.slotData.transmogLocation:GetSlot());
		if unassignedAtlas then
			self.Icon:SetAtlas(unassignedAtlas, TextureKitConstants.UseAtlasSize);
		end
	end

	-- Border art.
	local border = "transmog-gearslot-default";
	if not outfitSlotInfo.canTransmogrify then
		border = "transmog-gearslot-disabled";
	elseif outfitSlotInfo.displayType == Enum.TransmogOutfitDisplayType.Assigned then
		border = "transmog-gearslot-transmogrified";
	elseif outfitSlotInfo.displayType == Enum.TransmogOutfitDisplayType.Hidden then
		border = "transmog-gearslot-transmogrified-hidden";
	end

	self.Border:SetAtlas(border, TextureKitConstants.UseAtlasSize);
	self:SetHighlightAtlas(border, "ADD");

	-- Overlay icons.
	self.DisabledIcon:SetShown(not outfitSlotInfo.canTransmogrify);
	self.HiddenVisualIcon:SetShown(outfitSlotInfo.displayType == Enum.TransmogOutfitDisplayType.Hidden);
	self.ShowEquippedIcon:SetShown(outfitSlotInfo.displayType == Enum.TransmogOutfitDisplayType.Equipped);
	self.WarningFrame:SetShown(outfitSlotInfo.warning ~= Enum.TransmogOutfitSlotWarning.Ok);

	-- Pending frame.
	if outfitSlotInfo.hasPending and not self.SavedFrame:IsShown() then
		self.PendingFrame:Show();
		self.PendingFrame.AnimLoop:Restart();

		-- Only play the intro animation if things actually changed on the slot.
		if not self.lastOutfitSlotInfo or self.lastOutfitSlotInfo.displayType ~= outfitSlotInfo.displayType or (self.lastOutfitSlotInfo.displayType ~= Enum.TransmogOutfitDisplayType.Unassigned and self.lastOutfitSlotInfo.transmogID ~= outfitSlotInfo.transmogID) then
			self.PendingFrame.AnimStart:Restart();
		end
	else
		self.PendingFrame.AnimStart:Stop();
		self.PendingFrame.AnimLoop:Stop();
		self.PendingFrame:Hide();
	end

	self.lastOutfitSlotInfo = outfitSlotInfo;
end

function MCUDR_AppearanceSlotMixin:GetCurrentIcons()
	-- Collect all icons associated for this slot (and illusion slot, if present) for all weapon option types.
	local transmogIcons = {};

	if not self.slotData then
		return transmogIcons;
	end

	local function PopulateIcons(weaponOption)
		local outfitSlotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(self.slotData.transmogLocation:GetSlot(), self.slotData.transmogLocation:GetType(), weaponOption);
		if outfitSlotInfo and outfitSlotInfo.texture then
			table.insert(transmogIcons, outfitSlotInfo.texture);
		end

		if self.illusionSlotFrame then
			local outfitIllusionSlotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(self.illusionSlotFrame:GetTransmogLocation():GetSlot(), self.illusionSlotFrame:GetTransmogLocation():GetType(), weaponOption);
			if outfitIllusionSlotInfo and outfitIllusionSlotInfo.texture then
				table.insert(transmogIcons, outfitIllusionSlotInfo.texture);
			end
		end
	end

	if self.slotData.weaponOptionsInfo then
		for _index, weaponOptionInfo in ipairs(self.slotData.weaponOptionsInfo) do
			PopulateIcons(weaponOptionInfo.weaponOption);
		end
	else
		PopulateIcons(self.slotData.currentWeaponOptionInfo.weaponOption);
	end

	return transmogIcons;
end


MCUDR_SlotFlyoutDropdownMixin = CreateFromMixins(ButtonStateBehaviorMixin);

-- Overridden.
function MCUDR_SlotFlyoutDropdownMixin:OnButtonStateChanged()
	local atlas = self:IsDown() and "transmog-button-pullup-pressed" or "transmog-button-pullup";
	self:SetHighlightAtlas(atlas, "ADD");
end

-- Overridden.
function MCUDR_SlotFlyoutDropdownMixin:OnMenuOpened(menu)
	DropdownButtonMixin.OnMenuOpened(self, menu);

	self:SetNormalAtlas("transmog-button-pullup-open", TextureKitConstants.UseAtlasSize);
	HelpTip:HideAllSystem("TransmogCharacter");
end

-- Overridden.
function MCUDR_SlotFlyoutDropdownMixin:OnMenuClosed(menu)
	DropdownButtonMixin.OnMenuClosed(self, menu);

	self:SetNormalAtlas("transmog-button-pullup", TextureKitConstants.UseAtlasSize);
end


MCUDR_IllusionSlotMixin = CreateFromMixins(MCUDR_SlotMixin);

function MCUDR_IllusionSlotMixin:OnLoad()
	self.SavedFrame.Anim:SetScript("OnFinished", function()
		self.SavedFrame:Hide();
		self:Update();
	end);
end

function MCUDR_IllusionSlotMixin:OnShow()
	self:Update();
end

function MCUDR_IllusionSlotMixin:OnTransmogrifySuccess()
	-- Don't do anything if already animating.
	if not self.slotData or self.SavedFrame:IsShown() then
		return;
	end

	self.SavedFrame:Show();
	self.SavedFrame.Anim:Restart();
end

function MCUDR_IllusionSlotMixin:SetSelected(selected)
	self.SelectedFrame:SetShown(selected);
end

function MCUDR_IllusionSlotMixin:Update()
	if not self.slotData or not self.slotData.transmogLocation or not self:IsShown() then
		return;
	end

	local outfitSlotInfo = self:GetSlotInfo();
	if not outfitSlotInfo then
		return;
	end

	self:SetEnabled(outfitSlotInfo.canTransmogrify);

	-- Base icon texture.
	-- The texture will either be whatever is set in outfitSlotInfo, or the default slot texture if unset.
	if outfitSlotInfo.texture then
		self.Icon:SetTexture(outfitSlotInfo.texture);
	else
		self.Icon:SetAtlas("transmog-gearslot-unassigned-enchant", TextureKitConstants.UseAtlasSize);
	end

	-- Border art.
	local border = "transmog-gearslot-default-small";
	if not outfitSlotInfo.canTransmogrify then
		border = "transmog-gearslot-disabled-small";
	elseif outfitSlotInfo.displayType == Enum.TransmogOutfitDisplayType.Assigned then
		border = "transmog-gearslot-transmogrified-small";
	elseif outfitSlotInfo.displayType == Enum.TransmogOutfitDisplayType.Hidden then
		border = "transmog-gearslot-transmogrified-hidden-small";
	end

	self.Border:SetAtlas(border, TextureKitConstants.UseAtlasSize);
	self:SetHighlightAtlas(border, "ADD");

	-- Overlay icons.
	self.DisabledIcon:SetShown(not outfitSlotInfo.canTransmogrify);
	self.HiddenVisualIcon:SetShown(outfitSlotInfo.displayType == Enum.TransmogOutfitDisplayType.Hidden);
	self.ShowEquippedIcon:SetShown(outfitSlotInfo.displayType == Enum.TransmogOutfitDisplayType.Equipped);
	self.WarningFrame:SetShown(outfitSlotInfo.warning ~= Enum.TransmogOutfitSlotWarning.Ok);

	-- Pending frame.
	if outfitSlotInfo.hasPending and not self.SavedFrame:IsShown() then
		self.PendingFrame:Show();
		self.PendingFrame.AnimLoop:Restart();

		-- Only play the intro animation if things actually changed on the slot.
		if not self.lastOutfitSlotInfo or self.lastOutfitSlotInfo.displayType ~= outfitSlotInfo.displayType or (self.lastOutfitSlotInfo.displayType ~= Enum.TransmogOutfitDisplayType.Unassigned and self.lastOutfitSlotInfo.transmogID ~= outfitSlotInfo.transmogID) then
			self.PendingFrame.AnimStart:Restart();
		end
	else
		self.PendingFrame.AnimStart:Stop();
		self.PendingFrame.AnimLoop:Stop();
		self.PendingFrame:Hide();
	end

	self.lastOutfitSlotInfo = outfitSlotInfo;
end


MCUDR_WardrobeCollectionTabMixin = {};

function MCUDR_WardrobeCollectionTabMixin:SetTabSelected(isSelected)
	TabSystemButtonArtMixin.SetTabSelected(self, isSelected);

	self.SelectedHighlight:SetShown(isSelected);
end


MCUDR_SearchBoxMixin = {
	WARDROBE_SEARCH_DELAY = 0.6;
};

function MCUDR_SearchBoxMixin:OnHide()
	self:SetText("");
	self.ProgressFrame:Hide();
end

function MCUDR_SearchBoxMixin:OnUpdate(elapsed)
	if not self.searchType or not self.checkProgress then
		return;
	end

	self.updateDelay = self.updateDelay + elapsed;

	if not C_TransmogCollection.IsSearchInProgress(self.searchType) then
		self.checkProgress = false;
	elseif self.updateDelay >= self.WARDROBE_SEARCH_DELAY then
		self.checkProgress = false;
		if not C_TransmogCollection.IsSearchDBLoading() then
			self.ProgressFrame:ShowProgressBar();
		else
			self.ProgressFrame:ShowLoadingFrame();
		end
	end
end

-- Overridden.
function MCUDR_SearchBoxMixin:OnTextChanged()
	SearchBoxTemplate_OnTextChanged(self);

	self:UpdateSearch();
end

function MCUDR_SearchBoxMixin:SetSearchType(searchType)
	self.searchType = searchType;
	self.ProgressFrame:SetSearchType(searchType);
end

function MCUDR_SearchBoxMixin:Reset()
	if not self.searchType then
		return;
	end

	self:SetText("");
	self.ProgressFrame:Hide();
	self.updateDelay = 0;
	self.checkProgress = false;
	C_TransmogCollection.ClearSearch(self.searchType);
end

function MCUDR_SearchBoxMixin:UpdateSearch()
	if not self.searchType then
		return;
	end

	if self:GetText() == "" then
		C_TransmogCollection.ClearSearch(self.searchType);
	else
		C_TransmogCollection.SetSearch(self.searchType, self:GetText());
	end

	-- Restart search tracking.
	self.ProgressFrame:Hide();
	self.updateDelay = 0;
	self.checkProgress = true;
end


MCUDR_SearchBoxProgressMixin = {
	MIN_VALUE = 0;
	MAX_VALUE = 1000;
};

function MCUDR_SearchBoxProgressMixin:OnLoad()
	self.ProgressBar:SetStatusBarColor(0, .6, 0, 1);
	self.ProgressBar:SetMinMaxValues(self.MIN_VALUE, self.MAX_VALUE);
	self.ProgressBar:SetValue(0);
	self.ProgressBar:GetStatusBarTexture():SetDrawLayer("BORDER");
end

function MCUDR_SearchBoxProgressMixin:OnHide()
	self.ProgressBar:SetValue(0);
end

function MCUDR_SearchBoxProgressMixin:OnUpdate(_elapsed)
	if not self.searchType then
		return;
	end

	if self.updateProgressBar then
		if not C_TransmogCollection.IsSearchInProgress(self.searchType) then
			self:Hide();
		else
			local _minValue, maxValue = self.ProgressBar:GetMinMaxValues();
			local searchSize = C_TransmogCollection.SearchSize(self.searchType);
			if searchSize == 0 then
				self.ProgressBar:SetValue(0);
			else
				local searchProgress = C_TransmogCollection.SearchProgress(self.searchType);
				self.ProgressBar:SetValue((searchProgress * maxValue) / searchSize);
			end
		end
	end
end

function MCUDR_SearchBoxProgressMixin:SetSearchType(searchType)
	self.searchType = searchType;
end

function MCUDR_SearchBoxProgressMixin:ShowLoadingFrame()
	self.LoadingFrame:Show();
	self.ProgressBar:Hide();
	self.updateProgressBar = false;
	self:Show();
end

function MCUDR_SearchBoxProgressMixin:ShowProgressBar()
	self.LoadingFrame:Hide();
	self.ProgressBar:Show();
	self.updateProgressBar = true;
	self:Show();
end


MCUDR_ItemModelMixin = CreateFromMixins(MCUDR_ItemModelBaseMixin);

MCUDR_ItemModelMixin.DYNAMIC_EVENTS = {
	"VIEWED_TRANSMOG_OUTFIT_CHANGED",
	"VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH"
};

-- Overridden.
function MCUDR_ItemModelMixin:OnLoad()
	MCUDR_ItemModelBaseMixin.OnLoad(self);

	self.SavedFrame.Anim:SetScript("OnFinished", function()
		self.SavedFrame:Hide();
	end);
end

-- Overridden.
function MCUDR_ItemModelMixin:OnEnter()
	self:SetScript("OnUpdate", self.OnUpdate);

	local appearanceInfo = self:GetAppearanceInfo();
	if not appearanceInfo then
		return;
	end

	-- Show dressing room tooltip instead of transmog tooltip
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");

	local sources = C_TransmogCollection.GetAppearanceSources(appearanceInfo.visualID, self:GetCollectionFrame() and self:GetCollectionFrame().activeCategoryID);
	if sources and #sources > 0 then
		local best = sources[1];
		for _, s in ipairs(sources) do
			if s.isCollected then best = s; break; end
		end

		local r, g, b = GetItemQualityColor(best.quality or 1);
		GameTooltip:SetText(best.name or "", r, g, b);

		if best.isCollected then
			GameTooltip:AddLine(COLLECTED or "Collected", 0.1, 1.0, 0.1);
		else
			GameTooltip:AddLine(NOT_COLLECTED or "Not Collected", 1.0, 0.1, 0.1);
		end

		local sourceLabels = {
			[1] = ENCOUNTER_JOURNAL or "Dungeon/Raid Boss",
			[2] = QUEST or "Quest",
			[3] = VENDOR or "Vendor",
			[4] = WORLD_DROP or "World Drop",
			[7] = ACHIEVEMENTS or "Achievement",
			[8] = PROFESSIONS or "Profession",
			[10] = TRADING_POST or "Trading Post",
		};
		if best.sourceType and sourceLabels[best.sourceType] then
			GameTooltip:AddLine(sourceLabels[best.sourceType], 0.7, 0.7, 0.7);
		end

		GameTooltip:AddLine(" ");
		GameTooltip:AddLine("Click to preview on character", 0.5, 0.5, 0.5);
	end

	GameTooltip:Show();

	if C_TransmogCollection.IsNewAppearance(appearanceInfo.visualID) then
		C_TransmogCollection.ClearNewAppearance(appearanceInfo.visualID);
		if self.NewVisual then self.NewVisual:Hide(); end
	end
end

-- Overridden.
function MCUDR_ItemModelMixin:OnShow()
	FrameUtil.RegisterFrameForEvents(self, self.DYNAMIC_EVENTS);

	-- Don't call into base method, as it would mess with the below check.
	if self.needsReload then
		self:Reload();
	end

	self:UpdateItem();
end

function MCUDR_ItemModelMixin:OnHide()
	FrameUtil.UnregisterFrameForEvents(self, self.DYNAMIC_EVENTS);
end

function MCUDR_ItemModelMixin:OnEvent(event, ...)
	if event == "VIEWED_TRANSMOG_OUTFIT_CHANGED" or event == "VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH" then
		self:UpdateItemBorder();
	end
end

-- Overridden.
function MCUDR_ItemModelMixin:GetAppearanceInfo()
	if not self.elementData then
		return nil;
	end

	return self.elementData.appearanceInfo;
end

-- Overridden.
function MCUDR_ItemModelMixin:GetCollectionFrame()
	if not self.elementData then
		return nil;
	end

	return self.elementData.collectionFrame;
end

-- Overridden.
function MCUDR_ItemModelMixin:GetAppearanceLink()
	local link = nil;
	local appearanceInfo = self:GetAppearanceInfo();
	local itemsCollectionFrame = self:GetCollectionFrame();
	if not appearanceInfo or not itemsCollectionFrame then
		return link;
	end

	local sources = CollectionWardrobeUtil.GetSortedAppearanceSourcesForClass(appearanceInfo.visualID, C_TransmogCollection.GetClassFilter(), itemsCollectionFrame:GetActiveCategory(), itemsCollectionFrame:GetTransmogLocation());

	local primarySourceID = itemsCollectionFrame:GetChosenVisualSource(appearanceInfo.visualID);
	local sourceIndex = CollectionWardrobeUtil.GetDefaultSourceIndex(sources, primarySourceID);
	local index = CollectionWardrobeUtil.GetValidIndexForNumSources(sourceIndex, #sources);
	local preferArtifact = TransmogUtil.IsCategoryLegionArtifact(itemsCollectionFrame:GetActiveCategory());
	link = CollectionWardrobeUtil.GetAppearanceItemHyperlink(sources[index], preferArtifact);

	return link;
end

-- Overridden.
function MCUDR_ItemModelMixin:CanCheckDressUpClick()
	return false;
end

-- Overridden.
function MCUDR_ItemModelMixin:UpdateCamera()
	self.cameraID = nil;

	local appearanceInfo = self:GetAppearanceInfo();
	local itemsCollectionFrame = self:GetCollectionFrame();
	if not appearanceInfo or not itemsCollectionFrame then
		return;
	end

	local transmogLocation = itemsCollectionFrame:GetTransmogLocation();
	if transmogLocation:IsIllusion() then
		-- For illusions, the source should match the corresponding appearance slot.
		local transmogID = Constants.Transmog.NoTransmogID;
		local cameraVariation;

		-- First see if the appearance slot has a visual we can use.
		local appearanceType = Enum.TransmogType.Appearance;
		local appearanceSlotFrame = itemsCollectionFrame:GetSlotFrameCallback(transmogLocation:GetSlot(), appearanceType);
		if appearanceSlotFrame then
			local appearanceSlotTransmogLocation = appearanceSlotFrame:GetTransmogLocation();
			if appearanceSlotTransmogLocation then
				local checkSecondary = appearanceSlotTransmogLocation:GetSlotName() == "SHOULDERSLOT" and itemsCollectionFrame:HasActiveSecondaryAppearance();
				cameraVariation = TransmogUtil.GetCameraVariation(appearanceSlotTransmogLocation, checkSecondary);
			end

			local outfitSlotInfo = appearanceSlotFrame:GetSlotInfo();
			if outfitSlotInfo then
				transmogID = outfitSlotInfo.transmogID;
			end
		end

		if transmogID == Constants.Transmog.NoTransmogID or self:ShouldLocationUseDefaultVisual() then
			local itemModifiedAppearanceID = C_TransmogOutfitInfo.GetIllusionDefaultIMAIDForCollectionType(itemsCollectionFrame:GetActiveCategory());
			if itemModifiedAppearanceID then
				transmogID = itemModifiedAppearanceID;
			end
		end

		if transmogID ~= Constants.Transmog.NoTransmogID then
			self.cameraID = C_TransmogCollection.GetAppearanceCameraIDBySource(transmogID, cameraVariation);
		end
	else
		local checkSecondary = transmogLocation:GetSlotName() == "SHOULDERSLOT" and itemsCollectionFrame:HasActiveSecondaryAppearance();
		local cameraVariation = TransmogUtil.GetCameraVariation(transmogLocation, checkSecondary);
		self.cameraID = C_TransmogCollection.GetAppearanceCameraID(appearanceInfo.visualID, cameraVariation);
	end
end

function MCUDR_ItemModelMixin:Init(elementData)
	self.elementData = elementData;
	if not self.elementData then
		return;
	end

	self:RefreshItemCamera();
	self.needsReload = true;
end

function MCUDR_ItemModelMixin.Reset(framePool, self)
	Pool_HideAndClearAnchors(framePool, self);
	self.elementData = nil;
end

function MCUDR_ItemModelMixin:UpdateItemBorder()
	local appearanceInfo = self:GetAppearanceInfo();
	local itemsCollectionFrame = self:GetCollectionFrame();
	if not appearanceInfo or not itemsCollectionFrame then
		return;
	end

	local transmogStateAtlas;

	local selectedSlotData = itemsCollectionFrame:GetSelectedSlotCallback();
	if not selectedSlotData or not selectedSlotData.transmogLocation then
		return;
	end

	local outfitSlotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(selectedSlotData.transmogLocation:GetSlot(), selectedSlotData.transmogLocation:GetType(), selectedSlotData.currentWeaponOptionInfo.weaponOption);

	local sourceID = appearanceInfo.sourceID;
	if selectedSlotData.transmogLocation:IsAppearance() then
		sourceID = itemsCollectionFrame:GetAnAppearanceSourceFromVisual(appearanceInfo.visualID, nil);
	end

	if outfitSlotInfo and sourceID == outfitSlotInfo.transmogID and outfitSlotInfo.displayType ~= Enum.TransmogOutfitDisplayType.Unassigned and outfitSlotInfo.displayType ~= Enum.TransmogOutfitDisplayType.Equipped then
		if outfitSlotInfo.hasPending then
			transmogStateAtlas = "transmog-itemcard-transmogrified-pending";
		else
			transmogStateAtlas = "transmog-itemcard-transmogrified";
		end
	end

	if transmogStateAtlas then
		self.StateTexture:SetAtlas(transmogStateAtlas, TextureKitConstants.UseAtlasSize);
		self.StateTexture:Show();

		if outfitSlotInfo.hasPending then
			self.PendingFrame:Show();
			self.PendingFrame.Anim:Restart();
		else
			self.PendingFrame.Anim:Stop();
			self.PendingFrame:Hide();
		end

		if itemsCollectionFrame:GetOutfitSlotSavedState() then
			self.SavedFrame:Show();
			self.SavedFrame.Anim:Restart();

			local outfitSlotSaved = false;
			itemsCollectionFrame:SetOutfitSlotSavedState(outfitSlotSaved);
		end
	else
		self.StateTexture:Hide();

		self.PendingFrame.Anim:Stop();
		self.PendingFrame:Hide();
	end
end

function MCUDR_ItemModelMixin:UpdateItem()
	local appearanceInfo = self:GetAppearanceInfo();
	local itemsCollectionFrame = self:GetCollectionFrame();
	if not appearanceInfo or not itemsCollectionFrame then
		return;
	end

	-- Base Appearance
	local isArmor;
	local appearanceVisualID;
	local appearanceVisualSubclass;
	local transmogLocation = itemsCollectionFrame:GetTransmogLocation();
	if transmogLocation:IsIllusion() then
		-- For illusions, the visual should match the corresponding appearance slot.
		local transmogID = Constants.Transmog.NoTransmogID;

		-- First see if the appearance slot has a visual we can use.
		local appearanceType = Enum.TransmogType.Appearance;
		local appearanceSlotFrame = itemsCollectionFrame:GetSlotFrameCallback(transmogLocation:GetSlot(), appearanceType);
		if appearanceSlotFrame then
			local outfitSlotInfo = appearanceSlotFrame:GetSlotInfo();
			if outfitSlotInfo then
				transmogID = outfitSlotInfo.transmogID;
			end
		end

		if transmogID == Constants.Transmog.NoTransmogID or self:ShouldLocationUseDefaultVisual() then
			local itemModifiedAppearanceID = C_TransmogOutfitInfo.GetIllusionDefaultIMAIDForCollectionType(itemsCollectionFrame:GetActiveCategory());
			if itemModifiedAppearanceID then
				transmogID = itemModifiedAppearanceID;
			end
		end

		if transmogID ~= Constants.Transmog.NoTransmogID then
			local appearanceSourceInfo = C_TransmogCollection.GetAppearanceSourceInfo(transmogID);
			if appearanceSourceInfo then
				appearanceVisualID = appearanceSourceInfo.itemAppearanceID;
				appearanceVisualSubclass = appearanceSourceInfo.itemSubclass;
			end
		end
	else
		local selectedSlotData = itemsCollectionFrame:GetSelectedSlotCallback();
		if selectedSlotData and selectedSlotData.transmogLocation then
			local collectionInfo = C_TransmogOutfitInfo.GetCollectionInfoForSlotAndOption(selectedSlotData.transmogLocation:GetSlot(), selectedSlotData.currentWeaponOptionInfo.weaponOption, itemsCollectionFrame:GetActiveCategory());
			isArmor = not collectionInfo or not collectionInfo.isWeapon;
		end
	end

	local canDisplayVisuals = transmogLocation:IsIllusion() or appearanceInfo.canDisplayOnPlayer;
	if not canDisplayVisuals then
		if isArmor then
			self:UndressSlot(transmogLocation:GetSlotID());
		else
			self:ClearModel();
		end
	elseif isArmor then
		local sourceID = itemsCollectionFrame:GetAnAppearanceSourceFromVisual(appearanceInfo.visualID, nil);
		self:TryOn(sourceID);
	elseif appearanceVisualID then
		-- appearanceVisualID is only set when looking at enchants
		self:SetItemAppearance(appearanceVisualID, appearanceInfo.visualID, appearanceVisualSubclass);
	else
		self:SetItemAppearance(appearanceInfo.visualID);
	end

	-- Border State FX
	self:UpdateItemBorder();

	-- Icons
	self.FavoriteVisual:SetShown(appearanceInfo.isFavorite);
	self.HideVisual:SetShown(appearanceInfo.isHideVisual);

	local isNewAppearance = C_TransmogCollection.IsNewAppearance(appearanceInfo.visualID);
	self.NewVisual:SetShown(isNewAppearance);
end

function MCUDR_ItemModelMixin:RefreshItemCamera()
	self:UpdateCamera();
	self:RefreshCamera();
	if self.cameraID then
		Model_ApplyUICamera(self, self.cameraID);
	end
end

function MCUDR_ItemModelMixin:ShouldLocationUseDefaultVisual()
	local useDefaultVisual = false;

	local itemsCollectionFrame = self:GetCollectionFrame();
	if not itemsCollectionFrame then
		useDefaultVisual = true;
		return useDefaultVisual;
	end

	local transmogLocation = itemsCollectionFrame:GetTransmogLocation();
	if transmogLocation:IsIllusion() then
		local slotFrame = itemsCollectionFrame:GetSlotFrameCallback(transmogLocation:GetSlot(), transmogLocation:GetType());
		if slotFrame then
			local outfitSlotInfo = slotFrame:GetSlotInfo();
			if outfitSlotInfo then
				useDefaultVisual = outfitSlotInfo.warning == Enum.TransmogOutfitSlotWarning.WeaponDoesNotSupportIllusions;
			end
		end
	end

	return useDefaultVisual;
end


MCUDR_SetBaseModelMixin = {
	DYNAMIC_EVENTS = {
		"VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH",
		"PLAYER_EQUIPMENT_CHANGED"
	};
};

function MCUDR_SetBaseModelMixin:OnLoad()
	self:SetAutoDress(false);
	self:FreezeAnimation(0, 0, 0);
	local x, y, z = self:TransformCameraSpaceToModelSpace(CreateVector3D(0, 0, -0.25)):GetXYZ();
	self:SetPosition(x, y, z);

	local enabled = true;
	local lightValues = {
		omnidirectional = false,
		point = CreateVector3D(-1, 1, -1),
		ambientIntensity = 1,
		ambientColor = CreateColor(1, 1, 1),
		diffuseIntensity = 0,
		diffuseColor = CreateColor(1, 1, 1)
	};
	self:SetLight(enabled, lightValues);
end

function MCUDR_SetBaseModelMixin:OnShow()
	FrameUtil.RegisterFrameForEvents(self, self.DYNAMIC_EVENTS);
	local blend = false;
	self:SetUnit("player", blend, PlayerUtil.ShouldUseNativeFormInModelScene());

	self:UpdateSet();
end

function MCUDR_SetBaseModelMixin:OnHide()
	FrameUtil.UnregisterFrameForEvents(self, self.DYNAMIC_EVENTS);

	self.SavedFrame.Anim:SetScript("OnFinished", function()
		self.SavedFrame:Hide();
	end);
end

function MCUDR_SetBaseModelMixin:OnEnter()
	self:RefreshTooltip();
end

function MCUDR_SetBaseModelMixin:OnLeave()
	GameTooltip:Hide();
end

function MCUDR_SetBaseModelMixin:OnEvent(event, ...)
	if event == "VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH" or event == "PLAYER_EQUIPMENT_CHANGED" then
		self:UpdateSet();
	end
end

function MCUDR_SetBaseModelMixin:OnModelLoaded()
	if self.cameraID then
		Model_ApplyUICamera(self, self.cameraID);
	end
end

function MCUDR_SetBaseModelMixin:UpdateCamera()
	local _detailsCameraID, transmogCameraID = C_TransmogSets.GetCameraIDs();
	self.cameraID = transmogCameraID;
end

function MCUDR_SetBaseModelMixin:RefreshSetCamera()
	self:UpdateCamera();
	self:RefreshCamera();
	if self.cameraID then
		Model_ApplyUICamera(self, self.cameraID);
	end
end

function MCUDR_SetBaseModelMixin:UpdateSet()
	-- Override in your mixin.
end

function MCUDR_SetBaseModelMixin:RefreshTooltip()
	-- Override in your mixin.
end


MCUDR_SetModelMixin = {};

function MCUDR_SetModelMixin:OnMouseDown(button)
	if not self.elementData then
		return;
	end

	if button == "LeftButton" then
		PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);
		C_TransmogOutfitInfo.SetOutfitToSet(self.elementData.set.setID);
	end
end

function MCUDR_SetModelMixin:OnMouseUp(button)
	if not self.elementData then
		return;
	end

	if button ~= "RightButton" then
		return;
	end

	MenuUtil.CreateContextMenu(self, function(_owner, rootDescription)
		rootDescription:SetTag("MENU_TRANSMOG_SETS_MODEL_FILTER");

		local isFavorite, isGroupFavorite = C_TransmogSets.GetIsFavorite(self.elementData.set.setID);
		local text = isFavorite and TRANSMOG_ITEM_UNSET_FAVORITE or TRANSMOG_ITEM_SET_FAVORITE;
		rootDescription:CreateButton(text, function()
			self:ToggleFavorite(not isFavorite, isGroupFavorite);
		end);

		rootDescription:CreateButton(TRANSMOG_SET_OPEN_COLLECTION, function()
			TransmogUtil.OpenCollectionToSet(self.elementData.set.setID);
		end);
	end);
end

-- Overridden.
function MCUDR_SetModelMixin:UpdateSet()
	if not self.elementData then
		return;
	end

	-- Base Appearance
	for _index, primaryAppearance in ipairs(self.elementData.sourceData.primaryAppearances) do
		self:TryOn(primaryAppearance.appearanceID);
	end

	-- Border State FX
	local borderAtlas = self.elementData.set.collected and "transmog-setcard-default" or "transmog-setcard-incomplete";
	self.Border:SetAtlas(borderAtlas);
	self.Highlight:SetAtlas(borderAtlas);
	self.IncompleteOverlay:SetShown(not self.elementData.set.collected);

	local transmogStateAtlas;
	local appliedSetID, hasPending = self.elementData.collectionFrame:GetFirstMatchingSetID();
	if self.elementData.set.setID == appliedSetID then
		if hasPending then
			transmogStateAtlas = "transmog-setcard-transmogrified-pending";
		else
			transmogStateAtlas = "transmog-setcard-transmogrified";
		end
	end

	if transmogStateAtlas then
		self.TransmogStateTexture:SetAtlas(transmogStateAtlas, TextureKitConstants.IgnoreAtlasSize);
		self.TransmogStateTexture:Show();

		if hasPending then
			self.PendingFrame:Show();
			self.PendingFrame.Anim:Restart();
		else
			self.PendingFrame.Anim:Stop();
			self.PendingFrame:Hide();
		end

		if self.elementData.collectionFrame:GetOutfitSlotSavedState() then
			self.SavedFrame:Show();
			self.SavedFrame.Anim:Restart();

			local outfitSlotSaved = false;
			self.elementData.collectionFrame:SetOutfitSlotSavedState(outfitSlotSaved);
		end
	else
		self.TransmogStateTexture:Hide();

		self.PendingFrame.Anim:Stop();
		self.PendingFrame:Hide();
	end

	-- Icons
	self.Favorite.Icon:SetShown(self.elementData.set.favorite);
end

-- Overridden.
function MCUDR_SetModelMixin:RefreshTooltip()
	if not self.elementData then
		return;
	end

	local totalQuality = 0;
	local numTotalSlots = 0;
	local waitingOnQuality = false;
	local primaryAppearances = C_TransmogSets.GetSetPrimaryAppearances(self.elementData.set.setID);
	for _index, primaryAppearance in pairs(primaryAppearances) do
		numTotalSlots = numTotalSlots + 1;
		local sourceInfo = C_TransmogCollection.GetSourceInfo(primaryAppearance.appearanceID);
		if sourceInfo and sourceInfo.quality then
			totalQuality = totalQuality + sourceInfo.quality;
		else
			waitingOnQuality = true;
		end
	end

	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	if waitingOnQuality then
		GameTooltip:SetText(RETRIEVING_ITEM_INFO, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
	else
		local setQuality = (numTotalSlots > 0 and totalQuality > 0) and Round(totalQuality / numTotalSlots) or Enum.ItemQuality.Common;
		local setInfo = C_TransmogSets.GetSetInfo(self.elementData.set.setID);

		local colorData = ColorManager.GetColorDataForItemQuality(setQuality);
		if colorData then
			GameTooltip:SetText(setInfo.name, colorData.r, colorData.g, colorData.b);
		else
			GameTooltip:SetText(setInfo.name);
		end

		if setInfo.label then
			GameTooltip:AddLine(setInfo.label);
		end
	end

	if self.elementData.set.collected then
		GameTooltip_AddHighlightLine(GameTooltip, TRANSMOG_SET_COMPLETE);
	else
		GameTooltip_AddDisabledLine(GameTooltip, TRANSMOG_SET_INCOMPLETE);
	end

	GameTooltip:Show();
end

function MCUDR_SetModelMixin:Init(elementData)
	self.elementData = elementData;
	if not self.elementData then
		return;
	end

	self:RefreshSetCamera();
end

function MCUDR_SetModelMixin.Reset(framePool, self)
	Pool_HideAndClearAnchors(framePool, self);
	self.elementData = nil;
end

function MCUDR_SetModelMixin:ToggleFavorite(setFavorite, isGroupFavorite)
	if not self.elementData then
		return;
	end

	local setID = self.elementData.set.setID;
	if setFavorite and isGroupFavorite then
		local baseSetID = C_TransmogSets.GetBaseSetID(setID);
		C_TransmogSets.SetIsFavorite(baseSetID, false);

		for _index, variantSet in ipairs(C_TransmogSets.GetVariantSets(baseSetID)) do
			C_TransmogSets.SetIsFavorite(variantSet.setID, false);
		end
	end

	C_TransmogSets.SetIsFavorite(setID, setFavorite);
end


MCUDR_CustomSetModelMixin = {};

function MCUDR_CustomSetModelMixin:OnMouseDown(button)
	if not self.elementData then
		return;
	end

	if button == "LeftButton" then
		PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);
		C_TransmogOutfitInfo.SetOutfitToCustomSet(self.elementData.customSetID);
	end
end

function MCUDR_CustomSetModelMixin:OnMouseUp(button)
	if not self.elementData then
		return;
	end

	if button ~= "RightButton" then
		return;
	end

	MenuUtil.CreateContextMenu(self, function(_owner, rootDescription)
		rootDescription:SetTag("MENU_TRANSMOG_CUSTOM_SETS_MODEL_FILTER");

		if MCUDR_DressUpFrameLinkingSupported() then
			rootDescription:CreateButton(TRANSMOG_CUSTOM_SET_DRESSING_ROOM, function()
				DressUpFrame:ShowCustomSet(self.elementData.customSetID);
			end);
		end

		local itemTransmogInfoList = self.elementData.collectionFrame:GetItemTransmogInfoListCallback();
		rootDescription:CreateButton(TRANSMOG_CUSTOM_SET_RENAME, function()
			local name, _icon = C_TransmogCollection.GetCustomSetInfo(self.elementData.customSetID);
			local data = { name = name, customSetID = self.elementData.customSetID, itemTransmogInfoList = itemTransmogInfoList };
			StaticPopup_Show("TRANSMOG_CUSTOM_SET_NAME", nil, nil, data);
		end);

		local hasValidAppearance = TransmogUtil.IsValidItemTransmogInfoList(itemTransmogInfoList);
		if hasValidAppearance then
			rootDescription:CreateDivider();

			rootDescription:CreateButton(TRANSMOG_CUSTOM_SET_REPLACE, function()
				C_TransmogCollection.ModifyCustomSet(self.elementData.customSetID, itemTransmogInfoList);
			end);
		end

		rootDescription:CreateDivider();

		rootDescription:CreateButton(RED_FONT_COLOR:WrapTextInColorCode(TRANSMOG_CUSTOM_SET_DELETE), function()
			local name, _icon = C_TransmogCollection.GetCustomSetInfo(self.elementData.customSetID);
			StaticPopup_Show("CONFIRM_DELETE_TRANSMOG_CUSTOM_SET", name, nil, self.elementData.customSetID);
		end);
	end);
end

-- Overridden.
function MCUDR_CustomSetModelMixin:UpdateSet()
	if not self.elementData then
		return;
	end

	-- Base Appearance
	local customSetTransmogInfo = C_TransmogCollection.GetCustomSetItemTransmogInfoList(self.elementData.customSetID);
	for slotID, itemTransmogInfo in ipairs(customSetTransmogInfo) do
		self:SetItemTransmogInfo(itemTransmogInfo, slotID);
	end

	-- Border State FX
	local borderAtlas = self.elementData.isCollected and "transmog-setcard-default" or "transmog-setcard-incomplete";
	self.Border:SetAtlas(borderAtlas);
	self.Highlight:SetAtlas(borderAtlas);
	self.IncompleteOverlay:SetShown(not self.elementData.isCollected);

	local transmogStateAtlas;
	local appliedCustomSetID, hasPending = self.elementData.collectionFrame:GetFirstMatchingCustomSetID();
	if self.elementData.customSetID == appliedCustomSetID then
		if hasPending then
			transmogStateAtlas = "transmog-setcard-transmogrified-pending";
		else
			transmogStateAtlas = "transmog-setcard-transmogrified";
		end
	end

	if transmogStateAtlas then
		self.TransmogStateTexture:SetAtlas(transmogStateAtlas, TextureKitConstants.IgnoreAtlasSize);
		self.TransmogStateTexture:Show();

		if hasPending then
			self.PendingFrame:Show();
			self.PendingFrame.Anim:Restart();
		else
			self.PendingFrame.Anim:Stop();
			self.PendingFrame:Hide();
		end

		if self.elementData.collectionFrame:GetOutfitSlotSavedState() then
			self.SavedFrame:Show();
			self.SavedFrame.Anim:Restart();

			local outfitSlotSaved = false;
			self.elementData.collectionFrame:SetOutfitSlotSavedState(outfitSlotSaved);
		end
	else
		self.TransmogStateTexture:Hide();

		self.PendingFrame.Anim:Stop();
		self.PendingFrame:Hide();
	end
end

-- Overridden.
function MCUDR_CustomSetModelMixin:RefreshTooltip()
	if not self.elementData then
		return;
	end

	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");

	local name, _icon = C_TransmogCollection.GetCustomSetInfo(self.elementData.customSetID);
	GameTooltip:SetText(name);

	if self.elementData.isCollected then
		GameTooltip_AddHighlightLine(GameTooltip, TRANSMOG_CUSTOM_SET_COMPLETE);
	else
		GameTooltip_AddDisabledLine(GameTooltip, TRANSMOG_CUSTOM_SET_INCOMPLETE);
	end

	GameTooltip:Show();
end

function MCUDR_CustomSetModelMixin:Init(elementData)
	self.elementData = elementData;
	if not self.elementData then
		return;
	end

	self:RefreshSetCamera();
end

function MCUDR_CustomSetModelMixin.Reset(framePool, self)
	Pool_HideAndClearAnchors(framePool, self);
	self.elementData = nil;
end


MCUDR_SituationMixin = {
	DROPDOWN_WIDTH = 305;
};

function MCUDR_SituationMixin:OnLoad()
	self.Dropdown:SetWidth(self.DROPDOWN_WIDTH);
end

function MCUDR_SituationMixin:Init(elementData)
	self.elementData = elementData;

	local situationCategoryString = self.elementData.name;
	self.Title:SetText(situationCategoryString);

	local function IsSelected(data)
		return C_TransmogOutfitInfo.GetOutfitSituation(data);
	end

	local function SetSelectedRadio(data)
		if self.selectedSituation then
			C_TransmogOutfitInfo.UpdatePendingSituation(self.selectedSituation, false);
		end

		self.selectedSituation = data;

		C_TransmogOutfitInfo.UpdatePendingSituation(data, true);
	end

	local function SetSelectedCheckbox(data)
		local newValue = not IsSelected(data);
		C_TransmogOutfitInfo.UpdatePendingSituation(data, newValue);
	end

	self.Dropdown:SetupMenu(function(_dropdown, rootDescription)
		rootDescription:SetTag("MENU_TRANSMOG_SITUATION");

		for groupIndex, groupData in ipairs(self.elementData.groupData) do
			for _optionIndex, optionData in ipairs(groupData.optionData) do
				if self.elementData.isRadioButton then
					rootDescription:CreateRadio(optionData.name, IsSelected, SetSelectedRadio, optionData.option);
				else
					rootDescription:CreateCheckbox(optionData.name, IsSelected, SetSelectedCheckbox, optionData.option);
				end
			end

			if groupIndex < #self.elementData.groupData then
				rootDescription:CreateDivider();
			end
		end
	end);

	self.Dropdown:SetScript("OnEnter", function()
		GameTooltip:SetOwner(self.Dropdown, "ANCHOR_RIGHT", 0, 0);
		GameTooltip_AddHighlightLine(GameTooltip, self.elementData.name);
		GameTooltip_AddNormalLine(GameTooltip, self.elementData.description);
		GameTooltip:Show();
	end);

	self.Dropdown:SetScript("OnLeave", GameTooltip_Hide);
end

function MCUDR_SituationMixin:IsValid()
	-- A situation is considered valid if at least 1 option is selected on it.
	local _previousRadio, _nextRadio, selections = self.Dropdown:CollectSelectionData();
	return #selections > 0;
end
