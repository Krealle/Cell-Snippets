-- Anchor debuff tooltip to debuff icon
local F = Cell.funcs
---@type TooltipAnchor
local ANCHOR = "ANCHOR_BOTTOMRIGHT"
-- "ANCHOR_TOP" |"ANCHOR_RIGHT" |"ANCHOR_BOTTOM" |"ANCHOR_LEFT" |"ANCHOR_TOPRIGHT" |
-- "ANCHOR_BOTTOMRIGHT" |"ANCHOR_TOPLEFT" |"ANCHOR_BOTTOMLEFT" |"ANCHOR_CURSOR" |
-- "ANCHOR_CURSOR_RIGHT" |"ANCHOR_PRESERVE" |"ANCHOR_NONE"

local function Debuffs_ShowTooltip(debuffs, show)
    debuffs.showTooltip = show

    for i = 1, 10 do
        if show then
            debuffs[i]:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(debuffs[i], ANCHOR)
                GameTooltip:SetUnitAura(debuffs.parent.states.displayedUnit, self.index, "HARMFUL")
            end)

            debuffs[i]:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        else
            debuffs[i]:SetScript("OnEnter", nil)
            debuffs[i]:SetScript("OnLeave", nil)
            if not debuffs.enableBlacklistShortcut then debuffs[i]:EnableMouse(false) end
        end
    end
end

F:IterateAllUnitButtons(function(b)
    b.indicators.debuffs.ShowTooltip = Debuffs_ShowTooltip
end)
