-- Options page "Bags": marks on the quest items in your bags (Items/BagQuestItems.lua).
local ADDON, NA = ...

NA.Options.AddPage("bags", "Bags", function(parent)
    local W = NA.Widgets
    local BQ = NA.BagQuestItems
    local st = W.Stack(parent)
    local refreshers = {}
    local function add(w) refreshers[#refreshers + 1] = w.Refresh; return w end
    local deps = {}
    local function refreshDeps()
        for _, r in ipairs(deps) do W.SetActive(r, BQ.IsOn()) end
    end

    st:Add(W.PageHeader(parent, "Bags", "Which quest items in your bags are still needed."), "header")

    st:Add(add(W.Checkbox(parent, "Mark quest items in the bags",
        "A mark on an item a quest in your log needs, another on a quest item no quest in your log mentions. Its tooltip says which quest it is for.",
        function() return BQ.IsOn() end,
        function(v) BQ.Set(v); refreshDeps() end)), "row")

    -- size and place (both kinds)
    st:Add(W.Section(parent, "Mark"), "section")
    local sizeRow = st:Add(W.Row(parent, "Size"), "row")
    add(sizeRow:SetControl(W.Slider(sizeRow, BQ.MIN_SIZE, BQ.MAX_SIZE, 1, " px",
        function() return BQ.Size() end,
        function(v) NA.db.bagMarkSize = v; BQ.Refresh() end,
        nil, { majorEvery = 4 })))
    deps[#deps + 1] = sizeRow
    local sideRow = st:Add(W.Row(parent, "Position"), "row")
    add(sideRow:SetControl(W.Dropdown(sideRow, BQ.SIDES,
        function() return BQ.Side() end,
        function(key) NA.db.bagMarkSide = key; BQ.Refresh() end)))
    deps[#deps + 1] = sideRow

    -- picture + colour for one kind of item
    local function kindSection(title, kind, prefix, note)
        st:Add(W.Section(parent, title), "section")
        local styleRow = st:Add(W.Row(parent, "Picture"), "row")
        add(styleRow:SetControl(W.Dropdown(styleRow, BQ.STYLES,
            function() return BQ.Style(kind) end,
            function(key) NA.db[prefix .. "Style"] = key; BQ.Refresh() end)))
        deps[#deps + 1] = styleRow
        local colorRow = st:Add(W.Row(parent, "Colour"), "row")
        add(colorRow:SetControl(W.Dropdown(colorRow, BQ.COLORS,
            function() return BQ.Color(kind) end,
            function(key) NA.db[prefix .. "Color"] = key; BQ.Refresh() end)))
        deps[#deps + 1] = colorRow
        st:Add(W.Note(parent, note), "note")
    end
    kindSection("Needed by a quest", "useful", "bagUseful",
        "A quest you have now needs it (the tooltip names the quest).")
    kindSection("Not needed by any quest", "orphan", "bagOrphan",
        "No quest in your log mentions it, most likely left over from a quest you dropped. Check it before you throw it away: a few quests don't name the item they use.")

    st:Add(W.Note(parent, "Items that start a quest keep the game's own \"!\" and get only a tooltip line. Works with the game's bags (separate or combined) and with bag add-ons."), "note")

    return function()
        for _, r in ipairs(refreshers) do r() end
        refreshDeps()
    end
end)
