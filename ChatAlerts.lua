-------------------------------------------------------------------------------
-- Localized Lua globals.
-------------------------------------------------------------------------------
local table = _G.table

local pairs = _G.pairs

-------------------------------------------------------------------------------
-- Addon namespace
-------------------------------------------------------------------------------
local ADDON_NAME, namespace = ...

local LibStub = _G.LibStub
local ChatAlerts = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0")
local LDB = LibStub("LibDataBroker-1.1")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

-------------------------------------------------------------------------------
-- Constants.
-------------------------------------------------------------------------------
local ChatTypeGroup = _G.ChatTypeGroup

local FLASH_TEXTURES = {
	[[Interface\ChatFrame\ChatFrameTab-NewMessage]],
	[[Interface\PaperDollInfoFrame\UI-Character-Tab-Highlight]],
	[[Interface\CHATFRAME\ChatFrameTab]],
	[[Interface\GMChatFrame\UI-GMStatusFrame-Pulse]],
}

local FLASH_DESCRIPTIONS = {
	_G.DEFAULT,
	L["Classic"],
	L["Outline"],
	L["Bold Outline"],
}

local FLASH_OFFSET_Y = {
	-3,
	-5,
	0,
	-5,
}

local DEFAULT_OPTIONS = {
	listen = {
		BN_WHISPER = true,
		GUILD = true,
		INSTANCE_CHAT = true,
		INSTANCE_CHAT_LEADER = true,
		OFFICER = true,
		PARTY = true,
		PARTY_LEADER = true,
		WHISPER = true,
	},
	font = {
		active = {
			r = 1.0,
			g = 0.82,
			b = 0,
		},
		inactive = {
			r = 1.0,
			g = 0.82,
			b = 0,
		},
		alert = {
			r = 1.0,
			g = 0.82,
			b = 0,
		},
	},
	tab = {
		hide_border = false,
		always_show = false,
		fade_inactive = true,
		highlight = true,
	},
	alert_flash = {
		disable = false,
		texture = 1,
		colors = {
			r = 0.32,
			g = 0.73,
			b = 0.84,
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

-------------------------------------------------------------------------------
-- Upvalued functions
-------------------------------------------------------------------------------
local UpdateChatFrames
local UpdateChatFrame

-------------------------------------------------------------------------------
-- Local functions
-------------------------------------------------------------------------------
local function FlashTab(event)
	for frame_index, frame in pairs(CHAT_FRAMES) do
		for _, listen_type in pairs(frame.messageTypeList) do
			local event_list = ChatTypeGroup[listen_type]

			for event_index = 1, #event_list do
				if event_list[event_index] == event and db.listen[listen_type] then
					_G.FCF_StartAlertFlash(frame)
					UpdateChatFrame(frame_index)
					break
				end
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
	local frame_ref = "ChatFrame" .. id_num
	local left = _G[frame_ref .. "TabLeft"]
	local middle = _G[frame_ref .. "TabMiddle"]
	local right = _G[frame_ref .. "TabRight"]

	local action = db.tab.hide_border and "Hide" or "Show"

	left[action](left)
	middle[action](middle)
	right[action](right)
end

local function GetTabColors(id_num)
	local frame_name = "ChatFrame" .. id_num
	local frame = _G[frame_name]
	local tab = _G[frame_name .. "Tab"]
	local color

	if frame == _G.SELECTED_CHAT_FRAME then
		color = db.font.active
	elseif tab.glow and tab.alerting then
		color = db.font.alert
	else
		color = db.font.inactive
	end
	return color.r, color.g, color.b
end

local SetFontStates
do
	local base_font = _G.GameFontNormalSmall

	function SetFontStates(self, r, g, b, flags)
		-- The "self" parameter may be the tab's flash texture instead of the tab itself.
		local text = self.GetFontString and self:GetFontString() or self:GetParent():GetFontString()
		local font, font_size = base_font:GetFont()

		text:SetFont(font, font_size, flags)

		if r and g and b then
			text:SetTextColor(r, g, b)
		end
	end
end -- do-block

local function DoNothing()
end

local function Tab_OnEnter(self)
	local r, g, b = GetTabColors(self:GetID())
	SetFontStates(self, r, g, b, "OUTLINE")
end

local function Tab_OnLeave(self)
	local r, g, b = GetTabColors(self:GetID())
	SetFontStates(self, r, g, b)
end

function UpdateChatFrame(index)
	local frame_name = "ChatFrame" .. index
	local chat_frame = _G[frame_name]

	local tab = _G[frame_name .. "Tab"]
	tab:SetScript("OnEnter", Tab_OnEnter)
	tab:SetScript("OnLeave", Tab_OnLeave)

	if chat_frame == _G.SELECTED_CHAT_FRAME and tab.alerting then
		tab.alerting = nil
		_G.FCF_StopAlertFlash(chat_frame)
	end

	local r, g, b = GetTabColors(index)
	SetFontStates(tab, r, g, b)

	local tab_glow = tab.glow

	if db.alert_flash.disable then
		tab_glow:Hide()
	else
		local color = db.alert_flash.colors
		local tex_id = db.alert_flash.texture
		local y_offset = FLASH_OFFSET_Y[tex_id]

		tab_glow:SetTexture(FLASH_TEXTURES[tex_id])
		tab_glow:SetVertexColor(color.r, color.g, color.b)
		tab_glow:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, y_offset)
		tab_glow:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, y_offset)
	end
	SetTabBorders(index)

	local cache = TAB_DATA[index]

	-- Store and unset the tab's SetAlpha method - it's used by the default UI in a way which breaks the
	-- AddOn's options, so we'll handle it manually.
	if not cache.SetAlpha then
		cache.SetAlpha = tab.SetAlpha
		tab.SetAlpha = DoNothing
	end

	if not db.tab.fade_inactive then
		cache.SetAlpha(tab, 1)
	else
		if chat_frame == _G.SELECTED_CHAT_FRAME or tab.alering then
			cache.SetAlpha(tab, 1)
		else
			cache.SetAlpha(tab, 0.5)
		end
	end

	if not db.tab.highlight then
		if not cache.highlight then
			tab.leftHighlightTexture:Hide()
			tab.middleHighlightTexture:Hide()
			tab.rightHighlightTexture:Hide()
			cache.highlight = true
		end
	elseif cache.highlight then
		tab.leftHighlightTexture:Show()
		tab.middleHighlightTexture:Show()
		tab.rightHighlightTexture:Show()

		cache.highlight = nil
	end

	if db.tab.always_show then
		if not cache.Hide then
			if chat_frame.isDocked or chat_frame:IsVisible() then
				tab:Show()
			end
			cache.Hide = tab.Hide
			tab.Hide = DoNothing
		end
	else
		if cache.Hide then
			tab.Hide = cache.Hide
			cache.Hide = nil

			if not tab_glow:IsVisible() then
				tab:Hide()
			end
		end

		tab.leftSelectedTexture:Hide()
		tab.middleSelectedTexture:Hide()
		tab.rightSelectedTexture:Hide()
	end
end

-- Upvalued above
function UpdateChatFrames()
	for index = 1, _G.NUM_CHAT_WINDOWS do
		local chat_frame = _G["ChatFrame" .. index]

		if chat_frame:IsVisible() or chat_frame.isDocked then
			CHAT_FRAMES[index] = chat_frame
			TAB_DATA[index] = TAB_DATA[index] or {}

			UpdateChatFrame(index)
		end
	end
end

-------------------------------------------------------------------------------
-- Initialization.
-------------------------------------------------------------------------------
function ChatAlerts:OnInitialize()
	local defaults = {
		global = DEFAULT_OPTIONS
	}

	local temp_db = LibStub("AceDB-3.0"):New(ADDON_NAME .. "DB", defaults)
	db = temp_db.global

	self:SetupOptions()
end

function ChatAlerts:OnEnable()
	UpdateChatFrames()

	_G.hooksecurefunc("FCF_OpenNewWindow", UpdateChatFrames)
	_G.hooksecurefunc("FCF_Tab_OnClick", UpdateChatFrames)
	_G.hooksecurefunc("FCFTab_UpdateColors", UpdateChatFrames)
	_G.hooksecurefunc("FCF_Close", function(self, fallback)
		local frame = fallback or self
		_G.UIParent.Hide(_G[frame:GetName() .. "Tab"])
	end)

	data_obj = LDB:NewDataObject(ADDON_NAME, {
		type = "launcher",
		label = ADDON_NAME,
		icon = [[Interface\CHATFRAME\UI-ChatIcon-Chat-Up]],
		OnClick = function()
			local options_frame = _G.InterfaceOptionsFrame

			if options_frame:IsVisible() then
				options_frame:Hide()
			else
				_G.InterfaceOptionsFrame_OpenToCategory(ChatAlerts.options_frame)
			end
		end,
	})

	-- Register for configured events.
	for listenType, toggled in pairs(db.listen) do
		if toggled then
			local eventList = ChatTypeGroup[listenType]

			if eventList then
				for eventIndex = 1, #eventList do
					self:RegisterEvent(eventList[eventIndex], FlashTab)
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Configuration.
-------------------------------------------------------------------------------
local MESSAGE_TYPE_NAME_OVERRIDES = {
	BG_ALLIANCE = _G["CHAT_MSG_BG_SYSTEM_ALLIANCE"],
	BG_HORDE = _G["CHAT_MSG_BG_SYSTEM_HORDE"],
	BG_NEUTRAL = _G["CHAT_MSG_BG_SYSTEM_NEUTRAL"]
}

local function GetSectionName(section)
	return _G[section] or _G["CHAT_MSG_" .. section] or MESSAGE_TYPE_NAME_OVERRIDES[section] or ("%s_%s"):format(section, _G.UNKNOWN)
end

local function SectionNameSort(a, b)
	return GetSectionName(a) < GetSectionName(b)
end

local CHAT_MESSAGE_OPTIONS = {
	"ACHIEVEMENT",
	"BATTLEGROUND",
	"BATTLEGROUND_LEADER",
	"BN_CONVERSATION",
	"BN_WHISPER",
	"EMOTE",
	"GUILD",
	"GUILD_ACHIEVEMENT",
	"INSTANCE_CHAT",
	"INSTANCE_CHAT_LEADER",
	"OFFICER",
	"PARTY",
	"PARTY_LEADER",
	"RAID",
	"RAID_LEADER",
	"RAID_WARNING",
	"SAY",
	"WHISPER",
	"YELL",
}

table.sort(CHAT_MESSAGE_OPTIONS, SectionNameSort)

local CREATURE_MESSAGE_OPTIONS = {
	"MONSTER_BOSS_EMOTE",
	"MONSTER_BOSS_WHISPER",
	"MONSTER_EMOTE",
	"MONSTER_SAY",
	"MONSTER_WHISPER",
	"MONSTER_YELL",
}

table.sort(CREATURE_MESSAGE_OPTIONS, SectionNameSort)

local COMBAT_MESSAGE_OPTIONS = {
	"COMBAT_HONOR_GAIN",
	"COMBAT_XP_GAIN",
	"LOOT",
	"COMBAT_MISC_INFO",
	"MONEY",
	"OPENING",
	"COMBAT_FACTION_CHANGE",
	"SKILL",
	"TARGETICONS",
	"TRADESKILLS",
}

table.sort(COMBAT_MESSAGE_OPTIONS, SectionNameSort)

local PET_MESSAGE_OPTIONS = {
	"PET_INFO",
	"PET_BATTLE_COMBAT_LOG",
	"PET_BATTLE_INFO",
}

table.sort(PET_MESSAGE_OPTIONS, SectionNameSort)

local PVP_MESSAGE_OPTIONS = {
	"BG_ALLIANCE",
	"BG_HORDE",
	"BG_NEUTRAL",
}

table.sort(PVP_MESSAGE_OPTIONS, SectionNameSort)

local UnassignedMessageOptions = {}
for listen_category in pairs(ChatTypeGroup) do
	UnassignedMessageOptions[listen_category] = true
end

local function BuildMessageOptionArgs(arg_table, options)
	for index = 1, #options do
		local section = options[index]
		UnassignedMessageOptions[section] = nil

		arg_table[section:lower()] = {
			order = index,
			type = "toggle",
			width = "double",
			name = GetSectionName(section),
			desc = _G.BINDING_NAME_TOGGLECHATTAB,
			get = function()
				return db.listen[section]
			end,
			set = function(_, value)
				db.listen[section] = value

				local eventList = ChatTypeGroup[section]

				if eventList then
					if value then
						for eventIndex = 1, #eventList do
							ChatAlerts:RegisterEvent(eventList[eventIndex], FlashTab)
						end

					else
						for eventIndex = 1, #eventList do
							ChatAlerts:UnregisterEvent(eventList[eventIndex])
						end
					end
				end
			end,
		}
	end
end

-- Populated in GetMessageOptions
local OTHER_MESSAGE_OPTIONS = {}

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
				pet = {
					name = _G.PET_INFO,
					order = 40,
					type = "group",
					args = {}
				},
				pvp = {
					name = _G.PVP,
					order = 50,
					type = "group",
					args = {}
				},
				other = {
					name = _G.OTHER,
					order = 60,
					type = "group",
					args = {}
				},
			}
		}
		BuildMessageOptionArgs(message_options.args.chat.args, CHAT_MESSAGE_OPTIONS)
		BuildMessageOptionArgs(message_options.args.creature.args, CREATURE_MESSAGE_OPTIONS)
		BuildMessageOptionArgs(message_options.args.combat.args, COMBAT_MESSAGE_OPTIONS)
		BuildMessageOptionArgs(message_options.args.pvp.args, PVP_MESSAGE_OPTIONS)
		BuildMessageOptionArgs(message_options.args.pet.args, PET_MESSAGE_OPTIONS)

		-- Build OTHER_MESSAGE_OPTIONS from what hasn't already been assigned.
		for section in pairs(UnassignedMessageOptions) do
			OTHER_MESSAGE_OPTIONS[#OTHER_MESSAGE_OPTIONS + 1] = section
		end
		table.sort(OTHER_MESSAGE_OPTIONS, SectionNameSort)

		BuildMessageOptionArgs(message_options.args.other.args, OTHER_MESSAGE_OPTIONS)
	end
	return message_options
end

local color_options

local function GetColorOptions()
	if not color_options then
		color_options = {
			order = 2,
			name = _G.COLOR_PICKER,
			type = "group",
			args = {
				header1 = {
					order = 10,
					type = "header",
					name = L["Font Colors"],
				},
				active_font_color = {
					order = 20,
					type = "color",
					name = L["Active"],
					get = function()
						local col = db.font.active
						return col.r, col.g, col.b
					end,
					set = function(_, r, g, b)
						SetColorTable(db.font.active, r, g, b)
						UpdateChatFrames()
					end,
				},
				active_font_default = {
					order = 30,
					type = "execute",
					name = _G.DEFAULT,
					width = "half",
					func = function()
						local col = DEFAULT_OPTIONS.font.active

						SetColorTable(db.font.active, col.r, col.g, col.b)
						UpdateChatFrames()
					end,
				},
				spacer1 = {
					order = 35,
					type = "description",
					width = "full",
					name = " ",
				},
				inactive_font_color = {
					order = 40,
					type = "color",
					name = L["Inactive"],
					get = function()
						local col = db.font.inactive
						return col.r, col.g, col.b
					end,
					set = function(_, r, g, b)
						SetColorTable(db.font.inactive, r, g, b)
						UpdateChatFrames()
					end,
				},
				inactive_font_default = {
					order = 50,
					type = "execute",
					name = _G.DEFAULT,
					width = "half",
					func = function()
						local col = DEFAULT_OPTIONS.font.inactive

						SetColorTable(db.font.inactive, col.r, col.g, col.b)
						UpdateChatFrames()
					end,
				},
				spacer2 = {
					order = 55,
					type = "description",
					width = "full",
					name = " ",
				},
				alert_font_color = {
					order = 60,
					type = "color",
					name = L["Alert"],
					get = function()
						local col = db.font.alert
						return col.r, col.g, col.b
					end,
					set = function(_, r, g, b)
						SetColorTable(db.font.alert, r, g, b)
						UpdateChatFrames()
					end,
				},
				alert_font_default = {
					order = 70,
					type = "execute",
					name = _G.DEFAULT,
					width = "half",
					func = function()
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
			order = 3,
			name = _G.MISCELLANEOUS,
			type = "group",
			args = {
				header_1 = {
					order = 1,
					type = "header",
					name = L["Tab Options"],
				},
				always_show = {
					order = 10,
					type = "toggle",
					name = L["Always Show"],
					desc = L["Toggles between always showing the tab or only showing it on mouse-over."],
					get = function()
						return db.tab.always_show
					end,
					set = function(_, value)
						db.tab.always_show = value
						UpdateChatFrames()
					end,
				},
				fade_inactive = {
					order = 20,
					type = "toggle",
					name = L["Fade Inactive"],
					desc = L["Fades the name of inactive tabs."],
					get = function()
						return db.tab.fade_inactive
					end,
					set = function(_, value)
						db.tab.fade_inactive = value
						UpdateChatFrames()
					end,
				},
				hide_border = {
					order = 30,
					type = "toggle",
					name = L["Hide Border"],
					desc = L["Hides the tab border, leaving only the text visible."],
					get = function()
						return db.tab.hide_border
					end,
					set = function(_, value)
						db.tab.hide_border = value

						for index in pairs(CHAT_FRAMES) do
							SetTabBorders(index)
						end
					end,
				},
				highlight = {
					order = 40,
					type = "toggle",
					name = "Highlight",
					get = function()
						return db.tab.highlight
					end,
					set = function(_, value)
						db.tab.highlight = value
						UpdateChatFrames()
					end,
				},
				spacer_1 = {
					order = 41,
					type = "description",
					name = "",
				},
				tab_defaults = {
					order = 50,
					type = "execute",
					name = _G.DEFAULT,
					width = "half",
					func = function()
						for option, value in pairs(DEFAULT_OPTIONS.tab) do
							db.tab[option] = value
						end
						UpdateChatFrames()
					end,
				},
				header_2 = {
					order = 51,
					type = "header",
					name = L["Alert Options"],
				},
				flash_texture = {
					order = 60,
					type = "select",
					name = _G.APPEARANCE_LABEL,
					desc = L["Changes the appearance of the pulsing alert flash."],
					disabled = IsFlashDisabled,
					get = function()
						return db.alert_flash.texture
					end,
					set = function(_, value)
						db.alert_flash.texture = value
						UpdateChatFrames()
					end,
					values = FLASH_DESCRIPTIONS,
				},
				flash_color = {
					order = 70,
					type = "color",
					name = _G.COLOR,
					disabled = IsFlashDisabled,
					get = function()
						local col = db.alert_flash.colors
						return col.r, col.g, col.b
					end,
					set = function(_, r, g, b)
						SetColorTable(db.alert_flash.colors, r, g, b)
						UpdateChatFrames()
					end,
				},
				disable_flash = {
					order = 80,
					type = "toggle",
					name = _G.DISABLE,
					desc = L["Disables the pulsing alert flash."],
					get = function()
						return db.alert_flash.disable
					end,
					set = function(_, value)
						db.alert_flash.disable = value
						UpdateChatFrames()
					end,
				},
				spacer_2 = {
					order = 81,
					type = "description",
					name = "",
				},
				flash_defaults = {
					order = 90,
					type = "execute",
					name = _G.DEFAULT,
					width = "half",
					func = function()
						local col = DEFAULT_OPTIONS.alert_flash.colors

						SetColorTable(db.alert_flash.colors, col.r, col.g, col.b)

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
			args = {}
		}
		options.args.color_options = GetColorOptions()
		options.args.message_options = GetMessageOptions()
		options.args.misc_options = GetMiscOptions()
	end
	return options
end

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

function ChatAlerts:SetupOptions()
	AceConfigRegistry:RegisterOptionsTable(ADDON_NAME, GetOptions)
	self.options_frame = AceConfigDialog:AddToBlizOptions(ADDON_NAME)
end
