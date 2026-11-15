local index = __classmetatables[HandWeapon.class].__index
local originalDoTooltip = index.DoTooltip

index.DoTooltip = function(weapon, tooltip, ...)
    originalDoTooltip(weapon, tooltip, ...)
    if select("#", ...) == 0 and weapon:getModData().gunworksBoltOpen == true then
        local color = getCore():getBadHighlitedColor()
        local layout = tooltip:beginLayout()
        layout:addItem():setLabel(getText("IGUI_ChamberOpen"), color:getR(), color:getG(), color:getB(), 1.0)
        local endY = layout:render(5, tooltip:getHeight() - 5, tooltip)
        tooltip:endLayout(layout)
        tooltip:setHeight(endY + 5)
    end
end
