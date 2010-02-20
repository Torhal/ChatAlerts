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
function TabAlerts:OnInitialize()
	local defaults = {
		global = {
			listen = {
				["GUILD"]		= true,
				["GUILD_OFFICER"]	= true,
				["PARTY"]		= true,
				["PARTY_LEADER"]	= true,
				["WHISPER"]		= true,
			}
		}
	}
	local temp_db = LibStub("AceDB-3.0"):New(ADDON_NAME.."DB", defaults)
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
local options

local function GetOptions()
	if not options then
		options = {
			name = ADDON_NAME.." - ".._G.PLAYER_MESSAGES,
			type = "group",
			args = {
				battleground = {
					order	= 10,
					type	= "toggle",
					name	= _G.CHAT_MSG_BATTLEGROUND,
					desc	= _G.BINDING_NAME_TOGGLECHATTAB,
					get	= function()
							  return db.listen.BATTLEGROUND
						  end,
					set	= function(info, value)
							  db.listen.BATTLEGROUND = value
						  end,
				},
				battleground_leader = {
					order	= 20,
					type	= "toggle",
					name	= _G.CHAT_MSG_BATTLEGROUND_LEADER,
					desc	= _G.BINDING_NAME_TOGGLECHATTAB,
					get	= function()
							  return db.listen.BATTLEGROUND_LEADER
						  end,
					set	= function(info, value)
							  db.listen.BATTLEGROUND_LEADER = value
						  end,
				},
				emote = {
					order	= 30,
					type	= "toggle",
					name	= _G.CHAT_MSG_EMOTE,
					desc	= _G.BINDING_NAME_TOGGLECHATTAB,
					get	= function()
							  return db.listen.EMOTE
						  end,
					set	= function(info, value)
							  db.listen.EMOTE = value
						  end,
				},
				guild = {
					order	= 40,
					type	= "toggle",
					name	= _G.CHAT_MSG_GUILD,
					desc	= _G.BINDING_NAME_TOGGLECHATTAB,
					get	= function()
							  return db.listen.GUILD
						  end,
					set	= function(info, value)
							  db.listen.GUILD = value
						  end,
				},
				guild_officer = {
					order	= 50,
					type	= "toggle",
					name	= _G.CHAT_MSG_OFFICER,
					desc	= _G.BINDING_NAME_TOGGLECHATTAB,
					get	= function()
							  return db.listen.GUILD_OFFICER
						  end,
					set	= function(info, value)
							  db.listen.GUILD_OFFICER = value
						  end,
				},
				guild_achievement = {
					order	= 60,
					type	= "toggle",
					name	= _G.CHAT_MSG_GUILD_ACHIEVEMENT,
					desc	= _G.BINDING_NAME_TOGGLECHATTAB,
					get	= function()
							  return db.listen.GUILD_ACHIEVEMENT
						  end,
					set	= function(info, value)
							  db.listen.GUILD_ACHIEVEMENT = value
						  end,
				},
				party = {
					order	= 50,
					type	= "toggle",
					name	= _G.CHAT_MSG_PARTY,
					desc	= _G.BINDING_NAME_TOGGLECHATTAB,
					get	= function()
							  return db.listen.PARTY
						  end,
					set	= function(info, value)
							  db.listen.PARTY = value
						  end,
				},
				party_leader = {
					order	= 60,
					type	= "toggle",
					name	= _G.CHAT_MSG_PARTY_LEADER,
					desc	= _G.BINDING_NAME_TOGGLECHATTAB,
					get	= function()
							  return db.listen.PARTY_LEADER
						  end,
					set	= function(info, value)
							  db.listen.PARTY_LEADER = value
						  end,
				},
				raid = {
					order	= 70,
					type	= "toggle",
					name	= _G.CHAT_MSG_RAID,
					desc	= _G.BINDING_NAME_TOGGLECHATTAB,
					get	= function()
							  return db.listen.RAID
						  end,
					set	= function(info, value)
							  db.listen.RAID = value
						  end,
				},
				raid_leader = {
					order	= 80,
					type	= "toggle",
					name	= _G.CHAT_MSG_RAID_LEADER,
					desc	= _G.BINDING_NAME_TOGGLECHATTAB,
					get	= function()
							  return db.listen.RAID_LEADER
						  end,
					set	= function(info, value)
							  db.listen.RAID_LEADER = value
						  end,
				},
				raid_warning = {
					order	= 70,
					type	= "toggle",
					name	= _G.CHAT_MSG_RAID_WARNING,
					desc	= _G.BINDING_NAME_TOGGLECHATTAB,
					get	= function()
							  return db.listen.RAID_WARNING
						  end,
					set	= function(info, value)
							  db.listen.RAID_WARNING = value
						  end,
				},
				say = {
					order	= 110,
					type	= "toggle",
					name	= _G.CHAT_MSG_SAY,
					desc	= _G.BINDING_NAME_TOGGLECHATTAB,
					get	= function()
							  return db.listen.SAY
						  end,
					set	= function(info, value)
							  db.listen.SAY = value
						  end,
				},
				whisper = {
					order	= 110,
					type	= "toggle",
					name	= _G.CHAT_MSG_WHISPER,
					desc	= _G.BINDING_NAME_TOGGLECHATTAB,
					get	= function()
							  return db.listen.WHISPER
						  end,
					set	= function(info, value)
							  db.listen.WHISPER = value
						  end,
				},
				yell = {
					order	= 120,
					type	= "toggle",
					name	= _G.CHAT_MSG_YELL,
					desc	= _G.BINDING_NAME_TOGGLECHATTAB,
					get	= function()
							  return db.listen.YELL
						  end,
					set	= function(info, value)
							  db.listen.YELL = value
						  end,
				},
			},
		}
	end
	return options
end

function TabAlerts:SetupOptions()
	LibStub("AceConfig-3.0"):RegisterOptionsTable(ADDON_NAME, GetOptions())
	self.options_frame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON_NAME)
end
