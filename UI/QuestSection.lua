-- UI: the "Quests" section = header bar + stack of quest blocks.
local ADDON, NA = ...

local Section = {}
Section.__index = Section
NA.QuestSection = Section

local WIDTH = 260
local HEADER_H = 26
local BLOCK_X = 20
local BLOCK_GAP = 10

function Section.New(parent, onToggle)
    local self = setmetatable({}, Section)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(WIDTH, HEADER_H)
    self.frame = f
    self.blocks = {}

    local header = NA.Header.Create(f, {
        width = WIDTH, height = HEADER_H, label = "Quests",
        bg = "UI-QuestTracker-Secondary-Objective-Header", bgW = 300, bgH = 30,
        collapse = "UI-QuestTrackerButton-Secondary-Collapse",
        expand = "UI-QuestTrackerButton-Secondary-Expand",
        highlight = "UI-QuestTrackerButton-Yellow-Highlight",
        iconW = 16, iconH = 16, iconX = 1,
    })
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetScript("OnClick", function()
        NA.db.collapsedQuests = not NA.db.collapsedQuests
        if onToggle then onToggle() end
    end)
    self.header = header
    return self
end

function Section:HasItemButtons()
    for _, b in ipairs(self.blocks) do
        if b.frame:IsShown() and b.hasItem then return true end
    end
    return false
end

-- Lays out all quests. width = the list width. counts = small grey line under the header
-- next to the "Quests" title ("Active: 14   Shown: 5"), nil = none. Returns the total height used by the section.
function Section:Refresh(quests, emptyText, width, counts)
    width = width or WIDTH
    local blockW = width - BLOCK_X
    self.frame:SetWidth(width)
    self.header:SetWidthTo(width)
    local fsz = NA.ListLayout.FontSize()
    self.header:SetFontSize(fsz + 2)
    local collapsed = NA.db.collapsedQuests
    self.header:SetCollapsed(collapsed)

    local y = -HEADER_H
    local used = 0
    -- the counts sit on the header line, a small gap after "Quests"
    if counts then
        if not self.counts then
            local fs = self.header:CreateFontString(nil, "OVERLAY")
            fs:SetShadowOffset(1, -1)
            fs:SetShadowColor(0, 0, 0, 1)
            fs:SetTextColor(0.65, 0.65, 0.65)
            fs:SetJustifyH("LEFT")
            self.counts = fs
        end
        local t = self.header.text
        self.counts:SetFont("Fonts\\FRIZQT__.TTF", math.max(fsz - 2, 8), "")
        self.counts:ClearAllPoints()
        self.counts:SetPoint("LEFT", t, "LEFT", (t:GetStringWidth() or 0) + 8, -1)
        self.counts:SetText(counts)
        self.counts:Show()
    elseif self.counts then
        self.counts:Hide()
    end
    if self.empty then self.empty:Hide() end
    if not collapsed then
        y = y - BLOCK_GAP
        if #quests == 0 and emptyText then
            if not self.empty then
                local fs = self.frame:CreateFontString(nil, "OVERLAY")
                fs:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
                fs:SetShadowOffset(1, -1)
                fs:SetShadowColor(0, 0, 0, 1)
                fs:SetTextColor(0.6, 0.6, 0.6)
                fs:SetJustifyH("LEFT")
                self.empty = fs
            end
            self.empty:SetFont("Fonts\\FRIZQT__.TTF", fsz, "")
            self.empty:ClearAllPoints()
            self.empty:SetPoint("TOPLEFT", self.frame, "TOPLEFT", BLOCK_X, y)
            self.empty:SetText(emptyText)
            self.empty:Show()
            y = y - 12 - BLOCK_GAP
        end
        for i, q in ipairs(quests) do
            local block = self.blocks[i]
            if not block then
                block = NA.QuestBlock.New(self.frame)
                self.blocks[i] = block
            end
            block:SetData(q, blockW)
            block.frame:ClearAllPoints()
            block.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", BLOCK_X, y)
            block.frame:Show()
            y = y - block.height - BLOCK_GAP
            used = i
        end
    end
    for i = used + 1, #self.blocks do self.blocks[i].frame:Hide() end

    local height = -y
    self.frame:SetHeight(height)
    return height
end
