--[[ Show or hide indicators based on talent option

"talentID" The ID of the talent that controls the indicator
"spec" The spec to run the check on - can use both name and ID
"indicator" The name of the indicator you want to control
    If the indicator doesn't exist in the layout, it will be ignored
"enabled" The state of the indicator you want when the talent is active
    The inverse state will be used when the talent is not active
"layout" Name of the layout you want this to apply to
    If no layout is provided, it will apply to all layouts

]]

-------------------------
-- SET YOUR OPTIONS HERE
-------------------------
---@type table<number, IndicatorTalentOption>
local IndicatorTalentOptions = {
    -- Example, Only show Prescience indicator when: 
    -- 1. The talent Prescience is active
    -- 2. Playing Augmentation
    -- 3. Using the the default layout 
    { talentID = 409311, spec = "Augmentation", indicator = "Prescience", enabled = true, layout = "default" },
}

-- functions
local F = Cell.funcs
local isValidOption, updateCurrentLayoutOptions, updateIndicators, maybeOption, Print, DevAdd
-- vars
local curLayout = Cell.vars.currentLayout
local ValidTalentOptions = {}
local layoutChanged, init
local debug = false

---@param opt IndicatorTalentOption
---@param idx number
---@return boolean
isValidOption = function(opt, idx)
    if not opt then return false end

    if not opt["talentID"] or type(opt["talentID"]) ~= "number" then
        Print("Missing talentID for indicator #" .. idx, true)
        return false
    end
    if not opt["spec"] or (type(opt["spec"]) ~= "string" and type(opt["spec"]) ~= "number") then
        Print("Missing spec for indicator #" .. idx, true)
        return false
    end
    if not opt["indicator"] or type(opt["indicator"]) ~= "string" then
        Print("Missing indicator for indicator #" .. idx, true)
        return false
    end
    if opt["enabled"] == nil or type(opt["enabled"]) ~= "boolean" then
        Print("Missing enabled for indicator #" .. idx, true)
        return false
    end
    if type(opt["layout"]) ~= "string" then
        Print("Invalid layout for indicator #" .. idx, true)
    end

    return true
end

---@param opt IndicatorTalentOption
---@param curSpecID number
---@param curSpecName string
---@param idx number
---@return IndicatorTalentOption|false
maybeOption = function(opt, curSpecID, curSpecName, idx)
    if not isValidOption(opt, idx) or (opt.spec ~= curSpecID and opt.spec ~= curSpecName) then
        return false
    end
    if opt["layout"] and opt["layout"] ~= curLayout then
        return false
    end

    for _, indicator in pairs(Cell.vars.currentLayoutTable.indicators) do
        if opt.indicator == indicator.name or opt.indicator == indicator.indicatorName then
            return {
                talentID = opt.talentID,
                spec = opt.spec,
                indicatorName = indicator.indicatorName,
                enabled = opt.enabled,
            }
        end
    end

    Print("No indicator matching \"" .. opt.indicator .. "\" found #" .. idx)
    return false
end

updateCurrentLayoutOptions = function()
    Print("updateCurrentLayoutOptions")
    ValidTalentOptions = {}
    curLayout = Cell.vars.currentLayout

    local curSpecID, curSpecName = GetSpecializationInfo(GetSpecialization())

    for idx, opt  in pairs(IndicatorTalentOptions) do
        local option = maybeOption(opt, curSpecID, curSpecName, idx)

        if option then
            local layout = opt["layout"] or curLayout

            if not ValidTalentOptions[layout] then ValidTalentOptions[layout] = {} end
            table.insert(ValidTalentOptions[layout], option)
        end
    end
    DevAdd(ValidTalentOptions, "ValidTalentOptions")
end

updateIndicators = function()
    Print("updateIndicators - " .. "layout:" .. curLayout .. " valid:" .. (ValidTalentOptions[curLayout] and #ValidTalentOptions[curLayout] or 0))
    if not ValidTalentOptions[curLayout] then return end
    
    for _, opt in pairs(ValidTalentOptions[curLayout]) do
        local state
        if IsPlayerSpell(opt.talentID) then
            state = opt.enabled
        else
            state = not opt.enabled
        end

        Cell:Fire("UpdateIndicators", curLayout, opt.indicatorName, "enabled", state)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        updateCurrentLayoutOptions()
        -- Init callbacks event listeners
        if not init then 
            init = true
            
            Cell:RegisterCallback("UpdateLayout", "IndicatorTalentOption_UpdateLayout", function() 
                layoutChanged = true
                updateCurrentLayoutOptions()
            end)
            
            -- Talent update
            eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED") 
            -- Easy way to revert current changes
            eventFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
        end
    end

    updateIndicators()
end)

-- Use this to properly delay updates on various changes to layout
CellLoadingBar:HookScript("OnHide", function() 
    if layoutChanged then 
        layoutChanged = false
        updateIndicators() 
    end
end)
Cell.frames.optionsFrame:HookScript("OnHide", updateIndicators)

-- Debug
Print = function(msg, isErr) 
    if isErr then F:Print("IndicatorTalentOption: |cFFFF3030" .. msg .. "|r")
    elseif debug then F:Print("IndicatorTalentOption: " .. msg) end
end
DevAdd = function(data, name) if debug and DevTool then DevTool:AddData(data, name) end end

---@class IndicatorTalentOption
---@field talentID number
---@field spec string|number
---@field indicator string
---@field enabled boolean
---@field layout string|nil
