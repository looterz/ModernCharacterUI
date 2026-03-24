local addonName, ns = ...

local frame = ns.frame
local modelBg = ns.modelBg

local model = CreateFrame("DressUpModel", "ModernCharacterUIModel", frame)
model:SetPoint("TOPLEFT", modelBg, "TOPLEFT")
model:SetPoint("BOTTOMRIGHT", modelBg, "BOTTOMRIGHT")
model:SetFrameLevel(frame:GetFrameLevel() + 1)
ns.model = model

local DEFAULT_CAM_DISTANCE = 1.15
local DEFAULT_FACING = 0
local ZOOM_INCREMENT = 0.05
local ROTATE_INCREMENT = 0.15  -- radians per button click
local MIN_CAM_DISTANCE = 0.5
local MAX_CAM_DISTANCE = 2.0

local function ResetModel()
    model:SetUnit("player")
    model:SetPortraitZoom(0)
    model:SetCamDistanceScale(DEFAULT_CAM_DISTANCE)
    model:SetFacing(DEFAULT_FACING)
    model:SetSheathed(true)
    model.camDistance = DEFAULT_CAM_DISTANCE
    model.facing     = DEFAULT_FACING
    model.sheathed   = true
end

local function ZoomBy(delta)
    -- Negative delta = zoom in (decrease distance), positive = zoom out
    local dist = model.camDistance or DEFAULT_CAM_DISTANCE
    dist = max(MIN_CAM_DISTANCE, min(MAX_CAM_DISTANCE, dist - delta))
    model.camDistance = dist
    model:SetCamDistanceScale(dist)
end

local function RotateBy(delta)
    model.facing = (model.facing or 0) + delta
    model:SetFacing(model.facing)
end

model:EnableMouse(true)
model:EnableMouseWheel(true)

model:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        self.isDragging = true
        self.prevX = GetCursorPosition()
    elseif button == "RightButton" then
        ResetModel()
    end
end)

model:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
        self.isDragging = false
    end
end)

model:SetScript("OnUpdate", function(self)
    if self.isDragging then
        local x = GetCursorPosition()
        local delta = (x - (self.prevX or x)) * 0.01
        self.prevX = x
        self.facing = (self.facing or 0) + delta
        self:SetFacing(self.facing)
    end
end)

model:SetScript("OnMouseWheel", function(self, delta)
    ZoomBy(delta * ZOOM_INCREMENT)
end)

model:EnableKeyboard(true)
model:SetPropagateKeyboardInput(true)

model:SetScript("OnKeyDown", function(self, key)
    if key == "Z" then
        self:SetPropagateKeyboardInput(false)
        self.sheathed = not self.sheathed
        self:SetSheathed(self.sheathed)
    else
        self:SetPropagateKeyboardInput(true)
    end
end)

local BUTTON_SIZE = 32
local BUTTON_PAD  = -6

local controlBar = CreateFrame("Frame", nil, frame)
ns.controlBar = controlBar
controlBar:SetFrameLevel(model:GetFrameLevel() + 5)
controlBar:SetSize(5 * BUTTON_SIZE + 4 * BUTTON_PAD, BUTTON_SIZE)
controlBar:SetPoint("TOP", modelBg, "TOP", 0, -18)
controlBar:SetAlpha(0.5)

controlBar:EnableMouse(true)
controlBar:SetScript("OnEnter", function(self) self:SetAlpha(1.0) end)
controlBar:SetScript("OnLeave", function(self) self:SetAlpha(0.5) end)

--- Factory for a single camera-control button.
local function CreateControlButton(parent, index, atlasIcon, tooltipTitle,
                                    tooltipBody, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    btn:SetHitRectInsets(4, 4, 4, 4)

    local x = (index - 1) * (BUTTON_SIZE + BUTTON_PAD)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, 0)

    local normal = btn:CreateTexture(nil, "ARTWORK")
    normal:SetAllPoints()
    normal:SetAtlas("common-button-square-gray-up")
    btn:SetNormalTexture(normal)

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetAtlas("common-button-square-gray-up")
    highlight:SetAlpha(0.4)
    btn:SetHighlightTexture(highlight)

    local pushed = btn:CreateTexture(nil, "ARTWORK")
    pushed:SetAllPoints()
    pushed:SetAtlas("common-button-square-gray-down")
    btn:SetPushedTexture(pushed)

    local icon = btn:CreateTexture(nil, "OVERLAY")
    icon:SetSize(16, 16)
    icon:SetPoint("CENTER")
    icon:SetAtlas(atlasIcon)
    btn.icon = icon

    btn:SetScript("OnEnter", function(self)
        controlBar:SetAlpha(1.0)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltipTitle, HIGHLIGHT_FONT_COLOR.r,
                            HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
        if tooltipBody then
            GameTooltip:AddLine(tooltipBody, NORMAL_FONT_COLOR.r,
                                NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        controlBar:SetAlpha(0.5)
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        onClick()
    end)

    return btn
end

CreateControlButton(controlBar, 1, "common-icon-rotateleft",
    ROTATE_LEFT  or "Rotate Left",  ROTATE_TOOLTIP or "Click to rotate",
    function() RotateBy(ROTATE_INCREMENT) end)

CreateControlButton(controlBar, 2, "common-icon-zoomout",
    ZOOM_OUT     or "Zoom Out",     KEY_MOUSEWHEELDOWN or "Mouse Wheel Down",
    function() ZoomBy(-ZOOM_INCREMENT) end)

CreateControlButton(controlBar, 3, "common-icon-undo",
    RESET_POSITION or "Reset",      nil,
    function() ResetModel() end)

CreateControlButton(controlBar, 4, "common-icon-zoomin",
    ZOOM_IN      or "Zoom In",      KEY_MOUSEWHEELUP or "Mouse Wheel Up",
    function() ZoomBy(ZOOM_INCREMENT) end)

CreateControlButton(controlBar, 5, "common-icon-rotateright",
    ROTATE_RIGHT or "Rotate Right", ROTATE_TOOLTIP or "Click to rotate",
    function() RotateBy(-ROTATE_INCREMENT) end)

function ns:UpdateModel()
    ResetModel()
end
