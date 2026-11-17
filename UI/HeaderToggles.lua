-- UI: quick on/off buttons on the list title, left of the gear: Arrow, Distance, Zone, Dungeon, Most XP and,
-- last on the left, the yellow "?" = "ready to turn in" mode (Quests/TurnInMode.lua).
-- Same settings as the options window (the distance in yards comes from there); lit = on, dim = off.
local ADDON, NA = ...

local HT = {}
NA.HeaderToggles = HT

local SIZE = 16
local GAP = 4

local function filterById(id)
    for _, f in ipairs(NA.Filters.list) do
        if f.id == id then return f end
    end
end

local function afterChange()
    if NA.Tracker then NA.Tracker.RequestRefresh() end
    if NA.Arrow then NA.SafeCall(NA.Arrow.Update) end
    if NA.Options and NA.Options.RefreshCurrent then NA.SafeCall(NA.Options.RefreshCurrent) end
    HT.Refresh()
end

-- what each button shows and switches
local DEFS = {
    {
        key = "arrow",
        keepFolded = true, -- the arrow is not about the list: it doesn't open it
        icon = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\Arrow_Classic",
        tint = { 1, 0.82, 0 },
        isOn = function() return NA.Arrow ~= nil and NA.Arrow.IsOn() end,
        toggle = function() NA.db.arrowEnabled = not (NA.Arrow and NA.Arrow.IsOn()) end,
        tip = function(on) return "Arrow", on and "The arrow to the focused quest is shown. Click to hide it." or "The arrow is hidden. Click to show it." end,
    },
    {
        key = "distance",
        icon = "Interface\\Icons\\INV_Misc_Spyglass_03",
        crop = true,
        isOn = function() local f = filterById("distance"); return f ~= nil and NA.Filters.IsEnabled(f) end,
        toggle = function() local f = filterById("distance"); if f then NA.Filters.Toggle(f) end end,
        tip = function(on)
            local y = NA.db.distanceYards or 500
            return "Only quests near me", (on and "On" or "Off") .. string.format(": quests within %d yards. Click to turn it %s. The distance is set in the options. Turns the zone filter off.", y, on and "off" or "on")
        end,
    },
    {
        key = "zone",
        icon = "Interface\\Icons\\INV_Misc_Map_01",
        crop = true,
        isOn = function() local f = filterById("zone"); return f ~= nil and NA.Filters.IsEnabled(f) end,
        toggle = function() local f = filterById("zone"); if f then NA.Filters.Toggle(f) end end,
        tip = function(on)
            return "Only quests of this zone", (on and "On" or "Off") .. string.format(". Click to turn it %s. Turns the distance filter off.", on and "off" or "on")
        end,
    },
    {
        key = "dungeon",
        icon = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
        crop = true,
        isOn = function() local f = filterById("dungeon"); return f ~= nil and NA.Filters.IsEnabled(f) end,
        toggle = function() local f = filterById("dungeon"); if f then NA.Filters.Toggle(f) end end,
        tip = function(on)
            return "Hide dungeon quests", on and "On: dungeon quests are hidden while you are outside the dungeon. Click to show them." or "Off: dungeon quests are shown everywhere. Click to hide them outside dungeons."
        end,
    },
    {
        key = "xp",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        crop = true,
        isOn = function() local f = filterById("xp"); return f ~= nil and NA.Filters.IsEnabled(f) end,
        toggle = function() local f = filterById("xp"); if f then NA.Filters.Toggle(f) end end,
        tip = function(on)
            return "Most XP quests", (on and "On" or "Off") .. string.format(": only the 5 quests that give the most experience, wherever they are; same XP = nearest first; your own focus doesn't join it. Click to turn it %s. Turns the zone and distance filters off.", on and "off" or "on")
        end,
    },
    {
        key = "turnin",
        icon = "Interface\\GossipFrame\\ActiveQuestIcon",
        isOn = function() return NA.TurnInMode ~= nil and NA.TurnInMode.IsOn() end,
        toggle = function() if NA.TurnInMode then NA.TurnInMode.Toggle() end end,
        tip = function(on)
            if on then
                return "Ready to turn in", "On: only the quests ready to turn in, closest first (quests of other zones come last). Click to go back to your filters as they were."
            end
            return "Ready to turn in", "Off. Click to show only the quests ready to turn in, closest first. Your filters are switched off and come back when you click it again."
        end,
    },
}

HT.buttons = {}

local function paint(b)
    local on = b.def.isOn()
    local t = b.def.tint
    b.icon:SetDesaturated(not on)
    if t then
        if on then b.icon:SetVertexColor(t[1], t[2], t[3]) else b.icon:SetVertexColor(0.7, 0.7, 0.7) end
    end
    b.icon:SetAlpha(on and 1 or 0.4)
end

function HT.Refresh()
    for _, b in ipairs(HT.buttons) do paint(b) end
end

local function showTip(b)
    local title, text = b.def.tip(b.def.isOn())
    GameTooltip:SetOwner(b, "ANCHOR_LEFT")
    GameTooltip:SetText(title)
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
end

local function makeButton(header, def, xOffset)
    local b = CreateFrame("Button", nil, header)
    b:SetSize(SIZE, SIZE)
    b:SetPoint("RIGHT", header, "RIGHT", xOffset, 0)
    b:SetFrameLevel(header:GetFrameLevel() + 2)
    b.def = def

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(def.icon)
    if def.crop then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    b.icon = icon

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(def.icon)
    if def.crop then hl:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0.35)

    b:SetScript("OnMouseDown", function()
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", 1, -1)
    end)
    b:SetScript("OnMouseUp", function()
        icon:ClearAllPoints()
        icon:SetAllPoints()
    end)
    b:SetScript("OnClick", function(self)
        NA.SafeCall(def.toggle)
        -- a filter / the "?" clicked = you want to see the list: it opens, also when it was folded
        -- (by hand or in a city / on a flight) - user decision 2026-11-17
        if not def.keepFolded and NA.db.collapsedAll then
            NA.db.collapsedAll = false
            if NA.Quiet then NA.Quiet.ListToggledByHand() end
        end
        afterChange()
        if GameTooltip:IsOwned(self) then showTip(self) end
    end)
    b:SetScript("OnEnter", showTip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    HT.buttons[#HT.buttons + 1] = b
    paint(b)
    return b
end

-- room the buttons take on the title (so the title text can be made narrower)
HT.WIDTH = #DEFS * (SIZE + GAP)

-- header: the title button; startX: right edge of the first button (left of the gear)
function HT.Attach(header, startX)
    local x = startX
    for _, def in ipairs(DEFS) do
        makeButton(header, def, x)
        x = x - SIZE - GAP
    end
end

NA.OnInit(function()
    local T = NA.Tracker
    if not (T and T.header) then return end
    HT.Attach(T.header, -44)
    -- the options window can change the same settings: keep the buttons in step
    C_Timer.NewTicker(1, HT.Refresh)
end)
