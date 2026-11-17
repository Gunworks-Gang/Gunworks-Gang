local Magazine = require("WeaponSystems/Utils/Magazine")
local Ammo = require("WeaponSystems/Utils/Ammo")

---@class GunworksStackedGroup
---@field name           string
---@field magazines      string[]     one item fullType per side, side 1 first
---@field animation      string | nil WeaponReloadType of the flip's unload and load nodes; nil plays the gun's own
---@field unloadDuration number | nil server timing of that unload clip, in seconds
---@field loadDuration   number | nil server timing of that load clip, in seconds
---@field capacity       number | nil rounds per side, resolved on first use

---@class GunworksStackedPack
---@field group  GunworksStackedGroup
---@field side   integer                  the side that goes into the well
---@field rounds integer[]
---@field lists  table<integer, string[]>

---@class GunworksStackedMagazines
local StackedMagazines = {}

StackedMagazines.STATE_KEY = "GW_Stacked"

--- Anim variable the flip sets to the side going in ("1", "2", ...): a pack moves one way to seat side 2 and the
--- other way back to side 1, so the load nodes tell the two apart.
StackedMagazines.SIDE_VARIABLE = "GunworksStackedSide"

--- Anim variable the flip sets to the group's animation. Gunworks keeps WeaponReloadType on the gun's reload profile
--- during every reload (ReloadAnim/Sync.lua, for multiplayer observers too); while this is set it keeps it here.
StackedMagazines.ANIM_VARIABLE = "GunworksStackedReload"

---@type table<string, GunworksStackedGroup>
StackedMagazines.Groups = {}

-- Magazine fullType -> { group, side }
---@type table<string, { group: GunworksStackedGroup, side: integer }>
StackedMagazines.Sides = {}

local warned = {}

local function warnOnce(message)
    if warned[message] then
        return
    end
    warned[message] = true
    print("[Gunworks/StackedMagazines] " .. message)
end

-------------------------------------------------
-- Registration
-------------------------------------------------

--- Register (or replace) a stacked magazine group.
---@param name       string
---@param definition { magazines: string[], animation: string | nil, unloadDuration: number | nil, loadDuration: number | nil }
function StackedMagazines.RegisterMagazines(name, definition)
    if type(name) ~= "string" or name == "" or type(definition) ~= "table" then
        warnOnce("RegisterMagazines needs a name and a definition table")
        return
    end
    local magazines = definition.magazines
    if type(magazines) ~= "table" or #magazines < 2 then
        warnOnce("'" .. name .. "' needs at least two magazines, one per side")
        return
    end

    local old = StackedMagazines.Groups[name]
    if old then
        for i = 1, #old.magazines do
            local entry = StackedMagazines.Sides[old.magazines[i]]
            if entry and entry.group == old then
                StackedMagazines.Sides[old.magazines[i]] = nil
            end
        end
    end

    local group = {
        name = name,
        magazines = {},
        animation = definition.animation,
        unloadDuration = definition.unloadDuration,
        loadDuration = definition.loadDuration,
    }
    for i = 1, #magazines do
        group.magazines[i] = magazines[i]
        StackedMagazines.Sides[magazines[i]] = { group = group, side = i }
    end
    StackedMagazines.Groups[name] = group
end

-------------------------------------------------
-- Lookups
-------------------------------------------------

---@param fullType string | nil
---@return GunworksStackedGroup | nil group
---@return integer | nil side
function StackedMagazines.GetGroupForType(fullType)
    local entry = fullType and StackedMagazines.Sides[fullType]
    if not entry then
        return nil
    end
    return entry.group, entry.side
end

---@param item InventoryItem | nil
---@return boolean
function StackedMagazines.IsStackedMagazine(item)
    return item ~= nil and StackedMagazines.Sides[item:getFullType()] ~= nil
end

--- Rounds one side holds.
---@param group GunworksStackedGroup
---@return integer
function StackedMagazines.GetSideCapacity(group)
    if not group.capacity then
        local maxAmmo = instanceItem(group.magazines[1]):getMaxAmmo()
        group.capacity = math.max(1, math.floor(maxAmmo / #group.magazines))
    end
    return group.capacity
end

--- Is a stacked pack in this gun's well? True for a pack inserted before this system too (no split yet).
---@param gun HandWeapon
---@return boolean
function StackedMagazines.IsInGun(gun)
    return gun:isContainsClip() and StackedMagazines.Sides[gun:getMagazineType()] ~= nil
end

--- The split of the pack in the gun, or nil when there is no pack or it was never split.
---@param gun HandWeapon
---@return table | nil state
---@return GunworksStackedGroup | nil group
function StackedMagazines.GetGunState(gun)
    if not StackedMagazines.IsInGun(gun) then
        return nil
    end
    local state = gun:getModData()[StackedMagazines.STATE_KEY]
    if type(state) ~= "table" then
        return nil
    end
    local group = StackedMagazines.Groups[state.group]
    if not group or StackedMagazines.Sides[gun:getMagazineType()].group ~= group then
        return nil
    end
    return state, group
end

--- The item type of the side in the well. Read from the split, which reaches a client with the weapon sync; the
--- client's own getMagazineType() only follows on the next equip.
---@param gun HandWeapon
---@return string | nil
function StackedMagazines.GetWellType(gun)
    local state, group = StackedMagazines.GetGunState(gun)
    if state then
        return group.magazines[state.side]
    end
    return gun:getMagazineType()
end

--- The next side after the one in the well that has rounds, in clamp order.
---@param state table
---@param group GunworksStackedGroup
---@return integer | nil
function StackedMagazines.GetNextSide(state, group)
    local count = #group.magazines
    for offset = 1, count - 1 do
        local side = ((state.side - 1 + offset) % count) + 1
        if (tonumber(state.rounds[side]) or 0) > 0 then
            return side
        end
    end
    return nil
end

--- What a flip of this gun would seat: the side, its rounds and its item type.
---@param gun HandWeapon
---@return integer | nil side
---@return integer rounds
---@return string | nil magazineType
function StackedMagazines.PeekNextSide(gun)
    local state, group = StackedMagazines.GetGunState(gun)
    if not state then
        return nil, 0, nil
    end
    local side = StackedMagazines.GetNextSide(state, group)
    if not side then
        return nil, 0, nil
    end
    return side, tonumber(state.rounds[side]) or 0, group.magazines[side]
end

--- Rounds waiting on the sides that are not in the well.
---@param gun HandWeapon
---@return integer
function StackedMagazines.GetReserveRounds(gun)
    local state = StackedMagazines.GetGunState(gun)
    if not state then
        return 0
    end
    local total = 0
    for side, rounds in pairs(state.rounds) do
        if side ~= state.side then
            total = total + (tonumber(rounds) or 0)
        end
    end
    return total
end

--- The WeaponReloadType of the flip nodes for the pack in the gun (nil plays the gun's own unload, then its load).
---@param gun HandWeapon
---@return string | nil
function StackedMagazines.GetAnimation(gun)
    local _, group = StackedMagazines.GetGunState(gun)
    return group and group.animation or nil
end

-------------------------------------------------
-- Round lists
-------------------------------------------------

---@param list table | nil
---@return string[] | nil
local function copyList(list)
    if type(list) ~= "table" or #list == 0 then
        return nil
    end
    local copy = {}
    for i = 1, #list do
        copy[i] = list[i]
    end
    return copy
end

---@param item InventoryItem
---@return string | nil
local function defaultRound(item)
    local ammoType = item:getAmmoType()
    return ammoType and ammoType:getItemKey() or nil
end

-- A list that names `count` rounds: rounds it does not name sit at the bottom and get `filler`.
---@param list   string[] | nil
---@param count  integer
---@param filler string | nil
---@return string[] | nil
local function fitList(list, count, filler)
    if not list or count <= 0 then
        return nil
    end
    local fitted = {}
    local missing = count - #list
    if missing > 0 then
        if not filler then
            return nil
        end
        for i = 1, missing do
            fitted[i] = filler
        end
        for i = 1, #list do
            fitted[missing + i] = list[i]
        end
    else
        for i = 1, count do
            fitted[i] = list[#list - count + i]
        end
    end
    return fitted
end

-------------------------------------------------
-- Packs in the bag
-------------------------------------------------

---@param rounds   integer[]
---@param capacity integer
---@return integer | nil
local function lastSideWithRoom(rounds, capacity)
    for side = #rounds, 1, -1 do
        if rounds[side] < capacity then
            return side
        end
    end
    return nil
end

---@param rounds integer[]
---@return integer | nil
local function firstLoadedSide(rounds)
    for side = 1, #rounds do
        if rounds[side] > 0 then
            return side
        end
    end
    return nil
end

--- Split a stacked magazine item into its sides and pick the side to seat. Nil for any other item.
---@param magazine InventoryItem
---@return GunworksStackedPack | nil
function StackedMagazines.ReadPack(magazine)
    local group = StackedMagazines.GetGroupForType(magazine:getFullType())
    if not group then
        return nil
    end
    local sides = #group.magazines
    local capacity = StackedMagazines.GetSideCapacity(group)
    local total = magazine:getCurrentAmmoCount()
    local modData = magazine:getModData()
    local list = fitList(copyList(modData.AmmoList), total, defaultRound(magazine))

    local rounds = {}
    for side = 1, sides do
        rounds[side] = 0
    end

    local kept = 0
    local saved = modData[StackedMagazines.STATE_KEY]
    if type(saved) == "table" and type(saved.rounds) == "table" then
        for side = 1, sides do
            rounds[side] = math.max(0, math.min(capacity, math.floor(tonumber(saved.rounds[side]) or 0)))
            kept = kept + rounds[side]
        end
        local unloaded = kept - total
        local side = sides
        while unloaded > 0 and side >= 1 do
            local taken = math.min(unloaded, rounds[side])
            rounds[side] = rounds[side] - taken
            unloaded = unloaded - taken
            side = side - 1
        end
        kept = math.min(kept, total)
    end

    local lists = {}
    local index = 0
    if list then
        for side = 1, sides do
            if rounds[side] > 0 then
                local sideList = {}
                for i = 1, rounds[side] do
                    sideList[i] = list[index + i]
                end
                lists[side] = sideList
            end
            index = index + rounds[side]
        end
    end

    for i = kept + 1, total do
        local side = lastSideWithRoom(rounds, capacity) or 1
        rounds[side] = rounds[side] + 1
        if list then
            lists[side] = lists[side] or {}
            lists[side][#lists[side] + 1] = list[i]
        end
    end

    return { group = group, side = firstLoadedSide(rounds) or 1, rounds = rounds, lists = lists }
end

--- The item type the pack goes in as (the side its insert seats), or nil for any other item.
---@param magazine InventoryItem
---@return string | nil
function StackedMagazines.GetSeatedType(magazine)
    local pack = StackedMagazines.ReadPack(magazine)
    return pack and pack.group.magazines[pack.side] or nil
end

--- Write a split onto a magazine item: its count, its sides and one AmmoList in side order.
---@param magazine InventoryItem
---@param group    GunworksStackedGroup
---@param rounds   integer[]
---@param lists    table<integer, string[]>
function StackedMagazines.WritePack(magazine, group, rounds, lists)
    local total = 0
    local named = false
    for side = 1, #group.magazines do
        total = total + (rounds[side] or 0)
        named = named or lists[side] ~= nil
    end

    local list = nil
    if named then
        local filler = defaultRound(magazine)
        list = {}
        for side = 1, #group.magazines do
            local count = rounds[side] or 0
            if count > 0 then
                local sideList = fitList(lists[side], count, filler)
                if not sideList then
                    list = nil
                    break
                end
                for i = 1, #sideList do
                    list[#list + 1] = sideList[i]
                end
            end
        end
    end

    local stored = {}
    for side = 1, #group.magazines do
        stored[side] = rounds[side] or 0
    end
    local modData = magazine:getModData()
    modData[StackedMagazines.STATE_KEY] = { group = group.name, rounds = stored }
    modData.AmmoList = copyList(list)
    magazine:setCurrentAmmoCount(total)
end

-------------------------------------------------
-- Packs in the gun (server / singleplayer)
-------------------------------------------------

---@param gun   HandWeapon
---@param group GunworksStackedGroup
---@param side  integer
local function setWellSide(gun, group, side)
    local magazineType = group.magazines[side]
    gun:setMagazineType(magazineType)
    Magazine.SaveMagazineType(gun, magazineType)
    gun:setMaxAmmo(StackedMagazines.GetSideCapacity(group))
end

--- The insert is about to load this pack: the item now holds only the side that goes in, and the gun keeps the
--- other sides. Returns what undoes it when the insert does not happen.
---@param gun      HandWeapon
---@param magazine InventoryItem
---@param pack     GunworksStackedPack
---@return table undo
function StackedMagazines.PresentSide(gun, magazine, pack)
    local modData = magazine:getModData()
    local undo = {
        count = magazine:getCurrentAmmoCount(),
        list = modData.AmmoList,
        gunState = gun:getModData()[StackedMagazines.STATE_KEY],
    }

    local rounds, lists = {}, {}
    for side = 1, #pack.group.magazines do
        rounds[side] = pack.rounds[side]
        lists[side] = copyList(pack.lists[side])
    end
    magazine:setCurrentAmmoCount(rounds[pack.side])
    modData.AmmoList = lists[pack.side]
    rounds[pack.side] = 0
    lists[pack.side] = nil

    gun:getModData()[StackedMagazines.STATE_KEY] = {
        group = pack.group.name,
        side = pack.side,
        rounds = rounds,
        lists = lists,
    }
    return undo
end

---@param gun      HandWeapon
---@param magazine InventoryItem
---@param undo     table
function StackedMagazines.UndoPresentSide(gun, magazine, undo)
    magazine:setCurrentAmmoCount(undo.count)
    magazine:getModData().AmmoList = undo.list
    gun:getModData()[StackedMagazines.STATE_KEY] = undo.gunState
end

--- The pack is in: the gun takes the side's item type and capacity.
---@param gun  HandWeapon
---@param pack GunworksStackedPack
function StackedMagazines.SeatPack(gun, pack)
    setWellSide(gun, pack.group, pack.side)
end

--- A magazine that is not a pack went in: forget the split of a pack that left without this system.
---@param gun HandWeapon
function StackedMagazines.ForgetGunState(gun)
    local modData = gun:getModData()
    if modData[StackedMagazines.STATE_KEY] ~= nil and not StackedMagazines.IsInGun(gun) then
        modData[StackedMagazines.STATE_KEY] = nil
    end
end

-- The gun's AmmoList without its chambered round, and that round.
---@param gun HandWeapon
---@return string[] | nil list
---@return string | nil chambered
local function splitChamber(gun)
    local list = copyList(gun:getModData().AmmoList)
    local chambered = nil
    if list and gun:isRoundChambered() then
        chambered = table.remove(list)
    end
    return copyList(list), chambered
end

--- Flip the next loaded side into the well. The chambered round stays.
---@param character IsoGameCharacter
---@param gun       HandWeapon
---@return boolean flipped
function StackedMagazines.FlipSides(character, gun)
    local state, group = StackedMagazines.GetGunState(gun)
    if not state then
        return false
    end
    local nextSide = StackedMagazines.GetNextSide(state, group)
    if not nextSide then
        return false
    end

    local rounds, lists = {}, {}
    for side = 1, #group.magazines do
        rounds[side] = tonumber(state.rounds[side]) or 0
        lists[side] = copyList(state.lists and state.lists[side])
    end
    local wellList, chambered = splitChamber(gun)
    rounds[state.side] = gun:getCurrentAmmoCount()
    lists[state.side] = wellList

    local seatedList = lists[nextSide] or {}
    if chambered then
        seatedList[#seatedList + 1] = chambered
    end
    gun:setCurrentAmmoCount(rounds[nextSide])
    rounds[nextSide] = 0
    lists[nextSide] = nil

    local modData = gun:getModData()
    modData.AmmoList = copyList(seatedList)
    modData[StackedMagazines.STATE_KEY] = { group = group.name, side = nextSide, rounds = rounds, lists = lists }
    setWellSide(gun, group, nextSide)

    syncHandWeaponFields(character, gun)
    Ammo.SyncAmmoListToClient(character, gun)
    return true
end

--- Take the whole pack out of the gun as a new item of the group's first type (not added anywhere). The chambered
--- round stays. A pack inserted before this system (no split) comes out whole and splits on its next insert.
---@param gun HandWeapon
---@return InventoryItem | nil
function StackedMagazines.TakePack(gun)
    if not StackedMagazines.IsInGun(gun) then
        return nil
    end
    local group = StackedMagazines.GetGroupForType(gun:getMagazineType())
    local state = StackedMagazines.GetGunState(gun)
    local wellList, chambered = splitChamber(gun)
    local pack = instanceItem(group.magazines[1])

    if state then
        local rounds, lists = {}, {}
        for side = 1, #group.magazines do
            rounds[side] = tonumber(state.rounds[side]) or 0
            lists[side] = copyList(state.lists and state.lists[side])
        end
        rounds[state.side] = gun:getCurrentAmmoCount()
        lists[state.side] = wellList
        StackedMagazines.WritePack(pack, group, rounds, lists)
    else
        pack:setCurrentAmmoCount(gun:getCurrentAmmoCount())
        pack:getModData().AmmoList = wellList
    end

    local modData = gun:getModData()
    modData[StackedMagazines.STATE_KEY] = nil
    modData.AmmoList = chambered and { chambered } or nil
    gun:setContainsClip(false)
    gun:setCurrentAmmoCount(0)
    gun:setMagazineType(group.magazines[1])
    gun:setMaxAmmo(pack:getMaxAmmo())
    Magazine.ClearMagazineType(gun)
    return pack
end

--- Eject the pack into the character's inventory (ISEjectMagazine).
---@param character IsoGameCharacter
---@param gun       HandWeapon
---@return InventoryItem | nil
function StackedMagazines.EjectPack(character, gun)
    local pack = StackedMagazines.TakePack(gun)
    if not pack then
        return nil
    end
    local inventory = character:getInventory()
    inventory:AddItem(pack)
    sendAddItemToContainer(inventory, pack)
    syncHandWeaponFields(character, gun)
    Ammo.SyncAmmoListToClient(character, gun)
    return pack
end

--- Keep the gun's capacity at one side while a split pack is in (Magazine.RestoreMagazineType resets it to the
--- item's MaxAmmo).
---@param gun HandWeapon
function StackedMagazines.ApplySideCapacity(gun)
    local state, group = StackedMagazines.GetGunState(gun)
    if state then
        gun:setMaxAmmo(StackedMagazines.GetSideCapacity(group))
    end
end

-------------------------------------------------
-- Reload key (client / singleplayer)
-------------------------------------------------

---@param playerObj IsoPlayer
---@param gun       HandWeapon
---@return boolean
local function isFlipQueued(playerObj, gun)
    local actions = ISTimedActionQueue.getTimedActionQueue(playerObj).queue
    for i = 1, #actions do
        local action = actions[i]
        if action.Type == "ISStackedMagazine" and action.gun:getID() == gun:getID() then
            return true
        end
    end
    return false
end

--- Flip whenever another side has rounds, even when the side in the well is full. A second press while a flip is
--- queued does nothing (it would flip straight back). False leaves the reload to the normal magazine swap (no split
--- pack, or every other side is empty), which takes the pack out and inserts the best magazine like any other.
---@param playerObj IsoPlayer
---@param gun       HandWeapon
---@return boolean handled
function StackedMagazines.BeginReload(playerObj, gun)
    local state, group = StackedMagazines.GetGunState(gun)
    if not state then
        return false
    end
    if isFlipQueued(playerObj, gun) then
        return true
    end
    if not StackedMagazines.GetNextSide(state, group) then
        return false
    end
    ISTimedActionQueue.add(ISStackedMagazine:new(playerObj, gun))
    return true
end

return StackedMagazines
