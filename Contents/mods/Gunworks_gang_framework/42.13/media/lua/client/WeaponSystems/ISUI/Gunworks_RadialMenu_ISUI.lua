require "ISUI/ISFirearmRadialMenu"

local FoldingStock      = require("WeaponSystems/Utils/FoldingStock")
local FoldingBipod      = require("WeaponSystems/Utils/FoldingBipod")
local Bayonet           = require("WeaponSystems/Utils/Bayonet")
local DynamicAttachment = require("WeaponSystems/Utils/DynamicAttachment")
local Underbarrel       = require("WeaponSystems/Utils/Underbarrel")
local Magazine          = require("WeaponSystems/Utils/Magazine")
local Ammo              = require("WeaponSystems/Utils/Ammo")
local RateOfFireUI      = require("WeaponSystems/ISUI/RateOfFire_ISUI")

-------------------------------------------------
-- BaseCommand  (mirrors ISFirearmRadialMenu pattern)
-- frm = ISFirearmRadialMenu instance
-------------------------------------------------
local BaseCommand       = ISBaseObject:derive("BaseCommand")

function BaseCommand:new(frm)
    local o = ISBaseObject.new(self)
    o.frm = frm
    o.character = frm.character
    return o
end

function BaseCommand:getWeapon()
    return self.frm:getWeapon()
end

-------------------------------------------------
-- CFoldStock
-------------------------------------------------
local CFoldStock = BaseCommand:derive("CFoldStock")

function CFoldStock:new(frm)
    return BaseCommand.new(self, frm)
end

function CFoldStock:fillMenu(menu, weapon)
    if not FoldingStock.HasFoldableStock(weapon) then return end
    local isFolded = FoldingStock.IsStockFolded(weapon)
    local text = getText(isFolded and "IGUI_UnfoldStock" or "IGUI_FoldStock")
    local icon = isFolded and "media/ui/GunworksRadial_UnfoldStock.png" or "media/ui/GunworksRadial_FoldStock.png"
    menu:addSlice(text, getTexture(icon), self.invoke, self)
end

function CFoldStock:invoke()
    local weapon = self:getWeapon()
    if not weapon then return end
    ISTimedActionQueue.add(ISFoldStock:new(self.character, weapon, CharacterActionAnims.Craft))
end

-------------------------------------------------
-- CDeployBipod
-------------------------------------------------
local CDeployBipod = BaseCommand:derive("CDeployBipod")

function CDeployBipod:new(frm)
    return BaseCommand.new(self, frm)
end

function CDeployBipod:fillMenu(menu, weapon)
    if not FoldingBipod.HasFoldableBipod(weapon) then return end
    local isDeployed = FoldingBipod.IsBipodDeployed(weapon)
    local text = getText(isDeployed and "IGUI_FoldBipod" or "IGUI_DeployBipod")
    local icon = isDeployed and "media/ui/GunworksRadial_FoldBipod.png" or "media/ui/GunworksRadial_DeployBipod.png"
    menu:addSlice(text, getTexture(icon), self.invoke, self)
end

function CDeployBipod:invoke()
    local weapon = self:getWeapon()
    if not weapon then return end
    ISTimedActionQueue.add(ISFoldBipod:new(self.character, weapon, CharacterActionAnims.Craft))
end

-------------------------------------------------
-- CToggleIntegratedBayonet
-------------------------------------------------
local CToggleIntegratedBayonet = BaseCommand:derive("CToggleIntegratedBayonet")

function CToggleIntegratedBayonet:new(frm)
    return BaseCommand.new(self, frm)
end

function CToggleIntegratedBayonet:fillMenu(menu, weapon)
    if not Bayonet.HasIntegratedBayonet(weapon) then return end
    local isDeployed = Bayonet.IsBayonetDeployed(weapon)
    local text = getText(isDeployed and "IGUI_FoldBayonet" or "IGUI_DeployBayonet")
    local icon = isDeployed and "media/ui/GunworksRadial_FoldBayonet.png" or "media/ui/GunworksRadial_DeployBayonet.png"
    menu:addSlice(text, getTexture(icon), self.invoke, self)
end

function CToggleIntegratedBayonet:invoke()
    local weapon = self:getWeapon()
    if not weapon then return end
    if self.character:getPrimaryHandItem() ~= weapon then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(self.character, weapon, 50, true, true))
    end
    ISTimedActionQueue.add(ISToggleIntegratedBayonet:new(self.character, weapon, CharacterActionAnims.Craft))
end

-------------------------------------------------
-- CRemoveBayonet
-------------------------------------------------
local CRemoveBayonet = BaseCommand:derive("CRemoveBayonet")

function CRemoveBayonet:new(frm)
    return BaseCommand.new(self, frm)
end

function CRemoveBayonet:fillMenu(menu, weapon)
    if not Bayonet.CanRemoveBayonet(weapon) then return end
    local text = getText("IGUI_RemoveBayonet")
    menu:addSlice(text, getTexture("media/ui/GunworksRadial_FoldBayonet.png"), self.invoke, self)
end

function CRemoveBayonet:invoke()
    local weapon = self:getWeapon()
    if not weapon then return end
    ISTimedActionQueue.add(ISBayonetRemove:new(self.character, weapon))
end

-------------------------------------------------
-- CAttachBayonet
-- Picks the first compatible knife in inventory.
-- For multiple knife types the context menu remains the fallback.
-------------------------------------------------
local CAttachBayonet = BaseCommand:derive("CAttachBayonet")

function CAttachBayonet:new(frm)
    local o = BaseCommand.new(self, frm)
    o.bayonetKnife = nil
    return o
end

function CAttachBayonet:findBestKnife(weapon)
    local inventory = self.character:getInventory():getItems()
    for i = 0, inventory:size() - 1 do
        local invItem = inventory:get(i)
        if Bayonet.CanAttachBayonet(weapon, invItem) then
            return invItem
        end
    end
    return nil
end

function CAttachBayonet:fillMenu(menu, weapon)
    if Bayonet.CanRemoveBayonet(weapon) then return end
    local knife = self:findBestKnife(weapon)
    if not knife then return end
    self.bayonetKnife = knife
    local text = getText("IGUI_AttachBayonet")
    menu:addSlice(text, getTexture("media/ui/GunworksRadial_DeployBayonet.png"), self.invoke, self)
end

function CAttachBayonet:invoke()
    local weapon = self:getWeapon()
    if not weapon or not self.bayonetKnife then return end
    if not Bayonet.CanAttachBayonet(weapon, self.bayonetKnife) then return end
    ISTimedActionQueue.add(ISBayonetAttach:new(self.character, weapon, self.bayonetKnife))
end

-------------------------------------------------
-- CToggleUnderbarrelMode
-------------------------------------------------
local CToggleUnderbarrelMode = BaseCommand:derive("CToggleUnderbarrelMode")

function CToggleUnderbarrelMode:new(frm)
    return BaseCommand.new(self, frm)
end

function CToggleUnderbarrelMode:fillMenu(menu, weapon)
    if not Underbarrel.CanToggleUnderbarrel(weapon) then return end
    local isUnderbarrelMode = Underbarrel.IsWeaponInUnderbarrelMode(weapon)
    local text = getText(isUnderbarrelMode and "IGUI_UseMainWeapon" or "IGUI_UseUnderbarrel")
    menu:addSlice(text, getTexture("media/ui/GunworksRadial_Underbarrel.png"), self.invoke, self)
end

function CToggleUnderbarrelMode:invoke()
    local weapon = self:getWeapon()
    if not weapon then return end
    Underbarrel.ToggleUnderbarrel(weapon, self.character)
end

-------------------------------------------------
-- CSwapDynamicAttachment
-------------------------------------------------
local CSwapDynamicAttachment = BaseCommand:derive("CSwapDynamicAttachment")

function CSwapDynamicAttachment:new(frm)
    return BaseCommand.new(self, frm)
end

function CSwapDynamicAttachment:fillMenu(menu, weapon)
    if not DynamicAttachment.HasSwappableAttachment(weapon) then return end
    local partnerType, _, currentPart = DynamicAttachment.GetSwappableAttachment(weapon)
    if not partnerType or not currentPart then return end
    local partnerScript = ScriptManager.instance:getItem(partnerType)
    local partnerName = partnerScript and partnerScript:getDisplayName() or partnerType
    local text = getText("IGUI_SwapAttachment", partnerName)
    menu:addSlice(text, getTexture("media/ui/GunworksRadial_SwapAttachment.png"), self.invoke, self)
end

function CSwapDynamicAttachment:invoke()
    local weapon = self:getWeapon()
    if not weapon then return end
    ISTimedActionQueue.add(ISSwapAttachment:new(self.character, weapon, CharacterActionAnims.Craft))
end

-------------------------------------------------
-- Magazine sub-radial helpers
-------------------------------------------------

-- Returns {magType, item (fullest)} for each profile mag type the player has.
local function getAvailableMagazineTypes(playerObj, gun)
    local typeList = Magazine.GetMagazineTypesForGun(gun)
    if not typeList then return {} end
    local inv = playerObj:getInventory()
    local results = {}
    for _, magType in ipairs(typeList) do
        local best = nil
        local items = inv:getAllTypeRecurse(magType)
        if items then
            for i = 0, items:size() - 1 do
                local mag = items:get(i)
                if mag and (not best or mag:getCurrentAmmoCount() > best:getCurrentAmmoCount()) then
                    best = mag
                end
            end
        end
        if best then
            table.insert(results, { magType = magType, item = best })
        end
    end
    return results
end

-- Returns {bulletType, name, count} for each ammo type the player can load into magItem.
local function getAvailableAmmoTypesForMag(playerObj, magItem)
    local family = Ammo.ItemAmmoFamily[magItem:getFullType()]
    if not family then return {} end
    local typeList = Ammo.GetBulletTypesForFamily(family)
    if not typeList then return {} end
    local freeSpace = magItem:getMaxAmmo() - magItem:getCurrentAmmoCount()
    local results = {}
    for _, bulletType in ipairs(typeList) do
        local toLoad = math.min(playerObj:getInventory():getItemCountRecurse(bulletType), freeSpace)
        if toLoad > 0 then
            local script = ScriptManager.instance:getItem(bulletType)
            local name = script and script:getDisplayName() or bulletType
            local ammoItem = playerObj:getInventory():getFirstTypeRecurse(bulletType)
            local tex = ammoItem and ammoItem:getTex()
            table.insert(results, { bulletType = bulletType, name = name, count = toLoad, tex = tex })
        end
    end
    return results
end

-- Centre and show the shared radial for playerNum.
local function displaySubRadial(playerNum)
    local menu = getPlayerRadialMenu(playerNum)
    local cx = getPlayerScreenLeft(playerNum) + getPlayerScreenWidth(playerNum) / 2
    local cy = getPlayerScreenTop(playerNum) + getPlayerScreenHeight(playerNum) / 2
    menu:setX(cx - menu:getWidth() / 2)
    menu:setY(cy - menu:getHeight() / 2)
    menu:addToUIManager()
end

-- Called when player picks an ammo type from the third radial.
local function onAmmoTypeSelected(character, weapon, magItem, bulletType)
    ISInventoryPaneContextMenu.transferIfNeeded(character, magItem)
    local freeSpace = magItem:getMaxAmmo() - magItem:getCurrentAmmoCount()
    local ammoCount = math.min(character:getInventory():getItemCountRecurse(bulletType), freeSpace)
    if ammoCount <= 0 then return end
    local items = character:getInventory():getSomeTypeRecurse(bulletType, ammoCount)
    ISInventoryPaneContextMenu.transferIfNeeded(character, items)
    Ammo.MagazineAmmoProfileSetter(magItem, bulletType)
    ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(character, magItem, ammoCount))
    ISTimedActionQueue.add(ISInsertMagazine:new(character, weapon, magItem))
end

-- Called when player picks a magazine type from the second radial.
local function onMagazineTypeSelected(character, weapon, magItem, playerNum)
    local ammoTypes = getAvailableAmmoTypesForMag(character, magItem)
    if #ammoTypes > 1 then
        -- Open ammo-type sub-radial.
        local menu = getPlayerRadialMenu(playerNum)
        menu:clear()
        for _, entry in ipairs(ammoTypes) do
            local text = entry.name .. "\n" .. entry.count
            menu:addSlice(text, entry.tex, onAmmoTypeSelected, character, weapon, magItem, entry.bulletType)
        end
        displaySubRadial(playerNum)
    else
        -- Direct insert: load the one available ammo type (if any), then insert.
        ISInventoryPaneContextMenu.transferIfNeeded(character, magItem)
        if #ammoTypes == 1 then
            local at = ammoTypes[1]
            local items = character:getInventory():getSomeTypeRecurse(at.bulletType, at.count)
            ISInventoryPaneContextMenu.transferIfNeeded(character, items)
            Ammo.MagazineAmmoProfileSetter(magItem, at.bulletType)
            ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(character, magItem, at.count))
        end
        ISTimedActionQueue.add(ISInsertMagazine:new(character, weapon, magItem))
    end
end

-------------------------------------------------
-- CInsertMagazineProfile
-- Shown when the weapon has a Gunworks magazine
-- profile with multiple types.  Drives the
-- magazine → ammo selection sub-radials.
-------------------------------------------------
local CInsertMagazineProfile = BaseCommand:derive("CInsertMagazineProfile")

function CInsertMagazineProfile:new(frm)
    return BaseCommand.new(self, frm)
end

function CInsertMagazineProfile:fillMenu(menu, weapon)
    if weapon:isContainsClip() then return end
    if Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return end
    local typeList = Magazine.GetMagazineTypesForGun(weapon)
    if not typeList or #typeList < 2 then return end
    local available = getAvailableMagazineTypes(self.character, weapon)
    if #available == 0 then return end
    local text = getText("IGUI_SelectMagazine")
    menu:addSlice(text, getTexture("media/ui/GunworksRadial_SelectMagazine.png"), self.invoke, self)
end

function CInsertMagazineProfile:invoke()
    local weapon = self:getWeapon()
    if not weapon then return end
    local available = getAvailableMagazineTypes(self.character, weapon)
    if #available == 0 then return end
    local playerNum = self.character:getPlayerNum()
    if #available == 1 then
        -- Skip sub-radial, go straight to mag selection logic.
        onMagazineTypeSelected(self.character, weapon, available[1].item, playerNum)
        return
    end
    local menu = getPlayerRadialMenu(playerNum)
    menu:clear()
    for _, entry in ipairs(available) do
        local script = ScriptManager.instance:getItem(entry.magType)
        local name   = script and script:getDisplayName() or entry.magType
        local text   = name .. "\n" .. entry.item:getCurrentAmmoCount() .. "/" .. entry.item:getMaxAmmo()
        menu:addSlice(text, entry.item:getTex(),
            onMagazineTypeSelected, self.character, weapon, entry.item, playerNum)
    end
    displaySubRadial(playerNum)
end

-------------------------------------------------
-- Direct-bullet ammo selection helpers
-------------------------------------------------

-- Returns {bulletType, name, count, tex} for each Gunworks ammo type
-- the player can load directly into a non-magazine weapon.
local function getAvailableAmmoTypesForWeapon(playerObj, weapon)
    local family = Ammo.ItemAmmoFamily[weapon:getFullType()]
    if not family then return {} end
    local typeList = Ammo.GetBulletTypesForFamily(family)
    if not typeList then return {} end
    local freeSpace = weapon:getMaxAmmo() - weapon:getCurrentAmmoCount()
    local results = {}
    for _, bulletType in ipairs(typeList) do
        local toLoad = math.min(playerObj:getInventory():getItemCountRecurse(bulletType), freeSpace)
        if toLoad > 0 then
            local script = ScriptManager.instance:getItem(bulletType)
            local name = script and script:getDisplayName() or bulletType
            local ammoItem = playerObj:getInventory():getFirstTypeRecurse(bulletType)
            local tex = ammoItem and ammoItem:getTex()
            table.insert(results, { bulletType = bulletType, name = name, count = toLoad, tex = tex })
        end
    end
    return results
end

-- Called when player picks an ammo type from the direct-fire ammo sub-radial.
-- Tops off the remaining free space with the chosen bullet type.
local function onDirectAmmoTypeSelected(character, weapon, bulletType)
    ISInventoryPaneContextMenu.transferBullets(character, bulletType, weapon:getCurrentAmmoCount(), weapon:getMaxAmmo())
    ISInventoryPaneContextMenu.equipWeapon(weapon, true, false, character:getPlayerNum())
    Ammo.AmmoProfileSetter(weapon, bulletType)
    ISTimedActionQueue.add(ISReloadWeaponAction:new(character, weapon))
end

local function getFiremodeRadialTexture(entry)
    return getTexture("media/ui/GunworksRadial_FireMode_" .. entry.modeKey .. ".png")
        or getTexture("media/ui/GunworksRadial_ChangeFireMode.png")
end

local function onFiremodeSelected(character, weapon, firemode)
    RateOfFireUI.ApplyFiremode(character, weapon, firemode)
end

-------------------------------------------------
-- CSelectAmmunition
-- Shown on non-magazine weapons that have a
-- Gunworks ammo family with 2+ available types.
-------------------------------------------------
local CSelectAmmunition = BaseCommand:derive("CSelectAmmunition")

function CSelectAmmunition:new(frm)
    return BaseCommand.new(self, frm)
end

function CSelectAmmunition:fillMenu(menu, weapon)
    if weapon:getMagazineType() then return end
    local available = getAvailableAmmoTypesForWeapon(self.character, weapon)
    if #available == 0 then return end
    local text = getText("IGUI_SelectAmmunition")
    menu:addSlice(text, getTexture("media/ui/GunworksRadial_SelectAmmunition.png"), self.invoke, self)
end

function CSelectAmmunition:invoke()
    local weapon = self:getWeapon()
    if not weapon then return end
    local available = getAvailableAmmoTypesForWeapon(self.character, weapon)
    if #available == 0 then return end
    local playerNum = self.character:getPlayerNum()
    local menu = getPlayerRadialMenu(playerNum)
    menu:clear()
    for _, entry in ipairs(available) do
        local text = entry.name .. "\n" .. entry.count
        menu:addSlice(text, entry.tex, onDirectAmmoTypeSelected, self.character, weapon, entry.bulletType)
    end
    displaySubRadial(playerNum)
end

-------------------------------------------------
-- CChangeFireMode
-- Shows a sub-radial with the available fire
-- modes when the weapon supports 2+ modes.
-------------------------------------------------
local CChangeFireMode = BaseCommand:derive("CChangeFireMode")

function CChangeFireMode:new(frm)
    return BaseCommand.new(self, frm)
end

function CChangeFireMode:fillMenu(menu, weapon)
    if not RateOfFireUI.HasMultipleFiremodes(weapon) then return end
    local text = getText("ContextMenu_ChangeFireMode")
    menu:addSlice(text, getTexture("media/ui/GunworksRadial_ChangeFireMode.png"), self.invoke, self)
end

function CChangeFireMode:invoke()
    local weapon = self:getWeapon()
    if not weapon then return end

    local entries = RateOfFireUI.GetSelectableFiremodeEntries(weapon)
    if #entries == 0 then return end

    local playerNum = self.character:getPlayerNum()
    local menu = getPlayerRadialMenu(playerNum)
    menu:clear()

    for _, entry in ipairs(entries) do
        menu:addSlice(entry.label, getFiremodeRadialTexture(entry),
            onFiremodeSelected, self.character, weapon, entry.mode)
    end

    displaySubRadial(playerNum)
end

-------------------------------------------------
-- Helper: does this weapon have any Gunworks feature?
-------------------------------------------------
local function hasGunworksFeature(weapon, playerObj)
    if FoldingStock.HasFoldableStock(weapon) then return true end
    if FoldingBipod.HasFoldableBipod(weapon) then return true end
    if Bayonet.HasIntegratedBayonet(weapon) then return true end
    if Bayonet.CanRemoveBayonet(weapon) then return true end
    if Underbarrel.CanToggleUnderbarrel(weapon) then return true end
    if DynamicAttachment.HasSwappableAttachment(weapon) then return true end
    if RateOfFireUI.HasMultipleFiremodes(weapon) then return true end
    if Bayonet.BayonetMountableWeapons[weapon:getFullType()] then
        local inventory = playerObj:getInventory():getItems()
        for i = 0, inventory:size() - 1 do
            if Bayonet.CanAttachBayonet(weapon, inventory:get(i)) then return true end
        end
    end
    local magTypeList = Magazine.GetMagazineTypesForGun(weapon)
    if magTypeList and #magTypeList > 1 then
        local inv = playerObj:getInventory()
        for _, magType in ipairs(magTypeList) do
            if inv:getFirstTypeRecurse(magType) then return true end
        end
    end
    if not weapon:getMagazineType() then
        if #getAvailableAmmoTypesForWeapon(playerObj, weapon) > 0 then return true end
    end
    return false
end

-------------------------------------------------
-- Patch ISFirearmRadialMenu.fillMenu
-- Calls vanilla first so reload slices are built,
-- then appends applicable Gunworks slices.
-------------------------------------------------
local ISFirearmRadialMenu_fillMenu_orig = ISFirearmRadialMenu.fillMenu

function ISFirearmRadialMenu:fillMenu()
    ISFirearmRadialMenu_fillMenu_orig(self)

    local weapon = self.character:getPrimaryHandItem()
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then return end
    if not hasGunworksFeature(weapon, self.character) then return end

    local menu = getPlayerRadialMenu(self.playerNum)

    local commands = {
        CFoldStock:new(self),
        CDeployBipod:new(self),
        CToggleIntegratedBayonet:new(self),
        CRemoveBayonet:new(self),
        CAttachBayonet:new(self),
        CToggleUnderbarrelMode:new(self),
        CChangeFireMode:new(self),
        CSwapDynamicAttachment:new(self),
        CInsertMagazineProfile:new(self),
        CSelectAmmunition:new(self),
    }

    for _, command in ipairs(commands) do
        command:fillMenu(menu, weapon)
    end
end

-------------------------------------------------
-- Patch ISFirearmRadialMenu.checkWeapon
-- Ensures the R-key radial activates for weapons
-- that have Gunworks features.
-------------------------------------------------
local ISFirearmRadialMenu_checkWeapon_orig = ISFirearmRadialMenu.checkWeapon

function ISFirearmRadialMenu.checkWeapon(playerObj)
    if ISFirearmRadialMenu_checkWeapon_orig(playerObj) then return true end
    local weapon = playerObj:getPrimaryHandItem()
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then return false end
    return hasGunworksFeature(weapon, playerObj)
end
