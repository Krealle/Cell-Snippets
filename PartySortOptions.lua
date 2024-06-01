-- More options for party sorting

-- IMPORTANT: 
-- If "Sort By Role" is enabled groups will only be sorted if you are playing DPS
--
-- Due to how SecureFrames are handled in combat, and the implementation
-- Sorting only works when you are not in combat
-- Any rooster changes while in combat will be delayed until combat ends

---------------------------------------------------------------------------
-- SET YOUR OPTIONS HERE

-- This will maintain strict group order on roster changes in combat 
-- but will not show new group members until combat ends.
-- Recommend to keep it off unless you expect a lot of changes in combat
-- without the players in the group changing
local useNameFilter = false

-- Used for index sorting
-- Valid range: 1-5
local fixedPlayerIndex = 1 

-- Used for damager role sorting
-- Valid range: 1-3
local fixedPlayerDamagerIndex = 1
---------------------------------------------------------------------------
-- WIP: The ones below don't actually do anything yet

-- Add option to dictate priority based on names
local priorityList = {"Xephyris"}
local usePriorityList = false

-- Add option to dictate a fixed order
local fixedList = {"player1","player2","player3","player4","player5"}
local useFixedList = false
---------------------------------------------------------------------------
-- END OF OPTIONS
---------------------------------------------------------------------------

-- MARK: Sanitize user input
---------------------------------------------------------------------------
if type(fixedPlayerIndex) ~= "number" then fixedPlayerIndex = 1  
elseif fixedPlayerIndex > 5 then fixedPlayerIndex = 5 
elseif fixedPlayerIndex < 1 then fixedPlayerIndex = 1 end

if type(fixedPlayerDamagerIndex) ~= "number" then fixedPlayerDamagerIndex = 1 
elseif fixedPlayerDamagerIndex > 3 then fixedPlayerDamagerIndex = 3 
elseif fixedPlayerDamagerIndex < 1 then fixedPlayerDamagerIndex = 1 end
---------------------------------------------------------------------------

-- MARK: Variables
---------------------------------------------------------------------------
-- Functions
local F = Cell.funcs
local shouldSort, indexSort, roleSort, sortPartyFrames, PartyFrame_UpdateLayout, handleQueuedUpdate, updateAttributes
local Print, DevAdd
-- Vars
local nameList = {}
local playerName = GetUnitName("player")
local debug = false
local queuedUpdate

-- MARK: Sorting functions
-------------------------------------------------------
---@param layout string
---@param which string
sortPartyFrames = function(layout, which)
    if Cell.vars.groupType ~= "party" then 
        queuedUpdate = false
        return 
    end
    if InCombatLockdown() then 
        queuedUpdate = true
        return 
    end

    Print("sortPartyFrames - layout:" .. (layout or "") .. " which:" .. (which or ""))
    if (which and which ~= "sort") then return end

    layout = CellDB["layouts"][layout]
    
    if not shouldSort(layout) then return end

    local nameList
    if layout["main"]["sortByRole"] then
        Print("sortPartyFrames - Sorting by role.")
        nameList = roleSort(layout)
    else
        Print("sortPartyFrames - Sorting by index.")
        nameList = indexSort()
    end

    if not nameList then
        Print("Found no players in party.", true)
        return
    end

    updateAttributes(nameList)
end

---@return table<string>|false
indexSort = function()
    local units = {}
    for unit in F:IterateGroupMembers() do
        local name = GetUnitName(unit, true)

        if unit ~= "player" and name ~= playerName then
            local unitToUse = useNameFilter and name or unit
            tinsert(units, unitToUse)
        end
    end

    -- Prevent nil entries
    local index = math.min(fixedPlayerIndex, #units + 1)
    local player = useNameFilter and playerName or "player"
    tinsert(units, index, player)

    DevAdd(units, "indexSort units")
    if #units == 0 then return false end

    return units
end

---@param layout string
---@return table<string>|false
roleSort = function(layout)
    local roleUnits = {
        ["TANK"] = {},
        ["HEALER"] = {},
        ["DAMAGER"] = {},
        ["NONE"] = {} -- Shouldn't happen but just in case
    }

    for unit in F:IterateGroupMembers() do
        local name = GetUnitName(unit, true)
        if unit ~= "player" and name ~= playerName then
            local unitToUse = useNameFilter and name or unit
            tinsert(roleUnits[UnitGroupRolesAssigned(unit)], unitToUse)
        end
    end

    -- Prevent nil entries
    local index = math.min(fixedPlayerDamagerIndex, #roleUnits["DAMAGER"] + 1)
    local player = useNameFilter and playerName or "player"
    tinsert(roleUnits["DAMAGER"], index, player)

    DevAdd(roleUnits, "roleSort")
    local units = {}
    for _, role in pairs(Cell.vars.currentLayoutTable["main"]["roleOrder"]) do
        if roleUnits[role] then
            for _, unit in pairs(roleUnits[role]) do
                tinsert(units, unit)
            end
        end
    end

    if #roleUnits["NONE"] > 0 then
        -- Again this shouldn't happen but just in case
        -- We don't want to hide any potential players
        for _, unit in pairs(roleUnits["NONE"]) do
            tinsert(units, unit)
        end
    end

    DevAdd(units, "roleSort units")
    if #units == 0 then return false end

    return units
end

-- MARK: Helper functions
-------------------------------------------------------
---@param layout string
---@return boolean
shouldSort = function(layout)
    local playerRole = UnitGroupRolesAssigned("player")
    Print("shouldSort - playerRole:" .. playerRole .. " sortByRole:" .. (layout["main"]["sortByRole"] and "true" or "false"))
    return (layout["main"]["sortByRole"] and playerRole == "DAMAGER")
            or playerRole ~= "NONE"
end

---@param nameList table<string>
updateAttributes = function(nameList)
    if InCombatLockdown() then 
        queuedUpdate = true
        return 
    end
    
    if useNameFilter then
        if CellPartyFrameHeader:GetAttribute("sortMethod") ~= "NAMELIST" then
            CellPartyFrameHeader:SetAttribute("groupingOrder", "")
            CellPartyFrameHeader:SetAttribute("groupBy", nil)
            CellPartyFrameHeader:SetAttribute("sortMethod", "NAMELIST")
        end

        CellPartyFrameHeader:SetAttribute("nameList", F:TableToString(nameList, ","))

        -- update OmniCD namespace
        for i = 1, 5 do
            CellPartyFrameHeader:UpdateButtonUnit(CellPartyFrameHeader[i]:GetName(), CellPartyFrameHeader[i]:GetAttribute("unit"))
        end
        return
    end

    for i = 1, 5 do
        local unit = nameList[i] or "party"..i
        CellPartyFrameHeader[i]:SetAttribute("unit", unit)
        -- update OmniCD namespace
        CellPartyFrameHeader:UpdateButtonUnit(CellPartyFrameHeader[i]:GetName(), unit)
    end
end

---@param isInitial boolean
handleQueuedUpdate = function(isInitial)
    if not queuedUpdate then return end
    
    queuedUpdate = false
    sortPartyFrames(Cell.vars.currentLayout)
end

-- MARK: Events
-------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        handleQueuedUpdate(true)
        return
    end

    sortPartyFrames(Cell.vars.currentLayout) 
end)

-- MARK: Callback
-------------------------------------------------------
---@param layout string
---@param which string
PartyFrame_UpdateLayout = function(layout, which)
    -- Update layout after 0.5 seconds
    -- Need to make sure that the default function is resolved
    C_Timer.After(0.5, function() sortPartyFrames(layout, which) end)
end
Cell:RegisterCallback("UpdateLayout", "PartySortOptions_UpdateLayout", PartyFrame_UpdateLayout)

-- MARK: Slash command
-------------------------------------------------------
SLASH_CELLPARTYSORT1 = "/psort"
function SlashCmdList.CELLPARTYSORT()
    sortPartyFrames(Cell.vars.currentLayout, "sort")
    F:Print("sorted")
end

-- MARK: Debug
-------------------------------------------------------
Print = function(msg, isErr) 
    if isErr then F:Print("PartySortOptions: |cFFFF3030" .. msg .. "|r")
    elseif debug then F:Print("PartySortOptions: " .. msg) end
end
DevAdd = function(data, name) if debug and DevTool then DevTool:AddData(data, name) end end