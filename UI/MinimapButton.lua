-- UI: a QuestSift button on the edge of the minimap (click: open / close the options window,
-- drag: move it around the minimap). QuestSift is always in the game's add-on menu next to the
-- minimap, so this button is OFF by default; the tick box on the Interface options page shows it.
-- Settings: minimapButton (false), minimapButtonAngle (degrees, nil = default).
local ADDON, NA = ...

local MB = {}
NA.MinimapButton = MB

local ICON = "Interface\\AddOns\\QuestSift\\Media\\icon.tga"
local DEFAULT_ANGLE = 210 -- degrees: lower left of the minimap

local button

function MB.IsOn()
    return NA.db and NA.db.minimapButton == true
end

-- puts the button on the edge of the minimap, at its saved angle
local function Place()
    if not button or not Minimap then return end
    local angle = math.rad((NA.db and NA.db.minimapButtonAngle) or DEFAULT_ANGLE)
    local x, y = math.cos(angle), math.sin(angle)
    local half = (Minimap:GetWidth() or 140) / 2 + 5
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then -- a square minimap: the edge is the square, not the circle
        local s = math.max(math.abs(x), math.abs(y))
        x, y = x / s, y / s
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x * half, y * half)
end

local function ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine("QuestSift", 1, 0.82, 0)
    GameTooltip:AddLine("Click: open or close the options.", 1, 1, 1, true)
    GameTooltip:AddLine("Drag: move this button around the minimap.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end

local function Create()
    if button or not Minimap then return end
    button = CreateFrame("Button", "QuestSiftMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(22, 22)
    background:SetPoint("CENTER", 0, 0)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER", 0, 0)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", 0, 0)

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnClick", function()
        if NA.Options and NA.Options.Toggle then NA.Options.Toggle() end
    end)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- dragging: the button follows the mouse around the minimap (only its angle is kept)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            if not (mx and my and cx and cy and scale and scale ~= 0) then return end
            NA.db.minimapButtonAngle = math.deg((math.atan2 or math.atan)(cy / scale - my, cx / scale - mx)) % 360
            Place()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
end

-- shows or hides the button as the setting says
function MB.Update()
    if not MB.IsOn() then
        if button then button:Hide() end
        return
    end
    Create()
    if not button then return end
    Place()
    button:Show()
end

NA.OnInit(MB.Update)
