-- Gunworks reload-animation framework: two-stroke racks for guns whose bolt locks back, such as the
-- HK family (MP5, G3). A profile with `splitRack = true` racks in two separate actions, each with its
-- own AnimSet node: an opening stroke that locks the bolt back, then a closing stroke that releases it.
--
--   empty reload (nothing chambered):  open -> eject (if a magazine is in) -> insert -> close
--   reload with a round chambered:      eject -> insert
--   manual rack:                        open -> close
--
-- The round handling comes from the AnimSet events, so a manual rack still ejects one round and
-- chambers one: with Hot Brass the opening stroke's ejectCasing ejects and the closing stroke's
-- chamberRound chambers; without it the closing stroke's vanilla rackBullet does both and the opening
-- stroke only animates. The gun remembers an open bolt in its mod data: the rack the insert queues then
-- only closes, and an interrupted reload resumes with a closing stroke. Every choice is made when an
-- action starts, so the stroke rides the anim snapshot to observers and the constructor argument to
-- the server, like the aim flag. Gate the AnimSet nodes on GunworksRackPhase = "open" / "close".
--
-- Open-to-load variant (`splitRack = true` plus `openToLoad = true`), for non-magazine guns that load
-- through an open action, such as bolt-action rifles. The bolt always opens before rounds go in,
-- whatever is chambered:
--
--   reload:       open -> load the rounds -> close
--   manual rack:  open -> close
--
-- The opening stroke is put in front of the load when the queue begins it, so every way of starting a
-- load (reload key, radial menu, inventory menu) opens the bolt first. A reload that cannot add a
-- round (magazine plus chamber already hold maxAmmo) is skipped, because opening ejects the chambered
-- round.

---@class GunworksReloadAnim
local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")

ReloadAnim.RACK_PHASE_VARIABLE = "GunworksRackPhase"
ReloadAnim.RACK_PHASE_OPEN = "open"
ReloadAnim.RACK_PHASE_CLOSE = "close"

local BOLT_OPEN_KEY = "gunworksBoltOpen"

---@param handler GunworksReloadAnimHandler|nil
---@nodiscard
---@return boolean
function ReloadAnim.isSplitRackHandler(handler)
    return handler ~= nil and handler.splitRack == true
end

---@param handler GunworksReloadAnimHandler|nil
---@nodiscard
---@return boolean
function ReloadAnim.isOpenToLoadHandler(handler)
    return ReloadAnim.isSplitRackHandler(handler) and handler.openToLoad == true
end

---@param gun HandWeapon|nil
---@nodiscard
---@return boolean
function ReloadAnim.isBoltOpen(gun)
    local modData = gun and gun:getModData()
    return modData ~= nil and modData[BOLT_OPEN_KEY] == true
end

---@param gun HandWeapon|nil
---@param open boolean
---@return nil
function ReloadAnim.setBoltOpen(gun, open)
    local modData = gun and gun:getModData()
    if modData then
        modData[BOLT_OPEN_KEY] = open and true or nil
    end
end

--- Does a reload of this gun start with an opening stroke? True for a split-rack gun with nothing
--- chambered and its bolt still closed, when the reload will queue an eject or an insert: the gun
--- holds a magazine, or there is a magazine to insert.
---@param playerObj IsoPlayer
---@param gun HandWeapon|nil
---@param bestMagazine fun(playerObj:IsoPlayer, gun:HandWeapon):InventoryItem|nil
---@nodiscard
---@return boolean
function ReloadAnim.shouldOpenBoltBeforeReload(playerObj, gun, bestMagazine)
    if not instanceof(gun, "HandWeapon") or not gun:getMagazineType() or not gun:haveChamber() then
        return false
    end
    if gun:isRoundChambered() or ReloadAnim.isBoltOpen(gun) then
        return false
    end
    if not ReloadAnim.isSplitRackHandler(ReloadAnim.GetHandlerForGun(gun)) then
        return false
    end
    return gun:isContainsClip() or bestMagazine(playerObj, gun) ~= nil
end

--- Pick this rack's stroke when its creator did not: close a bolt that is already open; otherwise
--- open it now and queue the closing stroke right after (a full rack). Runs where the action queue
--- lives (client or singleplayer start); the server receives the result as a constructor argument.
---@param action ISRackFirearm
---@return string
function ReloadAnim.chooseRackPhase(action)
    if not action.gunworksRackPhase then
        if ReloadAnim.isBoltOpen(action.gun) then
            action.gunworksRackPhase = ReloadAnim.RACK_PHASE_CLOSE
        else
            action.gunworksRackPhase = ReloadAnim.RACK_PHASE_OPEN
            ISTimedActionQueue.addAfter(action,
                ISRackFirearm:new(action.character, action.gun, ReloadAnim.RACK_PHASE_CLOSE))
        end
    end
    return action.gunworksRackPhase
end

--- Start the opening stroke: vanilla ISRackFirearm:start without its canRack gate (an empty gun can
--- still lock its bolt back) and without ejectSpentRounds (Hot Brass chambers a round there).
---@param action ISRackFirearm
---@return nil
function ReloadAnim.startOpeningStroke(action)
    local character = action.character
    if isClient() then
        action.gun = character:getInventory():getItemById(action.gun:getID())
    end
    action:setAnimVariable("isRacking", true)
    action:setAnimVariable("RackAiming", character:isAiming())
    if character:isAiming() then
        character:setAimingDelay(character:getAimingDelay()
            + action.gun:getAimingTime() * (0.15 - character:getPerkLevel(Perks.Reloading) * 0.01))
    end
    action:setOverrideHandModels(action.gun, nil)
    action:setActionAnim(CharacterActionAnims.Reload)
    character:reportEvent("EventReloading")
    action:initVars()
end

--- Record the bolt position once a stroke has finished.
---@param action ISRackFirearm
---@return boolean opened true when this was an opening stroke
function ReloadAnim.finishRackStroke(action)
    if not action.gunworksRackPhase or not ReloadAnim.isSplitRackHandler(ReloadAnim.getHandlerForAction(action)) then
        return false
    end
    local opened = action.gunworksRackPhase == ReloadAnim.RACK_PHASE_OPEN
    ReloadAnim.setBoltOpen(action.gun, opened)
    return opened
end

--- Open-to-load: would a reload add nothing? Opening ejects the chambered round, so a magazine plus
--- chambered round that already make maxAmmo is as full as the gun gets.
---@param gun HandWeapon|nil
---@nodiscard
---@return boolean
function ReloadAnim.isFullForOpenToLoad(gun)
    if not instanceof(gun, "HandWeapon") or gun:getMagazineType() then
        return false
    end
    if not ReloadAnim.isOpenToLoadHandler(ReloadAnim.GetHandlerForGun(gun)) then
        return false
    end
    local chambered = (gun:haveChamber() and gun:isRoundChambered()) and 1 or 0
    return gun:getCurrentAmmoCount() + chambered >= gun:getMaxAmmo()
end

--- The queue is about to begin a load of an open-to-load gun. With the bolt closed, put an opening
--- stroke in front of the load and begin that instead; once it completes, the queue begins the load
--- again and this returns false. Runs where the action queue lives (client or singleplayer), before
--- the load is created or sent to the server.
---@param action ISReloadWeaponAction
---@return boolean true when the opening stroke began in place of the load
function ReloadAnim.openBoltBeforeLoad(action)
    if action.gunworksBoltOpenedForLoad or ReloadAnim.isBoltOpen(action.gun)
        or not ReloadAnim.isOpenToLoadHandler(ReloadAnim.getHandlerForAction(action)) then
        return false
    end
    if not ISTimedActionQueue or not ISTimedActionQueue.getTimedActionQueue then
        return false
    end
    local queue = ISTimedActionQueue.getTimedActionQueue(action.character)
    local index = queue:indexOf(action)
    if index == -1 then
        return false
    end
    action.gunworksBoltOpenedForLoad = true
    local opening = ISRackFirearm:new(action.character, action.gun, ReloadAnim.RACK_PHASE_OPEN)
    table.insert(queue.queue, index, opening)
    queue.current = opening
    opening:begin()
    return true
end

--- After the last round, queue the closing stroke of an open-to-load gun, unless a rack is already
--- coming: vanilla queues one itself while no round is chambered (singleplayer loadAmmo, client perform).
---@param action ISReloadWeaponAction
---@return nil
function ReloadAnim.closeBoltAfterLoad(action)
    local gun = action.gun
    if not ReloadAnim.isBoltOpen(gun) or not ReloadAnim.isOpenToLoadHandler(ReloadAnim.getHandlerForAction(action)) then
        return
    end
    if ISTimedActionQueue.hasActionType(action.character, "ISRackFirearm") then
        return
    end
    if isClient() and gun:haveChamber() and not gun:isRoundChambered() then
        return
    end
    ISTimedActionQueue.addAfter(action, ISRackFirearm:new(action.character, gun, ReloadAnim.RACK_PHASE_CLOSE))
end

--- Is this load running with the bolt of an open-to-load gun held open? Its complete and stop close the
--- bolt visual, so the caller puts it back.
---@param action ISReloadWeaponAction
---@nodiscard
---@return boolean
function ReloadAnim.isBoltHeldOpenForLoad(action)
    return ReloadAnim.isBoltOpen(action.gun) and ReloadAnim.isOpenToLoadHandler(ReloadAnim.getHandlerForAction(action))
end

return ReloadAnim
