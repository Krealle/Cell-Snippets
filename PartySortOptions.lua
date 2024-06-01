-- More options for party sorting

-- IMPORTANT: 
-- If "Sort By Role" is enabled groups will only be sorted if you are playing DPS
--
-- Due to how SecureFrames are handled in combat, and the implementation
-- Sorting only works when you are not in combat
-- Any rooster changes while in combat will be delayed until combat ends

---------------------------------------------------------------------------
-- SET YOUR OPTIONS HERE

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

    DevAdd(nameList, "nameList")
    if not nameList then
        Print("Found no players in party.", true)
        return
    end

    updateAttributes(nameList)
end

---@return string|false
indexSort = function()
    local names = {}
    for unit in F:IterateGroupMembers() do
        local name = GetUnitName(unit, true)

        if name and name ~= playerName then
            tinsert(names, name)
        end
    end

    -- Prevent nil entries
    local index = math.min(fixedPlayerIndex, #names + 1)
    tinsert(names, index, playerName)

    DevAdd(names, "indexSort names")
    if #names == 0 then return false end

    return F:TableToString(names, ",") 
end

---@param string
---@return string|false
roleSort = function(layout)
    local roleNames = {
        ["TANK"] = {},
        ["HEALER"] = {},
        ["DAMAGER"] = {},
        ["NONE"] = {} -- Shouldn't happen but just in case
    }

    for unit in F:IterateGroupMembers() do
        local name = GetUnitName(unit, true)

        if name and name ~= playerName then
            tinsert(roleNames[UnitGroupRolesAssigned(unit)], name)
        end
    end

    -- Prevent nil entries
    local index = math.min(fixedPlayerDamagerIndex, #roleNames["DAMAGER"] + 1)
    tinsert(roleNames["DAMAGER"], index, playerName)

    DevAdd(roleNames, "roleSort roleNames")
    local names = {}
    for _, role in pairs(layout["main"]["roleOrder"]) do
        if roleNames[role] then
            for _, name in pairs(roleNames[role]) do
                tinsert(names, name)
            end
        end
    end

    if #roleNames["NONE"] > 0 then
        -- Again this shouldn't happen but just in case
        -- We don't want to hide any potential players
        for _, name in pairs(roleNames["NONE"]) do
            tinsert(names, name)
        end
    end

    DevAdd(names, "roleSort names")
    if #names == 0 then return false end

    return F:TableToString(names, ",")
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

---@param nameList string
updateAttributes = function(nameList)
    if InCombatLockdown() then 
        queuedUpdate = true
        return 
    end
    
    if CellPartyFrameHeader:GetAttribute("sortMethod") ~= "NAMELIST" then
        CellPartyFrameHeader:SetAttribute("groupingOrder", "")
        CellPartyFrameHeader:SetAttribute("groupBy", nil)
        CellPartyFrameHeader:SetAttribute("sortMethod", "NAMELIST")
    end

    CellPartyFrameHeader:SetAttribute("nameList", nameList)
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