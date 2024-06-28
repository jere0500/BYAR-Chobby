function widget:GetInfo()
	return {
		name    = 'Optionpreset Panel',
		desc    = 'Implements the Optionpreset panel.',
		author  = 'jere0500',
		date    = '22 June 2024',
		license = 'GNU GPL v2',
		layer   = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Structure
local modoptionDefaults = {}
local modoptionStructure = {}

-- Variables
local battleLobby
local battle

-- edited by the preset
local currentModoptions = {}
local currentMap
local currentAINames
local currentStartRects

local window
local OptionpresetsPanel = {}


local appliedPreset
-- now we need to store the object in this class
local jsondata;
local selectedPreset


local localModoptions = {}

if appliedPreset == nil then
	appliedPreset = "defaultPreset";
	selectedPreset = "defaultPreset";
end

local refreshPresetMenu = function()
end



local function refreshJSONData()
	local modfile = io.open("modfile.json", 'r')
	if modfile ~= nil then
		-- create file
		jsondata = json.decode(modfile:read())
	end
	if jsondata == nil then
		jsondata = {}
		jsondata["defaultPreset"] = {}
		modfile = io.open("modfile.json", 'w')
		local jsonobj = json.encode(jsondata)
		modfile:write(jsonobj)
	end
	modfile:close()
end
local function saveJSONData()
	local modfile = io.open("modfile.json", 'w')
	if modfile == nil then
		-- maybe some logging
		return
	end
	local jsonobj = json.encode(jsondata)
	modfile:write(jsonobj)
	modfile:close()
end

local function applyPreset(presetName)
	appliedPreset = presetName

	--modoptions, ignore if nil
	local presetObj = jsondata[presetName]
	if presetObj ~= nil then
		localModoptions = presetObj["modoptions"]
		if (localModoptions ~= nil) then
			battleLobby:SetModOptions(localModoptions)
		end
		local presetMapName = presetObj["map"]
		if (presetMapName ~= nil) then
			battleLobby:SelectMap(presetMapName)
		end
		local presetRectangles = presetObj["startingRects"]
		if (presetRectangles ~= nil) then
			-- local brStartRects = WG.BattleRoomWindow.GetCurrentStartRects2()
			for index, value in ipairs(presetRectangles) do
				local l = value["left"]
				local r = value["right"]
				local t = value["top"]
				local b = value["bottom"]
				WG.BattleRoomWindow.AddStartRect(index-1, l, t, r, b)
			end
		end
	end
end

local function deletePreset(presetName)
	if presetName ~= "defaultPreset" then
		jsondata[presetName] = nil
		saveJSONData()
		refreshPresetMenu()
	end
end

-- also creates new Presets
local function overwritePreset(presetName)
	local preset = presetName
	if (presetName == nil) then
		preset = "defaultPreset"
	end
	if jsondata[preset] == nil then
		jsondata[preset] = {}
	end
	if jsondata[preset]["modoptions"] == nil then
		jsondata[preset]["modoptions"] = {}
	end
	if jsondata[preset]["map"] == nil then
		jsondata[preset]["map"] = {}
	end
	if jsondata[preset]["ai"] == nil then
		jsondata[preset]["ai"] = {}
	end
	if jsondata[preset]["startingRects"] == nil then
		jsondata[preset]["startingRects"] = {}
	end

	jsondata[preset]["modoptions"] = localModoptions
	jsondata[preset]["map"] = currentMap
	jsondata[preset]["ai"] = currentAINames
	jsondata[preset]["startingRects"] = currentStartRects


	selectedPreset = preset

	saveJSONData()
	refreshPresetMenu()
end

local function PopulatePresetTab()
	-- initial population
	refreshJSONData()

	-- parent panel
	local contentsPanel = ScrollPanel:New {
		x = 6,
		right = 5,
		y = 10,
		bottom = 8,
		parent = window,
		horizontalScrollbar = false,
	}


	local function OpenPresetPopup()
		local openPresetPopup = Window:New {
			caption = "Create new preset",
			name = "createNewPreset",
			parent = contentsPanel,
			align = "center",
			width = 500,
			height = 200,
			resizable = false,
			draggable = false,
			classname = "main_window",
		}

		local presetEditBox = EditBox:New {
			x                      = 10,
			y                      = 10,
			width                  = 300,
			height                 = 30,
			text                   = "",
			useIME                 = false,
			hint                   = "enter the name for your preset",
			parent                 = openPresetPopup,
			objectOverrideFont     = WG.Chobby.Configuration:GetFont(2),
			objectOverrideHintFont = WG.Chobby.Configuration:GetFont(11),
			tooltip                = "enter a name for your preset",
			OnFocusUpdate          = {
				-- function(obj)
				-- 	Spring.Echo("updated")
				-- end
			}
		}

		local buttonSave = Button:New {
			x = 10,
			width = 135,
			y = 50,
			height = 70,
			caption = "Save Preset",
			parent = openPresetPopup,
			objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
			classname = "action_button",
			OnClick = {
				function()
					local preset = "defaultPreset"
					if (presetEditBox.text ~= nil) then
						preset = presetEditBox.text
					end
					overwritePreset(preset)
					openPresetPopup:Dispose()
					-- if not json then
					--
					-- 	VFS.Include(LIB_LOBBY_DIRNAME .. "json.lua")
					-- end
					-- this only adds all options, which are different from the defaults
				end
			},
		}
		local buttonAbort = Button:New {
			x = 145,
			width = 135,
			y = 50,
			height = 70,
			caption = "Abort",
			parent = openPresetPopup,
			objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
			classname = "negative_button",
			OnClick = {
				function()
					refreshPresetMenu()
					openPresetPopup:Dispose()
				end
			},
		}
	end

	-- needs to get repopulated, when creating a new preset
	local presetNames = {}
	local presetList = {}
	refreshPresetMenu = function()
		presetNames = {}
		if jsondata[selectedPreset] == nil then
			selectedPreset = "defaultPreset"
		end

		table.insert(presetNames, selectedPreset)
		table.insert(presetNames, "<new>")
		for key, _ in pairs(jsondata) do
			if (key ~= selectedPreset) then
				table.insert(presetNames, key)
			end
		end


		contentsPanel:RemoveChild(presetList)
		presetList = ComboBox:New {
			x = 10,
			y = 0,
			width = 300,
			height = 30,
			valign = "center",
			align = "left",
			objectOverrideFont = WG.Chobby.Configuration:GetFont(2),
			items = presetNames,
			selectByName = true,
			selected = selectedPreset,
			OnSelectName = {
				function(obj, selectedName)
					if (selectedName == "<new>") then
						-- handle creation of the popup
						OpenPresetPopup()
						presetList.selected = appliedPreset
						selectedPreset = appliedPreset
						-- open the popup
					else
						selectedPreset = selectedName
					end
				end
			},
			itemKeyToName = presetNames, -- Not a chili key
			-- tooltip = data.desc,
		}
		contentsPanel:AddChild(presetList)
	end






	local buttonLoad = Button:New {
		x = 155,
		width = 135,
		y = 40,
		height = 70,
		caption = "Load Preset",
		objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
		classname = "action_button",
		OnClick = {
			function()
				applyPreset(selectedPreset)
				window:Dispose()
			end
		},
	}

	local buttonSave = Button:New {
		x = 300,
		width = 135,
		y = 40,
		height = 70,
		caption = "Overwrite Preset",
		objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
		classname = "action_button",
		OnClick = {
			function()
				overwritePreset(selectedPreset)
				window:Dispose()
				-- battleLobby:SetModOptions(localModoptions)
			end
		},
	}


	local buttonDelete = Button:New {
		x = 10,
		width = 135,
		y = 40,
		height = 70,
		caption = "Delete Preset",
		objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
		classname = "negative_button",
		OnClick = {
			function()
				deletePreset(selectedPreset)
			end
		},
	}






	refreshPresetMenu()

	-- contentsPanel:AddChild(presetEditBox)
	-- contentsPanel:AddChild(buttonSave)
	contentsPanel:AddChild(buttonLoad)
	contentsPanel:AddChild(buttonDelete)
	contentsPanel:AddChild(buttonSave)
	return { contentsPanel }
end

local function CreateOptionpresetWindow()
	local ww, wh = Spring.GetWindowGeometry()

	local optionpresetWindow = Window:New {
		caption = "",
		align = "center",
		name = "optionpresetSelectionWindow",
		parent = WG.Chobby.lobbyInterfaceHolder,
		width = math.min(650, ww - 50),
		height = math.min(300, wh - 50),
		resizable = false,
		draggable = false,
		classname = "main_window",
	}

	currentModoptions = Spring.Utilities.CopyTable(battleLobby:GetMyBattleModoptions() or {})

	local buttonCancel = Button:New {
		right = 6,
		width = 135,
		bottom = 1,
		height = 70,
		caption = i18n("cancel"),
		objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
		parent = optionpresetWindow,
		classname = "negative_button",
		OnClick = {
			function()
				-- CancelFunc()
				window:Dispose()
			end
		},
	}

	-- local popupHolder = WG.Chobby.PriorityPopup(modoptionsSelectionWindow, CancelFunc, AcceptFunc)

	WG.Chobby.lobbyInterfaceHolder.OnResize = WG.Chobby.lobbyInterfaceHolder.OnResize or {}
	WG.Chobby.lobbyInterfaceHolder.OnResize[#WG.Chobby.lobbyInterfaceHolder.OnResize + 1] = function()
		local ww, wh = Spring.GetWindowGeometry()

		local neww = math.min(1666, ww - 50)
		local newx = (WG.Chobby.lobbyInterfaceHolder.width - neww) / 2

		local newh = math.min(420, wh - 50)
		local newy = (WG.Chobby.lobbyInterfaceHolder.height - newh) / 2

		optionpresetWindow:SetPos(
			newx,
			newy,
			neww,
			newh
		)
	end

	local function CancelFunc()
		window:Dispose()
	end

	local popupHolder = WG.Chobby.PriorityPopup(optionpresetWindow, CancelFunc, nil)
	window = optionpresetWindow
	-- window:AddChild(PopulatePresetTab())
	PopulatePresetTab()
end




function OptionpresetsPanel.ShowModoptions()
	-- getting the correct values
	battleLobby = WG.LibLobby.localLobby
	localModoptions = Spring.Utilities.CopyTable(battleLobby:GetMyBattleModoptions() or {})
	-- need to get the modoptions
	battle = battleLobby:GetBattle(battleLobby:GetMyBattleID())

	-- not available in mp
	currentMap = battle.mapName


	currentAINames = battleLobby.battleAis

	currentStartRects = WG.BattleRoomWindow.GetCurrentStartRects()

	CreateOptionpresetWindow()
end

function widget:Initialize()
	CHOBBY_DIR = LUA_DIRNAME .. "widgets/chobby/"
	VFS.Include(LUA_DIRNAME .. "widgets/chobby/headers/exports.lua", nil, VFS.RAW_FIRST)
	VFS.Include("libs/json.lua")

	WG.OptionpresetsPanel = OptionpresetsPanel
end
