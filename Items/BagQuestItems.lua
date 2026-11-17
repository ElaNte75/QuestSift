-- Bags: marks quest items in your bags.
--   useful (default green tick)  = a quest you have now needs it (the tooltip says which one)
--   orphan (default orange "?")  = a quest item that no quest in your log mentions (likely left over from a dropped quest)
-- Picture, colour and size are set on the Bags options page. The pictures are our own white shapes
-- (Media/Marks/*.tga, made by _tools/make_marks.py) so any colour comes out clean.
-- Items that START a quest get no mark (the game already shows its own "!"), only a tooltip line.
-- Any bag window works (see "finding the bag squares").
-- It never deletes anything. Setting: bagMarks (on).
local ADDON, NA = ...

local BQ = {}
NA.BagQuestItems = BQ

local QUEST_CLASS = 12 -- item class "Quest"
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Marks\\"
-- the 4 corners of the square (other add-ons may already put their own mark in one of them)
-- (old saved values "LEFT" / "RIGHT" = the top corners)
BQ.SIDES = {
    { key = "LEFT", label = "Top left", point = "TOPLEFT", x = -2, y = 2 },
    { key = "RIGHT", label = "Top right", point = "TOPRIGHT", x = 2, y = 2 },
    { key = "BOTTOMLEFT", label = "Bottom left", point = "BOTTOMLEFT", x = -2, y = -2 },
    { key = "BOTTOMRIGHT", label = "Bottom right", point = "BOTTOMRIGHT", x = 2, y = -2 },
}
BQ.STYLES = {
    { key = "Tick", label = "Tick" }, { key = "Cross", label = "Cross" },
    { key = "Question", label = "Question mark" }, { key = "Exclaim", label = "Exclamation mark" },
    { key = "Star", label = "Star" }, { key = "Dot", label = "Dot" }, { key = "Diamond", label = "Diamond" },
}
BQ.COLORS = {
    { key = "Green", label = "Green", rgb = { 0.25, 1, 0.25 } },
    { key = "Yellow", label = "Yellow", rgb = { 1, 1, 0.15 } },
    { key = "Gold", label = "Gold", rgb = { 1, 0.82, 0.3 } },
    { key = "Orange", label = "Orange", rgb = { 1, 0.5, 0 } },
    { key = "Red", label = "Red", rgb = { 1, 0.2, 0.2 } },
    { key = "Blue", label = "Blue", rgb = { 0.3, 0.65, 1 } },
    { key = "Purple", label = "Purple", rgb = { 0.8, 0.45, 1 } },
    { key = "White", label = "White", rgb = { 1, 1, 1 } },
}
BQ.MIN_SIZE, BQ.MAX_SIZE = 12, 32
local DEFAULT = { useful = { style = "Tick", color = "Green" }, orphan = { style = "Question", color = "Orange" } }
local DB_KEY = { useful = "bagUseful", orphan = "bagOrphan" } -- + "Style" / "Color"

local function find(list, key)
    for _, e in ipairs(list) do if e.key == key then return e end end
end
function BQ.Style(kind)
    local v = NA.db and NA.db[DB_KEY[kind] .. "Style"]
    return find(BQ.STYLES, v) and v or DEFAULT[kind].style
end
function BQ.Color(kind)
    local v = NA.db and NA.db[DB_KEY[kind] .. "Color"]
    return find(BQ.COLORS, v) and v or DEFAULT[kind].color
end
function BQ.Size()
    local v = tonumber(NA.db and NA.db.bagMarkSize) or 20
    return math.min(math.max(v, BQ.MIN_SIZE), BQ.MAX_SIZE)
end

function BQ.IsOn() return NA.db and NA.db.bagMarks ~= false end
function BQ.Side()
    local v = NA.db and NA.db.bagMarkSide
    for _, e in ipairs(BQ.SIDES) do if e.key == v then return v end end
    return "LEFT"
end

-- ---------------------------------------------------------------- the quests you have
local byID, byName, objTexts = {}, {}, {}
local questsDirty = true

local function addTo(map, key, title)
    if not key or not title then return end
    local t = map[key]
    if not t then t = {}; map[key] = t end
    for _, v in ipairs(t) do if v == title then return end end
    t[#t + 1] = title
end

-- "0/5 Broken Tools" / "Broken Tools: 3/8" -> "broken tools"
local function objectiveName(text)
    if type(text) ~= "string" then return nil end
    local s = text:gsub("^%s*%d+%s*/%s*%d+%s*", ""):gsub("%s*:?%s*%d+%s*/%s*%d+%s*$", "")
    s = s:gsub("%s+$", "")
    if s == "" then return nil end
    return s:lower()
end

local function rebuildQuests()
    questsDirty = false
    wipe(byID); wipe(byName); wipe(objTexts)
    local QL = C_QuestLog
    if not (QL and QL.GetNumQuestLogEntries and QL.GetInfo) then return end
    local n = QL.GetNumQuestLogEntries() or 0
    for i = 1, n do
        local info = QL.GetInfo(i)
        if info and not info.isHeader and info.questID and info.title then
            local title = info.title
            if type(GetQuestLogSpecialItemInfo) == "function" then
                local ok, link = pcall(GetQuestLogSpecialItemInfo, i)
                local id = ok and link and tonumber(tostring(link):match("item:(%d+)"))
                if id then addTo(byID, id, title) end
                local name = ok and link and tostring(link):match("%[(.-)%]")
                if name then addTo(byName, name:lower(), title) end
            end
            local objs = QL.GetQuestObjectives and QL.GetQuestObjectives(info.questID)
            for _, o in ipairs(objs or {}) do
                if o.text then
                    if o.type == "item" then addTo(byName, objectiveName(o.text), title) end
                    objTexts[#objTexts + 1] = { text = o.text:lower(), title = title }
                end
            end
        end
    end
end

-- ---------------------------------------------------------------- what an item is
local function itemClass(itemID)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not f or not itemID then return nil end
    local ok, _, _, _, _, _, classID = pcall(f, itemID)
    return ok and classID or nil
end

-- status of the items seen in the bags (keeps "starts a quest", which only the bag slot can tell)
local lastSeen = {}

-- returns kind ("useful" / "orphan" / "starter" / nil), list of quest titles
local function classify(itemID, name, qinfo)
    if questsDirty then rebuildQuests() end
    -- a NEW list every time (adding to the stored lists made them grow on every refresh:
    -- the tooltip repeated the quest name dozens of times - user report 2026-11-16)
    local titles = {}
    local function add(list) for _, t in ipairs(list or {}) do addTo({ x = titles }, "x", t) end end
    add(itemID and byID[itemID])
    local lname = name and name:lower()
    if #titles == 0 and lname then add(byName[lname]) end
    if #titles == 0 and lname and #lname >= 4 then
        for _, o in ipairs(objTexts) do
            if o.text:find(lname, 1, true) then add({ o.title }) end
        end
    end
    if qinfo and qinfo.questID and qinfo.isActive then
        local t = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(qinfo.questID)
        if t then add({ t }) end
    end
    if #titles > 0 then return "useful", titles end
    if qinfo and qinfo.questID and not qinfo.isActive then return "starter" end
    if (qinfo and qinfo.isQuestItem) or itemClass(itemID) == QUEST_CLASS then return "orphan" end
    return nil
end

-- what a bag slot holds: itemID, name, quest info {isQuestItem, questID, isActive}, picture
-- (newer games: C_Container.*; older ones: the plain GetContainerItemInfo / GetContainerItemQuestInfo)
local function slotInfo(bag, slot)
    local C = C_Container
    local itemID, link, icon, qinfo
    if C and C.GetContainerItemInfo then
        local info = C.GetContainerItemInfo(bag, slot)
        if info then itemID, link, icon = info.itemID, info.hyperlink, info.iconFileID end
    elseif GetContainerItemInfo then
        local tex, _, _, _, _, _, l, _, _, id = GetContainerItemInfo(bag, slot)
        icon, link, itemID = tex, l, id or (l and tonumber(l:match("item:(%d+)")))
    end
    if not itemID then return nil end
    if C and C.GetContainerItemQuestInfo then
        qinfo = C.GetContainerItemQuestInfo(bag, slot)
    elseif GetContainerItemQuestInfo then
        local isQ, qid, active = GetContainerItemQuestInfo(bag, slot)
        qinfo = { isQuestItem = isQ, questID = qid, isActive = active }
    end
    local name = link and link:match("%[(.-)%]")
    return itemID, name, qinfo, icon
end

local marks = setmetatable({}, { __mode = "k" }) -- bag button -> our mark texture
-- a mark = dark round backing + the picture + the same picture again, added on top (brighter)
local function markOf(btn)
    local m = marks[btn]
    if not m then
        m = {}
        m.shadow = btn:CreateTexture(nil, "OVERLAY", nil, 5)
        m.shadow:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        m.shadow:SetVertexColor(0, 0, 0, 0.8)
        m.icon = btn:CreateTexture(nil, "OVERLAY", nil, 6)
        m.glow = btn:CreateTexture(nil, "OVERLAY", nil, 7)
        m.glow:SetBlendMode("ADD")
        m.glow:SetAlpha(0.35)
        m.glow:SetAllPoints(m.icon)
        m.shadow:SetPoint("CENTER", m.icon, "CENTER")
        marks[btn] = m
    end
    return m
end

local function hideMark(btn)
    local m = marks[btn]
    if m then m.shadow:Hide(); m.icon:Hide(); m.glow:Hide() end
end

local function showMark(btn, kind)
    local m = markOf(btn)
    local size = BQ.Size()
    m.icon:SetSize(size, size)
    m.shadow:SetSize(size, size)
    m.icon:ClearAllPoints()
    local corner = find(BQ.SIDES, BQ.Side())
    m.icon:SetPoint(corner.point, btn, corner.point, corner.x, corner.y)
    local c = find(BQ.COLORS, BQ.Color(kind)).rgb
    local pic = MEDIA .. BQ.Style(kind)
    for _, t in ipairs({ m.icon, m.glow }) do
        t:SetTexture(pic)
        t:SetVertexColor(c[1], c[2], c[3])
        t:Show()
    end
    m.shadow:Show()
end

local function paint(btn, itemID, name, qinfo)
    local kind, titles = classify(itemID, name, qinfo)
    lastSeen[itemID] = kind and { kind = kind, titles = titles } or nil
    if kind == "useful" or kind == "orphan" then
        showMark(btn, kind)
    else
        hideMark(btn)
    end
end

-- ---------------------------------------------------------------- finding the bag squares
-- Works with ANY bag window (the game's separate or combined bags, Bagnon, Baganator, ElvUI...):
-- we look at every item square on screen, ask it which bag and slot it shows (each window keeps
-- that in its own way, so we try the usual ways), and accept the answer only when the bag slot
-- really holds the item whose picture the square shows. No guessing about any one bag add-on.
local function call(obj, key)
    local v = obj[key]
    if type(v) == "function" then
        local ok, r = pcall(v, obj)
        if ok then return r end
        return nil
    end
    return v
end

local function asNum(v) return type(v) == "number" and v or nil end

local function bagCandidates(btn)
    local list = {}
    for _, k in ipairs({ "GetBagID", "GetBag", "bagID", "bagId", "bag", "BagID" }) do
        local v = asNum(call(btn, k)); if v then list[#list + 1] = v end
    end
    local p = btn.GetParent and btn:GetParent()
    if p then
        for _, k in ipairs({ "GetBagID", "bagID", "bag", "GetID" }) do
            local v = asNum(call(p, k)); if v then list[#list + 1] = v end
        end
    end
    return list
end

local function slotCandidates(btn)
    local list = {}
    for _, k in ipairs({ "slotID", "slotId", "slot", "GetSlotID", "GetID" }) do
        local v = asNum(call(btn, k)); if v and v > 0 then list[#list + 1] = v end
    end
    return list
end

local function shownPicture(btn)
    for _, k in ipairs({ "icon", "Icon", "IconTexture", "iconTexture" }) do
        local r = btn[k]
        if type(r) == "table" and r.GetTexture then return r:GetTexture() end
    end
    local n = btn.GetName and btn:GetName()
    local r = n and _G[n .. "IconTexture"]
    if type(r) == "table" and r.GetTexture then return r:GetTexture() end
    return nil
end

-- the item a square shows: itemID, name, quest info (nil = not a bag square / empty slot)
local function squareItem(btn)
    local pic = shownPicture(btn)
    if not pic then return nil end
    for _, bag in ipairs(bagCandidates(btn)) do
        for _, slot in ipairs(slotCandidates(btn)) do
            local itemID, name, qinfo, icon = slotInfo(bag, slot)
            if itemID and icon and (icon == pic or tostring(icon) == tostring(pic)) then
                return itemID, name, qinfo
            end
        end
    end
    return nil
end

local known = setmetatable({}, { __mode = "k" }) -- buttons that could be item squares
local STEP = 15000   -- frames looked at per pass (the game can have tens of thousands)
local cursor, scanned = nil, 0

-- a button with a picture and a bag + slot number (visible or not: bags open and close)
local function isCandidate(f)
    if f.IsForbidden and f:IsForbidden() then return false end
    local t = f.GetObjectType and f:GetObjectType()
    if t ~= "Button" and t ~= "ItemButton" and t ~= "CheckButton" then return false end
    if not shownPicture(f) then return false end
    return #bagCandidates(f) > 0 and #slotCandidates(f) > 0
end

-- Frames are listed in the order they were made, and new ones (a bag add-on's squares made when
-- you open your bags) come last. So we keep our place: the first passes look at everything, after
-- that only at frames made since the last look.
function BQ.Discover()
    if not EnumerateFrames then return end
    local f
    if cursor then f = EnumerateFrames(cursor) else f = EnumerateFrames() end
    local n = 0
    while f and n < STEP do
        n = n + 1
        local ok, yes = pcall(isCandidate, f)
        if ok and yes then known[f] = true end
        cursor = f
        f = EnumerateFrames(f)
    end
    scanned = scanned + n
end

local lastSummary
function BQ.Refresh()
    BQ.Discover()
    local on = BQ.IsOn()
    local nKnown, items = 0, {}
    for btn in pairs(known) do
        nKnown = nKnown + 1
        local ok, vis = pcall(btn.IsVisible, btn)
        if on and ok and vis then
            local ok2, itemID, name, qinfo = pcall(squareItem, btn)
            if ok2 and itemID and not (InCombatLockdown() and not marks[btn] and btn.IsProtected and btn:IsProtected()) then
                paint(btn, itemID, name, qinfo)
                local seen = lastSeen[itemID]
                items[#items + 1] = tostring(name) .. "=" .. (seen and seen.kind or "-")
            else
                hideMark(btn)
            end
        else
            hideMark(btn)
        end
    end
    local summary = "frames looked at=" .. scanned .. " candidates=" .. nKnown .. " | " .. table.concat(items, ", ")
    if #items > 0 and summary:gsub("frames looked at=%d+ ", "") ~= lastSummary then
        lastSummary = summary:gsub("frames looked at=%d+ ", "")
        NA.Debug("bag marks", summary)
    elseif not lastSummary then
        lastSummary = ""; NA.Debug("bag marks", summary)
    end
end

-- many bag/quest events come in bursts: one refresh shortly after
local pending = false
function BQ.Queue()
    if pending then return end
    pending = true
    C_Timer.After(0.6, function() NA.SafeCall(BQ.Refresh) end) -- bag add-ons may draw a moment later
    C_Timer.After(0.1, function()
        pending = false
        NA.SafeCall(BQ.Refresh)
    end)
end

-- ---------------------------------------------------------------- tooltip line
local function tooltipLine(tt, itemID, name)
    if not BQ.IsOn() or not itemID then return end
    local kind, titles = classify(itemID, name, nil)
    -- the bag scan knows more (quest starters, items the game ties to a quest by its ID)
    local seen = lastSeen[itemID]
    if seen and (seen.kind == "starter" or (seen.kind == "useful" and kind ~= "useful")) then
        kind, titles = seen.kind, seen.titles
    end
    -- "QuestSift:" in the add-on's gold (follows the look preset), then the message
    local g = (NA.Widgets and NA.Widgets.colors and NA.Widgets.colors.gold) or { 1, 0.82, 0.3 }
    local prefix = string.format("|cff%02x%02x%02xQuestSift:|r ", math.floor(g[1] * 255 + 0.5), math.floor(g[2] * 255 + 0.5), math.floor(g[3] * 255 + 0.5))
    if kind == "useful" and titles then
        local which = #titles > 1 and "the quests: " or "the quest: "
        tt:AddLine(prefix .. "This item is needed for " .. which .. "|cffffffff" .. table.concat(titles, ", ") .. "|r", 0.3, 1, 0.3, true)
    elseif kind == "orphan" then
        tt:AddLine(prefix .. "No quest in your log needs this item. It is probably left over from a quest you dropped.", 1, 0.6, 0.2, true)
    elseif kind == "starter" then
        tt:AddLine(prefix .. "This item starts a quest you don't have yet.", 1, 0.82, 0, true)
    end
end

local function hookTooltip()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
            if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
            NA.SafeCall(function()
                local name, link = tt:GetItem()
                local id = (data and data.id) or (link and tonumber(link:match("item:(%d+)")))
                tooltipLine(tt, id, name)
            end)
        end)
    elseif GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetItem", function(tt)
            NA.SafeCall(function()
                local name, link = tt:GetItem()
                tooltipLine(tt, link and tonumber(link:match("item:(%d+)")), name)
            end)
        end)
    end
end

-- ---------------------------------------------------------------- start
NA.OnInit(function()
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "BAG_UPDATE_DELAYED", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED",
                         "QUEST_TURNED_IN", "GET_ITEM_INFO_RECEIVED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", function(_, e)
        if e ~= "BAG_UPDATE_DELAYED" and e ~= "GET_ITEM_INFO_RECEIVED" then questsDirty = true; wipe(lastSeen) end
        BQ.Queue()
    end)
    -- the game's bag windows and the usual "open bags" calls (bag add-ons answer these too)
    for i = 1, 13 do
        local f = _G["ContainerFrame" .. i]
        if f then f:HookScript("OnShow", BQ.Queue) end
    end
    if ContainerFrameCombinedBags then ContainerFrameCombinedBags:HookScript("OnShow", BQ.Queue) end
    for _, fn in ipairs({ "ToggleAllBags", "OpenAllBags", "ToggleBackpack", "OpenBackpack", "ToggleBag", "OpenBag" }) do
        if type(_G[fn]) == "function" then hooksecurefunc(fn, BQ.Queue) end
    end
    -- bag add-ons draw in their own time and may open in their own way: look again now and then
    C_Timer.NewTicker(1.5, function()
        if BQ.IsOn() then NA.SafeCall(BQ.Refresh) end
    end)
    hookTooltip()
    NA.Debug("bag marks", "api: C_Container.GetContainerItemInfo=" .. tostring(C_Container and C_Container.GetContainerItemInfo ~= nil),
        "GetContainerItemInfo=" .. tostring(GetContainerItemInfo ~= nil), "EnumerateFrames=" .. tostring(EnumerateFrames ~= nil))
end)

-- for the options page: turn on/off and repaint at once
function BQ.Set(v)
    NA.db.bagMarks = v
    BQ.Refresh()
end
