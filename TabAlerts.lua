-------------------------------------------------------------------------------
-- Localized Lua globals.
-------------------------------------------------------------------------------
local _G = getfenv(0)

local string = _G.string

local pairs = _G.pairs
local ipairs = _G.ipairs

-------------------------------------------------------------------------------
-- Addon namespace
-------------------------------------------------------------------------------
local ADDON_NAME, namespace = ...

local LibStub	= _G.LibStub
local TabAlerts	= LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0")
local LDB	= LibStub("LibDataBroker-1.1")
local L		= LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

local debugger	= _G.tekDebug and _G.tekDebug:GetFrame(ADDON_NAME)

-------------------------------------------------------------------------------
-- Constants.
-------------------------------------------------------------------------------
local LISTEN_EVENTS = {
	-------------------------------------------------------------------------------
	-- Player chat.
	-------------------------------------------------------------------------------
	["ACHIEVEMENT"]			= "CHAT_MSG_ACHIEVEMENT",
	["BATTLEGROUND"]		= "CHAT_MSG_BATTLEGROUND",
	["BATTLEGROUND_LEADER"]		= "CHAT_MSG_BATTLEGROUND_LEADER",
	["EMOTE"]			= "CHAT_MSG_EMOTE",
	["GUILD"]			= "CHAT_MSG_GUILD",
	["GUILD_OFFICER"]		= "CHAT_MSG_OFFICER",
	["GUILD_ACHIEVEMENT"]		= "CHAT_MSG_GUILD_ACHIEVEMENT",
	["PARTY"]			= "CHAT_MSG_PARTY",
	["PARTY_LEADER"]		= "CHAT_MSG_PARTY_LEADER",
	["RAID"]			= "CHAT_MSG_RAID",
	["RAID_LEADER"]			= "CHAT_MSG_RAID_LEADER",
	["RAID_WARNING"]		= "CHAT_MSG_RAID_WARNING",
	["SAY"]				= "CHAT_MSG_SAY",
	["WHISPER"]			= "CHAT_MSG_WHISPER",
	["YELL"]			= "CHAT_MSG_YELL",
	-------------------------------------------------------------------------------
	-- Creature messages.
	-------------------------------------------------------------------------------
	["MONSTER_BOSS_EMOTE"]		= "CHAT_MSG_RAID_BOSS_EMOTE",
	["MONSTER_BOSS_WHISPER"]	= "CHAT_MSG_RAID_BOSS_WHISPER",
	["MONSTER_EMOTE"]		= "CHAT_MSG_MONSTER_EMOTE",
	["MONSTER_SAY"]			= "CHAT_MSG_MONSTER_SAY",
	["MONSTER_WHISPER"]		= "CHAT_MSG_MONSTER_WHISPER",
	["MONSTER_YELL"]		= "CHAT_MSG_MONSTER_YELL",
	-------------------------------------------------------------------------------
	-- Combat messages.
	-------------------------------------------------------------------------------
	["COMBAT_FACTION_CHANGE"]	= "CHAT_MSG_COMBAT_FACTION_CHANGE",
	["COMBAT_HONOR_GAIN"]		= "CHAT_MSG_COMBAT_HONOR_GAIN",
	["COMBAT_MISC_INFO"]		= "CHAT_MSG_COMBAT_MISC_INFO",
	["COMBAT_XP_GAIN"]		= "CHAT_MSG_COMBAT_XP_GAIN",
	["LOOT"]			= "CHAT_MSG_LOOT",
	["MONEY"]			= "CHAT_MSG_MONEY",
	["OPENING"]			= "CHAT_MSG_OPENING",
	["PET_INFO"]			= "CHAT_MSG_PET_INFO",
	["SKILL"]			= "CHAT_MSG_SKILL",
	["TRADESKILLS"]			= "CHAT_MSG_TRADESKILLS",
	-------------------------------------------------------------------------------
	-- PvP messages.
	-------------------------------------------------------------------------------
	["BG_SYSTEM_ALLIANCE"]		= "CHAT_MSG_BG_SYSTEM_ALLIANCE",
	["BG_SYSTEM_HORDE"]		= "CHAT_MSG_BG_SYSTEM_HORDE",
	["BG_SYSTEM_NEUTRAL"]		= "CHAT_MSG_BG_SYSTEM_NEUTRAL",
	-------------------------------------------------------------------------------
	-- System messages.
	-------------------------------------------------------------------------------
	["AFK"]			= "CHAT_MSG_AFK",
--	["CHANNEL"]		= "CHAT_MSG_",
	["DND"]			= "CHAT_MSG_DND",
--	["ERRORS"]		= "CHAT_MSG_RESTRICTED",
	["IGNORED"]		= "CHAT_MSG_IGNORED",
	["SYSTEM"]		= "CHAT_MSG_SYSTEM",
}

local FLASH_TEXTURES = {
	"Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight",
	"Interface\\CHATFRAME\\ChatFrameTab",
	"Interface\\GMChatFrame\\UI-GMStatusFrame-Pulse",
}

local FLASH_DESCRIPTIONS = {
	_G.DEFAULT,
	L["Outline"],
	L["Bold Outline"],
}

local FLASH_OFFSET_Y = {
	-5,
	0,
	-5,
}

local DEFAULT_OPTIONS = {
	listen = {
		["GUILD"]		= true,
		["GUILD_OFFICER"]	= true,
		["PARTY"]		= true,
		["PARTY_LEADER"]	= true,
		["WHISPER"]		= true,
	},
	font = {
		active = {
			["r"]	= 1.0,
			["g"]	= 0.82,
			["b"]	= 0,
		},
		inactive = {
			["r"]	= 1.0,
			["g"]	= 0.82,
			["b"]	= 0,
		},
		alert = {
			["r"]	= 1.0,
			["g"]	= 0.82,
			["b"]	= 0,
		},
	},
	tab = {
		hide_border	= false,
		always_show	= false,
		fade_inactive	= true,
	},
	alert_flash = {
		disable	= false,
		texture	= 1,
		colors	= {
			["r"]	= 0.32,
			["g"]	= 0.73,
			["b"]	= 0.84,
		}
	},
}

-------------------------------------------------------------------------------
-- Variables
-------------------------------------------------------------------------------
local data_obj
local db
local CHAT_FRAMES = {}
local TAB_DATA = {}
local orig_FCF_ChatTabFadeFinished

-------------------------------------------------------------------------------
-- Local functions
-------------------------------------------------------------------------------
local function Debug(...)
	if debugger then
		debugger:AddMessage(string.join(", ", ...))
	end
end

local function FlashTab(event, ...)
	local message, player, language = ...

	for index, frame in pairs(CHAT_FRAMES) do
		local type_list = frame.messageTypeList

		for index2, type in pairs(type_list) do
			if LISTEN_EVENTS[type] == event and db.listen[type] then
				Debug(event, frame:GetName(), message and ("\""..message.."\"") or "empty message", player or "no player",
				      language or "no language")
				_G.FCF_FlashTab(frame)
				break
			end
		end
	end
end

local function SetColorTable(color_table, r, g, b)
	color_table.r = r
	color_table.g = g
	color_table.b = b
end

local function SetTabBorders(id_num)
	local frame_ref = "ChatFrame"..id_num
	local left = _G[frame_ref.."TabLeft"]
	local middle = _G[frame_ref.."TabMiddle"]
	local right = _G[frame_ref.."TabRight"]

	local action = db.tab.hide_border and "Hide" or "Show"

	left[action](left)
	middle[action](middle)
	right[action](right)
end

local function GetTabColors(id_num)
	local r, g, b
	local frame_name = "ChatFrame"..id_num
	local flash = _G[frame_name.."TabFlash"]

	if _G[frame_name] == SELECTED_CHAT_FRAME then
		local color = db.font.active
		r, g, b = color.r, color.g, color.b
	elseif flash and flash:IsShown() then
		local color = db.font.alert
		r, g, b = color.r, color.g, color.b
	else
		local color = db.font.inactive
		r, g, b = color.r, color.g, color.b
	end
	return r, g, b
end

local SetFontStates
do
	local base_font = GameFontNormalSmall

	function SetFontStates(self, r, g, b, flags)
		-- The "self" parameter may be the tab's flash texture instead of the tab itself.
		local text = self.GetFontString and self:GetFontString() or self:GetParent():GetFontString()
		local font, font_size = base_font:GetFont()

		text:SetFont(font, font_size, flags)

		if r and g and b then
			text:SetTextColor(r, g, b)
		end
	end
end	-- do-block

local function DoNothing ()
end

local function UpdateChatFrames()
	for index = 1, _G.NUM_CHAT_WINDOWS do
		local frame_name = "ChatFrame"..index
		local chat_frame = _G[frame_name]
		local tab = _G[frame_name.."Tab"]
		local tab_flash = _G[frame_name.."TabFlash"]

		CHAT_FRAMES[index] = chat_frame
		TAB_DATA[index] = TAB_DATA[index] or {}

		tab:SetScript("OnEnter", Tab_OnEnter)
		tab:SetScript("OnLeave", Tab_OnLeave)

		local r, g, b = GetTabColors(index)
		SetFontStates(tab, r, g, b)

		tab_flash:SetScript("OnShow", Flash_OnShow)
		tab_flash:SetScript("OnHide", Flash_OnHide)

		if db.alert_flash.disable then
			tab_flash:GetRegions():SetTexture(nil)
		else
			local color = db.alert_flash.colors
			local tex_id =  db.alert_flash.texture
			local texture = tab_flash:GetRegions()
			local y_offset = FLASH_OFFSET_Y[tex_id]

			texture:SetTexture(FLASH_TEXTURES[tex_id])
			texture:SetVertexColor(color.r, color.g, color.b)

			texture:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, y_offset)
			texture:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, y_offset)
		end

		SetTabBorders(index)

		-- Store and unset the tab's SetAlpha method - it's used by the default UI in a way which breaks the
		-- AddOn's options, so we'll handle it manually.
		if not TAB_DATA[index].SetAlpha then
			TAB_DATA[index].SetAlpha = tab.SetAlpha
			tab.SetAlpha = DoNothing
		end

		if not db.tab.fade_inactive then
			TAB_DATA[index].SetAlpha(tab, 1)
		else
			if chat_frame ~= SELECTED_DOCK_FRAME then
				TAB_DATA[index].SetAlpha(tab, 0.5)
			else
				TAB_DATA[index].SetAlpha(tab, 1)
			end
		end

		if db.tab.always_show then
			if not TAB_DATA[index].Hide then
				if chat_frame.isDocked or chat_frame:IsShown() then
					tab:Show()
				end
				TAB_DATA[index].Hide = tab.Hide
				tab.Hide = DoNothing

				tab:SetHighlightTexture(nil)
			end

			if not orig_FCF_ChatTabFadeFinished then
				orig_FCF_ChatTabFadeFinished = _G.FCF_ChatTabFadeFinished
				_G.FCF_ChatTabFadeFinished = DoNothing()
			end
		else
			if TAB_DATA[index].Hide then
				tab:SetHighlightTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight", "ADD")

				local texture = tab:GetHighlightTexture()

				texture:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, -7)
				texture:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, -7)

				tab.Hide = TAB_DATA[index].Hide
				TAB_DATA[index].Hide = nil

				if not tab_flash:IsShown() then
					tab:Hide()
				end
			end

			if orig_FCF_ChatTabFadeFinished then
				_G.FCF_ChatTabFadeFinished = orig_FCF_ChatTabFadeFinished
				orig_FCF_ChatTabFadeFinished = nil
			end
		end
	end
end

function Tab_OnEnter(self, motion)
	local r, g, b = GetTabColors(self:GetID())
	SetFontStates(self, r, g, b, "OUTLINE")
end

function Tab_OnLeave(self, motion)
	local r, g, b = GetTabColors(self:GetID())
	SetFontStates(self, r, g, b)
end

function Flash_OnShow(self)
	local color = db.font.alert
	SetFontStates(self, color.r, color.g, color.b, "OUTLINE")
end

function Flash_OnHide(self)
	UpdateChatFrames()
end

-------------------------------------------------------------------------------
-- Initialization.
-------------------------------------------------------------------------------
-- Override the default flash behavior of the tabs so they don't time out until accessed instead of fading after 60 seconds.
-- Yanked straight out of the default UI's code and modified.
function _G.FCF_FlashTab(self)
	local tabFlash = _G[self:GetName().."TabFlash"];

	if not self.isDocked or self == SELECTED_DOCK_FRAME or UIFrameIsFlashing(tabFlash) then
		return
	end
	tabFlash:Show()
	UIFrameFlash(tabFlash, 0.25, 0.25, -1, nil, 0.5, 0.5);
end

function TabAlerts:OnInitialize()
	local defaults = {
		global = DEFAULT_OPTIONS
	}

	local temp_db = LibStub("AceDB-3.0"):New(ADDON_NAME.."DB", defaults)
	db = temp_db.global

	self:SetupOptions()
end

function TabAlerts:OnEnable()
	UpdateChatFrames()
	hooksecurefunc("FCF_OpenNewWindow", UpdateChatFrames)
	hooksecurefunc("FCF_Tab_OnClick", UpdateChatFrames)
	hooksecurefunc("FCF_Close",
		       function(self, fallback)
			       local frame = fallback or self
			       UIParent.Hide(_G[frame:GetName().."Tab"])
		       end)

	data_obj = LDB:NewDataObject(ADDON_NAME, {
		type	= "launcher",
		label	= ADDON_NAME,
		icon	= [[Interface\CHATFRAME\UI-ChatIcon-Chat-Up]],
		OnClick	= function(display, button)
				  local options_frame = _G.InterfaceOptionsFrame

				  if options_frame:IsVisible() then
					  options_frame:Hide()
				  else
					  _G.InterfaceOptionsFrame_OpenToCategory(TabAlerts.options_frame)
				  end
			  end,
	})

	-- Register for configured events.
	for type, toggled in pairs(db.listen) do
		if toggled then
			local reg_event = LISTEN_EVENTS[type]

			self:RegisterEvent(reg_event, FlashTab)
			Debug("OnEnable()", reg_event, "Registered")
		end
	end
end

-------------------------------------------------------------------------------
-- Configuration.
-------------------------------------------------------------------------------
local CHAT_OPTIONS = {
	"ACHIEVEMENT",
	"BATTLEGROUND",
	"BATTLEGROUND_LEADER",
	"EMOTE",
	"GUILD",
	"GUILD_OFFICER",
	"GUILD_ACHIEVEMENT",
	"PARTY",
	"PARTY_LEADER",
	"RAID",
	"RAID_LEADER",
	"RAID_WARNING",
	"SAY",
	"WHISPER",
	"YELL",
}

local CREATURE_OPTIONS = {
	"MONSTER_BOSS_EMOTE",
	"MONSTER_BOSS_WHISPER",
	"MONSTER_EMOTE",
	"MONSTER_SAY",
	"MONSTER_WHISPER",
	"MONSTER_YELL",
}

local COMBAT_OPTIONS = {
	"COMBAT_FACTION_CHANGE",
	"COMBAT_HONOR_GAIN",
	"COMBAT_MISC_INFO",
	"COMBAT_XP_GAIN",
	"LOOT",
	"MONEY",
	"OPENING",
	"PET_INFO",
	"SKILL",
	"TRADESKILLS",
}

local PVP_OPTIONS = {
	"BG_SYSTEM_ALLIANCE",
	"BG_SYSTEM_HORDE",
	"BG_SYSTEM_NEUTRAL",
}

local OTHER_OPTIONS = {
	"AFK",
	--	"CHANNEL",
	"DND",
	--	"ERRORS",
	"IGNORED",
	"SYSTEM",
}

local function BuildMessageOptionArgs(arg_table, options)
	for index, section in ipairs(options) do
		local low_section = section:lower()

		arg_table[low_section] = {
			order	= index,
			type	= "toggle",
			width	= "double",
			name	= _G[section] or _G[LISTEN_EVENTS[section]],
			desc	= _G.BINDING_NAME_TOGGLECHATTAB,
			get	= function()
					  return db.listen[section]
				  end,
			set	= function(info, value)
					  local event = LISTEN_EVENTS[section]

					  db.listen[section] = value

					  if value then
						  TabAlerts:RegisterEvent(event, FlashTab)
						  Debug(event, "Registered")
					  else
						  TabAlerts:UnregisterEvent(event)
						  Debug(event, "Unregistered")
					  end
				  end,
		}
	end
end
local message_options

local function GetMessageOptions()
	if not message_options then
		message_options = {
			order = 1,
			name = _G.MESSAGE_TYPES,
			type = "group",
			childGroups = "tab",
			args = {
				chat = {
					name = _G.PLAYER_MESSAGES,
					order = 10,
					type = "group",
					args = {}
				},
				creature = {
					name = _G.CREATURE_MESSAGES,
					order = 20,
					type = "group",
					args = {}
				},
				combat = {
					name = _G.COMBAT,
					order = 30,
					type = "group",
					args = {}
				},
				pvp = {
					name = _G.PVP,
					order = 40,
					type = "group",
					args = {}
				},
				other = {
					name = _G.OTHER,
					order = 50,
					type = "group",
					args = {}
				},
			}
		}
		BuildMessageOptionArgs(message_options.args.chat.args, CHAT_OPTIONS)
		BuildMessageOptionArgs(message_options.args.creature.args, CREATURE_OPTIONS)
		BuildMessageOptionArgs(message_options.args.combat.args, COMBAT_OPTIONS)
		BuildMessageOptionArgs(message_options.args.pvp.args, PVP_OPTIONS)
		BuildMessageOptionArgs(message_options.args.other.args, OTHER_OPTIONS)
	end
	return message_options
end
local color_options

local function GetColorOptions()
	if not color_options then
		color_options = {
			order	= 2,
			name	= _G.COLOR_PICKER,
			type	= "group",
			args = {
				header1 = {
					order	= 10,
					type	= "header",
					name	= L["Font Colors"],
				},
				active_font_color = {
					order	= 20,
					type	= "color",
					name	= L["Active"],
					get	= function()
							  local col = db.font.active
							  return col.r, col.g, col.b
						  end,
					set	= function(info, r, g, b)
							  SetColorTable(db.font.active, r, g, b)
							  UpdateChatFrames()
						  end,
				},
				active_font_default = {
					order	= 30,
					type	= "execute",
					name	= _G.DEFAULT,
					width	= "half",
					func	= function()
							  local col = DEFAULT_OPTIONS.font.active

							  SetColorTable(db.font.active, col.r, col.g, col.b)
							  UpdateChatFrames()
						  end,
				},
				spacer1 = {
					order	= 35,
					type	= "description",
					width	= "full",
					name	= " ",
				},
				inactive_font_color = {
					order	= 40,
					type	= "color",
					name	= L["Inactive"],
					get	= function()
							  local col = db.font.inactive
							  return col.r, col.g, col.b
						  end,
					set	= function(info, r, g, b)
							  SetColorTable(db.font.inactive, r, g, b)
							  UpdateChatFrames()
						  end,
				},
				inactive_font_default = {
					order	= 50,
					type	= "execute",
					name	= _G.DEFAULT,
					width	= "half",
					func	= function()
							  local col = DEFAULT_OPTIONS.font.inactive

							  SetColorTable(db.font.inactive, col.r, col.g, col.b)
							  UpdateChatFrames()
						  end,
				},
				spacer2 = {
					order	= 55,
					type	= "description",
					width	= "full",
					name	= " ",
				},
				alert_font_color = {
					order	= 60,
					type	= "color",
					name	= L["Alert"],
					get	= function()
							  local col = db.font.alert
							  return col.r, col.g, col.b
						  end,
					set	= function(info, r, g, b)
							  SetColorTable(db.font.alert, r, g, b)
							  UpdateChatFrames()
						  end,
				
				},
				alert_font_default = {
					order	= 70,
					type	= "execute",
					name	= _G.DEFAULT,
					width	= "half",
					func	= function()
							  local col = DEFAULT_OPTIONS.font.alert

							  SetColorTable(db.font.alert, col.r, col.g, col.b)
							  UpdateChatFrames()
						  end,
				},
			}
		}
	end
	return color_options
end
local misc_options

local function IsFlashDisabled()
	return db.alert_flash.disable
end

local function GetMiscOptions()
	if not misc_options then
		misc_options = {
			order	= 3,
			name	= _G.MISCELLANEOUS,
			type	= "group",
			args = {
				header_1 = {
					order	= 1,
					type	= "header",
					name	= L["Tab Options"],
				},
				always_show = {
					order	= 10,
					type	= "toggle",
					name	= L["Always Show"],
					desc	= L["Toggles between always showing the tab or only showing it on mouse-over."],
					get	= function()
							  return db.tab.always_show
						  end,
					set	= function(info, value)
							  db.tab.always_show = value
							  UpdateChatFrames()
						  end,
				},
				fade_inactive = {
					order	= 20,
					type	= "toggle",
					name	= L["Fade Inactive"],
					desc	= L["Fades the name of inactive tabs."],
					get	= function()
							  return db.tab.fade_inactive
						  end,
					set	= function(info, value)
							  db.tab.fade_inactive = value
							  UpdateChatFrames()
						  end,
				},
				hide_border = {
					order	= 30,
					type	= "toggle",
					name	= L["Hide Border"],
					desc	= L["Hides the tab border, leaving only the text visible."],
					get	= function()
							  return db.tab.hide_border
						  end,
					set	= function(info, value)
							  db.tab.hide_border = value

							  for index, frame in pairs(CHAT_FRAMES) do
								  SetTabBorders(index)
							  end
						  end,
				},
				tab_defaults = {
					order	= 40,
					type	= "execute",
					name	= _G.DEFAULT,
					width	= "half",
					func	= function()
							  for option, value in pairs(DEFAULT_OPTIONS.tab) do
								  db.tab[option] = value
							  end
							  UpdateChatFrames()
						  end,
				},
				header_2 = {
					order	= 41,
					type	= "header",
					name	= L["Alert Options"],
				},
				flash_texture = {
					order	= 50,
					type	= "select",
					name	= _G.APPEARANCE_LABEL,
					desc	= L["Changes the appearance of the pulsing alert flash."],
					disabled = IsFlashDisabled,
					get	= function()
							  return db.alert_flash.texture
						  end,
					set	= function(info, value)
							  db.alert_flash.texture = value
							  UpdateChatFrames()
						  end,
					values	= FLASH_DESCRIPTIONS,
				},
				flash_color = {
					order	= 60,
					type	= "color",
					name	= _G.COLOR,
					disabled = IsFlashDisabled,
					get	= function()
							  local col = db.alert_flash.colors
							  return col.r, col.g, col.b
						  end,
					set	= function(info, r, g, b)
							  SetColorTable(db.alert_flash.colors, r, g, b)
							  UpdateChatFrames()
						  end,
				},
				disable_flash = {
					order	= 70,
					type	= "toggle",
					name	= _G.DISABLE,
					desc	= L["Disables the pulsing alert flash."],
					get	= function()
							  return db.alert_flash.disable
						  end,
					set	= function(info, value)
							  db.alert_flash.disable = value
							  UpdateChatFrames()
						  end,
				},
				flash_defaults = {
					order	= 80,
					type	= "execute",
					name	= _G.DEFAULT,
					width	= "half",
					func	= function()
							  local col = DEFAULT_OPTIONS.alert_flash.colors

							  SetColorTable(db.alert_flash.colors, r, g, b)

							  for option, value in pairs(DEFAULT_OPTIONS.alert_flash) do
								  db.alert_flash[option] = value
							  end

							  for color, value in pairs(DEFAULT_OPTIONS.alert_flash.colors) do
								  db.alert_flash.colors[color] = value
							  end
							  UpdateChatFrames()
						  end,
				},
			},
		}
	end
	return misc_options
end
local options
--local suboptions = {}

local function GetOptions()
	if not options then
		options = {
			name = ADDON_NAME,
			type = "group",
			childGroups = "tab",
			args = {
			}
		}
		options.args.color_options = GetColorOptions()
		options.args.message_options = GetMessageOptions()
		options.args.misc_options = GetMiscOptions()
	end
	return options
end
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

function TabAlerts:SetupOptions()
	AceConfigRegistry:RegisterOptionsTable(ADDON_NAME, GetOptions)
	self.options_frame = AceConfigDialog:AddToBlizOptions(ADDON_NAME)--, nil, nil, "general")

	-- self:RegisterSubOptions(_G.MESSAGE_TYPES, "message_types", GetMessageOptions)
	-- self:RegisterSubOptions(_G.COLOR_PICKER, "color_picker", GetColorOptions)
end

--function TabAlerts:RegisterSubOptions(name, section, options_table)
-- 	suboptions[section] = options_table
-- 	self.options_frame[section] = AceConfigDialog:AddToBlizOptions(ADDON_NAME, name, ADDON_NAME, section)
-- end
