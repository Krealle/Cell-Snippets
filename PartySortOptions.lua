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
local FIXED_PLAYER_INDEX = 1
-- This overrides FIXED_PLAYER_INDEX to always be the last DPS
local FORCE_SELF_AUG_AS_LAST_DPS = false

-- Used for role sorting
-- Valid range: 1-5
local FIXED_PLAYER_ROLE_INDEX = 1

-- Whether to to use fixed player index
-- Set to true to use strict index when sorting by role
local USE_FIXED_INDEX = false

local onlySortWhenDamager = false
---------------------------------------------------------------------------
-- WIP: The ones below don't actually do anything yet

-- Add option to dictate priority based on names
local priorityList = { "Xephyris" }
local usePriorityList = false

-- Add option to dictate a fixed order
local fixedList = { "player1", "player2", "player3", "player4", "player5" }
local useFixedList = false
---------------------------------------------------------------------------
-- END OF OPTIONS
---------------------------------------------------------------------------

-- MARK: Sanitize user input
---------------------------------------------------------------------------
if type(FIXED_PLAYER_INDEX) ~= "number" then
    FIXED_PLAYER_INDEX = 1
elseif FIXED_PLAYER_INDEX > 5 then
    FIXED_PLAYER_INDEX = 5
elseif FIXED_PLAYER_INDEX < 1 then
    FIXED_PLAYER_INDEX = 1
end

if type(FIXED_PLAYER_ROLE_INDEX) ~= "number" then
    FIXED_PLAYER_ROLE_INDEX = 1
elseif FIXED_PLAYER_ROLE_INDEX > 5 then
    FIXED_PLAYER_ROLE_INDEX = 5
elseif FIXED_PLAYER_ROLE_INDEX < 1 then
    FIXED_PLAYER_ROLE_INDEX = 1
end

if type(USE_FIXED_INDEX) ~= "boolean" then
    USE_FIXED_INDEX = false
end

if type(onlySortWhenDamager) ~= "boolean" then
    onlySortWhenDamager = false
end

if
    FORCE_SELF_AUG_AS_LAST_DPS
    and select(3, C_PlayerInfo.GetClass({ unit = "player" })) == 13
    and GetSpecialization() == 3
then
    FIXED_PLAYER_INDEX = 4
    USE_FIXED_INDEX = true
end
---------------------------------------------------------------------------

-- MARK: Variables
---------------------------------------------------------------------------
-- Functions
local F = Cell.funcs
local shouldSort, handleQueuedUpdate, addUpdateToQueue, canelQueuedUpdate
local PartyFrame_UpdateLayout, updateAttributes
local Print, DevAdd
-- Vars
local playerName = GetUnitName("player")
local debug = false
local updateIsQued, queuedUpdate
local init = true

-- MARK: Sorting functions
-------------------------------------------------------

---@param roleOrder table<number, "DAMAGER" | "TANK" | "HEALER">
---@return table<string>|false
local function roleSort(roleOrder)
    local roleUnits = {
        ["TANK"] = {},
        ["HEALER"] = {},
        ["DAMAGER"] = {},
        ["NONE"] = {}, -- Shouldn't happen but just in case
    }

    for unit in F.IterateGroupMembers() do
        local name = GetUnitName(unit, true)

        if unit ~= "player" and name ~= playerName then
            local unitToUse = useNameFilter and name or unit
            local role = UnitGroupRolesAssigned(unit)

            tinsert(roleUnits[role], unitToUse)
        end
    end

    local player = useNameFilter and playerName or "player"

    -- When not using fixed index insert player into their respective role
    if not USE_FIXED_INDEX then
        local playerRole = UnitGroupRolesAssigned("player")
        local index = math.min(FIXED_PLAYER_ROLE_INDEX, #roleUnits[playerRole] + 1)

        tinsert(roleUnits[playerRole], index, player)
    end

    DevAdd(roleUnits, "roleSort")
    local units = {}
    for _, role in pairs(roleOrder) do
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

    -- When using fixed index insert player after all other units
    if USE_FIXED_INDEX then
        local index = math.min(FIXED_PLAYER_INDEX, #units + 1)
        tinsert(units, index, player)
    end

    DevAdd(units, "roleSort units")
    if #units == 0 then
        return false
    end

    return units
end

---@return table<string>|false
local function indexSort()
    local units = {}
    for unit in F.IterateGroupMembers() do
        local name = GetUnitName(unit, true)

        if unit ~= "player" and name ~= playerName then
            local unitToUse = useNameFilter and name or unit
            tinsert(units, unitToUse)
        end
    end

    -- Prevent nil entries
    local index = math.min(FIXED_PLAYER_INDEX, #units + 1)
    local player = useNameFilter and playerName or "player"
    tinsert(units, index, player)

    DevAdd(units, "indexSort units")
    if #units == 0 then
        return false
    end

    return units
end

local function sortPartyFrames()
    if not shouldSort() then
        return
    end
    -- We delay initial update to not affect loading time
    -- Inital call is from "UpdateLayout" fire
    if init then
        init = false
        addUpdateToQueue()
        return
    end

    local layout = Cell.vars.currentLayoutTable

    local nameList
    if layout["main"]["sortByRole"] then
        Print("sortPartyFrames - Sorting by role.")
        nameList = roleSort(layout["main"]["roleOrder"])
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

-- MARK: Helper functions
-------------------------------------------------------

---@return boolean
shouldSort = function()
    if Cell.vars.groupType ~= "party" then
        canelQueuedUpdate(true)
        return false
    end
    if InCombatLockdown() then
        canelQueuedUpdate()
        return false
    end

    local playerRole = UnitGroupRolesAssigned("player")
    if onlySortWhenDamager and playerRole ~= "DAMAGER" then
        canelQueuedUpdate(true)
        return false
    end

    return true
end

handleQueuedUpdate = function()
    if not updateIsQued or not shouldSort() then
        return
    end

    updateIsQued = false
    sortPartyFrames()
end

addUpdateToQueue = function()
    if not shouldSort() then
        return
    end

    -- Reset our queued update if we get new update requests
    -- eg. lots of new players joining or leaving
    -- no need to keep sorting
    if updateIsQued and queuedUpdate then
        queuedUpdate:Cancel()
    end

    updateIsQued = true
    queuedUpdate = C_Timer.NewTimer(1, handleQueuedUpdate)
end

--- Cancels queued update timer. fullReset will reset updateIsQued
---@param fullReset? boolean
canelQueuedUpdate = function(fullReset)
    if fullReset then
        updateIsQued = false
    end
    if queuedUpdate then
        queuedUpdate:Cancel()
    end
end

---@param nameList table<string>
updateAttributes = function(nameList)
    if InCombatLockdown() then
        queuedUpdate = true
        return
    end

    if useNameFilter then
        if CellPartyFrameHeader:GetAttribute("sortMethod") ~= "NAMELIST" then
            Print("Setting sortMethod to NAMELIST")
            CellPartyFrameHeader:SetAttribute("groupingOrder", "")
            CellPartyFrameHeader:SetAttribute("groupBy", nil)
            CellPartyFrameHeader:SetAttribute("sortMethod", "NAMELIST")
        end

        CellPartyFrameHeader:SetAttribute("nameList", F.TableToString(nameList, ","))

        -- update OmniCD namespace
        for i = 1, 5 do
            CellPartyFrameHeader:UpdateButtonUnit(
                CellPartyFrameHeader[i]:GetName(),
                CellPartyFrameHeader[i]:GetAttribute("unit")
            )
        end

        return
    end

    for i = 1, 5 do
        local unit = nameList[i] or ("party" .. i)
        CellPartyFrameHeader[i]:SetAttribute("unit", unit)
        -- update OmniCD namespace
        CellPartyFrameHeader:UpdateButtonUnit(CellPartyFrameHeader[i]:GetName(), unit)
    end
end

-- MARK: Events
-------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        handleQueuedUpdate()
        return
    end

    addUpdateToQueue()
end)

-- MARK: Callback
-------------------------------------------------------

PartyFrame_UpdateLayout = function()
    addUpdateToQueue()
end
Cell.RegisterCallback("UpdateLayout", "PartySortOptions_UpdateLayout", PartyFrame_UpdateLayout)

-- MARK: Slash command
-------------------------------------------------------
SLASH_CELLPARTYSORT1 = "/psort"
function SlashCmdList.CELLPARTYSORT()
    Cell.Fire("UpdateLayout", Cell.vars.currentLayout, "sort")
    F.Print("PartySortOptions: Sorting")
end

-- MARK: Debug
-------------------------------------------------------
Print = function(msg, isErr)
    if isErr then
        F.Print("PartySortOptions: |cFFFF3030" .. msg .. "|r")
    elseif debug then
        F.Print("PartySortOptions: " .. msg)
    end
end
DevAdd = function(data, name)
    if debug and DevTool then
        DevTool:AddData(data, name)
    end
end
