-- Filter "Most XP": shows only the 5 quests that give the most experience, whatever the zone or the
-- distance; same XP = the nearest first. Quests ready to turn in are left out.
-- It is in the "scope" group with Zone and Dist (only one of the three at a time). It lets every
-- quest through the filters itself; the cut to 5 is made by UI/Tracker.lua after the distance sort
-- (XPFilter.Apply), so ties keep the nearest-first order. Class quests and your own focus are still
-- put on top by the tracker and don't count in the 5. Inside a dungeon its own rule wins.
local ADDON, NA = ...

local XF = { id = "xp", label = "XP", default = false, group = "scope" }
NA.XPFilter = XF

XF.COUNT = 5

function XF.IsOn() return NA.Filters.IsEnabled(XF) end

function XF.Prepare() return {} end
function XF.Test() return true end

-- visible: the list after the filters and the distance sort. Returns the 5 with the most XP.
function XF.Apply(visible)
    if not XF.IsOn() then return visible end
    local R = NA.QuestRewards
    local open = {}
    for i, q in ipairs(visible) do
        if not q.isComplete then
            open[#open + 1] = { q = q, xp = (R and R.XP(q.questID)) or 0, pos = i }
        end
    end
    table.sort(open, function(a, b)
        if a.xp ~= b.xp then return a.xp > b.xp end
        return a.pos < b.pos -- same XP: keep the distance order (nearest first)
    end)
    local out = {}
    for i = 1, math.min(XF.COUNT, #open) do out[i] = open[i].q end
    return out
end

NA.Filters.Register(XF)
