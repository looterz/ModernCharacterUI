StaticPopupDialogs["MCU_DR_BUY_OUTFIT_SLOT"] = {
	text = CONFIRM_BUY_OUTFIT_SLOT,
	button1 = YES,
	button2 = NO,
	OnAccept = function(_dialog, _data)
		-- Check if player can afford.
		local nextOutfitCost = C_TransmogOutfitInfo.GetNextOutfitCost();
		if GetMoney() < nextOutfitCost then
			UIErrorsFrame:AddMessage(ERR_TRANSMOG_OUTFIT_SLOT_CANNOT_AFFORD, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
			return;
		end

		MCUDressingRoomFrame.OutfitPopup.mode = IconSelectorPopupFrameModes.New;
		MCUDressingRoomFrame.OutfitPopup:Show();
	end,
	OnShow = function(dialog, _data)
		local nextOutfitCost = C_TransmogOutfitInfo.GetNextOutfitCost();
		MoneyFrame_Update(dialog.MoneyFrame, nextOutfitCost);
	end,
	hasMoneyFrame = 1,
	timeout = 0,
	hideOnEscape = 1
};

StaticPopupDialogs["MCU_DR_OUTFIT_INVALID_NAME"] = {
	text = TRANSMOG_OUTFIT_INVALID_NAME,
	button1 = OKAY,
	button2 = CANCEL,
	OnAccept = function(_dialog, data)
		MCUDressingRoomFrame.OutfitPopup.mode = data.mode;
		MCUDressingRoomFrame.OutfitPopup.outfitData = data.outfitData;
		MCUDressingRoomFrame.OutfitPopup:Show();
	end,
	timeout = 0,
	hideOnEscape = 1
};

StaticPopupDialogs["MCU_DR_PENDING_CHANGES"] = {
	text = TRANSMOG_PENDING_CHANGES,
	button1 = OKAY,
	button2 = CANCEL,
	OnAccept = function(_dialog, data)
		if data.confirmCallback then
			data.confirmCallback();
		end
	end,
	timeout = 0,
	hideOnEscape = 1
};

StaticPopupDialogs["MCU_DR_USABLE_DISCOUNT"] = {
	text = TRANSMOG_USABLE_DISCOUNT_CONFIRM,
	button1 = TRANSMOG_USABLE_DISCOUNT_CLAIM,
	button2 = TRANSMOG_USABLE_DISCOUNT_USE_GOLD,
	button3 = CANCEL,
	selectCallbackByIndex = true,
	OnButton1 = function()
		local useAvailableDiscount = true;
		C_TransmogOutfitInfo.CommitAndApplyAllPending(useAvailableDiscount);
	end,
	OnButton2 = function()
		local useAvailableDiscount = false;
		C_TransmogOutfitInfo.CommitAndApplyAllPending(useAvailableDiscount);
	end,
	OnButton3 = function()
	end,
	OnShow = function(dialog, _data)
		-- Disable 'Use Gold' button if player cannot afford.
		local cost = C_TransmogOutfitInfo.GetPendingTransmogCost();
		local canAfford = cost and cost <= GetMoney();
		dialog:GetButton2():SetEnabled(canAfford);
	end,
	timeout = 0,
	hideOnEscape = 1
};

MCUDR_FrameMixin = {
	DYNAMIC_EVENTS = {
		"TRANSMOG_OUTFITS_CHANGED",
		"TRANSMOG_CUSTOM_SETS_CHANGED",
		"TRANSMOG_DISPLAYED_OUTFIT_CHANGED",
		"VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH",
		"VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED",
		"PLAYER_SPECIALIZATION_CHANGED",
		"DISPLAY_SIZE_CHANGED",
		"UI_SCALE_CHANGED"
	};
	STATIC_POPUPS = {
		"MCU_DR_BUY_OUTFIT_SLOT",
		"MCU_DR_OUTFIT_INVALID_NAME",
		"MCU_DR_PENDING_CHANGES",
		"MCU_DR_USABLE_DISCOUNT",
		"CONFIRM_DELETE_TRANSMOG_CUSTOM_SET",
		"TRANSMOG_CUSTOM_SET_NAME",
		"TRANSMOG_CUSTOM_SET_CONFIRM_OVERWRITE"
	};
	HELP_PLATE_INFO = {
		FramePos = { x = 0,	y = -21 },
		-- Base positions and sizes to reference, as the transmog frame uses the 'checkFit' UIPanel setting to adjust its scale.
		-- Actual positions and sizes set in RefreshHelpPlate.
		FrameSizeBase = { width = 1618, height = 861 },
		[1] = { ButtonPosBase = { x = 133, y = -328 }, HighLightBoxBase = { x = 3, y = -99, width = 308, height = 758 }, ToolTipDir = "DOWN", ToolTipText = TRANSMOG_HELP_1 },
		[2] = { ButtonPosBase = { x = 618, y = -328 }, HighLightBoxBase = { x = 315, y = -3, width = 651, height = 854 }, ToolTipDir = "DOWN", ToolTipText = TRANSMOG_HELP_2 },
		[3] = { ButtonPosBase = { x = 1269, y = -328 }, HighLightBoxBase = { x = 970, y = -3, width = 644, height = 854 }, ToolTipDir = "DOWN", ToolTipText = TRANSMOG_HELP_3 },
	};
};

function MCUDR_FrameMixin:OnLoad()
	self:SetPortraitAtlasRaw("transmog-icon-ui");
	self:SetTitle(DRESSUP_FRAME or "Dressing Room");

	if not MCUDR_HelpPlatesSupported() then
		self.HelpPlateButton:Hide();
	end
	self.HelpPlateButton:SetScript("OnClick", function()
		if not HelpPlate.IsShowingHelpInfo(self.HELP_PLATE_INFO) then
			self:RefreshHelpPlate();
			HelpPlate.Show(self.HELP_PLATE_INFO, self, self.HelpPlateButton);
		else
			local userToggled = true;
			HelpPlate.Hide(userToggled);
		end
	end);

	local function OutfitCollectionFrameCollapsedCallback()
		self:SetWidth(self.collapsedWidth);
		local point, _, _, offsetX, offsetY = self.OutfitCollection:GetPoint();
		self.CharacterPreview:ClearAllPoints();
		self.CharacterPreview:SetPoint(point, offsetX, offsetY);
	end;
	self.OutfitCollection.CollapsedCallback = OutfitCollectionFrameCollapsedCallback;

	self.WardrobeCollection.GetSelectedSlotCallback = GenerateClosure(self.CharacterPreview.GetSelectedSlotData, self.CharacterPreview);
	self.WardrobeCollection.GetCurrentTransmogInfoCallback = GenerateClosure(self.CharacterPreview.GetCurrentTransmogInfo, self.CharacterPreview);
	self.WardrobeCollection.GetItemTransmogInfoListCallback = GenerateClosure(self.CharacterPreview.GetItemTransmogInfoList, self.CharacterPreview);
	self.WardrobeCollection.GetSlotFrameCallback = GenerateClosure(self.CharacterPreview.GetSlotFrame, self.CharacterPreview);

	-- Scale frame to fit screen, same visual result as Transmog's checkFit
	self:RegisterEvent("DISPLAY_SIZE_CHANGED");
	self:RegisterEvent("UI_SCALE_CHANGED");
	self:HookScript("OnEvent", function(s, event)
		if event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
			s:FitToScreen();
		end
	end);
	self:HookScript("OnShow", function(s) s:FitToScreen(); end);
end

-- ESC to close: must be at file scope (not inside OnLoad) to avoid taint.
-- This matches how our character panel does it in MainFrame.lua.
tinsert(UISpecialFrames, "MCUDressingRoomFrame");

function MCUDR_FrameMixin:FitToScreen()
	local frameW, frameH = self:GetSize();
	local screenW, screenH = GetScreenWidth(), GetScreenHeight();
	if frameW <= 0 or frameH <= 0 or screenW <= 0 or screenH <= 0 then return; end

	local scaleX = (screenW - 40) / frameW;
	local scaleY = (screenH - 40) / frameH;
	local scale = min(scaleX, scaleY, 1);
	self:SetScale(scale);
end

function MCUDR_FrameMixin:OnShow()
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN);

	FrameUtil.RegisterFrameForEvents(self, self.DYNAMIC_EVENTS);

	self:SetPortraitToUnit("player");

	-- Set left sidebar title
	if self.OutfitCollection and self.OutfitCollection.AppearancesTitle then
		self.OutfitCollection.AppearancesTitle:SetText(WARDROBE_OUTFITS or "Saved Appearances");
	end

	-- Hide transmog-specific elements not needed for dressing room
	if self.OutfitCollection then
		if self.OutfitCollection.ShowEquippedGearSpellFrame then
			self.OutfitCollection.ShowEquippedGearSpellFrame:Hide();
		end
		if self.OutfitCollection.MoneyFrame then
			self.OutfitCollection.MoneyFrame:Hide();
		end
		if self.OutfitCollection.SaveOutfitButton then
			self.OutfitCollection.SaveOutfitButton:Hide();
		end
		if self.OutfitCollection.PurchaseOutfitButton then
			self.OutfitCollection.PurchaseOutfitButton:SetText(SAVE or "Save Appearance");
		end
	end
	if self.CharacterPreview and self.CharacterPreview.ClearAllPendingButton then
		self.CharacterPreview.ClearAllPendingButton:Hide();
	end

	-- Create dressing room buttons once
	if not self._drButtonsCreated and self.CharacterPreview then
		self._drButtonsCreated = true;
		local preview = self.CharacterPreview;
		local btnW, btnH = 80, 26;

		-- Button container at high frame level above the model
		local btnBar = CreateFrame("Frame", nil, preview);
		btnBar:SetPoint("BOTTOMLEFT", preview, "BOTTOMLEFT", 0, 0);
		btnBar:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", 0, 0);
		btnBar:SetHeight(44);
		btnBar:SetFrameLevel(preview:GetFrameLevel() + 50);

		-- Reset: re-dress player model with equipped gear
		local resetBtn = CreateFrame("Button", nil, btnBar, "UIPanelButtonTemplate");
		resetBtn:SetSize(btnW, btnH);
		resetBtn:SetPoint("BOTTOMLEFT", 24, 12);
		resetBtn:SetText(RESET or "Reset");
		resetBtn:SetScript("OnClick", function()
			PlaySound(SOUNDKIT.UI_TRANSMOG_REVERTING_GEAR_SLOT);
			local actor = preview.ModelScene and preview.ModelScene:GetPlayerActor();
			if actor then
				actor:SetModelByUnit("player", false, true, false,
					PlayerUtil.ShouldUseNativeFormInModelScene and PlayerUtil.ShouldUseNativeFormInModelScene());
			end
			MCUDR_PreviewedSlots = {};
			-- Deselect any saved appearance in the outfit list
			if self.OutfitCollection and self.OutfitCollection.OutfitList
			   and self.OutfitCollection.OutfitList.ScrollBox then
				self.OutfitCollection.OutfitList.ScrollBox:ForEachFrame(function(frame)
					if frame.OutfitButton and frame.OutfitButton.Selected then
						frame.OutfitButton.Selected:Hide();
					end
					if frame.OutfitButton and frame.OutfitButton.SelectedPurple then
						frame.OutfitButton.SelectedPurple:SetAlpha(0);
					end
				end);
			end
			C_Timer.After(0.3, function()
				if preview.RefreshDressingRoomSlots then
					preview:RefreshDressingRoomSlots();
				end
			end);
		end);

		-- Undress: strip all items from the model
		local undressBtn = CreateFrame("Button", nil, btnBar, "UIPanelButtonTemplate");
		undressBtn:SetSize(btnW, btnH);
		undressBtn:SetPoint("LEFT", resetBtn, "RIGHT", 8, 0);
		undressBtn:SetText(UNDRESS or "Undress");
		undressBtn:SetScript("OnClick", function()
			PlaySound(SOUNDKIT.UI_TRANSMOG_REVERTING_GEAR_SLOT);
			local actor = preview.ModelScene and preview.ModelScene:GetPlayerActor();
			if actor then
				actor:Undress();
			end
			MCUDR_PreviewedSlots = {};
			C_Timer.After(0.3, function()
				if preview.RefreshDressingRoomSlots then
					preview:RefreshDressingRoomSlots();
				end
			end);
		end);

		-- Link: share the last previewed item in chat
		local linkBtn = CreateFrame("Button", nil, btnBar, "UIPanelButtonTemplate");
		linkBtn:SetSize(btnW, btnH);
		linkBtn:SetPoint("LEFT", undressBtn, "RIGHT", 8, 0);
		linkBtn:SetText(LINK_BUTTON or "Link");
		linkBtn:SetScript("OnClick", function()
			local ns = MCUDressingRoomFrame._addonNS;
			local lastLink = ns and ns.drLastLink;
			if lastLink then
				ChatEdit_InsertLink(lastLink);
			end
		end);

		-- Close
		local closeBtn = CreateFrame("Button", nil, btnBar, "UIPanelButtonTemplate");
		closeBtn:SetSize(btnW, btnH);
		closeBtn:SetPoint("BOTTOMRIGHT", -24, 12);
		closeBtn:SetText(CLOSE or "Close");
		closeBtn:SetScript("OnClick", function()
			MCUDressingRoomFrame:Hide();
		end);
	end

	local selectActiveOutfit = true;
	self:RefreshOutfits(selectActiveOutfit);
end

function MCUDR_FrameMixin:OnHide()
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE);

	FrameUtil.UnregisterFrameForEvents(self, self.DYNAMIC_EVENTS);

	if self.OutfitPopup then
		self.OutfitPopup:Hide();
	end

	local userToggled = false;
	if HelpPlate and HelpPlate.Hide then
		HelpPlate.Hide(userToggled);
	end

	-- Reset dressing room state
	MCUDR_PreviewedSlots = {};

	-- Reset the model back to equipped gear
	if self.CharacterPreview and self.CharacterPreview.ModelScene then
		local actor = self.CharacterPreview.ModelScene:GetPlayerActor();
		if actor then
			actor:SetModelByUnit("player", false, true, false,
				PlayerUtil.ShouldUseNativeFormInModelScene and PlayerUtil.ShouldUseNativeFormInModelScene());
		end
	end

	-- Reset slot icons to equipped items
	if self.CharacterPreview and self.CharacterPreview.RefreshDressingRoomSlots then
		self.CharacterPreview:RefreshDressingRoomSlots();
	end

	-- Deselect any highlighted saved appearance
	if self.OutfitCollection and self.OutfitCollection.OutfitList
	   and self.OutfitCollection.OutfitList.ScrollBox then
		self.OutfitCollection.OutfitList.ScrollBox:ForEachFrame(function(frame)
			if frame.OutfitButton and frame.OutfitButton.Selected then
				frame.OutfitButton.Selected:Hide();
			end
			if frame.OutfitButton and frame.OutfitButton.SelectedPurple then
				frame.OutfitButton.SelectedPurple:SetAlpha(0);
			end
		end);
	end
end

function MCUDR_FrameMixin:OnEvent(event, ...)
	if event == "TRANSMOG_OUTFITS_CHANGED" or event == "TRANSMOG_CUSTOM_SETS_CHANGED" then
		local newOutfitID = ...;
		local selectActiveOutfit = false;
		self:RefreshOutfits(selectActiveOutfit);

		if newOutfitID and event == "TRANSMOG_OUTFITS_CHANGED" then
			self.OutfitCollection:AnimateOutfitAdded(newOutfitID);
		end
	elseif event == "TRANSMOG_DISPLAYED_OUTFIT_CHANGED" then
		local selectActiveOutfit = false;
		self:RefreshOutfits(selectActiveOutfit);
	elseif event == "VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH" or event == "VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED" then
		self:UpdateCostDisplay();
	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		self:RefreshSlots();
	elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
		self:RefreshHelpPlate();
	end
end

function MCUDR_FrameMixin:RefreshOutfits(selectActiveOutfit)
	local dataProvider = CreateDataProvider();

	-- Show custom sets (saved dressing room appearances) instead of transmog outfits
	if C_TransmogCollection and C_TransmogCollection.GetCustomSets then
		local setIDs = C_TransmogCollection.GetCustomSets();
		if setIDs then
			for _, setID in ipairs(setIDs) do
				local setName, setIcon = C_TransmogCollection.GetCustomSetInfo(setID);
				local onClickCallback = function()
					if self.CharacterPreview and self.CharacterPreview.ModelScene then
						local infoList = C_TransmogCollection.GetCustomSetItemTransmogInfoList(setID);
						local actor = self.CharacterPreview.ModelScene:GetPlayerActor();
						if actor and infoList then
							-- Using global MCUDR_PreviewedSlots directly
							MCUDR_PreviewedSlots = {};

							for slotID, info in pairs(infoList) do
								actor:SetItemTransmogInfo(info, slotID);
								if info.appearanceID and info.appearanceID > 0 then
									local sourceInfo = C_TransmogCollection.GetSourceInfo(info.appearanceID);
									local itemIcon;
									-- GetSourceInfo doesn't reliably return icon; get it from the item
									if sourceInfo then
										local itemID = sourceInfo.itemID or C_TransmogCollection.GetSourceItemID(info.appearanceID);
										if itemID then
											itemIcon = C_Item.GetItemIconByID(itemID) or select(5, C_Item.GetItemInfoInstant(itemID));
										end
									end
									if sourceInfo and sourceInfo.name then
										MCUDR_PreviewedSlots[slotID] = {
											icon = itemIcon,
											sourceID = info.appearanceID,
											name = sourceInfo.name,
											quality = sourceInfo.quality,
										};
									end
								end
							end

							-- Refresh immediately with what we have, then again after items load
						if self.CharacterPreview.RefreshDressingRoomSlots then
							self.CharacterPreview:RefreshDressingRoomSlots();
						end
						C_Timer.After(0.5, function()
							if self.CharacterPreview.RefreshDressingRoomSlots then
								self.CharacterPreview:RefreshDressingRoomSlots();
							end
						end);
						end
					end
				end;

				local onEditCallback = function()
					-- Custom sets don't support rename/icon change via API,
					-- so we delete and recreate with a new name
					StaticPopup_Show("MCU_DR_RENAME_CUSTOM_SET", setName, nil, {
						setID = setID,
						name = setName,
						icon = setIcon,
					});
				end;

				local outfitData = {
					outfitID = setID,
					name = setName or ("Set " .. setID),
					icon = setIcon or 136516,
					onClickCallback = onClickCallback,
					onEditCallback = onEditCallback,
				};

				dataProvider:Insert(outfitData);
			end
		end
	end

	self.OutfitCollection:Refresh(dataProvider, selectActiveOutfit);
end

function MCUDR_FrameMixin:RefreshSlots()
	-- Some action was done that could have changed slot info (weapon options, enabled state, etc.). Refresh things to reflect any new state.
	local clearCurrentWeaponOptionInfo = false;
	self.CharacterPreview:RefreshSlotWeaponOptions(clearCurrentWeaponOptionInfo);
	self.CharacterPreview:RefreshSlots();

	-- Update collection in case the selected slot changed.
	self.WardrobeCollection:UpdateSlot(self.CharacterPreview:GetSelectedSlotData());
end

function MCUDR_FrameMixin:RefreshHelpPlate()
	local relativeScale = self:GetEffectiveScale() / HelpPlate.GetEffectiveScale();

	self.HELP_PLATE_INFO.FrameSize = {
		width = self.HELP_PLATE_INFO.FrameSizeBase.width * relativeScale,
		height = self.HELP_PLATE_INFO.FrameSizeBase.height * relativeScale
	};

	local function UpdateHelpPlateSection(helpPlate)
		helpPlate.ButtonPos = {
			x = helpPlate.ButtonPosBase.x * relativeScale,
			y = helpPlate.ButtonPosBase.y * relativeScale
		};
		helpPlate.HighLightBox = {
			x = helpPlate.HighLightBoxBase.x * relativeScale,
			y = helpPlate.HighLightBoxBase.y * relativeScale,
			width = helpPlate.HighLightBoxBase.width * relativeScale,
			height = helpPlate.HighLightBoxBase.height * relativeScale
		};
	end

	UpdateHelpPlateSection(self.HELP_PLATE_INFO[1]);
	UpdateHelpPlateSection(self.HELP_PLATE_INFO[2]);
	UpdateHelpPlateSection(self.HELP_PLATE_INFO[3]);

	if HelpPlate.IsShowingHelpInfo(self.HELP_PLATE_INFO) then
		HelpPlate.Show(self.HELP_PLATE_INFO, self, self.HelpPlateButton);
	end
end

function MCUDR_FrameMixin:UpdateCostDisplay()
	-- No cost display in dressing room mode
end

function MCUDR_FrameMixin:SelectSlot(slotFrame, forceRefresh)
	-- Visually update selected slot
	self.CharacterPreview:UpdateSlot(slotFrame.slotData, forceRefresh);

	-- Navigate to correct items in collection.
	self.WardrobeCollection:UpdateSlot(slotFrame.slotData, forceRefresh);
end

function MCUDR_FrameMixin:GetViewedOutfitIcons()
	return self.CharacterPreview:GetCurrentTransmogIcons();
end

MCUDR_OutfitCollectionMixin = {
	DYNAMIC_EVENTS = {
		"VIEWED_TRANSMOG_OUTFIT_CHANGED",
		"VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS"
	};
	HELPTIP_INFO = {
		[Enum.FrameTutorialAccount.TransmogOutfits] =
		{
			text = TRANSMOG_OUTFITS_HELPTIP,
			buttonStyle = HelpTip.ButtonStyle.Close,
			targetPoint = HelpTip.Point.RightEdgeTop,
			alignment = HelpTip.Alignment.Center,
			offsetX = -33,
			offsetY = -33,
			system = "TransmogOutfitCollection",
			acknowledgeOnHide = true,
			cvarBitfield = "closedInfoFramesAccountWide",
			bitfieldFlag = Enum.FrameTutorialAccount.TransmogOutfits
		},
		[Enum.FrameTutorialAccount.TransmogTrialOfStyle] =
		{
			text = TRANSMOG_TRIAL_OF_STYLE_HELPTIP,
			buttonStyle = HelpTip.ButtonStyle.Close,
			targetPoint = HelpTip.Point.RightEdgeTop,
			alignment = HelpTip.Alignment.Center,
			offsetX = -33,
			offsetY = -33,
			system = "TransmogOutfitCollection",
			acknowledgeOnHide = true,
			cvarBitfield = "closedInfoFramesAccountWide",
			bitfieldFlag = Enum.FrameTutorialAccount.TransmogTrialOfStyle
		}
	};
	CollapsedCallback = nil;
};

function MCUDR_OutfitCollectionMixin:OnLoad()
	local view = CreateScrollBoxListLinearView();

	view:SetElementInitializer("MCUDR_OutfitEntryTemplate", function(frame, elementData)
		frame:Init(elementData);
	end);

	local padTop = 8;
	local pad = 0;
	local spacing = 2;
	view:SetPadding(padTop, pad, pad, pad, spacing);

	ScrollUtil.InitScrollBoxListWithScrollBar(self.OutfitList.ScrollBox, self.OutfitList.ScrollBar, view);
	ScrollUtil.AddResizableChildrenBehavior(self.OutfitList.ScrollBox);

	self.PurchaseOutfitButton:SetScript("OnMouseDown", function(button)
		button.Icon:SetPoint("LEFT", 16, -2);
	end);

	self.PurchaseOutfitButton:SetScript("OnMouseUp", function(button)
		button.Icon:SetPoint("LEFT", 14, 0);
	end);

	self.PurchaseOutfitButton:SetText(SAVE or "Save Appearance");

	self.PurchaseOutfitButton:SetScript("OnEnter", function(button)
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT");
		GameTooltip:SetText("Save current appearance as a custom set");
		GameTooltip:Show();
	end);

	self.PurchaseOutfitButton:SetScript("OnLeave", GameTooltip_Hide);

	self.PurchaseOutfitButton:SetScript("OnClick", function()
		StaticPopup_Show("MCU_DR_SAVE_CUSTOM_SET");
	end);

	self:InitSaveOutfitElements();
end

StaticPopupDialogs["MCU_DR_SAVE_CUSTOM_SET"] = {
	text = "Enter a name for this appearance:",
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = true,
	OnAccept = function(self)
		local eb = self.editBox or self.EditBox;
		local name = strtrim(eb:GetText() or "");
		if name ~= "" and MCUDressingRoomFrame and MCUDressingRoomFrame.CharacterPreview then
			local modelScene = MCUDressingRoomFrame.CharacterPreview.ModelScene;
			if modelScene then
				local actor = modelScene:GetPlayerActor();
				if actor and actor.GetItemTransmogInfoList then
					local infoList = actor:GetItemTransmogInfoList();
					if infoList and C_TransmogCollection and C_TransmogCollection.NewCustomSet then
						local headTex = GetInventoryItemTexture("player", 1) or 136516;
						C_TransmogCollection.NewCustomSet(name, headTex, infoList);
					end
				end
			end
		end
	end,
	EditBoxOnEnterPressed = function(self)
		local parent = self:GetParent();
		StaticPopupDialogs["MCU_DR_SAVE_CUSTOM_SET"].OnAccept(parent);
		parent:Hide();
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
};

StaticPopupDialogs["MCU_DR_RENAME_CUSTOM_SET"] = {
	text = "Enter a new name for this appearance:",
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = true,
	OnShow = function(self)
		local eb = self.editBox or self.EditBox;
		if eb and self.data and self.data.name then
			eb:SetText(self.data.name);
			eb:HighlightText();
		end
	end,
	OnAccept = function(self)
		local eb = self.editBox or self.EditBox;
		local newName = strtrim(eb and eb:GetText() or "");
		local data = self.data;
		if newName ~= "" and data and data.setID and C_TransmogCollection then
			local infoList = C_TransmogCollection.GetCustomSetItemTransmogInfoList(data.setID);
			C_TransmogCollection.DeleteCustomSet(data.setID);
			if infoList then
				C_TransmogCollection.NewCustomSet(newName, data.icon or 136516, infoList);
			end
			if MCUDressingRoomFrame then
				MCUDressingRoomFrame:RefreshOutfits();
			end
		end
	end,
	EditBoxOnEnterPressed = function(self)
		local parent = self:GetParent();
		StaticPopupDialogs["MCU_DR_RENAME_CUSTOM_SET"].OnAccept(parent);
		parent:Hide();
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
};

StaticPopupDialogs["MCU_DR_DELETE_CUSTOM_SET"] = {
	text = "Delete appearance \"%s\"?",
	button1 = YES,
	button2 = NO,
	OnAccept = function(self, data)
		if data and C_TransmogCollection and C_TransmogCollection.DeleteCustomSet then
			C_TransmogCollection.DeleteCustomSet(data);
			if MCUDressingRoomFrame then
				MCUDressingRoomFrame:RefreshOutfits();
			end
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
};

function MCUDR_OutfitCollectionMixin:InitSaveOutfitElements()
	-- Hide transmog-specific save/money elements in dressing room mode
	if self.SaveOutfitButton then self.SaveOutfitButton:Hide(); end
	if self.MoneyFrame then self.MoneyFrame:Hide(); end
end

function MCUDR_OutfitCollectionMixin:OnShow()
	if self.DYNAMIC_EVENTS then
		FrameUtil.RegisterFrameForEvents(self, self.DYNAMIC_EVENTS);
	end

	self.canScrollToOutfit = true;
	if self.OutfitList and self.OutfitList.ScrollBox then
		self.OutfitList.ScrollBox:ScrollToBegin();
	end
end

function MCUDR_OutfitCollectionMixin:OnHide()
	FrameUtil.UnregisterFrameForEvents(self, self.DYNAMIC_EVENTS);
end

function MCUDR_OutfitCollectionMixin:OnEvent(event, ...)
	if event == "VIEWED_TRANSMOG_OUTFIT_CHANGED" then
		self:UpdateSelectedOutfit();
	elseif event == "VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS" then
		local _slot, _type, _weaponOption = ...;

		self:RefreshUsableDiscountText();

		-- Already set to true, do not restart animations if multiple slots are changing.
		if self:GetOutfitSavedState() then
			return;
		end

		self:AnimateViewedOutfitSaved();
	end
end

function MCUDR_OutfitCollectionMixin:Refresh(dataProvider, selectActiveOutfit)
	self.OutfitList.ScrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition);
	self:UpdateShowEquippedGearButton();

	self:CheckShowHelptips();

	-- Active outfit is the outfit the player is wearing out in the world, viewed is what is being viewed in the transmog frame.
	local viewedOutfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID();
	local outfitID = selectActiveOutfit and C_TransmogOutfitInfo.GetActiveOutfitID() or viewedOutfitID;
	if outfitID == 0 then
		local firstElementData = dataProvider:Find(1);
		outfitID = firstElementData.outfitID;
	end

	-- Make sure to set the viewed outfit when first opening the frame, otherwise only call if it changed.
	if selectActiveOutfit or outfitID ~= viewedOutfitID then
		C_TransmogOutfitInfo.ChangeViewedOutfit(outfitID);
	end

	-- Check to see if we can purchase more outfits (the outfit list might now be at the max number of slots allowed).
	local source = Enum.TransmogOutfitEntrySource.PlayerPurchased;
	local unlockedOutfitCount = C_TransmogOutfitInfo.GetNumberOfOutfitsUnlockedForSource(source);
	local maxOutfitCount = C_TransmogOutfitInfo.GetMaxNumberOfTotalOutfitsForSource(source);
	local hasOutfitsToPurchase = unlockedOutfitCount < maxOutfitCount;
	local hasOutfitsToSelect = C_TransmogOutfitInfo.GetMaxNumberOfUsableOutfits() > 1;

	self.PurchaseOutfitButton:SetEnabled(hasOutfitsToPurchase);
	self.PurchaseOutfitButton.Icon:SetDesaturated(not hasOutfitsToPurchase);

	-- If we have no outfits to purchase, and can only select one outfit, collapse the outfit collection frame.
	if(not hasOutfitsToPurchase and not hasOutfitsToSelect) then
		self:Collapse();
	end
end

function MCUDR_OutfitCollectionMixin:Collapse()
		self:Hide();
		self.CollapsedCallback();
end

function MCUDR_OutfitCollectionMixin:RefreshUsableDiscountText()
	self.UsableDiscountText:SetShown(C_TransmogOutfitInfo.IsUsableDiscountAvailable());
end

function MCUDR_OutfitCollectionMixin:CheckShowHelptips()
	local showTrialOfStyleHelptip = not GetCVarBitfield("closedInfoFramesAccountWide", Enum.FrameTutorialAccount.TransmogTrialOfStyle) and C_TransmogOutfitInfo.TransmogEventActive();

	-- Use OutfitList as the parent for helptips here instead of any scroll box element to prevent the help tip being masked.
	if not GetCVarBitfield("closedInfoFramesAccountWide", Enum.FrameTutorialAccount.TransmogOutfits) then
		local helptipInfo = self.HELPTIP_INFO[Enum.FrameTutorialAccount.TransmogOutfits];
		if showTrialOfStyleHelptip then
			helptipInfo.onAcknowledgeCallback = function()
				self:CheckShowHelptips();
			end;
		end

		HelpTip:Show(self.OutfitList, helptipInfo);
	elseif showTrialOfStyleHelptip then
		HelpTip:Show(self.OutfitList, self.HELPTIP_INFO[Enum.FrameTutorialAccount.TransmogTrialOfStyle]);
	end
end

function MCUDR_OutfitCollectionMixin:UpdateShowEquippedGearButton()
	local overlayFX = self.ShowEquippedGearSpellFrame.OverlayFX;

	local activeOutfit = C_TransmogOutfitInfo.IsEquippedGearOutfitDisplayed();
	overlayFX.OverlayActive:SetShown(activeOutfit);
	self.ShowEquippedGearSpellFrame.Label:SetFontObject(activeOutfit and "GameFontHighlight" or "GameFontNormal");
	self.ShowEquippedGearSpellFrame.Checkmark:SetShown(activeOutfit);

	local isLockedOutfit = C_TransmogOutfitInfo.IsEquippedGearOutfitLocked();
	overlayFX.OverlayLocked:SetShown(isLockedOutfit);
	overlayFX.OverlayLocked:ShowAutoCastEnabled(isLockedOutfit);

	-- Trial of Style visuals
	local inTransmogEvent = C_TransmogOutfitInfo.InTransmogEvent();
	self.ShowEquippedGearSpellFrame.Button:SetEnabled(not inTransmogEvent);
	self.ShowEquippedGearSpellFrame.Button.Icon:SetDesaturated(inTransmogEvent);
end

function MCUDR_OutfitCollectionMixin:UpdateSelectedOutfit()
	local viewedOutfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID();

	if self.canScrollToOutfit then
		local alignment = ScrollBoxConstants.AlignNearest;
		self:ScrollToOutfit(viewedOutfitID, alignment);
		self.canScrollToOutfit = false;
	end

	self.OutfitList.ScrollBox:ForEachFrame(function(frame)
		local elementData = frame:GetElementData();
		if elementData then
			frame:SetSelected(elementData.outfitID == viewedOutfitID);
		end
	end);
end

function MCUDR_OutfitCollectionMixin:ScrollToOutfit(outfitID, alignment)
	local scrollBox = self.OutfitList.ScrollBox;
	local elementData = scrollBox:FindElementDataByPredicate(function(elementData)
		return elementData.outfitID == outfitID;
	end);

	if elementData then
		scrollBox:ScrollToElementData(elementData, alignment);
	end
end

function MCUDR_OutfitCollectionMixin:AnimateViewedOutfitSaved()
	local outfitSaved = true;
	self:SetOutfitSavedState(outfitSaved);

	local viewedOutfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID();
	local alignment = ScrollBoxConstants.AlignBegin;
	self:ScrollToOutfit(viewedOutfitID, alignment);

	self.OutfitList.ScrollBox:ForEachFrame(function(frame)
		local elementData = frame:GetElementData();
		if elementData and elementData.outfitID == viewedOutfitID then
			local animSaved = frame.OutfitButton.AnimSaved;
			animSaved:SetScript("OnFinished", function()
				animSaved:SetScript("OnFinished", nil);
				outfitSaved = false;
				self:SetOutfitSavedState(outfitSaved);
			end);
			animSaved:Restart();
		end
	end);
end

function MCUDR_OutfitCollectionMixin:AnimateOutfitAdded(outfitID)
	local alignment = ScrollBoxConstants.AlignBegin;
	self:ScrollToOutfit(outfitID, alignment);

	self.OutfitList.ScrollBox:ForEachFrame(function(frame)
		local elementData = frame:GetElementData();
		if elementData and elementData.outfitID == outfitID then
			frame.OutfitButton.AnimNew:Restart();
		end
	end);
end

function MCUDR_OutfitCollectionMixin:GetOutfitSavedState()
	return self.outfitSaved;
end

function MCUDR_OutfitCollectionMixin:SetOutfitSavedState(outfitSaved)
	self.outfitSaved = outfitSaved;
end

function MCUDR_OutfitCollectionMixin:GetSaveOutfitDisabledTooltip()
	return self.saveOutfitDisabledTooltip;
end

function MCUDR_OutfitCollectionMixin:SetSaveOutfitDisabledTooltip(tooltip)
	self.saveOutfitDisabledTooltip = tooltip;
end


MCUDR_ShowEquippedGearSpellFrameMixin = {};

function MCUDR_ShowEquippedGearSpellFrameMixin:OnLoad()
	-- Suppress cooldown update during OnLoad to avoid tainting
	-- CooldownFrame_Set — this frame is hidden in the dressing room.
	self.UpdateCooldown = function() end;
	UIPanelSpellButtonFrameMixin.OnLoad(self);

	local drawBling = false;
	self.Button.Cooldown:SetDrawBling(drawBling);

	self.Button.Icon:ClearAllPoints();
	self.Button.Icon:SetSize(36, 36);
	self.Button.Icon:SetPoint("CENTER");

	self.Button:ClearPushedTexture();
	self.Button:SetHighlightAtlas("transmog-outfit-spellframe", "ADD");
end

function MCUDR_ShowEquippedGearSpellFrameMixin:OnIconClick(_button, buttonName)
	-- If already active and normally clicking, nothing will happen so don't possibly show pending dialog.
	local activeOutfit = C_TransmogOutfitInfo.IsEquippedGearOutfitDisplayed();
	if activeOutfit and buttonName == "LeftButton" then
		return;
	end

	local toggleLock = false;
	if buttonName == "RightButton" then
		toggleLock = true;
	end

	C_TransmogOutfitInfo.ClearDisplayedOutfit(Enum.TransmogSituationTrigger.Manual, toggleLock);
end

function MCUDR_ShowEquippedGearSpellFrameMixin:OnIconDragStart()
	-- PickupOutfit with outfitID of 0 is a special case for this spell.
	C_TransmogOutfitInfo.PickupOutfit(0);
end


MCUDR_OutfitPopupMixin = {};

-- Overridden.
function MCUDR_OutfitPopupMixin:OnShow()
	IconSelectorPopupFrameTemplateMixin.OnShow(self);

	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN);
	self.BorderBox.IconSelectorEditBox:SetFocus();
	self.iconDataProvider = CreateAndInitFromMixin(IconDataProviderMixin, IconDataProviderExtraType.Transmog);
	self:SetIconFilter(IconSelectorPopupFrameIconFilterTypes.All);
	self:Update();
	self.BorderBox.IconSelectorEditBox:OnTextChanged();

	local function OnIconSelected(_selectionIndex, icon)
		self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(icon);

		-- Index is not yet set, but we know if an icon in IconSelector was selected it was in the list, so set directly.
		self.BorderBox.SelectedIconArea.SelectedIconText.SelectedIconDescription:SetText(ICON_SELECTION_CLICK);
		self.BorderBox.SelectedIconArea.SelectedIconText.SelectedIconDescription:SetFontObject(GameFontHighlightSmall);
	end
	self.IconSelector:SetSelectedCallback(OnIconSelected);
end

-- Overridden.
function MCUDR_OutfitPopupMixin:OnHide()
	IconSelectorPopupFrameTemplateMixin.OnHide(self);

	self.outfitData = nil;
end

-- Overridden.
function MCUDR_OutfitPopupMixin:Update()
	if self.mode == IconSelectorPopupFrameModes.New then
		self.BorderBox.IconSelectorEditBox:SetText("");

		local initialIndex = 1;
		self.IconSelector:SetSelectedIndex(initialIndex);
		self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(self:GetIconByIndex(initialIndex));
	elseif self.mode == IconSelectorPopupFrameModes.Edit and self.outfitData then
		self.BorderBox.IconSelectorEditBox:SetText(self.outfitData.name);
		self.BorderBox.IconSelectorEditBox:HighlightText();

		self.IconSelector:SetSelectedIndex(self:GetIndexOfIcon(self.outfitData.icon));
		self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(self.outfitData.icon);
	end

	local getSelection = GenerateClosure(self.GetIconByIndex, self);
	local getNumSelections = GenerateClosure(self.GetNumIcons, self);
	self.IconSelector:SetSelectionsDataProvider(getSelection, getNumSelections);
	self.IconSelector:ScrollToSelectedIndex();

	self:SetSelectedIconText();
end

-- Overridden.
function MCUDR_OutfitPopupMixin:OkayButton_OnClick()
	local iconTexture = self.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture();
	local text = self.BorderBox.IconSelectorEditBox:GetText();

	-- Validate name.
	if not C_TransmogOutfitInfo.IsValidTransmogOutfitName(text) then
		local dialogData = {
			mode = self.mode,
			outfitData = self.outfitData
		};
		StaticPopup_Show("MCU_DR_OUTFIT_INVALID_NAME", nil, nil, dialogData);
	else
		if self.mode == IconSelectorPopupFrameModes.New then
			C_TransmogOutfitInfo.AddNewOutfit(text, iconTexture);
		elseif self.mode == IconSelectorPopupFrameModes.Edit and self.outfitData then
			C_TransmogOutfitInfo.CommitOutfitInfo(self.outfitData.outfitID, text, iconTexture);
		end
	end

	-- Run at the end, as this will hide the frame and thus clear outfitData.
	IconSelectorPopupFrameTemplateMixin.OkayButton_OnClick(self);
end


MCUDR_CharacterMixin = {
	DYNAMIC_EVENTS = {
		"VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS",
		"VIEWED_TRANSMOG_OUTFIT_CHANGED",
		"VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH",
		"VIEWED_TRANSMOG_OUTFIT_SLOT_WEAPON_OPTION_CHANGED",
		"VIEWED_TRANSMOG_OUTFIT_SECONDARY_SLOTS_CHANGED",
		"TRANSMOG_DISPLAYED_OUTFIT_CHANGED",
		"PLAYER_EQUIPMENT_CHANGED"
	};
	HELPTIP_INFO = {
		text = TRANSMOG_WEAPON_OPTIONS_HELPTIP,
		buttonStyle = HelpTip.ButtonStyle.Close,
		targetPoint = HelpTip.Point.TopEdgeCenter,
		alignment = HelpTip.Alignment.Center,
		system = "TransmogCharacter",
		acknowledgeOnHide = true,
		cvarBitfield = "closedInfoFramesAccountWide",
		bitfieldFlag = Enum.FrameTutorialAccount.TransmogWeaponOptions
	};
};

function MCUDR_CharacterMixin:OnLoad()
	self.SavedFrame.Anim:SetScript("OnFinished", function()
		self.SavedFrame:Hide();
	end);

	self.HideIgnoredToggle.Checkbox:SetScript("OnClick", function()
		local toggledOn = not GetCVarBool("transmogHideIgnoredSlots");
		if toggledOn then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		else
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF);
		end

		SetCVar("transmogHideIgnoredSlots", toggledOn);
		self:RefreshHideIgnoredToggle();
		self:RefreshSlots();
	end);

	self.ClearAllPendingButton:SetScript("OnMouseDown", function(button)
		button.Icon:SetPoint("CENTER", 2, -2);
	end);

	self.ClearAllPendingButton:SetScript("OnMouseUp", function(button)
		button.Icon:SetPoint("CENTER");
	end);

	self.ClearAllPendingButton:SetScript("OnEnter", function(button)
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT");
		GameTooltip:SetText(TRANSMOGRIFY_CLEAR_ALL_PENDING);
	end);

	self.ClearAllPendingButton:SetScript("OnLeave", GameTooltip_Hide);

	self.ClearAllPendingButton:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.UI_TRANSMOG_REVERTING_GEAR_SLOT);
		C_TransmogOutfitInfo.ClearAllPendingTransmogs();
	end);

	local function OnSlotReleased(pool, slot)
		slot:Release();
		Pool_HideAndClearAnchors(pool, slot);
	end
	self.CharacterAppearanceSlotFramePool = CreateFramePool("BUTTON", self, "MCUDR_AppearanceSlotTemplate", OnSlotReleased);
	self.CharacterIllusionSlotFramePool = CreateFramePool("BUTTON", self, "MCUDR_IllusionSlotTemplate", OnSlotReleased);

	self.ModelScene.ControlFrame:SetModelScene(self.ModelScene);
end

function MCUDR_CharacterMixin:OnShow()
	local hasAlternateForm, inAlternateForm = C_PlayerInfo.GetAlternateFormInfo();
	if hasAlternateForm then
		self:RegisterUnitEvent("UNIT_FORM_CHANGED", "player");
		self.inAlternateForm = inAlternateForm;
	end
	FrameUtil.RegisterFrameForEvents(self, self.DYNAMIC_EVENTS);

	self.ModelScene:TransitionToModelSceneID(290, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true);
	self:RefreshPlayerModel();
	self:SetupSlots();
	-- Defer slot icon refresh so TryOn has time to apply
	C_Timer.After(0.6, function()
		self:RefreshDressingRoomSlots();
	end);

	-- Auto-select the first slot (head) so the appearances grid has something to show
	C_Timer.After(0.1, function()
		if self.drSlotFrames then
			-- Head slot (slotID=1, HEADSLOT)
			local firstSlotID = 1;
			local btn = self.drSlotFrames[firstSlotID];
			if btn then
				btn.SelectedBorder:Show();
				if MCUDR_AppearancesFrame then
					local transmogLoc = MCUDR_Util.GetTransmogLocation(btn.slotName, Enum.TransmogType.Appearance, false);
					if not transmogLoc then
						transmogLoc = MCUDR_Util.CreateTransmogLocation(btn.slotName, Enum.TransmogType.Appearance, false);
					end
					if transmogLoc then
						MCUDR_AppearancesFrame:SetActiveSlot(transmogLoc);
						-- Navigate to previewed item if one exists
						local preview = MCUDR_PreviewedSlots and MCUDR_PreviewedSlots[firstSlotID];
						if preview and preview.sourceID then
							MCUDR_AppearancesFrame:NavigateToSource(preview.sourceID, preview.name);
						end
					end
				end
			end
		end
	end);
end

function MCUDR_CharacterMixin:OnHide()
	self:UnregisterEvent("UNIT_FORM_CHANGED");
	FrameUtil.UnregisterFrameForEvents(self, self.DYNAMIC_EVENTS);

	self.selectedSlotData = nil;
end

-- Custom dressing room slot refresh: reads appearance state from the model actor
-- instead of from C_TransmogOutfitInfo (which is the NPC transmog state)
function MCUDR_CharacterMixin:RefreshDressingRoomSlots()
	if not self.drSlotFrames then return; end

	local previewedSlots = MCUDR_PreviewedSlots or {};

	for slotID, btn in pairs(self.drSlotFrames) do
		local preview = previewedSlots[slotID];
		local equippedTex = GetInventoryItemTexture("player", slotID);
		local isPreviewing = false;

		if preview and preview.icon then
			btn.Icon:SetTexture(preview.icon);
			btn.Icon:SetAlpha(1);
			btn.Icon:SetDesaturated(false);
			isPreviewing = true;
		elseif equippedTex then
			-- Show equipped item
			btn.Icon:SetTexture(equippedTex);
			btn.Icon:SetAlpha(1);
			btn.Icon:SetDesaturated(false);
		else
			-- Empty slot
			btn.Icon:SetTexture(136516);
			btn.Icon:SetAlpha(0.3);
			btn.Icon:SetDesaturated(true);
		end

		if btn.PendingGlow then
			btn.PendingGlow:SetShown(isPreviewing);
		end
	end
end

function MCUDR_CharacterMixin:OnEvent(event, ...)
	-- In dressing room mode, ignore transmog outfit events that would reset our preview
	if event == "VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH"
	   or event == "TRANSMOG_DISPLAYED_OUTFIT_CHANGED"
	   or event == "VIEWED_TRANSMOG_OUTFIT_CHANGED"
	   or event == "VIEWED_TRANSMOG_OUTFIT_SECONDARY_SLOTS_CHANGED"
	   or event == "VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS"
	   or event == "VIEWED_TRANSMOG_OUTFIT_SLOT_WEAPON_OPTION_CHANGED" then
		return;
	end

	if event == "UNIT_FORM_CHANGED" then
		self:HandleFormChanged();
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		-- Only refresh weapon options, don't reset the preview
	elseif event == "VIEWED_TRANSMOG_OUTFIT_SLOT_WEAPON_OPTION_CHANGED" then
		local slot, weaponOption = ...;
		local appearanceType = Enum.TransmogType.Appearance;
		local slotFrame = self:GetSlotFrame(slot, appearanceType);
		if slotFrame then
			slotFrame:SetCurrentWeaponOption(weaponOption);

			local illusionSlotFrame = slotFrame:GetIllusionSlotFrame();
			if illusionSlotFrame then
				illusionSlotFrame:SetCurrentWeaponOptionInfo(slotFrame:GetCurrentWeaponOptionInfo());
			end
		end
	end
end

function MCUDR_CharacterMixin:Refresh()
	self:RefreshPlayerModel();
	self:RefreshSlots();
end

function MCUDR_CharacterMixin:HandleFormChanged()
	if IsUnitModelReadyForUI("player") then
		local _hasAlternateForm, inAlternateForm = C_PlayerInfo.GetAlternateFormInfo();
		if self.inAlternateForm ~= inAlternateForm then
			self.inAlternateForm = inAlternateForm;
			self:Refresh();
		end
	end
end

-- Dressing room: build slots directly without C_TransmogOutfitInfo or TransmogLocation
local DR_SLOT_GROUPS = {
	Left = {
		{ slotID = 1,  name = "HEADSLOT" },
		{ slotID = 3,  name = "SHOULDERSLOT" },
		{ slotID = 15, name = "BACKSLOT" },
		{ slotID = 5,  name = "CHESTSLOT" },
		{ slotID = 19, name = "TABARDSLOT" },
		{ slotID = 4,  name = "SHIRTSLOT" },
		{ slotID = 9,  name = "WRISTSLOT" },
	},
	Right = {
		{ slotID = 10, name = "HANDSSLOT" },
		{ slotID = 6,  name = "WAISTSLOT" },
		{ slotID = 7,  name = "LEGSSLOT" },
		{ slotID = 8,  name = "FEETSLOT" },
	},
	Bottom = {
		{ slotID = 16, name = "MAINHANDSLOT" },
		{ slotID = 17, name = "SECONDARYHANDSLOT" },
	},
};

function MCUDR_CharacterMixin:SetupSlots()
	-- Release any existing slot frames from the pool
	if self.CharacterAppearanceSlotFramePool then
		self.CharacterAppearanceSlotFramePool:ReleaseAll();
	end
	if self.CharacterIllusionSlotFramePool then
		self.CharacterIllusionSlotFramePool:ReleaseAll();
	end

	-- Store simple slot frames we create (not using the complex pool/Init system)
	self.drSlotFrames = self.drSlotFrames or {};
	for _, f in pairs(self.drSlotFrames) do f:Hide(); end

	local groups = {
		{ parent = self.LeftSlots, slots = DR_SLOT_GROUPS.Left },
		{ parent = self.RightSlots, slots = DR_SLOT_GROUPS.Right },
		{ parent = self.BottomSlots, slots = DR_SLOT_GROUPS.Bottom },
	};

	for _, group in ipairs(groups) do
		local parentFrame = group.parent;
		if not parentFrame then break; end

		for index, slotInfo in ipairs(group.slots) do
			local key = slotInfo.slotID;
			local btn = self.drSlotFrames[key];

			if not btn then
				btn = CreateFrame("Button", nil, parentFrame);
				btn:SetSize(59, 59);

				-- Background dark fill (same as transmog slot)
				local bg = btn:CreateTexture(nil, "BACKGROUND");
				bg:SetSize(45, 45);
				bg:SetPoint("CENTER");
				bg:SetColorTexture(0, 0, 0, 0.5);

				local icon = btn:CreateTexture(nil, "ARTWORK");
				icon:SetSize(45, 45);
				icon:SetPoint("CENTER");
				icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
				btn.Icon = icon;

				-- Default border
				local border = btn:CreateTexture(nil, "BORDER");
				border:SetAllPoints();
				border:SetAtlas("transmog-gearslot-default");
				btn.Border = border;

				-- Selected border (shown when this slot is active)
				local selBorder = btn:CreateTexture(nil, "OVERLAY");
				selBorder:SetAllPoints();
				selBorder:SetAtlas("transmog-gearslot-selected");
				selBorder:Hide();
				btn.SelectedBorder = selBorder;

				-- Pending glow (shown when previewing a different item than equipped)
				local pendingGlow = btn:CreateTexture(nil, "OVERLAY", nil, 1);
				pendingGlow:SetAllPoints();
				pendingGlow:SetAtlas("transmog-gearSlot-transmogrified-Glw");
				pendingGlow:Hide();
				btn.PendingGlow = pendingGlow;

				-- Highlight
				local hl = btn:CreateTexture(nil, "HIGHLIGHT");
				hl:SetAllPoints();
				hl:SetAtlas("transmog-gearslot-default");
				hl:SetAlpha(0.3);

				btn:RegisterForClicks("LeftButtonUp", "RightButtonUp");
				btn.slotID = slotInfo.slotID;
				btn.slotName = slotInfo.name;

				btn:SetScript("OnEnter", function(self)
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
					-- Using global MCUDR_PreviewedSlots directly
					local preview = MCUDR_PreviewedSlots and MCUDR_PreviewedSlots[self.slotID];
					if preview and preview.name then
						local r, g, b = GetItemQualityColor(preview.quality or 1);
						GameTooltip:SetText(preview.name, r, g, b);
						GameTooltip:AddLine("Previewing", 0.5, 0.8, 1);
					else
						GameTooltip:SetInventoryItem("player", self.slotID);
					end
					GameTooltip:AddLine(" ");
					GameTooltip:AddLine("Click to find in collection", 0.5, 0.5, 0.5);
					GameTooltip:AddLine("Right-click to undress", 0.5, 0.5, 0.5);
					GameTooltip:Show();
				end);

				btn:SetScript("OnLeave", function() GameTooltip:Hide(); end);

				btn:SetScript("OnClick", function(self, button)
					local actor = MCUDressingRoomFrame and MCUDressingRoomFrame.CharacterPreview
						and MCUDressingRoomFrame.CharacterPreview.ModelScene
						and MCUDressingRoomFrame.CharacterPreview.ModelScene:GetPlayerActor();

					if button == "RightButton" then
						if actor then
							PlaySound(SOUNDKIT.UI_TRANSMOG_REVERTING_GEAR_SLOT);
							actor:DressPlayerSlot(self.slotID);
							-- Clear preview state for this slot
							-- Using global MCUDR_PreviewedSlots directly
							if MCUDR_PreviewedSlots then
								MCUDR_PreviewedSlots[self.slotID] = nil;
							end
							C_Timer.After(0.3, function()
								if MCUDressingRoomFrame and MCUDressingRoomFrame.CharacterPreview then
									MCUDressingRoomFrame.CharacterPreview:RefreshDressingRoomSlots();
								end
							end);
						end
					else
						PlaySound(SOUNDKIT.UI_TRANSMOG_GEAR_SLOT_CLICK);

						-- Highlight this slot
						local charPreview = MCUDressingRoomFrame and MCUDressingRoomFrame.CharacterPreview;
						if charPreview and charPreview.drSlotFrames then
							for _, sf in pairs(charPreview.drSlotFrames) do
								sf.SelectedBorder:Hide();
							end
						end
						self.SelectedBorder:Show();

						-- Navigate our standalone appearances grid to this slot's category
						if MCUDR_AppearancesFrame then
							local transmogLoc = MCUDR_Util.GetTransmogLocation(self.slotName, Enum.TransmogType.Appearance, false);
							if not transmogLoc then
								transmogLoc = MCUDR_Util.CreateTransmogLocation(self.slotName, Enum.TransmogType.Appearance, false);
							end
							if transmogLoc then
								MCUDR_AppearancesFrame:SetActiveSlot(transmogLoc);

								-- If this slot has a previewed item, navigate to it and highlight it
								local preview = MCUDR_PreviewedSlots and MCUDR_PreviewedSlots[self.slotID];
								if preview and preview.sourceID then
									MCUDR_AppearancesFrame:NavigateToSource(preview.sourceID, preview.name);
								else
									MCUDR_AppearancesFrame:ClearActiveVisual();
								end
							end
						end
					end
				end);

				self.drSlotFrames[key] = btn;
			end

			btn:SetParent(parentFrame);
			btn.layoutIndex = index;

			-- Set icon from equipped item
			local tex = GetInventoryItemTexture("player", slotInfo.slotID);
			if tex then
				btn.Icon:SetTexture(tex);
				btn.Icon:SetAlpha(1);
				btn.Icon:SetDesaturated(false);
			else
				btn.Icon:SetTexture(136516);
				btn.Icon:SetAlpha(0.3);
				btn.Icon:SetDesaturated(true);
			end

			btn:Show();
		end

		parentFrame:Layout();
	end
end

function MCUDR_CharacterMixin:SetupSlotSection(groupData)
	local parentFrame;
	if groupData.position == Enum.TransmogOutfitSlotPosition.Left then
		parentFrame = self.LeftSlots;
	elseif groupData.position == Enum.TransmogOutfitSlotPosition.Right then
		parentFrame = self.RightSlots;
	elseif groupData.position == Enum.TransmogOutfitSlotPosition.Bottom then
		parentFrame = self.BottomSlots;
	end

	-- Appearance slots.
	for index, appearanceInfo in ipairs(groupData.appearanceSlotInfo) do
		local slotFrame = self.CharacterAppearanceSlotFramePool:Acquire();

		local transmogLocation = TransmogUtil.GetTransmogLocation(appearanceInfo.slotName, appearanceInfo.type, appearanceInfo.isSecondary);
		local slotData = {
			transmogLocation = transmogLocation,
			transmogFrame = MCUDressingRoomFrame,
			currentWeaponOptionInfo = nil,
			-- Appearance specific fields.
			weaponOptionsInfo = nil,
			artifactOptionsInfo = nil
		};
		slotFrame.layoutIndex = index;

		slotFrame:Init(slotData);
		slotFrame:SetParent(parentFrame);
		slotFrame:Show();
	end

	-- Illusion slots, should only be created once their corresponding appearance slot is in place as they need to anchor off of it.
	local illusionAnchorOffset = 19;
	local appearanceType = Enum.TransmogType.Appearance;
	for _index, illusionInfo in ipairs(groupData.illusionSlotInfo) do
		local slotFrame = self:GetSlotFrame(illusionInfo.slot, appearanceType);
		assertsafe(slotFrame ~= nil);
		if slotFrame then
			local illusionSlotFrame = self.CharacterIllusionSlotFramePool:Acquire();
			slotFrame:SetIllusionSlotFrame(illusionSlotFrame);

			local transmogLocation = TransmogUtil.GetTransmogLocation(illusionInfo.slotName, illusionInfo.type, illusionInfo.isSecondary);
			local illusionSlotData = {
				transmogLocation = transmogLocation,
				transmogFrame = MCUDressingRoomFrame,
				currentWeaponOptionInfo = slotFrame:GetCurrentWeaponOptionInfo()
			};

			illusionSlotFrame:Init(illusionSlotData);
			illusionSlotFrame:SetParent(slotFrame);
			illusionSlotFrame:SetFrameLevel(300);
			if groupData.position == Enum.TransmogOutfitSlotPosition.Left then
				illusionSlotFrame:SetPoint("RIGHT", slotFrame, "LEFT", -illusionAnchorOffset, 0);
			elseif groupData.position == Enum.TransmogOutfitSlotPosition.Right then
				illusionSlotFrame:SetPoint("LEFT", slotFrame, "RIGHT", illusionAnchorOffset, 0);
			elseif groupData.position == Enum.TransmogOutfitSlotPosition.Bottom then
				illusionSlotFrame:SetPoint("TOP", slotFrame, "BOTTOM", 0, illusionAnchorOffset);
			end
			illusionSlotFrame:Show();
		end
	end

	parentFrame:Layout();
end

function MCUDR_CharacterMixin:RefreshHideIgnoredToggle()
	if self.HideIgnoredToggle then
		self.HideIgnoredToggle:Hide();
	end
end

function MCUDR_CharacterMixin:RefreshPlayerModel()
	local modelScene = self.ModelScene;
	if modelScene.previousActor then
		modelScene.previousActor:ClearModel();
		modelScene.previousActor = nil;
	end

	local actor = modelScene:GetPlayerActor();
	if actor then
		local sheatheWeapons = false;
		local autoDress = true;
		local hideWeapons = false;
		actor:SetModelByUnit("player", sheatheWeapons, autoDress, hideWeapons, PlayerUtil.ShouldUseNativeFormInModelScene());
		modelScene.previousActor = actor;
	end
end

function MCUDR_CharacterMixin:RefreshSlotWeaponOptions(clearCurrentWeaponOptionInfo)
	for slotFrame in self.CharacterAppearanceSlotFramePool:EnumerateActive() do
		if clearCurrentWeaponOptionInfo then
			slotFrame:SetCurrentWeaponOptionInfo(slotFrame.DEFAULT_WEAPON_OPTION_INFO);
		end

		slotFrame:RefreshWeaponOptions();
	end
end

function MCUDR_CharacterMixin:RefreshSlots()
	local actor = self.ModelScene:GetPlayerActor();
	if not actor then
		return;
	end

	for slotFrame in self.CharacterAppearanceSlotFramePool:EnumerateActive() do
		slotFrame:Update();

		-- Slot that was selected is now disabled, will need to select a new slot.
		local selectedSlotTransmogLocation = self.selectedSlotData and self.selectedSlotData.transmogLocation or nil;
		local appearanceSlotTransmogLocation = slotFrame:GetTransmogLocation();
		if appearanceSlotTransmogLocation and selectedSlotTransmogLocation and appearanceSlotTransmogLocation:IsEqual(selectedSlotTransmogLocation) and not slotFrame:IsEnabled() then
			self.selectedSlotData = nil;
		end

		local illusionSlotFrame = slotFrame:GetIllusionSlotFrame();
		if illusionSlotFrame then
			illusionSlotFrame:Update();

			local illusionSlotTransmogLocation = illusionSlotFrame:GetTransmogLocation();
			if illusionSlotTransmogLocation and selectedSlotTransmogLocation and illusionSlotTransmogLocation:IsEqual(selectedSlotTransmogLocation) and not illusionSlotFrame:IsEnabled() then
				self.selectedSlotData = nil;
			end
		end

		-- Only attempt to set a slot's appearance on the actor if this is not a secondary slot (the primary slot will handle things for it).
		local linkedSlotInfo = C_TransmogOutfitInfo.GetLinkedSlotInfo(slotFrame.slotData.transmogLocation:GetSlot());
		if not linkedSlotInfo or linkedSlotInfo.primarySlotInfo.slot == slotFrame.slotData.transmogLocation:GetSlot() then
			-- Secondary slots.
			local secondaryAppearanceID = Constants.Transmog.NoTransmogID;
			if linkedSlotInfo then
				-- Use primary slot option.
				local outfitSlotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(linkedSlotInfo.secondarySlotInfo.slot, linkedSlotInfo.secondarySlotInfo.type, slotFrame:GetCurrentWeaponOptionInfo().weaponOption);
				if outfitSlotInfo then
					secondaryAppearanceID = outfitSlotInfo.transmogID;
				end
			end

			-- Illusions.
			local illusionID = Constants.Transmog.NoTransmogID;
			if illusionSlotFrame then
				local illusionSlotInfo = illusionSlotFrame:GetSlotInfo();
				if illusionSlotInfo and illusionSlotInfo.warning ~= Enum.TransmogOutfitSlotWarning.WeaponDoesNotSupportIllusions then
					illusionID = illusionSlotInfo.transmogID;
				end
			end

			local transmogLocation = slotFrame:GetTransmogLocation();
			if transmogLocation then

				local slotID = transmogLocation:GetSlotID();
				if slotID ~= nil then
					local appearanceID = slotFrame:GetEffectiveTransmogID();
					local itemTransmogInfo = ItemUtil.CreateItemTransmogInfo(appearanceID, secondaryAppearanceID, illusionID);
					local currentItemTransmogInfo = actor:GetItemTransmogInfo(slotID);

					-- Need the main category for mainhand.
					local mainHandCategoryID;
					local isLegionArtifact = false;
					if transmogLocation:IsMainHand() then
						mainHandCategoryID = C_TransmogOutfitInfo.GetItemModifiedAppearanceEffectiveCategory(appearanceID);
						isLegionArtifact = TransmogUtil.IsCategoryLegionArtifact(mainHandCategoryID);
						itemTransmogInfo:ConfigureSecondaryForMainHand(isLegionArtifact);
					end

					-- Update only if there is a change or it can recurse (offhand is processed first and mainhand might override offhand).
					if not itemTransmogInfo:IsEqual(currentItemTransmogInfo) or isLegionArtifact then
						if appearanceID == Constants.Transmog.NoTransmogID then
							actor:UndressSlot(slotID);
						else
							-- Don't specify a slot for ranged weapons.
							if mainHandCategoryID and TransmogUtil.IsCategoryRangedWeapon(mainHandCategoryID) then
								slotID = nil;
							end
							actor:SetItemTransmogInfo(itemTransmogInfo, slotID);
						end
					end
				end
			end
		end
	end

	-- Select valid slot now that everything has updated if needed.
	if not self.selectedSlotData then
		self:SetInitialSelectedSlot();
	end
end

function MCUDR_CharacterMixin:RefreshSelectedSlot()
	if not self.selectedSlotData then
		return;
	end

	local slotFrame = self:GetSlotFrame(self.selectedSlotData.transmogLocation:GetSlot(), self.selectedSlotData.transmogLocation:GetType());
	if slotFrame then
		local forceRefresh = true;
		MCUDressingRoomFrame:SelectSlot(slotFrame, forceRefresh);
	end
end

function MCUDR_CharacterMixin:SetInitialSelectedSlot()
	local function FindValidSlotToSelect(slotsParent)
		for _index, slotFrame in ipairs(slotsParent:GetLayoutChildren()) do
			if slotFrame:IsEnabled() and slotFrame:GetTransmogLocation():IsAppearance() then
				local fromOnClick = false;
				slotFrame:OnSelect(fromOnClick);
				return true;
			end
		end
		return false;
	end

	local selectionFound = FindValidSlotToSelect(self.LeftSlots);

	if not selectionFound then
		selectionFound = FindValidSlotToSelect(self.BottomSlots);
	end

	if not selectionFound then
		selectionFound = FindValidSlotToSelect(self.RightSlots);
	end

	return selectionFound;
end

function MCUDR_CharacterMixin:UpdateSlot(slotData, forceRefresh)
	if not slotData then
		self.selectedSlotData = nil;
		return;
	end

	if not self.selectedSlotData or (slotData.transmogLocation and self.selectedSlotData.transmogLocation and not slotData.transmogLocation:IsEqual(self.selectedSlotData.transmogLocation)) then
		if self.selectedSlotData and self.selectedSlotData.transmogLocation:IsEitherHand() and not GetCVarBitfield("closedInfoFramesAccountWide", Enum.FrameTutorialAccount.TransmogWeaponOptions) then
			-- If the previous selected slot was either hand slot, and the associated help tip hasn't been acknowledged, mark it as seen as it should have been viewed by now.
			HelpTip:HideAllSystem("TransmogCharacter");
		end

		self.selectedSlotData = slotData;
		local showHelptip = self.selectedSlotData.transmogLocation:IsEitherHand() and not GetCVarBitfield("closedInfoFramesAccountWide", Enum.FrameTutorialAccount.TransmogWeaponOptions);
		for slotFrame in self.CharacterAppearanceSlotFramePool:EnumerateActive() do
			local selected = slotFrame.slotData.transmogLocation and self.selectedSlotData.transmogLocation and slotFrame.slotData.transmogLocation:IsEqual(self.selectedSlotData.transmogLocation);
			slotFrame:SetSelected(selected);

			if showHelptip and selected then
				-- Help tip parent is dependent on if the flyout dropdown is shown or not.
				local helpTipParent = slotFrame.FlyoutDropdown:IsShown() and slotFrame.FlyoutDropdown or slotFrame;
				HelpTip:Show(helpTipParent, self.HELPTIP_INFO);
			end
		end

		for slotFrame in self.CharacterIllusionSlotFramePool:EnumerateActive() do
			slotFrame:SetSelected(slotFrame.slotData.transmogLocation and self.selectedSlotData.transmogLocation and slotFrame.slotData.transmogLocation:IsEqual(self.selectedSlotData.transmogLocation));
		end
	elseif forceRefresh then
		self.selectedSlotData = slotData;
		-- Refresh the visuals on the actor.
		self:RefreshSlots();
	end
end

function MCUDR_CharacterMixin:GetSelectedSlotData()
	return self.selectedSlotData;
end

function MCUDR_CharacterMixin:GetSlotFrame(slot, type)
	for slotFrame in self.CharacterAppearanceSlotFramePool:EnumerateActive() do
		if slotFrame.slotData.transmogLocation and slotFrame.slotData.transmogLocation:GetSlot() == slot and slotFrame.slotData.transmogLocation:GetType() == type then
			return slotFrame;
		end
	end

	for slotFrame in self.CharacterIllusionSlotFramePool:EnumerateActive() do
		if slotFrame.slotData.transmogLocation and slotFrame.slotData.transmogLocation:GetSlot() == slot and slotFrame.slotData.transmogLocation:GetType() == type then
			return slotFrame;
		end
	end

	return nil;
end

function MCUDR_CharacterMixin:GetCurrentTransmogInfo()
	local transmogInfo = {};
	for slotFrame in self.CharacterAppearanceSlotFramePool:EnumerateActive() do
		local transmogLocation = slotFrame:GetTransmogLocation();
		local slotInfo = slotFrame:GetSlotInfo();
		if transmogLocation and not transmogLocation:IsSecondary() and slotInfo and slotInfo.transmogID ~= Constants.Transmog.NoTransmogID then
			transmogInfo[transmogLocation] = {
				transmogID = slotInfo.transmogID,
				hasPending = slotInfo.hasPending
			};
		end

		local illusionSlotFrame = slotFrame:GetIllusionSlotFrame();
		if illusionSlotFrame then
			local illusionTransmogLocation = illusionSlotFrame:GetTransmogLocation();
			local illusionSlotInfo = illusionSlotFrame:GetSlotInfo();

			if illusionTransmogLocation and not illusionTransmogLocation:IsSecondary() and illusionSlotInfo and illusionSlotInfo.transmogID ~= Constants.Transmog.NoTransmogID then
				transmogInfo[illusionTransmogLocation] = {
					transmogID = illusionSlotInfo.transmogID,
					hasPending = illusionSlotInfo.hasPending
				};
			end
		end
	end

	return transmogInfo;
end

function MCUDR_CharacterMixin:GetCurrentTransmogIcons()
	local transmogIcons = {};
	for slotFrame in self.CharacterAppearanceSlotFramePool:EnumerateActive() do
		local slotFrameIcons = slotFrame:GetCurrentIcons();
		for _index, slotFrameIcon in ipairs(slotFrameIcons) do
			table.insert(transmogIcons, slotFrameIcon);
		end
	end

	return transmogIcons;
end

-- Used for custom set data formats.
function MCUDR_CharacterMixin:GetItemTransmogInfoList()
	local actor = self.ModelScene:GetPlayerActor();
	if not actor then
		return nil;
	end

	return actor:GetItemTransmogInfoList();
end


MCUDR_WardrobeMixin = {
	HELPTIP_INFO = {
		[Enum.FrameTutorialAccount.TransmogSets] =
		{
			text = TRANSMOG_SETS_HELPTIP,
			buttonStyle = HelpTip.ButtonStyle.Close,
			targetPoint = HelpTip.Point.BottomEdgeCenter,
			alignment = HelpTip.Alignment.Center,
			offsetY = 5,
			system = "TransmogWardrobe",
			acknowledgeOnHide = true,
			cvarBitfield = "closedInfoFramesAccountWide",
			bitfieldFlag = Enum.FrameTutorialAccount.TransmogSets
		},
		[Enum.FrameTutorialAccount.TransmogCustomSets] =
		{
			text = TRANSMOG_CUSTOM_SETS_HELPTIP,
			buttonStyle = HelpTip.ButtonStyle.Close,
			targetPoint = HelpTip.Point.BottomEdgeCenter,
			alignment = HelpTip.Alignment.Center,
			offsetY = 5,
			system = "TransmogWardrobe",
			acknowledgeOnHide = true,
			cvarBitfield = "closedInfoFramesAccountWide",
			bitfieldFlag = Enum.FrameTutorialAccount.TransmogCustomSets
		},
		[Enum.FrameTutorialAccount.TransmogSituations] =
		{
			text = TRANSMOG_SITUATIONS_HELPTIP,
			buttonStyle = HelpTip.ButtonStyle.Close,
			targetPoint = HelpTip.Point.BottomEdgeCenter,
			alignment = HelpTip.Alignment.Center,
			offsetY = 5,
			system = "TransmogWardrobe",
			acknowledgeOnHide = true,
			cvarBitfield = "closedInfoFramesAccountWide",
			bitfieldFlag = Enum.FrameTutorialAccount.TransmogSituations
		},
		[Enum.FrameTutorialAccount.TransmogCustomSetsMigration] =
		{
			text = TRANSMOG_CUSTOM_SETS_MIGRATION_HELPTIP,
			buttonStyle = HelpTip.ButtonStyle.Close,
			targetPoint = HelpTip.Point.BottomEdgeCenter,
			alignment = HelpTip.Alignment.Center,
			offsetY = 5,
			system = "TransmogWardrobe",
			acknowledgeOnHide = true,
			cvarBitfield = "closedInfoFramesAccountWide",
			bitfieldFlag = Enum.FrameTutorialAccount.TransmogCustomSetsMigration
		}
	};
};

function MCUDR_WardrobeMixin:OnLoad()
	-- Hide the copied Transmog tab/content system — we use our own ported grid
	if self.TabHeaders then self.TabHeaders:Hide(); end
	if self.TabContent then self.TabContent:Hide(); end
end

-- Standalone appearances grid (no embedding of Blizzard frames)
function MCUDR_WardrobeMixin:InitAppearancesGrid()
	if self._gridInitDone then return; end
	self._gridInitDone = true;

	-- The MCUDR_AppearancesFrame is created by DressingRoomWardrobe.xml
	-- and should be a child of our WardrobeCollection panel in the DressingRoomFrame.xml.
	-- If it's not parented there yet, find it and position it.
	if MCUDR_AppearancesFrame then
		MCUDR_AppearancesFrame:SetParent(self);
		MCUDR_AppearancesFrame:ClearAllPoints();
		MCUDR_AppearancesFrame:SetAllPoints(self);
		MCUDR_AppearancesFrame:SetFrameLevel(self:GetFrameLevel() + 1);

		-- Add extra rows (5 total = 30 models)
		local grid = MCUDR_AppearancesFrame;
		if grid.Models and grid.NUM_ROWS then
			local numCols = grid.NUM_COLS or 6;
			local targetRows = 5;
			local targetCount = targetRows * numCols;

			if #grid.Models >= numCols * 2 and #grid.Models < targetCount then
				for newRow = 3, targetRows - 1 do
					for col = 0, numCols - 1 do
						local newIndex = newRow * numCols + col + 1;
						if not grid.Models[newIndex] then
							local model = CreateFrame("DressUpModel", nil, grid, "MCUDR_WardrobeModelTemplate");
							model:ClearAllPoints();
							if col == 0 then
								-- First column: anchor below model above (matches XML pattern)
								local aboveIndex = (newRow - 1) * numCols + 1;
								local aboveModel = grid.Models[aboveIndex];
								if aboveModel then
									model:SetPoint("TOPLEFT", aboveModel, "BOTTOMLEFT", 0, -24);
								end
							else
								-- Subsequent columns: anchor to the right of previous in same row
								local leftModel = grid.Models[newIndex - 1];
								if leftModel then
									model:SetPoint("TOPLEFT", leftModel, "TOPRIGHT", 16, 0);
								end
							end
							model:Hide();
							grid.Models[newIndex] = model;
						end
					end
				end
			end

			grid.NUM_ROWS = targetRows;
			grid.PAGE_SIZE = targetCount;
		end

		-- Vertically center the grid in the panel
		-- Model height=104, row gap=24, search bar~35px top, paging~33px bottom
		local numRows = grid.NUM_ROWS or 3;
		local gridHeight = numRows * 104 + (numRows - 1) * 24;
		local panelHeight = self:GetHeight() or 860;
		local topReserved = 35;   -- search/filter bar
		local bottomReserved = 33; -- paging controls
		local availableHeight = panelHeight - topReserved - bottomReserved;
		local yOffset = -(topReserved + (availableHeight - gridHeight) / 2);
		-- Reposition the first model to center the grid
		local firstModel = grid.Models and grid.Models[1];
		if firstModel then
			firstModel:ClearAllPoints();
			firstModel:SetPoint("TOP", grid, "TOP", -235, yOffset);
		end
	end
end

function MCUDR_WardrobeMixin:OnShow()
	self:InitAppearancesGrid();
	if MCUDR_AppearancesFrame then
		MCUDR_AppearancesFrame:Show();
	end
end

function MCUDR_WardrobeMixin:OnHide()
	if MCUDR_AppearancesFrame then
		MCUDR_AppearancesFrame:Hide();
	end
end

function MCUDR_WardrobeMixin:UpdateTabs() end
function MCUDR_WardrobeMixin:SetToDefaultAvailableTab() end

function MCUDR_WardrobeMixin:SetToItemsTab() end

function MCUDR_WardrobeMixin:SetTab(tabID) end
function MCUDR_WardrobeMixin:CheckShowHelptips(tabID) end

function MCUDR_WardrobeMixin:UpdateSlot(slotData, forceRefresh)
	if MCUDR_AppearancesFrame and slotData and slotData.transmogLocation then
		MCUDR_AppearancesFrame:SetActiveSlot(slotData.transmogLocation);
	end
end


MCUDR_WardrobeItemsMixin = {
	DYNAMIC_EVENTS = {
		"TRANSMOG_SEARCH_UPDATED",
		"TRANSMOG_COLLECTION_UPDATED",
		"UI_SCALE_CHANGED",
		"DISPLAY_SIZE_CHANGED",
		"TRANSMOG_COLLECTION_CAMERA_UPDATE",
		"VIEWED_TRANSMOG_OUTFIT_CHANGED",
		"VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH",
		"VIEWED_TRANSMOG_OUTFIT_SECONDARY_SLOTS_CHANGED",
		"VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS",
		"PLAYER_EQUIPMENT_CHANGED"
	};
	COLLECTION_TEMPLATES = {
		["COLLECTION_ITEM"] = { template = "MCUDR_ItemModelTemplate", initFunc = MCUDR_ItemModelMixin.Init, resetFunc = MCUDR_ItemModelMixin.Reset }
	};
	WEAPON_DROPDOWN_WIDTH = 168;
};

function MCUDR_WardrobeItemsMixin:OnLoad()
	self:InitFilterButton();
	self.PagedContent:SetElementTemplateData(self.COLLECTION_TEMPLATES);
	self.SearchBox:SetSearchType(self.searchType);
	self.WeaponDropdown:SetWidth(self.WEAPON_DROPDOWN_WIDTH);

	local function SetPendingDisplayTypeForSlot(displayType)
		local selectedSlotData = self:GetSelectedSlotCallback();
		if not selectedSlotData or not selectedSlotData.transmogLocation then
			return;
		end

		local transmogID = Constants.Transmog.NoTransmogID;
		C_TransmogOutfitInfo.SetPendingTransmog(selectedSlotData.transmogLocation:GetSlot(), selectedSlotData.transmogLocation:GetType(), selectedSlotData.currentWeaponOptionInfo.weaponOption, transmogID, displayType);
	end

	local displayTypeUnassignedButton = self.DisplayTypes.DisplayTypeUnassignedButton;
	local displayTypeEquippedButton = self.DisplayTypes.DisplayTypeEquippedButton;

	if not MCUDR_DisplayTypeUnassignedSupported() then
		displayTypeUnassignedButton:Hide();
	else
		displayTypeUnassignedButton.SavedFrame.Anim:SetScript("OnFinished", function()
			displayTypeUnassignedButton.SavedFrame:Hide();
		end);

		displayTypeUnassignedButton:SetScript("OnLeave", GameTooltip_Hide);

		displayTypeUnassignedButton:SetScript("OnClick", function()
			PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);
			SetPendingDisplayTypeForSlot(Enum.TransmogOutfitDisplayType.Unassigned);
		end);
	end

	displayTypeEquippedButton.SavedFrame.Anim:SetScript("OnFinished", function()
		displayTypeEquippedButton.SavedFrame:Hide();
	end);

	displayTypeEquippedButton:SetScript("OnEnter", function(button)
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT");
		GameTooltip_AddHighlightLine(GameTooltip, TRANSMOG_SLOT_DISPLAY_TYPE_EQUIPPED);
		GameTooltip_AddNormalLine(GameTooltip, TRANSMOG_SLOT_DISPLAY_TYPE_EQUIPPED_TOOLTIP);
		GameTooltip:Show();
	end);

	displayTypeEquippedButton:SetScript("OnLeave", GameTooltip_Hide);

	displayTypeEquippedButton:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);
		SetPendingDisplayTypeForSlot(Enum.TransmogOutfitDisplayType.Equipped);
	end);

	self.SecondaryAppearanceToggle.Checkbox:SetScript("OnClick", function(button)
		local selectedSlotData = self:GetSelectedSlotCallback();
		if not selectedSlotData or not selectedSlotData.transmogLocation then
			return;
		end

		local toggledOn = button:GetChecked();
		if toggledOn then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		else
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF);
		end
		C_TransmogOutfitInfo.SetSecondarySlotState(selectedSlotData.transmogLocation:GetSlot(), toggledOn);
		self.SecondaryAppearanceToggle.Text:SetFontObject(toggledOn and "GameFontHighlight" or "GameFontNormal");
	end);

	self:Reset();
	self.DisplayTypes:Layout();
end

function MCUDR_WardrobeItemsMixin:OnShow()
	local hasAlternateForm, inAlternateForm = C_PlayerInfo.GetAlternateFormInfo();
	if hasAlternateForm then
		self:RegisterUnitEvent("UNIT_FORM_CHANGED", "player");
		self.inAlternateForm = inAlternateForm;
	end
	FrameUtil.RegisterFrameForEvents(self, self.DYNAMIC_EVENTS);

	self:Refresh();
end

function MCUDR_WardrobeItemsMixin:OnHide()
	self:UnregisterEvent("UNIT_FORM_CHANGED");
	FrameUtil.UnregisterFrameForEvents(self, self.DYNAMIC_EVENTS);
end

function MCUDR_WardrobeItemsMixin:OnEvent(event, ...)
	if event == "UNIT_FORM_CHANGED" then
		self:HandleFormChanged();
	elseif event == "TRANSMOG_SEARCH_UPDATED" then
		local searchType, collectionType = ...;
		if searchType == self.searchType and collectionType == self.activeCategoryID then
			self:RefreshCollectionEntries();

			if self.jumpToTransmogID then
				self:PageToTransmogID(self.jumpToTransmogID);
				self.jumpToTransmogID = nil;
			end
		end
	elseif event == "TRANSMOG_COLLECTION_UPDATED" then
		self:RefreshCollectionEntries();
	elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" or event == "TRANSMOG_COLLECTION_CAMERA_UPDATE" then
		self:RefreshCameras();
	elseif event == "VIEWED_TRANSMOG_OUTFIT_CHANGED" then
		self:RefreshActiveSlotTitle();
		self:RefreshDisplayTypeButtons();
		self:RefreshSecondaryAppearanceToggle();
		self:RefreshCameras();
		self:RefreshPagedEntry();
	elseif event == "VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH" then
		self:RefreshDisplayTypeButtons();
		self:RefreshCollectionEntries();
	elseif event == "VIEWED_TRANSMOG_OUTFIT_SECONDARY_SLOTS_CHANGED" then
		self:RefreshActiveSlotTitle();
		self:RefreshCameras();
	elseif event == "VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS" then
		local slot, type, weaponOption = ...;
		local selectedSlotData = self:GetSelectedSlotCallback();
		if not selectedSlotData or not selectedSlotData.transmogLocation then
			return;
		end

		-- Already set to true, do not stomp if multiple slots are changing.
		if self:GetOutfitSlotSavedState() then
			return;
		end

		local outfitSlotSaved = selectedSlotData.transmogLocation:GetSlot() == slot and selectedSlotData.transmogLocation:GetType() == type and selectedSlotData.currentWeaponOptionInfo.weaponOption == weaponOption;
		self:SetOutfitSlotSavedState(outfitSlotSaved);
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		self:RefreshDisplayTypeButtons();
	end
end

function MCUDR_WardrobeItemsMixin:OnKeyDown(key)
	if key == WARDROBE_PREV_VISUAL_KEY or key == WARDROBE_NEXT_VISUAL_KEY or key == WARDROBE_UP_VISUAL_KEY or key == WARDROBE_DOWN_VISUAL_KEY then
		self:UpdateSelectedVisualFromKeyPress(key);
		return false;
	end
	return true;
end

function MCUDR_WardrobeItemsMixin:Init(wardrobeCollection)
	self.wardrobeCollection = wardrobeCollection;

	-- Ensure both collected and uncollected items are visible
	-- Use individual setters instead of SetDefaultFilters to avoid event loops
	if C_TransmogCollection.SetCollectedShown then
		C_TransmogCollection.SetCollectedShown(true);
	end
	if C_TransmogCollection.SetUncollectedShown then
		C_TransmogCollection.SetUncollectedShown(true);
	end
	if C_TransmogCollection.SetAllSourceTypeFilters then
		C_TransmogCollection.SetAllSourceTypeFilters(true);
	end
end

function MCUDR_WardrobeItemsMixin:InitFilterButton()
	self.FilterButton:SetText(SOURCES);

	self.FilterButton:SetupMenu(function(_dropdown, rootDescription)
		rootDescription:SetTag("MENU_TRANSMOG_ITEMS_FILTER");

		rootDescription:CreateButton(CHECK_ALL, function()
			C_TransmogCollection.SetAllSourceTypeFilters(true);
			return MenuResponse.Refresh;
		end);

		rootDescription:CreateButton(UNCHECK_ALL, function()
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
			if (C_TransmogCollection.IsValidTransmogSource(filterIndex)) then
				rootDescription:CreateCheckbox(_G["TRANSMOG_SOURCE_"..filterIndex], IsChecked, SetChecked, filterIndex);
			end
		end
	end);

	self.FilterButton:SetIsDefaultCallback(function()
		return C_TransmogCollection.IsUsingDefaultFilters();
	end);

	self.FilterButton:SetDefaultCallback(function()
		return C_TransmogCollection.SetDefaultFilters();
	end);
end

function MCUDR_WardrobeItemsMixin:Reset()
	self.activeCategoryID = nil;
	self.lastWeaponCategoryID = nil;
	self.transmogLocation = nil;
	self.itemCollectionEntries = nil;
	self.chosenVisualSources = {};
	self.PagedContent:SetDataProvider(CreateDataProvider());
end

function MCUDR_WardrobeItemsMixin:HandleFormChanged()
	if IsUnitModelReadyForUI("player") then
		local _hasAlternateForm, inAlternateForm = C_PlayerInfo.GetAlternateFormInfo();
		if self.inAlternateForm ~= inAlternateForm then
			self.inAlternateForm = inAlternateForm;
			self:RefreshCollectionEntries();
		end
	end
end

function MCUDR_WardrobeItemsMixin:Refresh()
	self:RefreshActiveSlotTitle();
	self:RefreshFilterButtons();
	self:RefreshWeaponDropdown();
	self:RefreshDisplayTypeButtons();
	self:RefreshSecondaryAppearanceToggle();
	self:RefreshCollectionEntries();
end

function MCUDR_WardrobeItemsMixin:RefreshActiveSlotTitle()
	local selectedSlotData = self:GetSelectedSlotCallback();
	if not selectedSlotData or not selectedSlotData.transmogLocation then
		self.ActiveSlotTitle:SetText("");
		return;
	end

	local slotName = _G[selectedSlotData.transmogLocation:GetSlotName()];
	if selectedSlotData.transmogLocation:IsIllusion() then
		slotName = WEAPON_ENCHANTMENT;
	else
		-- Use weapon option name if set.
		-- Use different names if slots are split.
		if selectedSlotData.currentWeaponOptionInfo.weaponOption ~= Enum.TransmogOutfitSlotOption.None then
			slotName = selectedSlotData.currentWeaponOptionInfo.name;
		elseif C_TransmogOutfitInfo.GetSecondarySlotState(selectedSlotData.transmogLocation:GetSlot()) then
			if selectedSlotData.transmogLocation:GetSlot() == Enum.TransmogOutfitSlot.ShoulderRight then
				slotName = RIGHTSHOULDERSLOT;
			elseif selectedSlotData.transmogLocation:GetSlot() == Enum.TransmogOutfitSlot.ShoulderLeft then
				slotName = LEFTSHOULDERSLOT;
			end
		end
	end
	self.ActiveSlotTitle:SetText(slotName);
end

function MCUDR_WardrobeItemsMixin:RefreshFilterButtons()
	local selectedSlotData = self:GetSelectedSlotCallback();
	if not selectedSlotData or not selectedSlotData.transmogLocation or selectedSlotData.transmogLocation:IsIllusion() then
		self.SearchBox:Hide();
		self.FilterButton:Hide();
		return;
	end

	self.SearchBox:Show();
	self.FilterButton:Show();

	-- Reapply current search, in case the collection has changed.
	self.SearchBox:UpdateSearch();
end

function MCUDR_WardrobeItemsMixin:RefreshWeaponDropdown()
	if not self.activeCategoryID then
		self.WeaponDropdown:Hide();
		return;
	end

	local selectedSlotData = self:GetSelectedSlotCallback();
	if not selectedSlotData or not selectedSlotData.transmogLocation or selectedSlotData.transmogLocation:IsIllusion() then
		self.WeaponDropdown:Hide();
		return;
	end

	local activeCollectionInfo = C_TransmogOutfitInfo.GetCollectionInfoForSlotAndOption(selectedSlotData.transmogLocation:GetSlot(), selectedSlotData.currentWeaponOptionInfo.weaponOption, self.activeCategoryID);

	if not activeCollectionInfo or not activeCollectionInfo.isWeapon then
		self.WeaponDropdown:Hide();
		return;
	end

	local validCategories = {};
	for categoryID = FIRST_TRANSMOG_COLLECTION_WEAPON_TYPE, LAST_TRANSMOG_COLLECTION_WEAPON_TYPE do
		local collectionInfo = C_TransmogOutfitInfo.GetCollectionInfoForSlotAndOption(selectedSlotData.transmogLocation:GetSlot(), selectedSlotData.currentWeaponOptionInfo.weaponOption, categoryID);
		if collectionInfo and collectionInfo.isWeapon then
			validCategories[categoryID] = collectionInfo.name;
		end
	end

	-- Only show weapon dropdown if there are more than 1 options to choose from.
	if table.count(validCategories) <= 1 then
		self.WeaponDropdown:Hide();
		return;
	end

	self.WeaponDropdown:Show();

	local function IsSelected(categoryID)
		return categoryID == self.activeCategoryID;
	end

	local function SetSelected(categoryID)
		if categoryID ~= self.activeCategoryID then
			self:SetActiveCategory(categoryID);
		end
	end

	self.WeaponDropdown:SetupMenu(function(_dropdown, rootDescription)
		rootDescription:SetTag("MENU_TRANSMOG_WEAPONS_FILTER");

		for categoryID, name in pairs(validCategories) do
			rootDescription:CreateRadio(name, IsSelected, SetSelected, categoryID);
		end
	end);
end

function MCUDR_WardrobeItemsMixin:RefreshDisplayTypeButtons()
	-- Hidden in dressing room mode - all items always shown
	if self.DisplayTypes then
		self.DisplayTypes:Hide();
	end
end

local function _OrigRefreshDisplayTypeButtons_Unused(self)
	local unassignedButton = self.DisplayTypes.DisplayTypeUnassignedButton;
	local equippedButton = self.DisplayTypes.DisplayTypeEquippedButton;

	local selectedSlotData = self:GetSelectedSlotCallback();
	if not selectedSlotData or not selectedSlotData.transmogLocation then
		unassignedButton:Hide();
		equippedButton:Hide();
		return;
	end

	local outfitSlotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(selectedSlotData.transmogLocation:GetSlot(), selectedSlotData.transmogLocation:GetType(), selectedSlotData.currentWeaponOptionInfo.weaponOption);
	if not outfitSlotInfo then
		unassignedButton:Hide();
		equippedButton:Hide();
		return;
	end

	-- Slightly different logic if the current weapon option is an artifact option.
	local artifactOptionSelected = false;
	if selectedSlotData.artifactOptionsInfo then
		for _index, artifactOptionInfo in ipairs(selectedSlotData.artifactOptionsInfo) do
			if artifactOptionInfo.weaponOption == selectedSlotData.currentWeaponOptionInfo.weaponOption then
				artifactOptionSelected = true;
				break;
			end
		end
	end

	unassignedButton:SetShown(MCUDR_DisplayTypeUnassignedSupported());
	equippedButton:SetShown(not artifactOptionSelected);

	local function SetDisplayTypeButtonState(displayTypeButton, selected)
		local stateAtlas;
		if selected then
			displayTypeButton.IconFrame.Border:SetAtlas("transmog-appearance-circFrame-active", TextureKitConstants.UseAtlasSize);
			displayTypeButton:SetNormalAtlas("common-button-tertiary-depressed-normal", TextureKitConstants.IgnoreAtlasSize);
			displayTypeButton:SetNormalFontObject("GameFontHighlight");

			if outfitSlotInfo.hasPending then
				stateAtlas = "common-button-tertiary-depressed-normal-glow-purple";
			else
				stateAtlas = "common-button-tertiary-depressed-normal-purple";
			end
		else
			displayTypeButton.IconFrame.Border:SetAtlas("transmog-appearance-circframe", TextureKitConstants.UseAtlasSize);
			displayTypeButton:SetNormalAtlas("common-button-tertiary-normal", TextureKitConstants.IgnoreAtlasSize);
			displayTypeButton:SetNormalFontObject("GameFontNormal");
		end

		if stateAtlas then
			displayTypeButton.StateTexture:SetAtlas(stateAtlas, TextureKitConstants.IgnoreAtlasSize);
			displayTypeButton.StateTexture:Show();

			if outfitSlotInfo.hasPending then
				displayTypeButton.PendingFrame:Show();
				displayTypeButton.PendingFrame.Anim:Restart();
			else
				displayTypeButton.PendingFrame.Anim:Stop();
				displayTypeButton.PendingFrame:Hide();
			end

			if self:GetOutfitSlotSavedState() then
				displayTypeButton.SavedFrame:Show();
				displayTypeButton.SavedFrame.Anim:Restart();

				local outfitSlotSaved = false;
				self:SetOutfitSlotSavedState(outfitSlotSaved);
			end
		else
			displayTypeButton.StateTexture:Hide();

			displayTypeButton.PendingFrame.Anim:Stop();
			displayTypeButton.PendingFrame:Hide();
		end

		-- Do not show hover or click states when selected.
		displayTypeButton:SetEnabled(not selected);
	end

	local unassignedAtlas;
	if selectedSlotData.transmogLocation:IsIllusion() then
		unassignedAtlas = "transmog-appearance-unassigned-enchant";
	else
		unassignedAtlas = C_TransmogOutfitInfo.GetUnassignedDisplayAtlasForSlot(selectedSlotData.transmogLocation:GetSlot());
	end

	-- Unassigned Button.
	if unassignedButton:IsShown() then
		local buttonText = artifactOptionSelected and TRANSMOG_SLOT_DISPLAY_TYPE_UNASSIGNED_ARTIFACT or TRANSMOG_SLOT_DISPLAY_TYPE_UNASSIGNED;
		local tooltipText = artifactOptionSelected and TRANSMOG_SLOT_DISPLAY_TYPE_UNASSIGNED_ARTIFACT_TOOLTIP or TRANSMOG_SLOT_DISPLAY_TYPE_UNASSIGNED_TOOLTIP;

		unassignedButton:SetText(buttonText);
		unassignedButton:SetScript("OnEnter", function(button)
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT");
			GameTooltip_AddHighlightLine(GameTooltip, buttonText);
			GameTooltip_AddNormalLine(GameTooltip, tooltipText);
			GameTooltip:Show();
		end);

		unassignedButton.IconFrame.Icon:SetAtlas(unassignedAtlas, TextureKitConstants.UseAtlasSize);

		local isUnassigned = outfitSlotInfo.displayType == Enum.TransmogOutfitDisplayType.Unassigned;
		SetDisplayTypeButtonState(unassignedButton, isUnassigned);
	end

	-- Equipped Button.
	if equippedButton:IsShown() then
		local equippedIcon = equippedButton.IconFrame.Icon;
		if outfitSlotInfo.warning ~= Enum.TransmogOutfitSlotWarning.Ok then
			equippedIcon:SetAtlas(unassignedAtlas, TextureKitConstants.UseAtlasSize);
		else
			local textureName = GetInventoryItemTexture("player", selectedSlotData.transmogLocation:GetSlotID());
			if textureName then
				equippedIcon:SetTexture(textureName);
			else
				equippedIcon:SetAtlas(unassignedAtlas, TextureKitConstants.UseAtlasSize);
			end
		end

		local isEquipped = outfitSlotInfo.displayType == Enum.TransmogOutfitDisplayType.Equipped;
		SetDisplayTypeButtonState(equippedButton, isEquipped);
	end
end

function MCUDR_WardrobeItemsMixin:RefreshSecondaryAppearanceToggle()
	local selectedSlotData = self:GetSelectedSlotCallback();
	if not selectedSlotData or not selectedSlotData.transmogLocation then
		return;
	end

	local slot = selectedSlotData.transmogLocation:GetSlot();
	local hasSecondary = C_TransmogOutfitInfo.SlotHasSecondary(slot);
	if hasSecondary then
		self.SecondaryAppearanceToggle:Show();
		local toggledOn = C_TransmogOutfitInfo.GetSecondarySlotState(slot);
		self.SecondaryAppearanceToggle.Checkbox:SetChecked(toggledOn);
		self.SecondaryAppearanceToggle.Text:SetFontObject(toggledOn and "GameFontHighlight" or "GameFontNormal");
	else
		self.SecondaryAppearanceToggle:Hide();
	end
end

function MCUDR_WardrobeItemsMixin:RefreshCollectionEntries()
	if not self.transmogLocation or not self.activeCategoryID then
		return;
	end

	-- Guard against re-entry from filter change events
	if self._refreshingEntries then return; end
	self._refreshingEntries = true;

	if self.transmogLocation:IsIllusion() then
		self.itemCollectionEntries = C_TransmogCollection.GetIllusions();
	else
		-- Get appearances from the API
		local rawEntries = C_TransmogCollection.GetCategoryAppearances(self.activeCategoryID, self.transmogLocation:GetData());

		-- The Transmog API may filter out uncollected items based on filter state.
		-- If uncollected items are missing, supplement with data from GetAppearanceSources
		-- to include uncollected appearances (same approach the Collections UI uses internally).
		if rawEntries then
			-- Check if we're missing uncollected items by comparing count
			local hasUncollected = false;
			for _, entry in ipairs(rawEntries) do
				if not entry.isCollected then
					hasUncollected = true;
					break;
				end
			end

			if not hasUncollected then
				-- Force uncollected shown and re-fetch
				local wasUncollected = C_TransmogCollection.GetUncollectedShown();
				C_TransmogCollection.SetUncollectedShown(true);
				rawEntries = C_TransmogCollection.GetCategoryAppearances(self.activeCategoryID, self.transmogLocation:GetData());
				if not wasUncollected then
					-- Restore original state after fetching
					C_Timer.After(0, function()
						C_TransmogCollection.SetUncollectedShown(wasUncollected);
					end);
				end
			end

			self.itemCollectionEntries = rawEntries;
		else
			self.itemCollectionEntries = {};
		end
	end

	local retainCurrentPage = true;
	self:SetCollectionEntries(self.itemCollectionEntries, retainCurrentPage);

	self._refreshingEntries = false;
end

function MCUDR_WardrobeItemsMixin:RefreshCameras()
	self.PagedContent:ForEachFrame(function(frame)
		frame:RefreshItemCamera();
	end);
end

function MCUDR_WardrobeItemsMixin:RefreshPagedEntry()
	local selectedSlotData = self:GetSelectedSlotCallback();
	if not selectedSlotData or not selectedSlotData.transmogLocation then
		return;
	end

	local outfitSlotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(selectedSlotData.transmogLocation:GetSlot(), selectedSlotData.transmogLocation:GetType(), selectedSlotData.currentWeaponOptionInfo.weaponOption);
	if not outfitSlotInfo or outfitSlotInfo.displayType == Enum.TransmogOutfitDisplayType.Unassigned or outfitSlotInfo.displayType == Enum.TransmogOutfitDisplayType.Equipped then
		self.PagedContent.PagingControls:SetCurrentPage(1);
	else
		self:PageToTransmogID(outfitSlotInfo.transmogID);
	end
end

function MCUDR_WardrobeItemsMixin:SelectVisual(visualID)
	if not self.transmogLocation then
		return;
	end

	local sourceID;
	if self.transmogLocation:IsAppearance() then
		local mustBeUsable = true;
		sourceID = self:GetAnAppearanceSourceFromVisual(visualID, mustBeUsable);
	else
		for _index, itemEntry in ipairs(self.itemCollectionEntries) do
			if itemEntry.visualID == visualID then
				sourceID = itemEntry.sourceID;
				break;
			end
		end
	end

	-- Artifacts from other specs will not have something valid
	if sourceID ~= Constants.Transmog.NoTransmogID then
		local selectedSlotData = self:GetSelectedSlotCallback();
		if not selectedSlotData or not selectedSlotData.transmogLocation then
			return;
		end

		local displayType = Enum.TransmogOutfitDisplayType.Assigned;
		if selectedSlotData.transmogLocation:IsAppearance() then
			if C_TransmogCollection.IsAppearanceHiddenVisual(sourceID) then
				displayType = Enum.TransmogOutfitDisplayType.Hidden;
			end
		else
			if C_TransmogCollection.IsSpellItemEnchantmentHiddenVisual(sourceID) then
				displayType = Enum.TransmogOutfitDisplayType.Hidden;
			end
		end
		C_TransmogOutfitInfo.SetPendingTransmog(selectedSlotData.transmogLocation:GetSlot(), selectedSlotData.transmogLocation:GetType(), selectedSlotData.currentWeaponOptionInfo.weaponOption, sourceID, displayType);

		PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);
	end
end

function MCUDR_WardrobeItemsMixin:UpdateSelectedVisualFromKeyPress(key)
	local selectedSlotData = self:GetSelectedSlotCallback();
	if not selectedSlotData or not selectedSlotData.transmogLocation then
		return;
	end

	-- Keyboard navigation only works if selecting something in the paged grid.
	local outfitSlotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(selectedSlotData.transmogLocation:GetSlot(), selectedSlotData.transmogLocation:GetType(), selectedSlotData.currentWeaponOptionInfo.weaponOption);
	if not outfitSlotInfo or outfitSlotInfo.transmogID == NoTransmogID or outfitSlotInfo.displayType == Enum.TransmogOutfitDisplayType.Unassigned or outfitSlotInfo.displayType == Enum.TransmogOutfitDisplayType.Equipped then
		return;
	end

	-- Get the current index relative to the entire displayed collection.
	local startingIndex = self.PagedContent:FindIndexByPredicate(function(elementData)
		if selectedSlotData.transmogLocation:IsAppearance() then
			local mustBeUsable = true;
			local sourceID = self:GetAnAppearanceSourceFromVisual(elementData.appearanceInfo.visualID, mustBeUsable);

			return sourceID == outfitSlotInfo.transmogID;
		else
			return elementData.appearanceInfo.sourceID == outfitSlotInfo.transmogID;
		end
	end);

	-- Could happen if the selected item is filtered out.
	if startingIndex == nil then
		return;
	end

	-- Find the updated target index that we should navigate to.
	local contentSize = self.PagedContent:GetSize();
	local templateKey = "COLLECTION_ITEM";
	local viewIndex = 1;
	local maxColumns, maxRows = self.PagedContent:TryGetMaxGridCountForTemplateInView(templateKey, viewIndex);
	if maxColumns == nil or maxRows == nil then
		return;
	end

	-- If moving would go past the ends, cap to the end. If on the end to start, wrap to the other cap.
	-- Moving up/down jumps a whole row.
	local targetIndex = startingIndex;
	if key == WARDROBE_PREV_VISUAL_KEY then
		targetIndex = targetIndex - 1;
		if targetIndex <= 0 then
			targetIndex = contentSize;
		end
	elseif key == WARDROBE_NEXT_VISUAL_KEY then
		targetIndex = targetIndex + 1;
		if targetIndex > contentSize then
			targetIndex = 1;
		end
	elseif key == WARDROBE_UP_VISUAL_KEY then
		if targetIndex == 1 then
			targetIndex = contentSize;
		else
			targetIndex = targetIndex - maxColumns;
			if targetIndex <= 0 then
				targetIndex = 1;
			end
		end
	elseif key == WARDROBE_DOWN_VISUAL_KEY then
		if targetIndex == contentSize then
			targetIndex = 1;
		else
			targetIndex = targetIndex + maxColumns;
			if targetIndex > contentSize then
				targetIndex = contentSize;
			end
		end
	end

	if targetIndex == startingIndex then
		return;
	end

	-- Select and page to new index.
	local targetElementData = self.PagedContent:GetElementDataByIndex(targetIndex);
	if self.transmogLocation:IsAppearance() then
		local mustBeUsable = true;
		local sourceID = self:GetAnAppearanceSourceFromVisual(targetElementData.appearanceInfo.visualID, mustBeUsable);

		local itemID = C_Transmog.GetItemIDForSource(sourceID);
		if not itemID then
			return;
		end

		-- Handles sparse cases, ensures things can be validly selected.
		local item = Item:CreateFromItemID(itemID);
		item:ContinueOnItemLoad(function()
			-- Since the player may have run another key press while waiting here on a previous item, make sure the starting info is still the same to ensure a valid state.
			local currentOutfitSlotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(selectedSlotData.transmogLocation:GetSlot(), selectedSlotData.transmogLocation:GetType(), selectedSlotData.currentWeaponOptionInfo.weaponOption);
			if currentOutfitSlotInfo.transmogID ~= outfitSlotInfo.transmogID or currentOutfitSlotInfo.displayType == Enum.TransmogOutfitDisplayType.Unassigned or currentOutfitSlotInfo.displayType == Enum.TransmogOutfitDisplayType.Equipped then
				return;
			end

			self:SelectVisual(targetElementData.appearanceInfo.visualID);
			self:RefreshPagedEntry();
		end);
	else
		self:SelectVisual(targetElementData.appearanceInfo.visualID);
		self:RefreshPagedEntry();
	end
end

function MCUDR_WardrobeItemsMixin:GetAnAppearanceSourceFromVisual(visualID, mustBeUsable)
	if not self.transmogLocation or not self.activeCategoryID then
		return nil;
	end

	local sourceID = self:GetChosenVisualSource(visualID);
	if sourceID == Constants.Transmog.NoTransmogID then
		local sources = CollectionWardrobeUtil.GetSortedAppearanceSources(visualID, self.activeCategoryID, self.transmogLocation);
		for _index, source in ipairs(sources) do
			-- First 1 if it doesn't have to be usable
			if not mustBeUsable or self:IsAppearanceUsableForActiveCategory(source) then
				sourceID = source.sourceID;
				break;
			end
		end
	end
	return sourceID;
end

function MCUDR_WardrobeItemsMixin:GetChosenVisualSource(visualID)
	return self.chosenVisualSources[visualID] or Constants.Transmog.NoTransmogID;
end

function MCUDR_WardrobeItemsMixin:SetChosenVisualSource(visualID, sourceID)
	self.chosenVisualSources[visualID] = sourceID;
end

function MCUDR_WardrobeItemsMixin:ValidateChosenVisualSources()
	for visualID, sourceID in pairs(self.chosenVisualSources) do
		if sourceID ~= Constants.Transmog.NoTransmogID then
			local keep = false;
			local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID);
			if sourceInfo and sourceInfo.isCollected and not sourceInfo.useError then
				keep = true;
			end

			if not keep then
				self.chosenVisualSources[visualID] = Constants.Transmog.NoTransmogID;
			end
		end
	end
end

function MCUDR_WardrobeItemsMixin:IsAppearanceUsableForActiveCategory(appearanceInfo)
	if not self.activeCategoryID then
		return false;
	end

	local inLegionArtifactCategory = TransmogUtil.IsCategoryLegionArtifact(self.activeCategoryID);
	return CollectionWardrobeUtil.IsAppearanceUsable(appearanceInfo, inLegionArtifactCategory);
end

function MCUDR_WardrobeItemsMixin:GetAppearanceNameTextAndColor(appearanceInfo)
	if not self.activeCategoryID then
		return nil, nil;
	end

	local inLegionArtifactCategory = TransmogUtil.IsCategoryLegionArtifact(self.activeCategoryID);
	return CollectionWardrobeUtil.GetAppearanceNameTextAndColor(appearanceInfo, inLegionArtifactCategory);
end

function MCUDR_WardrobeItemsMixin:SetAppearanceTooltip(frame)
	GameTooltip:SetOwner(frame, "ANCHOR_RIGHT");
	self.tooltipModel = frame;
	self.tooltipVisualID = frame:GetAppearanceInfo().visualID;
	self:RefreshAppearanceTooltip();
end

function MCUDR_WardrobeItemsMixin:RefreshAppearanceTooltip()
	if not self.tooltipVisualID or not self.transmogLocation or not self.activeCategoryID then
		return;
	end

	local sources = CollectionWardrobeUtil.GetSortedAppearanceSourcesForClass(self.tooltipVisualID, C_TransmogCollection.GetClassFilter(), self.activeCategoryID, self.transmogLocation);
	local appearanceData = {
		sources = sources,
		primarySourceID = self:GetChosenVisualSource(self.tooltipVisualID),
		selectedIndex = nil,
		showUseError = true,
		inLegionArtifactCategory = TransmogUtil.IsCategoryLegionArtifact(self.activeCategoryID),
		subheaderString = nil,
		warningString = CollectionWardrobeUtil.GetBestVisibilityWarning(self.tooltipModel, self.transmogLocation, sources),
		showTrackingInfo = false,
		slotType = nil
	}

	local _tooltipSourceIndex, _tooltipCycle = CollectionWardrobeUtil.SetAppearanceTooltip(GameTooltip, appearanceData);
end

function MCUDR_WardrobeItemsMixin:ClearAppearanceTooltip()
	self.tooltipModel = nil;
	self.tooltipVisualID = nil;
	GameTooltip:Hide();
end

function MCUDR_WardrobeItemsMixin:SetCollectionEntries(entries, retainCurrentPage)
	local compareEntries = function(element1, element2)
		local source1 = element1.appearanceInfo;
		local source2 = element2.appearanceInfo;

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

	local collectionElements = {};
	for _index, itemEntry in ipairs(entries) do
		if (itemEntry.isUsable and itemEntry.isCollected) or itemEntry.alwaysShowItem then
			local element = {
				templateKey = "COLLECTION_ITEM",
				appearanceInfo = itemEntry,
				collectionFrame = self
			};
			table.insert(collectionElements, element);
		end
	end

	table.sort(collectionElements, compareEntries);

	local collectionData = {{elements = collectionElements}};
	local dataProvider = CreateDataProvider(collectionData);
	self.PagedContent:SetDataProvider(dataProvider, retainCurrentPage);
end

function MCUDR_WardrobeItemsMixin:UpdateSlot(slotData, forceRefresh)
	if not slotData then
		return;
	end

	local transmogLocation = slotData.transmogLocation;
	if transmogLocation then
		local outfitSlotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(transmogLocation:GetSlot(), transmogLocation:GetType(), slotData.currentWeaponOptionInfo.weaponOption);
		if outfitSlotInfo then
			local isUnassignedOrEquipped = outfitSlotInfo.displayType == Enum.TransmogOutfitDisplayType.Unassigned or outfitSlotInfo.displayType == Enum.TransmogOutfitDisplayType.Equipped;
			if not transmogLocation:IsEqual(self.transmogLocation) or forceRefresh then
				self:SetActiveSlot(transmogLocation, forceRefresh);

				-- If initially setting to a new category and not one of the display type buttons, make sure we can correctly page to the entry we want once search filters update.
				if not isUnassignedOrEquipped then
					self.jumpToTransmogID = outfitSlotInfo.transmogID;
				end
			end

			if isUnassignedOrEquipped then
				self.PagedContent.PagingControls:SetCurrentPage(1);
			else
				self:PageToTransmogID(outfitSlotInfo.transmogID);
			end
		end
	end

end

function MCUDR_WardrobeItemsMixin:GetActiveSlotInfo()
	return TransmogUtil.GetInfoForEquippedSlot(self.transmogLocation);
end

function MCUDR_WardrobeItemsMixin:SetActiveSlot(transmogLocation, forceRefresh)
	self:SetTransmogLocation(transmogLocation);
	local activeSlotInfo = self:GetActiveSlotInfo();

	-- Figure out a category.
	local categoryID;
	local useLastWeaponCategory = not forceRefresh and self.transmogLocation:IsEitherHand() and self.lastWeaponCategoryID and self:IsValidWeaponCategoryForSlot(self.lastWeaponCategoryID);
	if useLastWeaponCategory then
		categoryID = self.lastWeaponCategoryID;
	elseif activeSlotInfo.selectedSourceID ~= Constants.Transmog.NoTransmogID then
		local appearanceSourceInfo = C_TransmogCollection.GetAppearanceSourceInfo(activeSlotInfo.selectedSourceID);
		categoryID = appearanceSourceInfo and appearanceSourceInfo.category;
		if categoryID and not self:IsValidWeaponCategoryForSlot(categoryID) then
			categoryID = nil;
		end
	end

	if not categoryID then
		if self.transmogLocation:IsEitherHand() then
			-- Find the first valid weapon category.
			for weaponCategoryID = FIRST_TRANSMOG_COLLECTION_WEAPON_TYPE, LAST_TRANSMOG_COLLECTION_WEAPON_TYPE do
				if self:IsValidWeaponCategoryForSlot(weaponCategoryID) then
					categoryID = weaponCategoryID;
					break;
				end
			end
		else
			categoryID = self.transmogLocation:GetArmorCategoryID();
		end
	end

	if categoryID and categoryID ~= self.activeCategoryID then
		self:SetActiveCategory(categoryID);
	end

	self:Refresh();
end

function MCUDR_WardrobeItemsMixin:IsValidWeaponCategoryForSlot(categoryID)
	local selectedSlotData = self:GetSelectedSlotCallback();
	if not selectedSlotData or not selectedSlotData.transmogLocation then
		return false;
	end

	local collectionInfo = C_TransmogOutfitInfo.GetCollectionInfoForSlotAndOption(selectedSlotData.transmogLocation:GetSlot(), selectedSlotData.currentWeaponOptionInfo.weaponOption, categoryID);
	return collectionInfo and collectionInfo.isWeapon;
end

function MCUDR_WardrobeItemsMixin:PageToTransmogID(transmogID)
	if transmogID == Constants.Transmog.NoTransmogID then
		self.PagedContent.PagingControls:SetCurrentPage(1);
		return;
	end

	self.PagedContent:GoToElementByPredicate(function(elementData)
		if self.transmogLocation:IsAppearance() then
			local mustBeUsable = true;
			local sourceID = self:GetAnAppearanceSourceFromVisual(elementData.appearanceInfo.visualID, mustBeUsable);

			return sourceID == transmogID;
		else
			return elementData.appearanceInfo.sourceID == transmogID;
		end
	end);
end

function MCUDR_WardrobeItemsMixin:GetActiveCategory()
	return self.activeCategoryID;
end

function MCUDR_WardrobeItemsMixin:SetActiveCategory(categoryID)
	if self.activeCategoryID == categoryID then
		return;
	end

	self.activeCategoryID = categoryID;

	local selectedSlotData = self:GetSelectedSlotCallback();
	if not selectedSlotData or not selectedSlotData.transmogLocation or not self.transmogLocation then
		return;
	end

	if self.transmogLocation:IsAppearance() then
		C_TransmogCollection.SetSearchAndFilterCategory(self.activeCategoryID);
		local collectionInfo = C_TransmogOutfitInfo.GetCollectionInfoForSlotAndOption(selectedSlotData.transmogLocation:GetSlot(), selectedSlotData.currentWeaponOptionInfo.weaponOption, self.activeCategoryID);
		if collectionInfo and collectionInfo.isWeapon then
			self.lastWeaponCategoryID = self.activeCategoryID;
		end
	end
end

function MCUDR_WardrobeItemsMixin:GetTransmogLocation()
	return self.transmogLocation;
end

function MCUDR_WardrobeItemsMixin:SetTransmogLocation(transmogLocation)
	self.transmogLocation = transmogLocation;
end

function MCUDR_WardrobeItemsMixin:GetActiveSlot()
	return self.transmogLocation and self.transmogLocation:GetSlotName();
end

function MCUDR_WardrobeItemsMixin:HasActiveSecondaryAppearance()
	local secondaryAppearanceToggle = self.SecondaryAppearanceToggle;
	return secondaryAppearanceToggle:IsShown() and secondaryAppearanceToggle.Checkbox:GetChecked();
end

function MCUDR_WardrobeItemsMixin:GetOutfitSlotSavedState()
	return self.outfitSlotSaved;
end

function MCUDR_WardrobeItemsMixin:SetOutfitSlotSavedState(outfitSlotSaved)
	self.outfitSlotSaved = outfitSlotSaved;
end

function MCUDR_WardrobeItemsMixin:GetSelectedSlotCallback()
	if self.wardrobeCollection and self.wardrobeCollection.GetSelectedSlotCallback then
		return self.wardrobeCollection.GetSelectedSlotCallback();
	end
	return nil;
end

function MCUDR_WardrobeItemsMixin:GetSlotFrameCallback(slot, type)
	if self.wardrobeCollection and self.wardrobeCollection.GetSlotFrameCallback then
		return self.wardrobeCollection.GetSlotFrameCallback(slot, type);
	end
	return nil;
end


MCUDR_WardrobeSetsMixin = {
	DYNAMIC_EVENTS = {
		"TRANSMOG_SEARCH_UPDATED",
		"TRANSMOG_COLLECTION_UPDATED",
		"TRANSMOG_SETS_UPDATE_FAVORITE",
		"UI_SCALE_CHANGED",
		"DISPLAY_SIZE_CHANGED",
		"VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS"
	};
	COLLECTION_TEMPLATES = {
		["COLLECTION_SET"] = { template = "MCUDR_SetModelTemplate", initFunc = MCUDR_SetModelMixin.Init, resetFunc = MCUDR_SetModelMixin.Reset }
	};
};

function MCUDR_WardrobeSetsMixin:OnLoad()
	self:InitFilterButton();
	self.PagedContent:SetElementTemplateData(self.COLLECTION_TEMPLATES);
	self.SearchBox:SetSearchType(self.searchType);
	self.setsDataProvider = CreateFromMixins(MCUDR_WardrobeSetsDataProviderMixin);
end

function MCUDR_WardrobeSetsMixin:OnShow()
	local hasAlternateForm, inAlternateForm = C_PlayerInfo.GetAlternateFormInfo();
	if hasAlternateForm then
		self:RegisterUnitEvent("UNIT_FORM_CHANGED", "player");
		self.inAlternateForm = inAlternateForm;
	end
	FrameUtil.RegisterFrameForEvents(self, self.DYNAMIC_EVENTS);

	self:RefreshCollectionEntries();
end

function MCUDR_WardrobeSetsMixin:OnHide()
	self:UnregisterEvent("UNIT_FORM_CHANGED");
	FrameUtil.UnregisterFrameForEvents(self, self.DYNAMIC_EVENTS);
end

function MCUDR_WardrobeSetsMixin:OnEvent(event, ...)
	if event == "UNIT_FORM_CHANGED" then
		self:HandleFormChanged();
	elseif event == "TRANSMOG_SEARCH_UPDATED" then
		local searchType, _collectionType = ...;
		if searchType == self.searchType then
			self:RefreshCollectionEntries();
		end
	elseif event == "TRANSMOG_COLLECTION_UPDATED" or event == "TRANSMOG_SETS_UPDATE_FAVORITE" then
		self:RefreshCollectionEntries();
	elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
		self:RefreshCameras();
	elseif event == "VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS" then
		local _slot, _type, _weaponOption = ...;

		-- Already set to true, do not stomp if multiple slots are changing.
		if self:GetOutfitSlotSavedState() then
			return;
		end

		local appliedSetID, _hasPending = self:GetFirstMatchingSetID();
		local outfitSlotSaved = appliedSetID ~= nil;
		self:SetOutfitSlotSavedState(outfitSlotSaved);
	end
end

function MCUDR_WardrobeSetsMixin:Init(wardrobeCollection)
	self.wardrobeCollection = wardrobeCollection;
end

function MCUDR_WardrobeSetsMixin:InitFilterButton()
	self.FilterButton:SetupMenu(function(_dropdown, rootDescription)
		rootDescription:SetTag("MENU_TRANSMOG_SETS_FILTER");

		local function SetSetsFilter(filter)
			C_TransmogSets.SetSetsFilter(filter, not C_TransmogSets.GetSetsFilter(filter));
		end

		rootDescription:CreateCheckbox(COLLECTED, C_TransmogSets.GetSetsFilter, SetSetsFilter, LE_TRANSMOG_SET_FILTER_COLLECTED);
		rootDescription:CreateCheckbox(NOT_COLLECTED, C_TransmogSets.GetSetsFilter, SetSetsFilter, LE_TRANSMOG_SET_FILTER_UNCOLLECTED);
		rootDescription:CreateDivider();
		rootDescription:CreateCheckbox(TRANSMOG_SET_PVE, C_TransmogSets.GetSetsFilter, SetSetsFilter, LE_TRANSMOG_SET_FILTER_PVE);
		rootDescription:CreateCheckbox(TRANSMOG_SET_PVP, C_TransmogSets.GetSetsFilter, SetSetsFilter, LE_TRANSMOG_SET_FILTER_PVP);
	end);

	self.FilterButton:SetIsDefaultCallback(function()
		return C_TransmogSets.IsUsingDefaultSetsFilters();
	end);

	self.FilterButton:SetDefaultCallback(function()
		return C_TransmogSets.SetDefaultSetsFilters();
	end);
end

function MCUDR_WardrobeSetsMixin:HandleFormChanged()
	if IsUnitModelReadyForUI("player") then
		local _hasAlternateForm, inAlternateForm = C_PlayerInfo.GetAlternateFormInfo();
		if self.inAlternateForm ~= inAlternateForm then
			self.inAlternateForm = inAlternateForm;
			self:RefreshCollectionEntries();
		end
	end
end

function MCUDR_WardrobeSetsMixin:RefreshCollectionEntries()
	self.setsDataProvider:ClearSets();

	local collectionElements = {};
	local availableSets = self.setsDataProvider:GetAvailableSets();
	for _index, availableSet in ipairs(availableSets) do
		local element = {
			templateKey = "COLLECTION_SET",
			set = availableSet,
			sourceData = self.setsDataProvider:GetSetSourceData(availableSet.setID),
			collectionFrame = self
		};
		table.insert(collectionElements, element);
	end

	local collectionData = {{elements = collectionElements}};
	local dataProvider = CreateDataProvider(collectionData);
	local retainCurrentPage = true;
	self.PagedContent:SetDataProvider(dataProvider, retainCurrentPage);
end

function MCUDR_WardrobeSetsMixin:RefreshCameras()
	self.PagedContent:ForEachFrame(function(frame)
		frame:RefreshSetCamera();
	end);
end

function MCUDR_WardrobeSetsMixin:GetFirstMatchingSetID()
	local appliedSetID, hasPending;

	local transmogInfo = self:GetCurrentTransmogInfoCallback();
	local usableSets = self.setsDataProvider:GetUsableSets();
	for _index, usableSet in ipairs(usableSets) do
		local setMatched = false;
		hasPending = false;
		for transmogLocation, info in pairs(transmogInfo) do
			if transmogLocation:IsAppearance() then
				local sourceIDs = C_TransmogOutfitInfo.GetSourceIDsForSlot(usableSet.setID, transmogLocation:GetSlot());
				-- If there are no sources for a slot, that slot is considered matched.
				local slotMatched = #sourceIDs == 0;
				for _indexSourceIDs, sourceID in ipairs(sourceIDs) do
					if info.transmogID == sourceID then
						slotMatched = true;
						if not hasPending and info.hasPending then
							hasPending = true;
						end
						break;
					end
				end

				setMatched = slotMatched;
				if not setMatched then
					break;
				end
			end
		end

		if setMatched then
			appliedSetID = usableSet.setID;
			break;
		end
	end

	return appliedSetID, hasPending;
end

function MCUDR_WardrobeSetsMixin:GetOutfitSlotSavedState()
	return self.outfitSlotSaved;
end

function MCUDR_WardrobeSetsMixin:SetOutfitSlotSavedState(outfitSlotSaved)
	self.outfitSlotSaved = outfitSlotSaved;
end

function MCUDR_WardrobeSetsMixin:GetCurrentTransmogInfoCallback()
	if self.wardrobeCollection and self.wardrobeCollection.GetCurrentTransmogInfoCallback then
		return self.wardrobeCollection.GetCurrentTransmogInfoCallback();
	end
	return nil;
end


MCUDR_WardrobeCustomSetsMixin = {
	DYNAMIC_EVENTS = {
		"TRANSMOG_CUSTOM_SETS_CHANGED",
		"UI_SCALE_CHANGED",
		"DISPLAY_SIZE_CHANGED",
		"VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS",
		"VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH"
	};
	COLLECTION_TEMPLATES = {
		["COLLECTION_CUSTOM_SET"] = { template = "MCUDR_CustomSetModelTemplate", initFunc = MCUDR_CustomSetModelMixin.Init, resetFunc = MCUDR_CustomSetModelMixin.Reset }
	};
};

function MCUDR_WardrobeCustomSetsMixin:OnLoad()
	self.PagedContent:SetElementTemplateData(self.COLLECTION_TEMPLATES);

	self.NewCustomSetButton:SetScript("OnClick", function()
		local data = { name = "", customSetID = nil, itemTransmogInfoList = self:GetItemTransmogInfoListCallback() };
		StaticPopup_Show("TRANSMOG_CUSTOM_SET_NAME", nil, nil, data);
	end);

	self.NewCustomSetButton:SetScript("OnEnter", function(button)
		local showTooltip = self.NewCustomSetButton.Text:IsTruncated() or self.NewCustomSetButton.disabledTooltip;
		if showTooltip then
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT");

			if self.NewCustomSetButton.Text:IsTruncated() then
				local text = self.NewCustomSetButton.Text:GetText();
				if text then
					GameTooltip_AddNormalLine(GameTooltip, text);
				end
			end

			if self.NewCustomSetButton.disabledTooltip then
				GameTooltip_AddErrorLine(GameTooltip, self.NewCustomSetButton.disabledTooltip);
			end

			GameTooltip:Show();
		end
	end);

	self.NewCustomSetButton:SetScript("OnLeave", GameTooltip_Hide);
end

function MCUDR_WardrobeCustomSetsMixin:OnShow()
	local hasAlternateForm, inAlternateForm = C_PlayerInfo.GetAlternateFormInfo();
	if hasAlternateForm then
		self:RegisterUnitEvent("UNIT_FORM_CHANGED", "player");
		self.inAlternateForm = inAlternateForm;
	end
	FrameUtil.RegisterFrameForEvents(self, self.DYNAMIC_EVENTS);

	self:RefreshNewCustomSetButton();
	self:RefreshCollectionEntries();
end

function MCUDR_WardrobeCustomSetsMixin:OnHide()
	self:UnregisterEvent("UNIT_FORM_CHANGED");
	FrameUtil.UnregisterFrameForEvents(self, self.DYNAMIC_EVENTS);
end

function MCUDR_WardrobeCustomSetsMixin:OnEvent(event, ...)
	if event == "UNIT_FORM_CHANGED" then
		self:HandleFormChanged();
	elseif event == "TRANSMOG_CUSTOM_SETS_CHANGED" then
		self:RefreshNewCustomSetButton();
		self:RefreshCollectionEntries();
	elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
		self:RefreshCameras();
	elseif event == "VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS" then
		local _slot, _type, _weaponOption = ...;

		-- Already set to true, do not stomp if multiple slots are changing.
		if self:GetOutfitSlotSavedState() then
			return;
		end

		local appliedCustomSetID, _hasPending = self:GetFirstMatchingCustomSetID();
		local outfitSlotSaved = appliedCustomSetID ~= nil;
		self:SetOutfitSlotSavedState(outfitSlotSaved);
	elseif event == "VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH" then
		self:RefreshNewCustomSetButton();
	end
end

function MCUDR_WardrobeCustomSetsMixin:Init(wardrobeCollection)
	self.wardrobeCollection = wardrobeCollection;
end

function MCUDR_WardrobeCustomSetsMixin:HandleFormChanged()
	if IsUnitModelReadyForUI("player") then
		local _hasAlternateForm, inAlternateForm = C_PlayerInfo.GetAlternateFormInfo();
		if self.inAlternateForm ~= inAlternateForm then
			self.inAlternateForm = inAlternateForm;
			self:RefreshCollectionEntries();
		end
	end
end

function MCUDR_WardrobeCustomSetsMixin:RefreshNewCustomSetButton()
	-- Enable the new custom set button if not at max custom sets, and there is at least 1 valid slot apperance to make a custom set from.
	self.NewCustomSetButton.disabledTooltip = nil;

	local customSets = C_TransmogCollection.GetCustomSets();
	if #customSets >= C_TransmogCollection.GetNumMaxCustomSets() then
		self.NewCustomSetButton.disabledTooltip = TRANSMOG_CUSTOM_SET_NEW_TOOLTIP_DISABLED_MAX_COUNT;
	else
		local itemTransmogInfoList = self:GetItemTransmogInfoListCallback();
		if not TransmogUtil.IsValidItemTransmogInfoList(itemTransmogInfoList) then
			self.NewCustomSetButton.disabledTooltip = TRANSMOG_CUSTOM_SET_NEW_TOOLTIP_DISABLED;
		end
	end

	self.NewCustomSetButton:SetEnabled(self.NewCustomSetButton.disabledTooltip == nil);
end

function MCUDR_WardrobeCustomSetsMixin:RefreshCollectionEntries()
	local compareEntries = function(element1, element2)
		if element1.isCollected ~= element2.isCollected then
			return element1.isCollected;
		end

		local customSetName1, _customSetIcon1 = C_TransmogCollection.GetCustomSetInfo(element1.customSetID);
		local customSetName2, _customSetIcon2 = C_TransmogCollection.GetCustomSetInfo(element2.customSetID);
		return customSetName1 < customSetName2;
	end

	local collectionElements = {};
	local customSets = C_TransmogCollection.GetCustomSets();
	for _indexCustomSet, customSetID in ipairs(customSets) do
		local isCollected = TransmogUtil.IsCustomSetCollected(customSetID);

		local element = {
			templateKey = "COLLECTION_CUSTOM_SET",
			customSetID = customSetID,
			isCollected = isCollected,
			collectionFrame = self
		};
		table.insert(collectionElements, element);
	end
	table.sort(collectionElements, compareEntries);

	local collectionData = {{elements = collectionElements}};
	local dataProvider = CreateDataProvider(collectionData);
	local retainCurrentPage = true;
	self.PagedContent:SetDataProvider(dataProvider, retainCurrentPage);
end

function MCUDR_WardrobeCustomSetsMixin:RefreshCameras()
	self.PagedContent:ForEachFrame(function(frame)
		frame:RefreshSetCamera();
	end);
end

function MCUDR_WardrobeCustomSetsMixin:GetFirstMatchingCustomSetID()
	local appliedCustomSetID, hasPending;

	local customSets = C_TransmogCollection.GetCustomSets();
	for _indexCustomSet, customSetID in ipairs(customSets) do
		if TransmogUtil.IsCustomSetCollected(customSetID) then
			local customSetTransmogInfo = C_TransmogCollection.GetCustomSetItemTransmogInfoList(customSetID);

			local customSetMatched = false;
			hasPending = false;

			local slotMatched = false;
			for indexCustomSetInfo, customSetInfo in ipairs(customSetTransmogInfo) do
				-- Should we check this slot? (filters out non appearances like neck slot, as well as slots not set in the custom set).
				local slot = C_TransmogOutfitInfo.GetTransmogOutfitSlotFromInventorySlot(indexCustomSetInfo - 1);

				-- Weapon slots are special here, as there is ambiguity with weapon options.
				local isValidSlot = slot ~= nil and slot ~= Constants.TransmogOutfitDataConsts.TRANSMOG_OUTFIT_SLOT_NONE and not C_TransmogOutfitInfo.IsSlotWeaponSlot(slot);
				if isValidSlot and customSetInfo.appearanceID ~= Constants.Transmog.NoTransmogID then
					slotMatched = false;

					local appearanceType = Enum.TransmogType.Appearance;
					local weaponOption = Enum.TransmogOutfitSlotOption.None;
					local outfitInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(slot, appearanceType, weaponOption);
					if outfitInfo.transmogID ~= customSetInfo.appearanceID then
						break;
					end

					slotMatched = true;
					if not hasPending and outfitInfo.hasPending then
						hasPending = true;
					end
				end
			end

			customSetMatched = slotMatched;
			if customSetMatched then
				appliedCustomSetID = customSetID;
				break;
			end
		end
	end

	return appliedCustomSetID, hasPending;
end

function MCUDR_WardrobeCustomSetsMixin:GetOutfitSlotSavedState()
	return self.outfitSlotSaved;
end

function MCUDR_WardrobeCustomSetsMixin:SetOutfitSlotSavedState(outfitSlotSaved)
	self.outfitSlotSaved = outfitSlotSaved;
end

function MCUDR_WardrobeCustomSetsMixin:GetCurrentTransmogInfoCallback()
	if self.wardrobeCollection and self.wardrobeCollection.GetCurrentTransmogInfoCallback then
		return self.wardrobeCollection.GetCurrentTransmogInfoCallback();
	end
	return nil;
end

function MCUDR_WardrobeCustomSetsMixin:GetItemTransmogInfoListCallback()
	if self.wardrobeCollection and self.wardrobeCollection.GetItemTransmogInfoListCallback then
		return self.wardrobeCollection.GetItemTransmogInfoListCallback();
	end
	return nil;
end


MCUDR_WardrobeSituationsMixin = {
	DYNAMIC_EVENTS = {
		"VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED"
	};
};

function MCUDR_WardrobeSituationsMixin:OnLoad()
	self.SituationFramePool = CreateFramePool("FRAME", self.Situations, "MCUDR_SituationTemplate", nil);

	self.DefaultsButton:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION);
		C_TransmogOutfitInfo.ResetOutfitSituations();
	end);

	self.EnabledToggle.Checkbox:SetScript("OnClick", function()
		local toggledOn = not C_TransmogOutfitInfo.GetOutfitSituationsEnabled();
		if toggledOn then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		else
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF);
		end
		C_TransmogOutfitInfo.SetOutfitSituationsEnabled(toggledOn);
		self:Refresh();
	end);

	self.ApplyButton:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION);
		C_TransmogOutfitInfo.CommitPendingSituations();
	end);

	self.UndoButton:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_INVENTORY_ROTATE_CHARACTER);
		C_TransmogOutfitInfo.ClearAllPendingSituations();
	end);
end

function MCUDR_WardrobeSituationsMixin:OnShow()
	FrameUtil.RegisterFrameForEvents(self, self.DYNAMIC_EVENTS);

	self:Refresh();
end

function MCUDR_WardrobeSituationsMixin:OnHide()
	FrameUtil.UnregisterFrameForEvents(self, self.DYNAMIC_EVENTS);
end

function MCUDR_WardrobeSituationsMixin:OnEvent(event, ...)
	if event == "VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED" then
		self:Refresh();
	end
end

function MCUDR_WardrobeSituationsMixin:Init()
	-- Set up situation dropdowns separately from any outfit's data.
	self.SituationFramePool:ReleaseAll();

	local situationsData = C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions();
	if situationsData then
		for index, data in ipairs(situationsData) do
			local situationFrame = self.SituationFramePool:Acquire();
			local situationData = {
				triggerID = data.triggerID,
				name = data.name,
				description = data.description,
				isRadioButton = data.isRadioButton,
				groupData = data.groupData
			};
			situationFrame.layoutIndex = index;

			situationFrame:Init(situationData);
			situationFrame:Show();
		end
		self.Situations:Layout();
		self.hasSituationData = true;
	end
end

function MCUDR_WardrobeSituationsMixin:CanShow()
	return self.hasSituationData;
end

function MCUDR_WardrobeSituationsMixin:Refresh()
	local situationsEnabled = C_TransmogOutfitInfo.GetOutfitSituationsEnabled();
	self.EnabledToggle.Checkbox:SetChecked(situationsEnabled);
	self.EnabledToggle.Text:SetFontObject(situationsEnabled and "GameFontHighlight" or "GameFontNormal");
	local titleFontColor = situationsEnabled and NORMAL_FONT_COLOR or GRAY_FONT_COLOR;
	local dropdownFontColor = situationsEnabled and RED_FONT_COLOR or GRAY_FONT_COLOR;
	local formattedDefaultText = dropdownFontColor:WrapTextInColorCode(TRANSMOG_SITUATIONS_NO_VALID_OPTIONS);

	local situationsAreValid = true;
	for situationFrame in self.SituationFramePool:EnumerateActive() do
		situationFrame.Title:SetTextColor(titleFontColor:GetRGB());
		situationFrame.Dropdown:SetEnabled(situationsEnabled);
		situationFrame.Dropdown:SetDefaultText(formattedDefaultText);
		situationFrame.Dropdown:GenerateMenu();
		if situationsAreValid and not situationFrame:IsValid() then
			situationsAreValid = false;
		end
	end

	local disabledTooltip = nil;
	local disabledTooltipAnchor = nil;
	if not situationsAreValid then
		disabledTooltip = TRANSMOG_SITUATIONS_APPLY_DISABLED_TOOLTIP;
		disabledTooltipAnchor = "ANCHOR_RIGHT";
	end
	self.ApplyButton:SetDisabledTooltip(disabledTooltip, disabledTooltipAnchor);

	local hasPending = C_TransmogOutfitInfo.HasPendingOutfitSituations();
	self.ApplyButton:SetEnabled(hasPending and (situationsAreValid or not situationsEnabled));
	self.UndoButton:SetShown(hasPending);
end
