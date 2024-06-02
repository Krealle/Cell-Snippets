-- More options for raid sorting

-- IMPORTANT: 
-- Due to how SecureFrames are handled in combat, and the implementation
-- Sorting only works when you are not in combat
-- Any rooster changes while in combat will be delayed until combat ends

-- Does NOT work if you have "Combine Groups" enabled

-- /rsort - Sorts raid frames
-- /rupdate - Updates sort settings

---------------------------------------------------------------------------
-- SET YOUR OPTIONS HERE

-- Build your desired sorting order
-- Valid options are:
-- "PLAYER"
-- "SPEC"
-- "NAME"
-- "ROLE"
-- "SPECROLE"
-- Top of list = highest priority
local SORTING_ORDER = {
    "PLAYER",
    "NAME",
    "SPEC",
    -- "ROLE"
    -- "SPECROLE"
}

-- Whether to sorting Ascending or Descending
local sortDirection = "ASC" -- "ASC" or "DESC"

-- How long in seconds to wait before updating raid frames
-- Should be kept high to prevent oversorting on rapid roster changes
-- eg. start/end of raid
local QUE_TIMER = 1

-- Top of list = highest priority
-- No support for "-Realm" suffix, so don't add it.
local NAME_PRIORITY = {"Xephyris","Entro"}

-- Top of list = highest priority
local ROLE_PRIORITY = {"HEALER","DAMAGER","TANK"}

-- Top of list = highest priority
-- When spec can't be found for a player, this will default to their role
-- eg. dps with no found spec will default to "DAMAGER"
local SPECROLE_PRIORITY = {"RANGED","MELEE","DAMAGER","HEALER","TANK"}

-- Top of list = highest priority
local SPEC_PRIORITY = {
    -- Melee
    251, -- Death Knight - Frost
    252, -- Death Knight - Unholy
    577, -- Demon Hunter - Havoc
    103, -- Druid - Feral
    255, -- Hunter - Survival
    269, -- Monk - Windwalker
    70, -- Paladin - Retribution
    259, -- Rogue - Assassination
    260, -- Rogue - Combat
    261, -- Rogue - Subtlety
    263, -- Shaman - Enhancement
    71, -- Warrior - Arms
    72, -- Warrior - Fury

    -- Ranged
    253, -- Hunter - Beast 野兽控制
    254, -- Hunter - Marksmanship
    102, -- Druid - Balance
    1467, -- Evoker - Devastation
    62, -- Mage - Arcane
    63, -- Mage - Fire
    64, -- Mage - Frost
    258, -- Priest - Shadow
    262, -- Shaman - Elemental
    265, -- Warlock - Affliction
    266, -- Warlock - Demonology
    267, -- Warlock - Destruction

    -- Healer
    105, -- Druid - Restoration
    1468, -- Evoker - Preservation
    270, -- Monk - Mistweaver
    65, -- Paladin - Holy
    256, -- Priest - Discipline
    257, -- Priest - Holy
    264, -- Shaman - Restoration

    -- Tank
    250, -- Death Knight - Blood
    581, -- Demon Hunter - Vengeance
    104, -- Druid - Guardian
    268, -- Monk - Brewmaster
    66, -- Paladin - Protection
    73, -- Warrior - Protection

    -- Support
    1473, -- Evoker - Augmentation
}

---------------------------------------------------------------------------
-- WIP: The ones below don't actually do anything yet

-- WIP sorts
-- "ROLE"
-- "SPECROLE"
-- "CLASS"
-- local rolePriority = {"TANK", "HEALER", "DAMAGER"}
-- local classPriority = {"DEATHKNIGHT", "DEMONHUNTER", "DRUID", "HUNTER", "MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"}

-- Where to place the player
-- Ideally use sortingPriority over this unless you need a very specific position
-- Valid range: 1-5
-- local fixedPlayerIndex = 1 
-- local useFixedPlayedIndex = false

-- This will maintain strict group order on roster changes in combat 
-- but will not show new group members until combat ends.
-- Recommend to keep it off unless you expect a lot of changes in combat
-- without the players in the group changing
-- local useNameFilter = false

-- Toggle whether to sort only your group
-- local onlySortMyGroup = true
---------------------------------------------------------------------------
-- END OF OPTIONS
---------------------------------------------------------------------------

-- MARK: Variables
---------------------------------------------------------------------------
-- Functions
local F = Cell.funcs
local LGI = LibStub:GetLibrary("LibGroupInfo")

local shouldSort, sortRaidFrames, RaidFrame_UpdateLayout, addUpdateToQue, handleQueuedUpdate
local buildRaidInfo, getSortedRaidGroup, updateRaidFrames, getSortFunction
local Print, DevAdd, sanitizeSortOptions
local direction, playerSort, specSort, nameSort, roleSort, specRoleSort, comparePriority
local isValidPlayers, getPlayerInfo, isValidPlayerInfo
-- Vars
local nameList = {}
local playerName = GetUnitName("player")
local debug = false
local updateIsQued = false
local queuedUpdate = nil
local playerSubGroup = 1
local init = true

-- MARK: Sanitize user input
---------------------------------------------------------------------------
local VALID_SORT_OPTIONS = {["PLAYER"] = true, ["SPEC"] = true, ["NAME"] = true, ["ROLE"] = true, ["SPECROLE"] = true}
local VALID_SORT_DIRECTIONS = {["ASC"] = true, ["DESC"] = true}
local VALID_ROLES = {["DAMAGER"] = true, ["HEALER"] = true, ["TANK"] = true}
local VALID_SPECROLES = {["RANGED"] = true, ["MELEE"] = true, 
                        ["DAMAGER"] = true, ["HEALER"] = true, ["TANK"] = true}

---@type table<SortOption, function>
local INTERNAL_SORT_OPTIONS
---@type table<number, number>
local INTERNAL_SPEC_PRIORITY
---@type table<string, number>
local INTERNAL_NAME_PRIORITY
---@type table<string, number>
local INTERNAL_ROLES_PRIORITY
---@type table<string, number>
local INTERNAL_SPECROLES_PRIORITY
---@type "ASC"|"DESC
local INTERNAL_SORT_DIRECTION

sanitizeSortOptions = function()
    INTERNAL_SORT_OPTIONS = {}
    for _, option in pairs(SORTING_ORDER) do
        if option and VALID_SORT_OPTIONS[option] then
            local sortFunction = getSortFunction(option)
            if type(sortFunction) == "function" then
                tinsert(INTERNAL_SORT_OPTIONS, sortFunction)
            else
                Print("Failed to find sort function for: " .. option .. " this is an error on my part, please report it.", true)
            end
        else
            Print("Invalid sortOption: " .. (option or "nil"), true)
        end
    end

    INTERNAL_SPEC_PRIORITY = {}
    for i, spec in pairs(SPEC_PRIORITY) do
        if spec and type(spec) == "number" then
            INTERNAL_SPEC_PRIORITY[spec] = i
        else
            Print("Invalid spec: " .. (spec or "nil"), true)
        end
    end

    INTERNAL_NAME_PRIORITY = {}
    for i, name in pairs(NAME_PRIORITY) do
        if name and type(name) == "string" then
            INTERNAL_NAME_PRIORITY[name] = i
        else
            Print("Invalid name: " .. (name or "nil"), true)
        end
    end

    INTERNAL_ROLES_PRIORITY = {}
    for i, role in pairs(ROLE_PRIORITY) do
        if role and VALID_ROLES[role] then
            INTERNAL_ROLES_PRIORITY[role] = i
        else
            Print("Invalid role: " .. (role or "nil"), true)
        end
    end

    INTERNAL_SPECROLES_PRIORITY = {}
    for i, specRole in pairs(SPECROLE_PRIORITY) do
        if specRole and VALID_SPECROLES[specRole] then
            INTERNAL_SPECROLES_PRIORITY[specRole] = i
        else
            Print("Invalid specRole: " .. (specRole or "nil"), true)
        end
    end

    if sortDirection and VALID_SORT_DIRECTIONS[sortDirection] then
        INTERNAL_SORT_DIRECTION = sortDirection
    else
        Print("Invalid sortDirection - forced to ASC", true)
        INTERNAL_SORT_DIRECTION = "ASC"
    end
    DevAdd({INTERNAL_SORT_OPTIONS, 
            INTERNAL_SPEC_PRIORITY, 
            INTERNAL_NAME_PRIORITY, 
            INTERNAL_ROLES_PRIORITY, 
            INTERNAL_SPECROLES_PRIORITY, 
            INTERNAL_SORT_DIRECTION}, 
            "Internal sort options")

    if type(QUE_TIMER) ~= "number" or QUE_TIMER < 0.5 then
        Print("Invalid QUE_TIMER - forced to 1", true)
        QUE_TIMER = 1
    end
end

-- MARK: Main functions
-------------------------------------------------------
---@param layout string
---@param which string
sortRaidFrames = function(layout, which)
    if not shouldSort() then return end
    if init then 
        init = false 
        addUpdateToQue() 
        return
    end

    if not INTERNAL_SORT_OPTIONS or not INTERNAL_SPEC_PRIORITY
        or not INTERNAL_NAME_PRIORITY or not INTERNAL_SORT_DIRECTION then
        Print("We need to sanitize first")
        sanitizeSortOptions()
    end

    local UNSORTED_RAID_GROUP = buildRaidInfo()
    if not UNSORTED_RAID_GROUP then
        Print("Found no players in group.", true)
        return
    end

    local SORTED_RAID_GROUP = getSortedRaidGroup(UNSORTED_RAID_GROUP)
    if not SORTED_RAID_GROUP then
        Print("Failed to sort group.", true)
        return
    end
    
    updateRaidFrames(SORTED_RAID_GROUP)
end

---@param SORTED_RAID_GROUP table<Player>
updateRaidFrames = function(SORTED_RAID_GROUP)
    -- We have to be 100% certain we won't be tainting
    if InCombatLockdown() then 
        updateIsQued = true
        return 
    end
    
    --[[ if useNameFilter then
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
    end ]]

    Print("updateRaidFrames")
    for i = 1, #SORTED_RAID_GROUP do
        ---@type Player
        local player = SORTED_RAID_GROUP[i]

        local b = _G["CellRaidFrameHeader"..playerSubGroup][i]
        Cell.unitButtons.raid.units
        b:SetAttribute("unit", player.unit)
        -- Update OmniCD namespace
        _G[b:GetName()].unit = player.unit
    end
end

-- MARK: Sorting functions
-------------------------------------------------------

---@param UNSORTED_RAID_GROUP table<Player>
---@return table<Player> SORTED_RAID_GROUP
getSortedRaidGroup = function(UNSORTED_RAID_GROUP)
    if not UNSORTED_RAID_GROUP then return end
    
    ---@type table<Player>
    local SORTED_RAID_GROUP = F:Copy(UNSORTED_RAID_GROUP)

    table.sort(SORTED_RAID_GROUP, 
    ---@param playerA Player
    ---@param playerB Player
    function(playerA, playerB)
        local isValidData, maybeResult = isValidPlayers(playerA, playerB)
        if not isValidData then
            Print("invalid data " .. (maybeResult and "true" or maybeResult ~= nil and "false" or "nil"))
            if maybeResult ~= nil then
                return direction(maybeResult)
            end
            return direction(playerA.unit < playerB.unit)
        end

        if debug then print("") end
        Print("sort: ".. playerA.name.."("..playerA.unit..") ".. playerB.name.."("..playerB.unit..") ==>")

        for sortOption, sortFunction in pairs(INTERNAL_SORT_OPTIONS) do
            local maybeResult = sortFunction(playerA, playerB)
            if maybeResult ~= nil then
                return direction(maybeResult)
            end
        end

        Print("Fallback")
        return direction(playerA.unit < playerB.unit)
    end)

    DevAdd(SORTED_RAID_GROUP, "SORTED_RAID_GROUP")

    return SORTED_RAID_GROUP
end

---@param playerA Player
---@param playerB Player
---@return boolean|nil
playerSort = function(playerA, playerB)
    Print("playerSort")
    if not playerA or not playerB then return nil end
    if not playerA.name and not playerB.name then return nil end

    if playerA.name == playerName then
        return true
    elseif playerB.name == playerName then
        return false
    end

    return nil
end

---@param playerA Player
---@param playerB Player
---@return boolean|nil
specSort = function(playerA, playerB)
    Print("specSort")
    if not playerA or not playerB then return nil end

    local aSpec, bSpec = playerA.specId, playerB.specId
    if not aSpec and not bSpec then return nil end

    local aPrio = INTERNAL_SPEC_PRIORITY[aSpec]
    local bPrio = INTERNAL_SPEC_PRIORITY[bSpec]
    if not aPrio and not bPrio then return nil end

    Print(aSpec .. "(".. (aPrio or "n/a") .. ") " .. bSpec .. "(".. (bPrio or "n/a") .. ")")
    return comparePriority(aPrio, bPrio)
end

---@param playerA Player
---@param playerB Player
---@return boolean|nil
nameSort = function(playerA, playerB)
    Print("nameSort")
    if not playerA or not playerB then return nil end
    
    local aName, bName = playerA.name, playerB.name
    if not aName and not bName then return nil end

    local aPrio = INTERNAL_NAME_PRIORITY[aName]
    local bPrio = INTERNAL_NAME_PRIORITY[bName]
    if not aPrio and not bPrio then return nil end

    Print(aName .. "(".. (aPrio or "n/a") .. ") " .. bName .. "(".. (bPrio or "n/a") .. ")")
    return comparePriority(aPrio, bPrio)   
end

---@param playerA Player
---@param playerB Player
---@return boolean|nil
roleSort = function(playerA, playerB)
    Print("roleSort")
    if not playerA or not playerB then return nil end

    local aRole, bRole = playerA.role, playerB.role
    if not aRole and not bRole then return nil end

    local aPrio = INTERNAL_ROLES_PRIORITY[aRole]
    local bPrio = INTERNAL_ROLES_PRIORITY[bRole]
    if not aPrio and not bPrio then return nil end

    Print(aRole .. "(".. (aPrio or "n/a") .. ") " .. bRole .. "(".. (bPrio or "n/a") .. ")")
    return comparePriority(aPrio, bPrio)
end

---@param playerA Player
---@param playerB Player
---@return boolean|nil
specRoleSort = function(playerA, playerB)
    Print("specRoleSort")
    if not playerA or not playerB then return nil end

    local aSpecRole, bSpecRole = playerA.specRole, playerB.specRole
    if not aSpecRole and not bSpecRole then return nil end

    local aPrio = INTERNAL_SPECROLES_PRIORITY[aSpecRole]
    local bPrio = INTERNAL_SPECROLES_PRIORITY[bSpecRole]
    if not aPrio and not bPrio then return nil end

    Print(aSpecRole .. "(".. (aPrio or "n/a") .. ") " .. bSpecRole .. "(".. (bPrio or "n/a") .. ")")
    return comparePriority(aPrio, bPrio)
end

---@param a number|nil
---@param b number|nil
---@return boolean|nil
comparePriority = function(a, b)
    if a and b then
        return a < b
    elseif a then
        return true
    elseif b then
        return false
    end

    return nil
end

---@param sortOption SortOption
---@return function SortFunction
getSortFunction = function(sortOption)
    if sortOption == "PLAYER" then
        return playerSort
    elseif sortOption == "SPEC" then
        return specSort
    elseif sortOption == "NAME" then
        return nameSort
    elseif sortOption == "ROLE" then
        return roleSort
    elseif sortOption == "SPECROLE" then
        return specRoleSort
    end
end

-- MARK: Helper functions
-------------------------------------------------------

---@return table<Player> UNSORTED_RAID_GROUP
buildRaidInfo = function()
    Print("buildRaidInfo")
    ---@type table<Player>
    UNSORTED_RAID_GROUP = {}

    playerSubGroup = select(2, F:GetRaidInfoByName(playerName))
    for _, unit in pairs(F:GetUnitsInSubGroup(playerSubGroup)) do
        local player = getPlayerInfo(unit)
        tinsert(UNSORTED_RAID_GROUP, player)
    end

    DevAdd(UNSORTED_RAID_GROUP, "UNSORTED_RAID_GROUP")
    return UNSORTED_RAID_GROUP
end

---@return boolean
shouldSort = function()
    if Cell.vars.groupType ~= "raid" then
        updateIsQued = false
        if queuedUpdate then queuedUpdate:Cancel() end
        return false
    end
    if InCombatLockdown() then 
        updateIsQued = true
        if queuedUpdate then queuedUpdate:Cancel() end
        return false
    end

    return true
end

handleQueuedUpdate = function()
    if not updateIsQued or not shouldSort() then return end
    
    updateIsQued = false
    sortRaidFrames()
end

addUpdateToQue = function()
    if not shouldSort() then return end

    -- Reset our queued update if we get new update requests
    -- eg. lots of new players joining or leaving
    -- no need to keep sorting 
    if updateIsQued and queuedUpdate then
        queuedUpdate:Cancel()
    end

    updateIsQued = true
    queuedUpdate = C_Timer.NewTimer(QUE_TIMER, handleQueuedUpdate)
end

--- Normalize the sort direction
---@param bool boolean
---@return boolean
direction = function(bool) 
    if INTERNAL_SORT_DIRECTION == "ASC" then 
        return bool 
    else 
        return not bool  
    end
end

---@param aPlayer Player
---@param bPlayer Player
---@return boolean isValid
---@return boolean|nil? maybeResult
isValidPlayers = function(aPlayer, bPlayer)
    if not aPlayer and not bPlayer then 
        Print("both nil")
        return false, nil
    elseif not aPlayer then
        Print("aPlayer nil")
        return false, false
    elseif not bPlayer then
        Print("bPlayer nil")
        return false, true
    end
    return true
end

---@param info CachedPlayerInfo
---@return boolean
isValidPlayerInfo = function(info)
    return info and info.specId and info.specRole 
            and info.role and info.name and info.realm
end

---@param guid string
---@return Player player
getPlayerInfo = function(unit)
    local guid = UnitGUID(unit)

    ---@type CachedPlayerInfo
    local cachedInfo = LGI:GetCachedInfo(guid)
    if isValidPlayerInfo(cachedInfo) then 
        DevAdd(cachedInfo, unit)
        return {
            name = cachedInfo.name,
            realm = cachedInfo.realm,
            unit = unit,
            guid = guid,
            subGroup = playerSubGroup,
            role = cachedInfo.role,
            specId = cachedInfo.specId,
            specRole = cachedInfo.specRole,
        }
    else
        local raidIndex = tonumber(select(2, string.match(unit, "^(raid)(%d+)$")))
        if not raidIndex then
            local name, realm = UnitName(unit)
            Print("Unable to find spec info for " .. name .. "-" .. realm, true)
            return {
                name = name,
                realm = realm,
                unit = unit,
                guid = guid,
                subGroup = playerSubGroup,
            }
        end

        local name, rank, subGroup, level, class, fileName, 
                zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(raidIndex)

        local name, realm = string.match(name, "([^%-]+)%-([^%-]+)")

        DevAdd({name, realm, rank, subGroup, level, class, fileName, zone, online, isDead, role, isML, combatRole}, unit)
        
        Print("Unable to find spec info for " .. name .. "-" .. realm, true)
        return {
            name = name,
            realm = realm,
            unit = unit,
            guid = guid,
            subGroup = subGroup,
            role = combatRole,
            specRole = combatRole, -- won't give melee/ranged
            -- TODO:
            -- specId = 1467,
            -- specRole = LGI.specRoles[specId]
        }
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

    addUpdateToQue()
end)

-- MARK: Callback
-------------------------------------------------------
RaidFrame_UpdateLayout = function()
    addUpdateToQue()
end
Cell:RegisterCallback("UpdateLayout", "RaidSortOptions_UpdateLayout", RaidFrame_UpdateLayout)

-- MARK: Debug
-------------------------------------------------------
Print = function(msg, isErr, isInfo) 
    if isErr then F:Print("RaidSortOptions: |cFFFF3030" .. msg .. "|r")
    elseif isInfo then F:Print("RaidSortOptions: " .. msg)
    elseif debug then F:Print("RaidSortOptions: " .. msg) end
end
DevAdd = function(data, name) if debug and DevTool then DevTool:AddData(data, name) end end

-- MARK: Slash command
-------------------------------------------------------
SLASH_CELLRAIDSORT1 = "/rsort"
function SlashCmdList.CELLRAIDSORT()
    sortRaidFrames()
    if InCombatLockdown() then
        Print("Sort queued till after combat", false, true)
    else
        Print("Sorted", false, true)
    end
end

SLASH_CELLRAIDSORTUPDATE1 = "/rupdate"
function SlashCmdList.CELLRAIDSORTUPDATE()
    sanitizeSortOptions()
    Print("Updated sort options", false, true)
end

-- MARK: Annotations
-------------------------------------------------------

---@class CachedPlayerInfo
---@field assignedRole string 
---@field class string 
---@field faction string 
---@field gender string 
---@field inspected boolean 
---@field level number 
---@field name string 
---@field race string 
---@field realm string 
---@field role string 
---@field specIcon number 
---@field specId number 
---@field specName string 
---@field specRole string 
---@field unit string

---@class Player
---@field name string
---@field realm string
---@field unit string
---@field subGroup number
---@field guid string
---@field specId number
---@field role string
---@field specRole string

---@alias SortOption 
---| "PLAYER"
---| "SPEC"
---| "NAME"
---| "ROLE"
---| "SPECROLE"
