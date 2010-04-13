local ADDON_NAME, namespace = ...

local L = LibStub("AceLocale-3.0"):NewLocale(ADDON_NAME, "enUS", true)

if not L then return end

L["Font Colors"]	= true
L["Active"]		= true
L["Inactive"]		= true
L["Alert"]		= true

L["Hide Tab Border"]	= true
L["Hides the tab border, leaving only the text visible."]	= true

L["Always Show"]	= true
L["Toggles between always showing the tab or only showing it on mouse-over."]	= true

L["Fade Inactive"]	= true
L["The name of inactive tabs will be faded."]	= true
