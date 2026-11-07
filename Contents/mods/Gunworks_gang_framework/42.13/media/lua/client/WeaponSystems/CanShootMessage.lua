Events.OnWeaponSwing.Add(
    function(player, weapon)
        if player and weapon and weapon:getModData().gunworksBoltOpen == true then
            player:Say(getText("Chamber is open, close it before firing."), 0.15, 0.15, 0.15, UIFont.Dialogue, 0, "default")
        end
    end
)
