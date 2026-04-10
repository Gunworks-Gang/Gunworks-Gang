require "ISUI/ISFirearmRadialMenu"

local FoldingStock      = require("WeaponSystems/Utils/FoldingStockUtils")
local FoldingBipod      = require("WeaponSystems/Utils/FoldingBipodUtils")
local Bayonet           = require("WeaponSystems/Utils/BayonetUtils")
local DynamicAttachment = require("WeaponSystems/Utils/DynamicAttachmentUtils")
local Underbarrel       = require("WeaponSystems/Utils/UnderbarrelUtils")

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
    local isDeployed = Bayonet.IsIntegratedBayonetDeployed(weapon)
    local text = getText(isDeployed and "IGUI_FoldBayonet" or "IGUI_DeployBayonet")
    local icon = isDeployed and "media/ui/GunworksRadial_FoldBayonet.png" or "media/ui/GunworksRadial_DeployBayonet.png"
    menu:addSlice(text, getTexture(icon), self.invoke, self)
end

function CToggleIntegratedBayonet:invoke()
    local weapon = self:getWeapon()
    if not weapon then return end
    Bayonet.ToggleIntegratedBayonet(weapon)
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
    menu:addSlice(text, getTexture("media/ui/GunworksRadial_DeployBipod.png"), self.invoke, self)
end

function CAttachBayonet:invoke()
    local weapon = self:getWeapon()
    if not weapon or not self.bayonetKnife then return end
    if not Bayonet.CanAttachBayonet(weapon, self.bayonetKnife) then return end
    ISTimedActionQueue.add(ISBayonetAttach:new(self.character, weapon, self.bayonetKnife))
end

-------------------------------------------------
-- CToggleIntegratedUnderbarrel
-------------------------------------------------
local CToggleIntegratedUnderbarrel = BaseCommand:derive("CToggleIntegratedUnderbarrel")

function CToggleIntegratedUnderbarrel:new(frm)
    return BaseCommand.new(self, frm)
end

function CToggleIntegratedUnderbarrel:fillMenu(menu, weapon)
    if not Underbarrel.HasIntegratedUnderbarrel(weapon) then return end
    local isDeployed = Underbarrel.IsIntegratedUnderbarrelDeployed(weapon)
    local text = getText(isDeployed and "IGUI_StowUnderbarrel" or "IGUI_DeployUnderbarrel")
    local icon = isDeployed and "media/ui/GunworksRadial_StowUnderbarrel.png" or "media/ui/GunworksRadial_DeployUnderbarrel.png"
    menu:addSlice(text, getTexture(icon), self.invoke, self)
end

function CToggleIntegratedUnderbarrel:invoke()
    local weapon = self:getWeapon()
    if not weapon then return end
    Underbarrel.ToggleIntegratedUnderbarrel(weapon)
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
-- Helper: does this weapon have any Gunworks feature?
-------------------------------------------------
local function hasGunworksFeature(weapon, playerObj)
    if FoldingStock.HasFoldableStock(weapon) then return true end
    if FoldingBipod.HasFoldableBipod(weapon) then return true end
    if Bayonet.HasIntegratedBayonet(weapon) then return true end
    if Bayonet.CanRemoveBayonet(weapon) then return true end
    if Underbarrel.HasIntegratedUnderbarrel(weapon) then return true end
    if DynamicAttachment.HasSwappableAttachment(weapon) then return true end
    if Bayonet.BayonetMountableWeapons[weapon:getFullType()] then
        local inventory = playerObj:getInventory():getItems()
        for i = 0, inventory:size() - 1 do
            if Bayonet.CanAttachBayonet(weapon, inventory:get(i)) then return true end
        end
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
        CToggleIntegratedUnderbarrel:new(self),
        CSwapDynamicAttachment:new(self),
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
