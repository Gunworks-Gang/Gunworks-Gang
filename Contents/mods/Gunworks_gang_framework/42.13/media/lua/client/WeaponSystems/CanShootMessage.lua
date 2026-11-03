Events.OnWeaponSwing.Add(
    function(player, weapon)
        if player and weapon and weapon:getModData().gunworksBoltOpen == true then
            player:Say(getText("Weapon is Open, Rack it to close"), 0.25, 0.25, 0.25, UIFont.Dialogue, 0, "default")
        end
    end
)
