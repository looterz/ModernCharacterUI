StaticPopupDialogs["MCU_DR_FAVORITE_WARNING"] = {
	text = TRANSMOG_FAVORITE_LOSE_REFUND_AND_TRADE,
	button1 = OKAY,
	button2 = CANCEL,
	OnAccept = function(_dialog, data)
		local setFavorite = true;
		local confirmed = true;
		MCUDR_Util.ToggleFavorite(data.visualID, setFavorite, data.itemsCollectionFrame, confirmed);
	end,
	timeout = 0,
	hideOnEscape = 1
};

MCUDR_TransmogSlotOrder = {
	INVSLOT_HEAD,
	INVSLOT_SHOULDER,
	INVSLOT_BACK,
	INVSLOT_CHEST,
	INVSLOT_BODY,
	INVSLOT_TABARD,
	INVSLOT_WRIST,
	INVSLOT_HAND,
	INVSLOT_WAIST,
	INVSLOT_LEGS,
	INVSLOT_FEET,
	INVSLOT_MAINHAND,
	INVSLOT_OFFHAND,
};

local WARDROBE_MODEL_SETUP = {
	["HEADSLOT"] 		= { useTransmogSkin = false, useTransmogChoices = false, obeyHideInTransmogFlag = false, slots = { CHESTSLOT = true,  HANDSSLOT = false, LEGSSLOT = false, FEETSLOT = false, HEADSLOT = false } },
	["SHOULDERSLOT"]	= { useTransmogSkin = true,  useTransmogChoices = true,  obeyHideInTransmogFlag = true,  slots = { CHESTSLOT = false, HANDSSLOT = false, LEGSSLOT = false, FEETSLOT = false, HEADSLOT = true  } },
	["BACKSLOT"]		= { useTransmogSkin = true,  useTransmogChoices = true,  obeyHideInTransmogFlag = true,  slots = { CHESTSLOT = false, HANDSSLOT = false, LEGSSLOT = false, FEETSLOT = false, HEADSLOT = true  } },
	["CHESTSLOT"]		= { useTransmogSkin = true,  useTransmogChoices = true,  obeyHideInTransmogFlag = true,  slots = { CHESTSLOT = false, HANDSSLOT = false, LEGSSLOT = false, FEETSLOT = false, HEADSLOT = true  } },
	["TABARDSLOT"]		= { useTransmogSkin = true,  useTransmogChoices = true,  obeyHideInTransmogFlag = true,  slots = { CHESTSLOT = false, HANDSSLOT = false, LEGSSLOT = false, FEETSLOT = false, HEADSLOT = true  } },
	["SHIRTSLOT"]		= { useTransmogSkin = true,  useTransmogChoices = true,  obeyHideInTransmogFlag = true,  slots = { CHESTSLOT = false, HANDSSLOT = false, LEGSSLOT = false, FEETSLOT = false, HEADSLOT = true  } },
	["WRISTSLOT"]		= { useTransmogSkin = true,  useTransmogChoices = true,  obeyHideInTransmogFlag = true,  slots = { CHESTSLOT = false, HANDSSLOT = false, LEGSSLOT = false, FEETSLOT = false, HEADSLOT = true  } },
	["HANDSSLOT"]		= { useTransmogSkin = false, useTransmogChoices = true,  obeyHideInTransmogFlag = true,  slots = { CHESTSLOT = true,  HANDSSLOT = false, LEGSSLOT = true,  FEETSLOT = true,  HEADSLOT = true  } },
	["WAISTSLOT"]		= { useTransmogSkin = true,  useTransmogChoices = true,  obeyHideInTransmogFlag = true,  slots = { CHESTSLOT = false, HANDSSLOT = false, LEGSSLOT = false, FEETSLOT = false, HEADSLOT = true  } },
	["LEGSSLOT"]		= { useTransmogSkin = true,  useTransmogChoices = true,  obeyHideInTransmogFlag = true,  slots = { CHESTSLOT = false, HANDSSLOT = false, LEGSSLOT = false, FEETSLOT = false, HEADSLOT = true  } },
	["FEETSLOT"]		= { useTransmogSkin = false, useTransmogChoices = true,  obeyHideInTransmogFlag = true,  slots = { CHESTSLOT = true,  HANDSSLOT = true,  LEGSSLOT = true,  FEETSLOT = false, HEADSLOT = true  } }
}

local WARDROBE_MODEL_SETUP_GEAR = {
	["CHESTSLOT"] = 78420,
	["LEGSSLOT"] = 78425,
	["FEETSLOT"] = 78427,
	["HANDSSLOT"] = 78426,
	["HEADSLOT"] = 78416
}

MCUDR_TRANSMOG_SLOTS = {};

-- Populated when MCUDR_TRANSMOG_SLOTS transmoglocations are created.
local SLOT_ID_TO_NAME = {};

MCUDR_Util = {
	HiddenModelFrame = nil;
};

function MCUDR_Util.GetInfoForEquippedSlot(transmogLocation)
	local equippedSlotInfo = {
		appliedSourceID = nil,
		appliedVisualID = nil,
		selectedSourceID = nil,
		selectedVisualID = nil,
		itemSubclass = nil
	};

	local slotVisualInfo = C_Transmog.GetSlotVisualInfo(transmogLocation:GetData());
	if slotVisualInfo then
		if slotVisualInfo.appliedSourceID == Constants.Transmog.NoTransmogID then
			slotVisualInfo.appliedSourceID = slotVisualInfo.baseSourceID;
			slotVisualInfo.appliedVisualID = slotVisualInfo.baseVisualID;
		end

		equippedSlotInfo.appliedSourceID = slotVisualInfo.appliedSourceID;
		equippedSlotInfo.appliedVisualID = slotVisualInfo.appliedVisualID;
		equippedSlotInfo.itemSubclass = slotVisualInfo.itemSubclass;

		if slotVisualInfo.pendingSourceID ~= Constants.Transmog.NoTransmogID then
			equippedSlotInfo.selectedSourceID = slotVisualInfo.pendingSourceID;
			equippedSlotInfo.selectedVisualID = slotVisualInfo.pendingVisualID;
		elseif slotVisualInfo.hasUndo then
			equippedSlotInfo.selectedSourceID = slotVisualInfo.baseSourceID;
			equippedSlotInfo.selectedVisualID = slotVisualInfo.baseVisualID;
		else
			equippedSlotInfo.selectedSourceID = slotVisualInfo.appliedSourceID;
			equippedSlotInfo.selectedVisualID = slotVisualInfo.appliedVisualID;
		end
	end

	return equippedSlotInfo;
end

function MCUDR_Util.CanEnchantSource(sourceID)
	local appearanceSourceInfo = C_TransmogCollection.GetAppearanceSourceInfo(sourceID);
	if appearanceSourceInfo and appearanceSourceInfo.canHaveIllusion then
		if not MCUDR_Util.HiddenModelFrame then
			MCUDR_Util.HiddenModelFrame = CreateFrame("DressUpModel", nil, UIParent);
			MCUDR_Util.HiddenModelFrame:Hide();
			MCUDR_Util.HiddenModelFrame:SetKeepModelOnHide(true);
		end

		MCUDR_Util.HiddenModelFrame:SetItemAppearance(appearanceSourceInfo.itemAppearanceID, 0, appearanceSourceInfo.itemSubclass);
		return MCUDR_Util.HiddenModelFrame:HasAttachmentPoints();
	end

	return false;
end

function MCUDR_Util.GetWeaponInfoForEnchant(transmogLocation)
	local equippedSlotInfo = MCUDR_Util.GetInfoForEquippedSlot(transmogLocation);

	if not MCUDR_Util.CanEnchantSource(equippedSlotInfo.selectedSourceID) then
		equippedSlotInfo.selectedSourceID = C_TransmogCollection.GetFallbackWeaponAppearance();
		local appearanceSourceInfo = C_TransmogCollection.GetAppearanceSourceInfo(equippedSlotInfo.selectedSourceID);
		if appearanceSourceInfo then
			equippedSlotInfo.selectedVisualID = appearanceSourceInfo.itemAppearanceID;
			equippedSlotInfo.itemSubclass = appearanceSourceInfo.itemSubclass;
		end
	end

	return equippedSlotInfo.selectedSourceID, equippedSlotInfo.selectedVisualID, equippedSlotInfo.itemSubclass;
end

-- Returns the weaponSlot and appearanceSourceID for the weapon that an illusion should be applied to (for dressup frames, etc)
-- If the player has a mainhand equipped that can have an illusion applied to it, uses that
-- If not, and the player has an offhand equipped that can have an illusion applied to it, uses that
-- Otherwise uses the fallback weapon in the mainhand
function MCUDR_Util.GetBestWeaponInfoForIllusionDressup()
	local isSecondary = false;
	local mainHandTransmogLocation = MCUDR_Util.GetTransmogLocation("MAINHANDSLOT", Enum.TransmogType.Appearance, isSecondary);
	local mainHandVisualInfo = C_Transmog.GetSlotVisualInfo(mainHandTransmogLocation:GetData());

	local offHandTransmogLocation = MCUDR_Util.GetTransmogLocation("SECONDARYHANDSLOT", Enum.TransmogType.Appearance, isSecondary);
	local offHandVisualInfo = C_Transmog.GetSlotVisualInfo(offHandTransmogLocation:GetData());

	local transmogLocation = ((mainHandVisualInfo and mainHandVisualInfo.baseSourceID == NO_TRANSMOG_VISUAL_ID) and (offHandVisualInfo and offHandVisualInfo.baseSourceID ~= NO_TRANSMOG_VISUAL_ID)) and offHandTransmogLocation or mainHandTransmogLocation;
	local weaponSourceID = MCUDR_Util.GetWeaponInfoForEnchant(transmogLocation);

	return transmogLocation:GetSlotName(), weaponSourceID;
end

function MCUDR_Util.GetSlotID(slotName)
	local slotID = GetInventorySlotInfo(slotName);
	SLOT_ID_TO_NAME[slotID] = slotName;
	return slotID;
end

function MCUDR_Util.GetSlotName(slotID)
	return SLOT_ID_TO_NAME[slotID];
end

local function GetSlotID(slotDescriptor)
	if type(slotDescriptor) == "string" then
		return MCUDR_Util.GetSlotID(slotDescriptor);
	else
		return slotDescriptor;
	end
end

function MCUDR_Util.CreateTransmogLocation(slotDescriptor, transmogType, isSecondary)
	local slotID = GetSlotID(slotDescriptor);

	-- For linked slots, this will always return the primary.
	local slot = C_TransmogOutfitInfo.GetTransmogOutfitSlotFromInventorySlot(slotID - 1);

	if isSecondary then
		local linkedSlotInfo = C_TransmogOutfitInfo.GetLinkedSlotInfo(slot);
		if linkedSlotInfo then
			slot = linkedSlotInfo.secondarySlotInfo.slot;
		end
	end

	local locationData = {
		slot = slot,
		slotID = slotID,
		transmogType = transmogType,
		isSecondary = isSecondary
	};

	local transmogLocation = CreateFromMixins(MCUDR_LocationMixin);
	transmogLocation:Set(locationData);
	return transmogLocation;
end

function MCUDR_Util.GetTransmogLocation(slotDescriptor, transmogType, isSecondary)
	local slotID = GetSlotID(slotDescriptor);
	local lookupKey = MCUDR_Util.GetTransmogLocationLookupKey(slotID, transmogType, isSecondary);
	local transmogSlot = MCUDR_TRANSMOG_SLOTS[lookupKey];
	return transmogSlot and transmogSlot.location;
end

function MCUDR_Util.GetCorrespondingHandTransmogLocation(transmogLocation)
	local isSecondary = false;
	if transmogLocation:IsMainHand() then
		return MCUDR_Util.GetTransmogLocation("MAINHANDSLOT", Enum.TransmogType.Appearance, isSecondary);
	elseif transmogLocation:IsOffHand() then
		return MCUDR_Util.GetTransmogLocation("SECONDARYHANDSLOT", Enum.TransmogType.Appearance, isSecondary);
	end
end

function MCUDR_Util.GetTransmogLocationLookupKey(slotID, transmogType, isSecondary)
	local secondaryValue = isSecondary and 1 or 0;
	return slotID * 100 + transmogType * 10 + secondaryValue;
end

function MCUDR_Util.GetSetIcon(setID)
	local bestItemID;
	local bestSortOrder = 100;
	local setAppearances = C_TransmogSets.GetSetPrimaryAppearances(setID);
	if setAppearances then
		for _index, appearanceInfo in pairs(setAppearances) do
			local sourceInfo = C_TransmogCollection.GetSourceInfo(appearanceInfo.appearanceID);
			if sourceInfo then
				local sortOrder = EJ_GetInvTypeSortOrder(sourceInfo.invType);
				if sortOrder < bestSortOrder then
					bestSortOrder = sortOrder;
					bestItemID = sourceInfo.itemID;
				end
			end
		end
	end

	if bestItemID then
		return select(5, C_Item.GetItemInfoInstant(bestItemID));
	else
		return QUESTION_MARK_ICON;
	end
end

function MCUDR_Util.IsSecondaryTransmoggedForItemLocation(itemLocation)
	if itemLocation and C_Item.DoesItemExist(itemLocation) then
		local itemTransmogInfo = C_Item.GetAppliedItemTransmogInfo(itemLocation);
		return itemTransmogInfo and itemTransmogInfo.secondaryAppearanceID ~= Constants.Transmog.NoTransmogID;
	end

	return false;
end

function MCUDR_Util.GetItemLocationFromTransmogLocation(transmogLocation)
	if not transmogLocation then
		return nil;
	end

	return ItemLocation:CreateFromEquipmentSlot(transmogLocation:GetSlotID());
end

function MCUDR_Util.IsCategoryLegionArtifact(categoryID)
	return categoryID == Enum.TransmogCollectionType.Paired;
end

function MCUDR_Util.IsCategoryRangedWeapon(categoryID)
	return (categoryID == Enum.TransmogCollectionType.Bow) or (categoryID == Enum.TransmogCollectionType.Gun) or (categoryID == Enum.TransmogCollectionType.Crossbow);
end

function MCUDR_Util.IsValidTransmogSlotID(slotID)
	local isSecondary = false;
	local lookupKey = MCUDR_Util.GetTransmogLocationLookupKey(slotID, Enum.TransmogType.Appearance, isSecondary);
	return not not MCUDR_TRANSMOG_SLOTS[lookupKey];
end

function MCUDR_Util.OpenCollectionToItem(sourceID)
	if MCUDR_Util.OpenCollectionUI() then
		WardrobeCollectionFrame:GoToItem(sourceID);
	end
end

function MCUDR_Util.OpenCollectionToSet(setID)
	if MCUDR_Util.OpenCollectionUI() then
		WardrobeCollectionFrame:GoToSet(setID);
	end
end

function MCUDR_Util.OpenCollectionUI()
	if not CollectionsJournal then
		CollectionsJournal_LoadUI();
	end

	if CollectionsJournal then
		if not CollectionsJournal:IsVisible() or not WardrobeCollectionFrame:IsVisible() then
			ToggleCollectionsJournal(COLLECTIONS_JOURNAL_TAB_INDEX_APPEARANCES);
		end
		return true;
	end

	return false;
end

function MCUDR_Util.GetEmptyItemTransmogInfoList()
	local list = { };
	for _index = 1, INVSLOT_LAST_EQUIPPED do
		table.insert(list, ItemUtil.CreateItemTransmogInfo(0, 0, 0));
	end

	return list;
end

local NUM_CUSTOM_SET_SLASH_COMMAND_VALUES = 17;

-- Custom set slash command sample:
-- /customset v1 7019,7017,0,0,7022,0,0,7015,7020,7016,7018,7021,70216,0,0,0,0
-- "v1" is the version so future formats won't break older slash commands
-- The comma-separated values are as follows:
-- 		Head		- appearanceID
--		Shoulder	- appearanceID
--		Shoulder	- secondaryAppearanceID (0 if shoulders aren't split)
-- 		Back		- appearanceID
--		Chest		- appearanceID
--		Body		- appearanceID
--		Tabard		- appearanceID
--		Wrist		- appearanceID
--		Hand		- appearanceID
--		Waist		- appearanceID
--		Legs		- appearanceID
--		Feet		- appearanceID
--		MainHand	- appearanceID
--		MainHand	- secondaryAppearanceID (0 if the weapon is from Legion Artifacts category, -1 otherwise)
--		MainHand	- illusionID
--		OffHand		- appearanceID
--		OffHand		- illusionID

function MCUDR_Util.CreateCustomSetSlashCommand(itemTransmogInfoList)
	local slashCommand = "/customset v1 ";
	local isPairedWeapons = false;
	for index, slotID in ipairs(MCUDR_TransmogSlotOrder) do
		local transmogInfo = itemTransmogInfoList[slotID];
		if transmogInfo then
			local appearanceID = transmogInfo.appearanceID;
			if slotID == INVSLOT_OFFHAND and isPairedWeapons then
				appearanceID = -1;
			end

			if index == 1 then
				slashCommand = slashCommand..appearanceID;
			else
				slashCommand = slashCommand..","..appearanceID;
			end

			-- secondaries
			if slotID == INVSLOT_SHOULDER or slotID == INVSLOT_MAINHAND then
				slashCommand = slashCommand..","..transmogInfo.secondaryAppearanceID;
			end

			-- illusions
			if slotID == INVSLOT_MAINHAND or slotID == INVSLOT_OFFHAND then
				slashCommand = slashCommand..","..transmogInfo.illusionID;
			end
		end
	end

	return slashCommand;
end

function MCUDR_Util.ParseCustomSetSlashCommand(msg)
	-- check version #
	if string.sub(msg, 1, 3) == "v1 " then
		local readlist = C_Transmog.ExtractTransmogIDList(string.sub(msg, 4));
		if #readlist ~= NUM_CUSTOM_SET_SLASH_COMMAND_VALUES then
			DEFAULT_CHAT_FRAME:AddMessage(TRANSMOG_CUSTOM_SET_LINK_INVALID, RED_FONT_COLOR:GetRGB());
			return;
		end

		-- accessor for next value
		local readIndex = 0;
		local function GetNextReadValue()
			readIndex = readIndex + 1; 
			return readlist[readIndex];
		end

		-- set the values
		local itemTransmogInfoList = MCUDR_Util.GetEmptyItemTransmogInfoList();
		for _index, slotID in ipairs(MCUDR_TransmogSlotOrder) do
			local info = itemTransmogInfoList[slotID];
			info.appearanceID = GetNextReadValue();
			-- secondaries
			if slotID == INVSLOT_SHOULDER or slotID == INVSLOT_MAINHAND then
				info.secondaryAppearanceID = GetNextReadValue();
				-- category check on shoulder secondary
				if slotID == INVSLOT_SHOULDER and info.secondaryAppearanceID ~= Constants.Transmog.NoTransmogID then
					local appearanceSourceInfo = C_TransmogCollection.GetAppearanceSourceInfo(info.secondaryAppearanceID);
					if appearanceSourceInfo and appearanceSourceInfo.category ~= Enum.TransmogCollectionType.Shoulder then
						info.secondaryAppearanceID = Constants.Transmog.NoTransmogID;
					end
				end
			end

			-- illusions
			if slotID == INVSLOT_MAINHAND or slotID == INVSLOT_OFFHAND then
				info.illusionID = math.max(GetNextReadValue(), Constants.Transmog.NoTransmogID);
			end
		end

		return itemTransmogInfoList;
	end

	DEFAULT_CHAT_FRAME:AddMessage(TRANSMOG_CUSTOM_SET_LINK_INVALID, RED_FONT_COLOR:GetRGB());
	return nil;
end

function MCUDR_Util.GetWardrobeModelSetupData(slot)
	return WARDROBE_MODEL_SETUP[slot];
end

function MCUDR_Util.GetWardrobeModelSetupGearData(slot)
	return WARDROBE_MODEL_SETUP_GEAR[slot];
end

function MCUDR_Util.GetUseTransmogSkin(slot)
	local modelSetupTable = WARDROBE_MODEL_SETUP[slot];
	if not modelSetupTable or modelSetupTable.useTransmogSkin then
		return true;
	end

	-- this exludes head slot
	if modelSetupTable.useTransmogChoices then
		local isSecondary = false;
		local transmogLocation = MCUDR_Util.GetTransmogLocation(slot, Enum.TransmogType.Appearance, isSecondary);
		if transmogLocation then
			if not C_PlayerInfo.HasVisibleInvSlot(transmogLocation.slotID) then
				return true;
			end
		end
	end

	return false;
end

function MCUDR_Util.GetCameraVariation(transmogLocation, checkSecondary)
	if checkSecondary == nil then
		local itemLocation = MCUDR_Util.GetItemLocationFromTransmogLocation(transmogLocation);
		checkSecondary = MCUDR_Util.IsSecondaryTransmoggedForItemLocation(itemLocation);
	end

	if checkSecondary then
		if transmogLocation:IsSecondary() then
			return 0;
		else
			return 1;
		end
	end

	return nil;
end

function MCUDR_Util.ToggleFavorite(visualID, setFavorite, itemsCollectionFrame, confirmed)
	if setFavorite and not confirmed then
		local allSourcesConditional = true;
		local transmogLocation = itemsCollectionFrame:GetTransmogLocation();
		local sources = C_TransmogCollection.GetAppearanceSources(visualID, itemsCollectionFrame:GetActiveCategory(), transmogLocation:GetData());
		for _index, sourceInfo in ipairs(sources) do
			local info = C_TransmogCollection.GetAppearanceInfoBySource(sourceInfo.sourceID);
			if info.sourceIsCollectedPermanent then
				allSourcesConditional = false;
				break;
			end
		end

		if allSourcesConditional then
			local dialogData = {
				visualID = visualID,
				itemsCollectionFrame = itemsCollectionFrame
			}
			StaticPopup_Show("MCU_DR_FAVORITE_WARNING", nil, nil, dialogData);
			return;
		end
	end

	C_TransmogCollection.SetIsAppearanceFavorite(visualID, setFavorite);
end

function MCUDR_Util.IsValidItemTransmogInfoList(itemTransmogInfoList)
	local isValid = false;
	for slotID, itemTransmogInfo in ipairs(itemTransmogInfoList) do
		local isValidAppearance = false;
		if MCUDR_Util.IsValidTransmogSlotID(slotID) then
			local appearanceID = itemTransmogInfo.appearanceID;
			isValidAppearance = appearanceID ~= Constants.Transmog.NoTransmogID;

			-- Skip offhand if mainhand is an appeance from Legion Artifacts category and the offhand matches the paired appearance.
			if isValidAppearance and slotID == INVSLOT_OFFHAND then
				local mainHandInfo = itemTransmogInfoList[INVSLOT_MAINHAND];
				if mainHandInfo:IsMainHandPairedWeapon() then
					isValidAppearance = appearanceID ~= C_TransmogCollection.GetPairedArtifactAppearance(mainHandInfo.appearanceID);
				end
			end

			if isValidAppearance then
				local _hasAllData, canCollect = C_TransmogCollection.PlayerCanCollectSource(appearanceID);
				if canCollect then
					isValid = true;
					break;
				end

				-- Secondary check
				local secondaryAppearanceID = itemTransmogInfo.secondaryAppearanceID;
				if secondaryAppearanceID ~= Constants.Transmog.NoTransmogID and C_Transmog.CanHaveSecondaryAppearanceForSlotID(slotID) then
					_hasAllData, canCollect = C_TransmogCollection.PlayerCanCollectSource(secondaryAppearanceID);
					if canCollect then
						isValid = true;
						break;
					end
				end
			end
		end
	end

	return isValid;
end

function MCUDR_Util.IsCustomSetCollected(customSetID)
	local isCollected = true;
	local customSetTransmogInfo = C_TransmogCollection.GetCustomSetItemTransmogInfoList(customSetID);
	for _indexCustomSetInfo, customSetInfo in ipairs(customSetTransmogInfo) do
		local appearanceInfo = C_TransmogCollection.GetAppearanceInfoBySource(customSetInfo.appearanceID);
		if appearanceInfo and isCollected and not appearanceInfo.appearanceIsCollected then
			isCollected = false;
			break;
		end
	end
	return isCollected;
end


MCUDR_LocationMixin = {};

function MCUDR_LocationMixin:Set(locationData)
	self.slot = locationData.slot;
	self.slotID = locationData.slotID;
	self.type = locationData.transmogType;
	self.modification = locationData.isSecondary and Enum.TransmogModification.Secondary or Enum.TransmogModification.Main;
end

function MCUDR_LocationMixin:IsAppearance()
	return self.type == Enum.TransmogType.Appearance;
end

function MCUDR_LocationMixin:IsIllusion()
	return self.type == Enum.TransmogType.Illusion;
end

function MCUDR_LocationMixin:IsEitherHand()
	return self:IsMainHand() or self:IsOffHand();
end

function MCUDR_LocationMixin:IsMainHand()
	local slotName = self:GetSlotName();
	return slotName == "MAINHANDSLOT";
end

function MCUDR_LocationMixin:IsOffHand()
	local slotName = self:GetSlotName();
	return slotName == "SECONDARYHANDSLOT";
end

function MCUDR_LocationMixin:IsRangedSlot()
	local slotName = self:GetSlotName();
	return slotName == "RANGEDSLOT";
end

function MCUDR_LocationMixin:IsSecondary()
	return self.modification == Enum.TransmogModification.Secondary;
end

function MCUDR_LocationMixin:IsEqual(transmogLocation)
	if not transmogLocation then
		return false;
	end

	return self.slotID == transmogLocation.slotID and self.type == transmogLocation.type and self.modification == transmogLocation.modification;
end

function MCUDR_LocationMixin:GetSlot()
	return self.slot;
end

function MCUDR_LocationMixin:GetSlotID()
	return self.slotID;
end

function MCUDR_LocationMixin:GetType()
	return self.type;
end

function MCUDR_LocationMixin:GetSlotName()
	return MCUDR_Util.GetSlotName(self.slotID);
end

function MCUDR_LocationMixin:GetArmorCategoryID()
	local transmogSlot = MCUDR_TRANSMOG_SLOTS[self:GetLookupKey()];
	return transmogSlot and transmogSlot.armorCategoryID;
end

function MCUDR_LocationMixin:GetLookupKey()
	return MCUDR_Util.GetTransmogLocationLookupKey(self.slotID, self.type, self:IsSecondary());
end

-- Data format for API that takes a transmogLocation as an argument.
function MCUDR_LocationMixin:GetData()
	return {
		slotID = self.slotID,
		type = self.type,
		modification = self.modification
	};
end

-- This will indirectly populate SLOT_ID_TO_NAME.
do
	function InitializeSlotLocationInfo()
		local function InitializeLocation(slotInfo)
			local slotInfoValid = true;
			if slotInfo.slot == "RANGEDSLOT" and not C_PaperDollInfo.IsRangedSlotShown() then
				slotInfoValid = false;
			end

			if slotInfoValid then
				local location = MCUDR_Util.CreateTransmogLocation(slotInfo.slotName, slotInfo.type, slotInfo.isSecondary);
				local lookupKey = location:GetLookupKey();
				local armorCategoryID = slotInfo.collectionType;
				if armorCategoryID == Enum.TransmogCollectionType.None then
					armorCategoryID = nil;
				end
				MCUDR_TRANSMOG_SLOTS[lookupKey] = { location = location, armorCategoryID = armorCategoryID };
			end
		end

		local appearanceSlotInfo, illusionSlotInfo = C_TransmogOutfitInfo.GetAllSlotLocationInfo();
		if appearanceSlotInfo then
			for _index, slotInfo in ipairs(appearanceSlotInfo) do
				InitializeLocation(slotInfo);
			end
		end

		if illusionSlotInfo then
			for _index, slotInfo in ipairs(illusionSlotInfo) do
				InitializeLocation(slotInfo);
			end
		end
	end

	InitializeSlotLocationInfo();
end


-- This base mixin assumes that it is associated with a DressUpModel.
-- The intent is to make a mixin that inherits this, do not use directly.
MCUDR_ItemModelBaseMixin = { };

function MCUDR_ItemModelBaseMixin:OnLoad()
	self:SetAutoDress(false);

	local enabled = true;
	local lightValues = {
		omnidirectional = false,
		point = CreateVector3D(-1, 1, -1),
		ambientIntensity = 1.05,
		ambientColor = CreateColor(1, 1, 1),
		diffuseIntensity = 0,
		diffuseColor = CreateColor(1, 1, 1)
	};
	self:SetLight(enabled, lightValues);

	self.desaturated = false;
end

function MCUDR_ItemModelBaseMixin:OnModelLoaded()
	if self.cameraID then
		Model_ApplyUICamera(self, self.cameraID);
	end
	self.desaturated = false;
end

function MCUDR_ItemModelBaseMixin:OnMouseUp(button)
	local appearanceInfo = self:GetAppearanceInfo();
	local itemsCollectionFrame = self:GetCollectionFrame();
	if not appearanceInfo or not itemsCollectionFrame then
		return;
	end

	if button ~= "RightButton" then
		return;
	end

	if not appearanceInfo.isCollected or appearanceInfo.isHideVisual or itemsCollectionFrame:GetTransmogLocation():IsIllusion() then
		return;
	end

	MenuUtil.CreateContextMenu(self, function(_owner, rootDescription)
		rootDescription:SetTag("MENU_WARDROBE_ITEMS_MODEL_FILTER");

		local visualID = appearanceInfo.visualID;
		local favorite = C_TransmogCollection.GetIsAppearanceFavorite(visualID);
		local text = favorite and TRANSMOG_ITEM_UNSET_FAVORITE or TRANSMOG_ITEM_SET_FAVORITE;
		rootDescription:CreateButton(text, function()
			self:ToggleFavorite(visualID, not favorite);
		end);

		rootDescription:QueueSpacer();
		rootDescription:QueueTitle(WARDROBE_TRANSMOGRIFY_AS);

		local activeCategory = itemsCollectionFrame:GetActiveCategory();
		local transmogLocation = itemsCollectionFrame:GetTransmogLocation();
		local chosenSourceID = itemsCollectionFrame:GetChosenVisualSource(visualID);
		for _index, source in ipairs(CollectionWardrobeUtil.GetSortedAppearanceSources(visualID, activeCategory, transmogLocation)) do
			if source.isCollected and itemsCollectionFrame:IsAppearanceUsableForActiveCategory(source) then
				if chosenSourceID == Constants.Transmog.NoTransmogID then
					chosenSourceID = source.sourceID;
				end

				local function IsChecked(data)
					return chosenSourceID == data.sourceID;
				end

				local function SetChecked(data)
					itemsCollectionFrame:SetChosenVisualSource(data.visualID, data.sourceID);
					if itemsCollectionFrame.SelectVisual then
						itemsCollectionFrame:SelectVisual(data.visualID);
					end
				end

				local name, color = itemsCollectionFrame:GetAppearanceNameTextAndColor(source);
				if name and color then
					local coloredText = color:WrapTextInColorCode(name);
					local data = {
						visualID = visualID,
						sourceID = source.sourceID
					};
					rootDescription:CreateRadio(coloredText, IsChecked, SetChecked, data);
				end
			end
		end
	end);
end

function MCUDR_ItemModelBaseMixin:OnMouseDown(button)
	local appearanceInfo = self:GetAppearanceInfo();
	local itemsCollectionFrame = self:GetCollectionFrame();
	if not appearanceInfo or not itemsCollectionFrame then
		return;
	end

	if IsModifiedClick("CHATLINK") then
		local link;
		if itemsCollectionFrame:GetTransmogLocation():IsIllusion() then
			link = self:GetIllusionLink();
		else
			link = self:GetAppearanceLink();
		end

		if link then
			HandleModifiedItemClick(link);
		end
	elseif self:CanCheckDressUpClick() and IsModifiedClick("DRESSUP") then
		itemsCollectionFrame:DressUpVisual(appearanceInfo);
	elseif button == "LeftButton" and itemsCollectionFrame.SelectVisual then
		itemsCollectionFrame:SelectVisual(appearanceInfo.visualID);
	end
end

function MCUDR_ItemModelBaseMixin:OnEnter()
	local appearanceInfo = self:GetAppearanceInfo();
	local itemsCollectionFrame = self:GetCollectionFrame();
	if not appearanceInfo or not itemsCollectionFrame then
		return;
	end

	self.needsItemGeo = false;
	self:SetScript("OnUpdate", self.OnUpdate);

	if itemsCollectionFrame:GetTransmogLocation():IsIllusion() then
		local name = C_TransmogCollection.GetIllusionStrings(appearanceInfo.sourceID);
		if not name then
			return;
		end

		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(name);
		if appearanceInfo.sourceText then
			GameTooltip:AddLine(appearanceInfo.sourceText, 1, 1, 1, 1);
		end
		GameTooltip:Show();
	else
		self.needsItemGeo = not self:IsGeoReady();
		itemsCollectionFrame:SetAppearanceTooltip(self);
	end
end

function MCUDR_ItemModelBaseMixin:OnLeave()
	local itemsCollectionFrame = self:GetCollectionFrame();
	if not itemsCollectionFrame then
		return;
	end

	self:SetScript("OnUpdate", nil);
	itemsCollectionFrame:ClearAppearanceTooltip();
end

function MCUDR_ItemModelBaseMixin:OnUpdate()
	local itemsCollectionFrame = self:GetCollectionFrame();
	if not itemsCollectionFrame then
		return;
	end

	if self.needsItemGeo and self:IsGeoReady() then
		self.needsItemGeo = false;
		itemsCollectionFrame:SetAppearanceTooltip(self);
	end

	if self:CanCheckDressUpClick() then
		if IsModifiedClick("DRESSUP") then
			ShowInspectCursor();
		else
			ResetCursor();
		end
	end
end

function MCUDR_ItemModelBaseMixin:OnShow()
	if self.needsReload then
		self:Reload();
	end
end

function MCUDR_ItemModelBaseMixin:Reload()
	local itemsCollectionFrame = self:GetCollectionFrame();
	if not itemsCollectionFrame then
		return;
	end

	local reloadSlot = itemsCollectionFrame:GetActiveSlot();
	if self:IsShown() then
		local wardrobeModelSetupData = MCUDR_Util.GetWardrobeModelSetupData(reloadSlot);

		-- No need to update things if the last used form (if supported for this character) and setup data is the same.
		local shouldUseNativeForm = PlayerUtil.ShouldUseNativeFormInModelScene();
		if shouldUseNativeForm == self.shouldUseNativeForm and self.modelSetupData == wardrobeModelSetupData then
			self.needsReload = nil;
			return;
		end

		self.shouldUseNativeForm = shouldUseNativeForm;
		self.modelSetupData = wardrobeModelSetupData;
		if self.modelSetupData then
			local useTransmogSkin = MCUDR_Util.GetUseTransmogSkin(reloadSlot);
			self:SetUseTransmogSkin(useTransmogSkin);
			self:SetUseTransmogChoices(self.modelSetupData.useTransmogChoices);
			self:SetObeyHideInTransmogFlag(self.modelSetupData.obeyHideInTransmogFlag);
			local blend = false;
			self:SetUnit("player", blend, self.shouldUseNativeForm);
			for slot, equip in pairs(self.modelSetupData.slots) do
				if equip then
					self:TryOn(MCUDR_Util.GetWardrobeModelSetupGearData(slot));
				end
			end
		end
		self:SetKeepModelOnHide(true);
		self:UpdateCamera();
		self.needsReload = nil;
	else
		self.needsReload = true;
	end
end

-- Note that if cameraID is cleared via Reload before OnModelLoaded happens, you may run into issues with the camera not being how we expect.
function MCUDR_ItemModelBaseMixin:UpdateCamera()
	self.cameraID = nil;
end

function MCUDR_ItemModelBaseMixin:SetDesaturated(desaturated)
	if self.desaturated ~= desaturated then
		self.desaturated = desaturated;
		self:SetDesaturation((desaturated and 1) or 0);
	end
end

function MCUDR_ItemModelBaseMixin:ToggleFavorite(visualID, isFavorite)
	local itemsCollectionFrame = self:GetCollectionFrame();
	MCUDR_Util.ToggleFavorite(visualID, isFavorite, itemsCollectionFrame);
end

function MCUDR_ItemModelBaseMixin:GetAppearanceInfo()
	-- Override in your mixin, this is the item's associated data.
	return nil;
end

function MCUDR_ItemModelBaseMixin:GetCollectionFrame()
	-- Override in your mixin, this is the associated frame that has any number of general collection calls that may be needed.
	return nil;
end

function MCUDR_ItemModelBaseMixin:GetIllusionLink()
	local link = nil;

	local appearanceInfo = self:GetAppearanceInfo();
	if not appearanceInfo then
		return link;
	end

	local _name;
	_name, link = C_TransmogCollection.GetIllusionStrings(appearanceInfo.sourceID);
	return link;
end

function MCUDR_ItemModelBaseMixin:GetAppearanceLink()
	-- Override in your mixin.
	return nil;
end

function MCUDR_ItemModelBaseMixin:CanCheckDressUpClick()
	-- Override in your mixin if needed.
	return true;
end


MCUDR_WardrobeSetsDataProviderMixin = {};

function MCUDR_WardrobeSetsDataProviderMixin:SortSets(sets, reverseUIOrder, ignorePatchID, ignoreCollected)
	local comparison = function(set1, set2)
		local groupFavorite1 = set1.favoriteSetID and true;
		local groupFavorite2 = set2.favoriteSetID and true;
		if groupFavorite1 ~= groupFavorite2 then
			return groupFavorite1;
		end

		if set1.favorite ~= set2.favorite then
			return set1.favorite;
		end

		if not ignoreCollected then
			if set1.collected ~= set2.collected then
				return set1.collected;
			end
		end

		if set1.expansionID ~= set2.expansionID then
			return set1.expansionID > set2.expansionID;
		end

		if not ignorePatchID then
			if set1.patchID ~= set2.patchID then
				return set1.patchID > set2.patchID;
			end
		end

		if set1.uiOrder ~= set2.uiOrder then
			if reverseUIOrder then
				return set1.uiOrder < set2.uiOrder;
			else
				return set1.uiOrder > set2.uiOrder;
			end
		end

		if reverseUIOrder then
			return set1.setID < set2.setID;
		else
			return set1.setID > set2.setID;
		end
	end

	table.sort(sets, comparison);
end

function MCUDR_WardrobeSetsDataProviderMixin:GetBaseSets()
	if not self.baseSets then
		self.baseSets = C_TransmogSets.GetBaseSets();
		self:DetermineFavorites();

		local reverseUIOrder = false;
		local ignorePatchID = false;
		local ignoreCollected = true;
		self:SortSets(self.baseSets, reverseUIOrder, ignorePatchID, ignoreCollected);
	end
	return self.baseSets;
end

function MCUDR_WardrobeSetsDataProviderMixin:GetBaseSetByID(baseSetID)
	local baseSets = self:GetBaseSets();
	for index, baseSet in ipairs(baseSets) do
		if baseSet.setID == baseSetID then
			return baseSet, index;
		end
	end
	return nil, nil;
end

-- Usable sets are sets that the player can use that are completed.
function MCUDR_WardrobeSetsDataProviderMixin:GetUsableSets()
	if not self.usableSets then
		self.usableSets = C_TransmogSets.GetUsableSets();

		local reverseUIOrder = false;
		local ignorePatchID = false;
		local ignoreCollected = true;
		self:SortSets(self.usableSets, reverseUIOrder, ignorePatchID, ignoreCollected);

		-- Group sets by baseSetID, except for favorited sets since those are to remain bucketed to the front.
		for index, usableSet in ipairs(self.usableSets) do
			if not usableSet.favorite then
				local baseSetID = usableSet.baseSetID or usableSet.setID;
				local numRelatedSets = 0;
				for indexSecondary = index + 1, #self.usableSets do
					if self.usableSets[indexSecondary].baseSetID == baseSetID or self.usableSets[indexSecondary].setID == baseSetID then
						numRelatedSets = numRelatedSets + 1;
						-- No need to do anything if already contiguous
						if indexSecondary ~= index + numRelatedSets then
							local relatedSet = self.usableSets[indexSecondary];
							tremove(self.usableSets, indexSecondary);
							tinsert(self.usableSets, index + numRelatedSets, relatedSet);
						end
					end
				end
			end
		end
	end
	return self.usableSets;
end

-- Available sets are sets that the player can use that have at least 1 slot unlocked.
function MCUDR_WardrobeSetsDataProviderMixin:GetAvailableSets()
	if not self.availableSets then
		self.availableSets = C_TransmogSets.GetAvailableSets();

		local reverseUIOrder = false;
		local ignorePatchID = false;
		local ignoreCollected = false;
		self:SortSets(self.availableSets, reverseUIOrder, ignorePatchID, ignoreCollected);
	end
	return self.availableSets;
end

-- Variant sets are all of the different versions (recolors, etc.) of a base set.
function MCUDR_WardrobeSetsDataProviderMixin:GetVariantSets(baseSetID)
	if not self.variantSets then
		self.variantSets = {};
	end

	local variantSets = self.variantSets[baseSetID];
	if not variantSets then
		variantSets = C_TransmogSets.GetVariantSets(baseSetID) or {};
		self.variantSets[baseSetID] = variantSets;
		if #variantSets > 0 then
			-- Add base to variants and sort.
			local baseSet = self:GetBaseSetByID(baseSetID);
			if baseSet then
				tinsert(variantSets, baseSet);
			end
			local reverseUIOrder = true;
			local ignorePatchID = true;
			local ignoreCollected = true;
			self:SortSets(variantSets, reverseUIOrder, ignorePatchID, ignoreCollected);
		end
	end
	return variantSets;
end

function MCUDR_WardrobeSetsDataProviderMixin:GetSetSourceData(setID)
	if not self.sourceData then
		self.sourceData = {};
	end

	local sourceData = self.sourceData[setID];
	if not sourceData then
		local primaryAppearances = C_TransmogSets.GetSetPrimaryAppearances(setID);
		local numCollected = 0;
		local numTotal = 0;
		for _index, primaryAppearance in ipairs(primaryAppearances) do
			if primaryAppearance.collected then
				numCollected = numCollected + 1;
			end
			numTotal = numTotal + 1;
		end
		sourceData = { numCollected = numCollected, numTotal = numTotal, primaryAppearances = primaryAppearances };
		self.sourceData[setID] = sourceData;
	end
	return sourceData;
end

function MCUDR_WardrobeSetsDataProviderMixin:GetSetSourceCounts(setID)
	local sourceData = self:GetSetSourceData(setID);
	return sourceData.numCollected, sourceData.numTotal;
end

function MCUDR_WardrobeSetsDataProviderMixin:GetBaseSetData(setID)
	if not self.baseSetsData then
		self.baseSetsData = {};
	end

	if not self.baseSetsData[setID] then
		local baseSetID = C_TransmogSets.GetBaseSetID(setID);
		if baseSetID ~= setID then
			return;
		end

		local topCollected, topTotal = self:GetSetSourceCounts(setID);
		local variantSets = self:GetVariantSets(setID);
		for _index, varientSet in ipairs(variantSets) do
			local numCollected, numTotal = self:GetSetSourceCounts(varientSet.setID);
			if numCollected > topCollected then
				topCollected = numCollected;
				topTotal = numTotal;
			end
		end
		local setInfo = { topCollected = topCollected, topTotal = topTotal, completed = (topCollected == topTotal) };
		self.baseSetsData[setID] = setInfo;
	end
	return self.baseSetsData[setID];
end

function MCUDR_WardrobeSetsDataProviderMixin:GetSetSourceTopCounts(setID)
	local baseSetData = self:GetBaseSetData(setID);
	if baseSetData then
		return baseSetData.topCollected, baseSetData.topTotal;
	else
		return self:GetSetSourceCounts(setID);
	end
end

function MCUDR_WardrobeSetsDataProviderMixin:IsBaseSetNew(baseSetID)
	local baseSetData = self:GetBaseSetData(baseSetID)
	if not baseSetData then
		return false;
	end

	if not baseSetData.newStatus then
		local newStatus = C_TransmogSets.SetHasNewSources(baseSetID);
		if not newStatus then
			-- Check variants
			local variantSets = self:GetVariantSets(baseSetID);
			for _index, variantSet in ipairs(variantSets) do
				if C_TransmogSets.SetHasNewSources(variantSet.setID) then
					newStatus = true;
					break;
				end
			end
		end
		baseSetData.newStatus = newStatus;
	end
	return baseSetData.newStatus;
end

function MCUDR_WardrobeSetsDataProviderMixin:ResetBaseSetNewStatus(baseSetID)
	local baseSetData = self:GetBaseSetData(baseSetID)
	if baseSetData then
		baseSetData.newStatus = nil;
	end
end

function MCUDR_WardrobeSetsDataProviderMixin:GetSortedSetSources(setID)
	local returnTable = {};
	local sourceData = self:GetSetSourceData(setID);
	for _index, primaryAppearance in ipairs(sourceData.primaryAppearances) do
		local sourceID = primaryAppearance.appearanceID;
		local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID);
		if sourceInfo then
			local sortOrder = EJ_GetInvTypeSortOrder(sourceInfo.invType);
			tinsert(returnTable, { sourceID = sourceID, collected = primaryAppearance.collected, sortOrder = sortOrder, itemID = sourceInfo.itemID, invType = sourceInfo.invType });
		end
	end

	local comparison = function(entry1, entry2)
		if entry1.sortOrder == entry2.sortOrder then
			return entry1.itemID < entry2.itemID;
		else
			return entry1.sortOrder < entry2.sortOrder;
		end
	end
	table.sort(returnTable, comparison);
	return returnTable;
end

function MCUDR_WardrobeSetsDataProviderMixin:ClearSets()
	self.baseSets = nil;
	self.baseSetsData = nil;
	self.variantSets = nil;
	self.usableSets = nil;
	self.availableSets = nil;
	self.sourceData = nil;
end

function MCUDR_WardrobeSetsDataProviderMixin:ClearBaseSets()
	self.baseSets = nil;
end

function MCUDR_WardrobeSetsDataProviderMixin:ClearVariantSets()
	self.variantSets = nil;
end

function MCUDR_WardrobeSetsDataProviderMixin:ClearUsableSets()
	self.usableSets = nil;
end

function MCUDR_WardrobeSetsDataProviderMixin:ClearAvailableSets()
	self.availableSets = nil;
end

function MCUDR_WardrobeSetsDataProviderMixin:GetIconForSet(setID)
	local sourceData = self:GetSetSourceData(setID);
	if not sourceData.icon then
		local sortedSources = self:GetSortedSetSources(setID);
		if sortedSources[1] then
			local _itemID, _itemType, _itemSubType, _itemEquipLoc, icon = C_Item.GetItemInfoInstant(sortedSources[1].itemID);
			sourceData.icon = icon;
		else
			sourceData.icon = QUESTION_MARK_ICON;
		end
	end
	return sourceData.icon;
end

function MCUDR_WardrobeSetsDataProviderMixin:DetermineFavorites()
	-- If a variant is favorited, so is the base set.
	-- Keep track of which set is favorited.
	local baseSets = self:GetBaseSets();
	for _indexBaseSet, baseSet in ipairs(baseSets) do
		baseSet.favoriteSetID = nil;
		if baseSet.favorite then
			baseSet.favoriteSetID = baseSet.setID;
		else
			local variantSets = self:GetVariantSets(baseSet.setID);
			for _indexVariantSet, variantSet in ipairs(variantSets) do
				if variantSet.favorite then
					baseSet.favoriteSetID = variantSet.setID;
					break;
				end
			end
		end
	end
end

function MCUDR_WardrobeSetsDataProviderMixin:RefreshFavorites()
	self.baseSets = nil;
	self.variantSets = nil;
	self:DetermineFavorites();
end
