-- Quests: "Ready to turn in" mode - the yellow "?" button on the list title (UI/HeaderToggles.lua,
-- left of the book). User decision 2026-11-17:
--   * on: the list shows ONLY the quests ready to turn in (all of them, any zone), closest turn-in
--     first (also when "Nearest quest first" is off); every filter is switched off and remembered
--   * off (click it again): the filters come back exactly as they were
--   * changing any filter while it is on (title buttons or options) ends it first (filters come
--     back), then that change is made
--   * a quest you focus yourself still wins (on top, the arrow leads to it); otherwise auto focus
--     and the arrow lead to the closest turn-in, whatever the distance setting
--   * it stays on after /reload (turnInMode + the remembered filters turnInSaved)
-- Distances are known only for quests of the zone you are in: the others come after them.
local ADDON, NA = ...

local TI = {}
NA.TurnInMode = TI

function TI.IsOn()
    return NA.db and NA.db.turnInMode == true
end

local function state()
    NA.db.filters = NA.db.filters or {}
    return NA.db.filters
end

-- on: remember every filter as it is now, then switch them all off
function TI.Enter()
    if TI.IsOn() then return end
    local saved = {}
    for _, f in ipairs(NA.Filters.list) do
        saved[f.id] = NA.Filters.IsEnabled(f)
        state()[f.id] = false -- written directly: Filters.SetEnabled would end this mode
    end
    NA.db.turnInSaved = saved
    NA.db.turnInMode = true
end

-- off: the filters come back as they were before
function TI.Exit()
    if not TI.IsOn() then return end
    NA.db.turnInMode = false
    local saved = NA.db.turnInSaved
    if type(saved) == "table" then
        for _, f in ipairs(NA.Filters.list) do
            if saved[f.id] ~= nil then state()[f.id] = saved[f.id] and true or false end
        end
    end
    NA.db.turnInSaved = nil
end

function TI.Toggle()
    if TI.IsOn() then TI.Exit() else TI.Enter() end
end

-- only the quests ready to turn in, from all tracked quests
function TI.Filter(all)
    local out = {}
    for _, q in ipairs(all) do
        if q.isComplete then out[#out + 1] = q end
    end
    return out
end
