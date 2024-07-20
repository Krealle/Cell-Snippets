-- Anchor debuff tooltip to debuff icon
local F = Cell.funcs
---@type TooltipAnchor
local ANCHOR = "ANCHOR_BOTTOMRIGHT"
-- "ANCHOR_TOP" |"ANCHOR_RIGHT" |"ANCHOR_BOTTOM" |"ANCHOR_LEFT" |"ANCHOR_TOPRIGHT" |
-- "ANCHOR_BOTTOMRIGHT" |"ANCHOR_TOPLEFT" |"ANCHOR_BOTTOMLEFT" |"ANCHOR_CURSOR" |
-- "ANCHOR_CURSOR_RIGHT" | "ANCHOR_CURSOR_LEFT" |"ANCHOR_PRESERVE" |"ANCHOR_NONE"

local function hasDebuffIndicator(frame, aura)
    return (frame and frame.indicators and frame.indicators.debuffs and frame.indicators.debuffs[aura])
end

local function isDebuff(type, filter)
    return (type and type == "spell" and filter and filter == "HARMFUL")
end

function F:ShowTooltips(anchor, tooltipType, unit, aura, filter)
    if not CellDB["general"]["enableTooltips"] or (tooltipType == "unit" and CellDB["general"]["hideTooltipsInCombat"] and InCombatLockdown()) then return end

    if isDebuff(tooltipType, filter) and hasDebuffIndicator(anchor, aura) then
        GameTooltip:SetOwner(anchor.indicators.debuffs[aura], ANCHOR)
    elseif CellDB["general"]["tooltipsPosition"][2] == "Default" then
        GameTooltip_SetDefaultAnchor(GameTooltip, anchor)
    elseif CellDB["general"]["tooltipsPosition"][2] == "Cell" then
        GameTooltip:SetOwner(Cell.frames.mainFrame, "ANCHOR_NONE")
        GameTooltip:SetPoint(CellDB["general"]["tooltipsPosition"][1], Cell.frames.mainFrame,
            CellDB["general"]["tooltipsPosition"][3], CellDB["general"]["tooltipsPosition"][4],
            CellDB["general"]["tooltipsPosition"][5])
    elseif CellDB["general"]["tooltipsPosition"][2] == "Unit Button" then
        GameTooltip:SetOwner(anchor, "ANCHOR_NONE")
        GameTooltip:SetPoint(CellDB["general"]["tooltipsPosition"][1], anchor, CellDB["general"]["tooltipsPosition"][3],
            CellDB["general"]["tooltipsPosition"][4], CellDB["general"]["tooltipsPosition"][5])
    elseif CellDB["general"]["tooltipsPosition"][2] == "Cursor" then
        GameTooltip:SetOwner(anchor, "ANCHOR_CURSOR")
    elseif CellDB["general"]["tooltipsPosition"][2] == "Cursor Left" then
        GameTooltip:SetOwner(anchor, "ANCHOR_CURSOR_LEFT", CellDB["general"]["tooltipsPosition"][4],
            CellDB["general"]["tooltipsPosition"][5])
    elseif CellDB["general"]["tooltipsPosition"][2] == "Cursor Right" then
        GameTooltip:SetOwner(anchor, "ANCHOR_CURSOR_RIGHT", CellDB["general"]["tooltipsPosition"][4],
            CellDB["general"]["tooltipsPosition"][5])
    end

    if tooltipType == "unit" then
        GameTooltip:SetUnit(unit)
    elseif tooltipType == "spell" and unit and aura then
        -- GameTooltip:SetSpellByID(aura)
        GameTooltip:SetUnitAura(unit, aura, filter)
    end
end
