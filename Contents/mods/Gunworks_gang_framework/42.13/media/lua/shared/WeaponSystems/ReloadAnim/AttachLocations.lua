-- Registers the in-hand reload-magazine attached-item location.
--
-- Done at file scope (not OnGameBoot) so it survives a Core.ResetLua the same way the vanilla
-- NPCs/AttachedLocations.lua does: a ResetLua re-runs every file, re-registering vanilla's
-- locations - and ours alongside them. (An OnGameBoot handler would not re-fire on a ResetLua,
-- e.g. an MP join, so the location would be missing afterwards and setAttachedItem would throw.)
--
-- Kept in its own small file so a registration error can never break the core reload-anim modules.
-- The location's attachmentName is Bip01_Prop2, the off-hand prop bone (reparented onto
-- Bip01_L_Hand, IsoPlayer.java:1210) that the secondary-hand weapon model uses - so the magazine
-- model follows the left hand through the reload animation.

local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")

if AttachedLocations then
    local humanGroup = AttachedLocations.getGroup("Human")
    if humanGroup then
        humanGroup:getOrCreateLocation(ReloadAnim.RELOAD_MAGAZINE_ATTACH_LOCATION):setAttachmentName("Bip01_Prop2")
        -- Second, independent slot for a hand-held reload prop (the musket's paper cartridge / ball)
        -- that must track the RIGHT hand. It CANNOT reuse the stock Bip01_Prop1 socket -- the engine
        -- attaches the primary-hand weapon MODEL there (AnimatedModel:625), so the prop would ride the gun
        -- rather than sit in the palm. Nor can it reuse the off-hand Bip01_Prop2 (the ramrod's slot). So it
        -- points at "GunworksReloadHand", a dedicated ModelAttachment we add to the FemaleBody/MaleBody
        -- ModelScripts (see client/.../HandAttachment.lua) bound to Bip01_R_Hand. An attached item resolves
        -- its parent attachment by name against the body ModelScript (ModelInstance.getAttachmentById ->
        -- ModelScript.attachmentById), so this only renders on a client that has actually run that
        -- registration -- which is why HandAttachment.lua now registers it with a bounded retry so a joining
        -- observer gets it too, not just the reloader. Fed by gwSetHandProp.
        humanGroup:getOrCreateLocation(ReloadAnim.RELOAD_HAND_ATTACH_LOCATION):setAttachmentName("GunworksReloadHand")
    end
end

return ReloadAnim
