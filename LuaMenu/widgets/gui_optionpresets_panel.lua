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

-- Variables
local battleLobby
local battle
local OptionpresetsPanel = {}
local window
local multiplayer = false

-- enabled options
local enabledOptions = {}

-- edited by the preset
local currentModoptions = {}
local currentMap
local currentAITable = {}
local currentStartRects
local currentStartPosType
local currentMPBattleSettings = {}

-- now we need to store the object in this class
local jsondata;

-- preset that is selected in the dropdown menu
local selectedPresetName = "defaultPreset";

-- preset that is currently applied
local appliedPresetName = "defaultPreset";

-- defining function to later overwrite
local refreshPresetMenu = function()
end


--------------------------------------------------------------------------------
--- Helper functions
--------------------------------------------------------------------------------
local function refreshJSONData()
	local modfile = io.open("optionsPresets.json", 'r')
	if modfile ~= nil then
		local boolOut
		boolOut, jsondata = pcall(json.decode, modfile:read())

		-- handles broken json file
		if not boolOut then
			--error during file reading, should output read text TODO
			modfile:close()
			local localtime = os.date('%Y-%m-%d-%H:%M:%S')
			local renamesuccess = os.rename("optionsPresets.json", "optionsPresetsError:" .. localtime .. ".json")
			if not renamesuccess then
				Spring.Echo("fail during rename")
				return
			end
			-- generate a new file
			refreshJSONData()
			return
		end
	end
	if modfile == nil then
		-- creates file when it does not exist
		jsondata = {}
		jsondata["defaultPreset"] = {}
		modfile = io.open("optionsPresets.json", 'w')
		local jsonobj = json.encode(jsondata)
		modfile:write(jsonobj)
	end

	modfile:close()
end

-- writes preset changes to file
local function saveJSONData()
	local modfile = io.open("optionsPresets.json", 'w')
	if modfile == nil then
		-- maybe some logging
		return
	end
	local jsonobj = json.encode(jsondata)
	modfile:write(jsonobj)
	modfile:close()
end

-- apply specific preset to the current Lobby
local function applyPreset(presetName)
	appliedPresetName = presetName

	local presetObj = jsondata[presetName]
	if presetObj ~= nil then
		-- only apply in multiplayer
		local presetMPBattleSettings = presetObj["MPBattleSettings"]
		if presetMPBattleSettings ~= nil and multiplayer then
			battleLobby:SayBattle("!preset " .. presetMPBattleSettings["preset"])
			if presetMPBattleSettings["locked"] then
				battleLobby:SayBattle("!lock")
			else
				battleLobby:SayBattle("!unlock")
			end
			battleLobby:SayBattle("!autobalance " .. presetMPBattleSettings["autoBalance"])
			battleLobby:SayBattle("!balanceMode " .. presetMPBattleSettings["balanceMode"])
			battleLobby:SayBattle("!set teamSize " .. presetMPBattleSettings["teamSize"])
			battleLobby:SayBattle("!nbTeams " .. presetMPBattleSettings["nbTeams"])
		end

		-- modoptions
		currentModoptions = presetObj["modoptions"]
		if (currentModoptions ~= nil and enabledOptions["modoptions"]) then
			battleLobby:SetModOptions(currentModoptions)
		end

		-- AIs with their settings
		local presetAi = presetObj["ai"]
		if presetAi ~= nil and enabledOptions["ai"] then
			local newAiNames = {}

			for key, _ in pairs(currentAITable) do
				battleLobby:RemoveAi(key)
			end
			currentAITable = {}
			for key, value in pairs(presetAi) do
				currentAITable[key] = value
				local battlestatusoptions = {}
				battlestatusoptions.teamColor = value.teamColor
				battlestatusoptions.side = value.side
				battleLobby:AddAi(key, value.aiLib, value.allyNumber, value.aiVersion, value.aiOptions,
					battlestatusoptions)
			end
		end

		-- map
		local presetMapName = presetObj["map"]
		if (presetMapName ~= nil and enabledOptions["map"]) then
			battleLobby:SelectMap(presetMapName)
		end

		-- starting Areas
		local presetRectangles = presetObj["startingRects"]
		if (presetRectangles ~= nil and enabledOptions["startingRects"]) then
			WG.BattleRoomWindow.RemoveStartRect()
			for index, value in ipairs(presetRectangles) do
				local l = value["left"]
				local r = value["right"]
				local t = value["top"]
				local b = value["bottom"]

				WG.BattleRoomWindow.AddStartRect(index - 1, l, t, r, b)
			end
		end

		local startPosType = presetObj["startPosType"]
		if startPosType ~= nil and enabledOptions["startPosType"] then
			WG.BattleRoomWindow.SetBattleStartPosType(startPosType)
		end
	end
end

-- deletes a preset by name
local function deletePreset(presetName)
	if presetName ~= "defaultPreset" then
		jsondata[presetName] = nil
		saveJSONData()
		refreshPresetMenu()
	end
end

-- applies changes to specified preset
-- (creates new preset if none with that name exists)
local function writePreset(presetName)
	local preset = presetName
	if (presetName == nil) then
		preset = "defaultPreset"
	end

	if jsondata[preset] == nil then
		jsondata[preset] = {}
	end

	if currentModoptions ~= nil and enabledOptions["modoptions"] then
		if jsondata[preset]["modoptions"] == nil then
			jsondata[preset]["modoptions"] = {}
		end
		jsondata[preset]["modoptions"] = currentModoptions
	end

	if currentMap ~= nil and enabledOptions["map"] then
		if jsondata[preset]["map"] == nil then
			jsondata[preset]["map"] = {}
		end
		jsondata[preset]["map"] = currentMap
	end


	if currentAITable ~= nil then
		if jsondata[preset]["ai"] and enabledOptions["ai"] == nil then
			jsondata[preset]["ai"] = {}
		end
		jsondata[preset]["ai"] = currentAITable
	end

	if currentStartRects ~= nil then
		if jsondata[preset]["startingRects"] and enabledOptions["startingRects"] == nil then
			jsondata[preset]["startingRects"] = {}
		end
		jsondata[preset]["startingRects"] = currentStartRects
	end

	if currentStartPosType ~= nil then
		if jsondata[preset]["startPosType"] == nil and enabledOptions["startPosType"] then
			jsondata[preset]["startPosType"] = {}
		end
		jsondata[preset]["startPosType"] = currentStartPosType
	end

	if currentMPBattleSettings ~= nil then
		if jsondata[preset]["MPBattleSettings"] == nil and enabledOptions["MPBattleSettings"] then
			jsondata[preset]["MPBattleSettings"] = {}
		end
		jsondata[preset]["MPBattleSettings"] = currentMPBattleSettings
	end

	-- selects to apply preset
	selectedPresetName = preset

	saveJSONData()
	refreshPresetMenu()
end

--------------------------------------------------------------------------------
--- Gui functions
--------------------------------------------------------------------------------

-- generate checkbox panel for disabling/ enabling loading
local function ProcessBoolOption(name, active, index)
	local label = Label:New {
		x = 35,
		y = 0,
		width = 1200,
		height = 30,
		valign = "center",
		align = "left",
		caption = name,
		objectOverrideFont = WG.Chobby.Configuration:GetFont(2),
	}

	local checkBox = Checkbox:New {
		x = 5,
		y = 0,
		width = 30,
		height = 30,
		boxalign = "left",
		boxsize = 25,
		caption = "", --data.name,
		checked = active,
		objectOverrideFont = WG.Chobby.Configuration:GetFont(2),

		OnChange = {
			function(_, newState)
				enabledOptions[name] = ((newState and true) or false)
			end
		},
	}

	return Control:New {
		x = 0,
		y = index * 32,
		width = 1600,
		height = 32,
		padding = { 0, 0, 0, 0 },
		children = {
			label,
			checkBox
		}
	}
end

-- generates the view for the preset selection panel
local function PopulatePresetPanel(parentPanel)
	-- reading the default Preset options from the json data
	refreshJSONData()

	-- popup for entering a new preset Name
	local function OpenPresetPopup()
		local openPresetPopup = Window:New {
			caption = "Create new preset",
			name = "createNewPreset",
			parent = parentPanel,
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
			right                  = 10,
			height                 = 30,
			text                   = "",
			useIME                 = false,
			hint                   = "enter the name for your preset",
			parent                 = openPresetPopup,
			objectOverrideFont     = WG.Chobby.Configuration:GetFont(2),
			objectOverrideHintFont = WG.Chobby.Configuration:GetFont(11),
			tooltip                = "enter a name for your new preset",
		}

		Button:New {
			x = 10,
			width = 135,
			y = 50,
			height = 70,
			caption = "Save",
			parent = openPresetPopup,
			objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
			classname = "action_button",
			OnClick = {
				function()
					local preset = "defaultPreset"
					if (presetEditBox.text ~= nil) then
						preset = presetEditBox.text
					end
					writePreset(preset)
					openPresetPopup:Dispose()
				end
			},
		}

		Button:New {
			x = 155,
			width = 135,
			y = 50,
			height = 70,
			caption = "Cancel",
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

		-- also need the disposing thign
		-- local function CancelFunc()
		-- 	openPresetPopup:Dispose()
		-- end
		--
		-- WG.Chobby.PriorityPopup(openPresetPopup, CancelFunc, nil)
	end

	local presetNames = {}
	local presetList = {}
	-- (re)generates the dropdown list of presets
	refreshPresetMenu = function()
		presetNames = {}
		if jsondata[selectedPresetName] == nil then
			selectedPresetName = "defaultPreset"
		end

		table.sort(jsondata)
		table.insert(presetNames, selectedPresetName)
		table.insert(presetNames, "<new>")
		local jsonNames = {}
		for key, _ in pairs(jsondata) do
			table.insert(jsonNames, key)
		end
		table.sort(jsonNames)
		for _, value in pairs(jsonNames) do
			if (value ~= selectedPresetName) then
				table.insert(presetNames, value)
			end
		end


		parentPanel:RemoveChild(presetList)
		presetList = ComboBox:New {
			x = 10,
			y = 0,
			width = 425,
			height = 30,
			valign = "center",
			align = "left",
			objectOverrideFont = WG.Chobby.Configuration:GetFont(2),
			items = presetNames,
			selectByName = true,
			selected = selectedPresetName,
			OnSelectName = {
				function(obj, selectedName)
					if (selectedName == "<new>") then
						OpenPresetPopup()
						presetList.selected = appliedPresetName
						selectedPresetName = appliedPresetName
					else
						selectedPresetName = selectedName
					end
				end
			},
			itemKeyToName = presetNames,
		}
		parentPanel:AddChild(presetList)
	end

	local buttonLoad = Button:New {
		x = 10,
		width = 135,
		y = 40,
		height = 70,
		caption = "Load",
		objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
		classname = "action_button",
		OnClick = {
			function()
				applyPreset(selectedPresetName)
				window:Dispose()
			end
		},
	}

	local buttonSave = Button:New {
		x = 155,
		width = 135,
		y = 40,
		height = 70,
		caption = "Overwrite",
		objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
		classname = "action_button",
		OnClick = {
			function()
				writePreset(selectedPresetName)
				window:Dispose()
				-- battleLobby:SetModOptions(localModoptions)
			end
		},
	}

	local function disableSelectedPreset()
		deletePreset(selectedPresetName)
	end


	local buttonDelete = Button:New {
		x = 300,
		width = 135,
		y = 40,
		height = 70,
		caption = "Delete ",
		objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
		classname = "negative_button",
		OnClick = {
			function()
				WG.Chobby.ConfirmationPopup(disableSelectedPreset, "This will delete the preset. Are you sure?", nil, 315,
					170, i18n("yes"), i18n("cancel"))
			end
		},
	}

	refreshPresetMenu()

	parentPanel:AddChild(buttonLoad)
	parentPanel:AddChild(buttonDelete)
	parentPanel:AddChild(buttonSave)
	return { parentPanel }
end

local function CreateOptionpresetWindow()
	local ww, wh = Spring.GetWindowGeometry()

	local optionpresetWindow = Window:New {
		caption = "",
		align = "center",
		name = "OptionpresetsWindow",
		parent = WG.Chobby.lobbyInterfaceHolder,
		width = math.min(505, ww - 50),
		height = math.min(380, wh - 50),
		resizable = false,
		draggable = false,
		classname = "main_window",
	}
	-- first panel
	local contentsPanel = ScrollPanel:New {
		x = 4,
		right = 0,
		y = 10,
		bottom = 0,
		horizontalScrollbar = false,
	}

	-- add the tabs
	local tabs = {}
	tabs[1] = {
		name = "tsneraio",
		caption = "presets",
		tooltip = nil,
		objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
		children = { contentsPanel },
		weight = 1,
	}


	-- potential panel 2
	local optionpanel = ScrollPanel:New {
		x = 4,
		y = 10,
		right = 0,
		bottom = 0,
		-- height = 100,
		-- width = 400,
		-- parent = contentsPanel,
		horizontalScrollbar = false,
	}
	tabs[2] = {
		name = "options",
		caption = "load options",
		tooltip = nil,
		objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
		children = { optionpanel },
		weight = 2,
	}

	Spring.Echo("-----tabvals-----")
	Spring.Echo(tabs[#tabs].name)
	Spring.Echo(tabs[#tabs].caption)
	Spring.Echo(tabs[#tabs].tooltip)
	Spring.Echo(tabs[#tabs].objectOverrideFont)
	Spring.Echo(tabs[#tabs].children)
	Spring.Echo(tabs[#tabs].weight)

	-- initiate the tab layout
	local tabPanel = Chili.DetachableTabPanel:New {
		x = 4,
		right = 4,
		y = 49,
		bottom = 75,
		padding = { 0, 0, 0, 0 },
		minTabWidth = 220,
		tabs = tabs,
		parent = optionpresetWindow,
		OnTabChange = {
		}
	}

	local tabBarHolder = Control:New {
		name = "tabBarHolder",
		x = 0,
		y = 0,
		right = 0,
		height = 60,
		resizable = false,
		draggable = false,
		padding = { 18, 6, 18, 0 },
		parent = optionpresetWindow,
		children = {
			Line:New {
				classname = "line_solid",
				x = 0,
				y = 52,
				right = 0,
				bottom = 0,
			},
			tabPanel.tabBar
		}
	}

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
	PopulatePresetPanel(contentsPanel)

	-- adding the enabled/ disabled options
	-- preparing the array
	-- first all should be enabled, keys are the same as in the localjson
	enabledOptions["modoptions"] = true
	enabledOptions["map"] = true
	enabledOptions["ai"] = true
	enabledOptions["startingRects"] = true
	enabledOptions["startPosType"] = true
	enabledOptions["MPBattleSettings"] = multiplayer

	-- to add a bit of offset
	--


	local counter = 0
	for key, value in pairs(enabledOptions) do
		optionpanel:AddChild(ProcessBoolOption(key, value, counter))
		counter = counter + 1
	end
end

-- external function to open the preset Panel
function OptionpresetsPanel.ShowPresetPanel()
	battleLobby = WG.LibLobby.localLobby
	battle = battleLobby:GetBattle(battleLobby:GetMyBattleID())

	-- multiplayer case, battle/ lobby are the WG.LibLobby.lobby
	if not battle then
		battleLobby = WG.LibLobby.lobby
		battle = battleLobby:GetBattle(battleLobby:GetMyBattleID())
		multiplayer = true
	end

	-- copy all options from the battle/ lobby for managing:

	currentModoptions = Spring.Utilities.CopyTable(battleLobby:GetMyBattleModoptions() or {})

	if battle then
		currentMap = battle.mapName
		currentStartPosType = battle.startPosType
	else
		Spring.Echo("No battle found")
	end


	local currentAINames = battleLobby.battleAis
	currentAITable = {}
	for _, value in pairs(currentAINames) do
		local aiStatus = battleLobby:GetUserBattleStatus(value)
		if (aiStatus ~= nil) then
			currentAITable[value] = aiStatus
		end
	end

	currentStartRects = WG.BattleRoomWindow.GetCurrentStartRects()

	-- multiplayer specific options
	if multiplayer then
		currentMPBattleSettings["locked"] = battle.locked
		currentMPBattleSettings["autoBalance"] = battle.autoBalance
		currentMPBattleSettings["teamSize"] = battle.teamSize
		currentMPBattleSettings["nbTeams"] = battle.nbTeams
		currentMPBattleSettings["balanceMode"] = battle.balanceMode
		currentMPBattleSettings["preset"] = battle.preset
	end

	CreateOptionpresetWindow()
end

-- make the widget accessible from the preset Panel
function widget:Initialize()
	CHOBBY_DIR = LUA_DIRNAME .. "widgets/chobby/"
	VFS.Include(LUA_DIRNAME .. "widgets/chobby/headers/exports.lua", nil, VFS.RAW_FIRST)
	VFS.Include("libs/json.lua")

	WG.OptionpresetsPanel = OptionpresetsPanel
end
