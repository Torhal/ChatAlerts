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

local DEFAULT_OPTIONS = {
	global = {
		listen = {
			["GUILD"]		= true,
			["GUILD_OFFICER"]	= true,
			["PARTY"]		= true,
			["PARTY_LEADER"]	= true,
			["WHISPER"]		= true,
		},
		tab = {
			font_color = {
				["r"]	= 1.0,
				["g"]	= 0.82,
				["b"]	= 0,
			}
		},
	}
}

-------------------------------------------------------------------------------
-- Variables
-------------------------------------------------------------------------------
local data_obj
local db
local CHAT_FRAMES = {}

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
	local temp_db = LibStub("AceDB-3.0"):New(ADDON_NAME.."DB", DEFAULT_OPTIONS)
	db = temp_db.global

	self:SetupOptions()
end

function TabAlerts:OnEnable()
	for i = 1, _G.NUM_CHAT_WINDOWS do
		CHAT_FRAMES[i] = _G["ChatFrame"..i]
	end

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
local options
local suboptions = {}

local function GetOptions()
	if not options then
		options = {
			name = ADDON_NAME,
			type = "group",
			args = {
				general = {
					order	= 1,
					type	= "group",
					name	= _G.GENERAL,
					args	= {	
						header1 = {
							order	= 10,
							type	= "header",
							name	= _G.GENERAL,
						},
						font_color = {
							order	= 20,
							type	= "color",
							name	= "Font Color",
							get	= function()
									  local font = db.tab.font_color
									  return font.r, font.g, font.b
								  end,
							set	= function(info, r, g, b)
									  local font = db.tab.font_color

									  font.r = r
									  font.g = g
									  font.b = b

									  for index, frame in pairs(CHAT_FRAMES) do
										  local tab = _G["ChatFrame"..index.."Tab"]
										  local text = tab:GetFontString()

										  text:SetTextColor(r, g, b)
									  end
								  end,
						},
						font_color_default = {
							order	= 30,
							type	= "execute",
							name	= _G.DEFAULT,
							func	= function()
									  local font = DEFAULT_OPTIONS.global.tab.font_color

									  for index, frame in pairs(CHAT_FRAMES) do
										  local tab = _G["ChatFrame"..index.."Tab"]
										  local text = tab:GetFontString()

										  text:SetTextColor(font.r, font.g, font.b)
									  end
								  end,
						},
					},
				},
			}
		}

		-- Add the sub-options to the list.
		for name, options_table in pairs(suboptions) do
			options.args[name] = (type(options_table) == "function") and options_table() or options_table
		end
	end
	return options
end
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

function TabAlerts:SetupOptions()
	AceConfigRegistry:RegisterOptionsTable(ADDON_NAME, GetOptions)
	self.options_frame = AceConfigDialog:AddToBlizOptions(ADDON_NAME, nil, nil, "general")

	self:RegisterSubOptions(_G.MESSAGE_TYPES, "message_types", GetMessageOptions)
end

function TabAlerts:RegisterSubOptions(name, section, options_table)
	suboptions[section] = options_table
	self.options_frame[section] = AceConfigDialog:AddToBlizOptions(ADDON_NAME, name, ADDON_NAME, section)
end
