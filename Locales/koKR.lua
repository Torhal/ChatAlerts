﻿local ADDON_NAME, namespace = ...

local L = LibStub("AceLocale-3.0"):NewLocale(ADDON_NAME, "koKR", false)

if not L then return end

--@localization(locale="koKR", format="lua_additive_table", handle-unlocalized="ignore", escape-non-ascii=false, same-key-is-true=true)@