local ADDON_NAME, namespace = ...

local L = LibStub("AceLocale-3.0"):NewLocale(ADDON_NAME, "enUS", true)

if not L then return end

L["Classic"]		= true
L["Large"]		= true
L["Outline"]		= true
L["Bold Outline"]	= true

L["Font Colors"]	= true
L["Active"]		= true
L["Inactive"]		= true
L["Alert"]		= true

L["Hide Border"]	= true
L["Hides the tab border, leaving only the text visible."]	= true

L["Always Show"]	= true
L["Toggles between always showing the tab or only showing it on mouse-over."]	= true

L["Fade Inactive"]	= true
L["Fades the name of inactive tabs."]	= true

L["Tab Options"]	= true
L["Alert Options"]	= true
L["Changes the appearance of the pulsing alert flash."]	= true
L["Disables the pulsing alert flash."]	= true
