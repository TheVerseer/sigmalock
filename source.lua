local gui

if game:GetService("RunService"):IsStudio() then
	gui = script.Parent:FindFirstChild("Lock_Gui") or game:GetObjects('rbxassetid://18622836850')[1] 
else
	gui = game:GetObjects('rbxassetid://18622836850')[1]
end 

--[[
	IGNORE: USED FOR DEBUGGING
]]

gui.Parent = game.Players.LocalPlayer.PlayerGui

local defaultSettings = {
	["LockBind"] = Enum.KeyCode.LeftShift,
	["ESPBind"] = Enum.KeyCode.LeftAlt,
	["RefreshESPBind"] = Enum.KeyCode.RightAlt,
	["AimSwitchBind"] = Enum.KeyCode.RightShift,
	["FFASwitchBind"] = Enum.KeyCode.RightControl,

	["FreeForAll"] = false,
	["TeamsToSkip"] = {},
	
	["RunForRigs"] = true,
	
	["AimAt"] = "Head",
	["AimAtOptions"] = {"Head", "Torso", "LowerTorso"},

	["ESP"] = false,
	["ESPRefreshInterval"] = 10,
	
	["ESPDefaultColor"] = Color3.fromRGB(255, 0, 0),
	["ESPDefaultColor_NPC"] = Color3.fromRGB(0, 255, 0),
	["ESPFillTransparency_Visible"] = 0.8,
	["ESPOutlineTransparency_Visible"] = 0.4,
	["ESPFillTransparency_NonVisible"] = 0.4,
	["ESPOutlineTransparency_NonVisible"] = 0.2,

	["LockEnabledColor"] = Color3.fromRGB(10, 100, 10),
	["LockDisabledColor"] = Color3.fromRGB(100, 10, 10),

	["GuiTransparency"] = 0.4, 
	["TweenInfo"] = TweenInfo.new(0.1, Enum.EasingStyle.Exponential),

	["_currentAimAtPart"] = 0,
	["_currentESPColor"] = 0,
	["_currentLockedPlayer"] = nil,
	
	["_DEBUG"] = false
}

--------------------------------------------------------------------------------------

local data = _G._Aim or {}

for gIndex, gValue in pairs(defaultSettings) do
	if not data[gIndex] then
		data[gIndex] = gValue
	else
		if typeof(data[gIndex]) ~= typeof(gValue) then
			data[gIndex] = gValue
		end
	end
end

--------------------------------------------------------------------------------------

local plrs = game:GetService("Players")
local cgui = game:GetService("CoreGui")
local runs = game:GetService("RunService")
local ts = game:GetService("TweenService")
local uis = game:GetService("UserInputService")

--------------------------------------------------------------------------------------

local player = plrs.LocalPlayer
local mouse = player:GetMouse()
local curCam = workspace.CurrentCamera

--------------------------------------------------------------------------------------

local currentPlayersESP = {}
local currentESPConnections = {}
local currentESP = {}

local lastPlayerESPVisibilityChange = {}
local lastESPToggle = nil

local defaultSizes = {}
local disabledText = `Hold "{data.LockBind.Name}" to Enable`

--------------------------------------------------------------------------------------

local function CanLockPlayer(plr)
	if data._currentLockedPlayer then
		return false
	end
	
	if plr and plr:IsA("Player") then
		if plr ~= player then
			if plr.Team ~= player.Team then
				return true
			else
				return data.FreeForAll
			end
		end
	elseif plr:IsA("Model") then
		return true
	end
	
	return false
end

local function GetRigs()
	local rigs = {}
	for _, rig in pairs(workspace:GetDescendants()) do
		if rig:IsA("Model") and rig:FindFirstChildOfClass("Humanoid") and not plrs:GetPlayerFromCharacter(rig) then
			table.insert(rigs, rig)
		end
	end
	return rigs
end

local function ClearInstanceOfClass(i,c,d)
	for _, o:Instance in pairs(i:GetChildren()) do
		if o:IsA(c) then
			if d and o:IsDescendantOf(d) then
				continue
			end

			o:Destroy()
		end
	end
end

local function ToggleLabel(label, enabled)
	task.spawn(function()
		if enabled then
			if not defaultSizes[label] then
				defaultSizes[label] = label.UITextSizeConstraint.MaxTextSize
			end
			label.Visible = true
		else
			label.Visible = false
		end
	end)
end

local function CycleAimPart()
	local function add()
		if data._currentAimAtPart+1 > #data.AimAtOptions then 
			data._currentAimAtPart = 1 
		else
			data._currentAimAtPart+=1
		end
	end

	add()

	if not player.Character:FindFirstChild(data.AimAtOptions[data._currentAimAtPart]) then 
		repeat add() until player.Character:FindFirstChild(data.AimAtOptions[data._currentAimAtPart])
	end

	data.AimAt = data.AimAtOptions[data._currentAimAtPart]
end

--------------------------------------------------------------------------------------

local function GetPlayersNearMouse()
	local playersNearMouse = {}
	for _, plr in pairs(plrs:GetPlayers()) do
		local character = plr.Character
		if character then
			local distance = (character.HumanoidRootPart.Position - mouse.Hit.Position).Magnitude
			table.insert(playersNearMouse, {plr, distance})
		end
	end
	if data.RunForRigs then
		for _, rig in pairs(GetRigs()) do
			if rig then
				local distance = (rig.HumanoidRootPart.Position - mouse.Hit.Position).Magnitude
				table.insert(playersNearMouse, {rig, distance, true})
			end
		end
	end
	table.sort(playersNearMouse, function(a, b) return a[2] < b[2] end)
	return playersNearMouse
end

local function GetPlayersNearLocalPlayer()
	local playersNearLocalPlayer = {}
	local localCharacter = player.Character
	if not localCharacter then return playersNearLocalPlayer end
	local localPosition = localCharacter.HumanoidRootPart.Position

	for _, plr in pairs(plrs:GetPlayers()) do
		local character = plr.Character
		if character then
			local distance = (character.HumanoidRootPart.Position - localPosition).Magnitude
			table.insert(playersNearLocalPlayer, {plr, distance})
		end
	end
	if data.RunForRigs then
		for _, rig in pairs(GetRigs()) do
			if rig then
				local distance = (rig.HumanoidRootPart.Position - localPosition).Magnitude
				table.insert(playersNearLocalPlayer, {rig, distance, true})
			end
		end
	end
	table.sort(playersNearLocalPlayer, function(a, b) return a[2] < b[2] end)
	return playersNearLocalPlayer
end

local function PlayerIsVisible(plr)
	if plr:IsA("Player") then
		local _, onScreen = curCam:WorldToViewportPoint(plr.Character.HumanoidRootPart.Position)
		return onScreen
	elseif plr:IsA("Model") then
		local _, onScreen = curCam:WorldToViewportPoint(plr.HumanoidRootPart.Position)
		return onScreen
	end
end

local function FindBestPlayerToLock()
	local playersNearMouse = GetPlayersNearMouse()
	local playersNearLocalPlayer = GetPlayersNearLocalPlayer()

	for _, entry in pairs(playersNearMouse) do
		if entry[3] or CanLockPlayer(entry[1]) then
			if PlayerIsVisible(entry[1]) then
				return entry[1]
			end
		end
	end

	for _, entry in pairs(playersNearLocalPlayer) do
		if entry[3] or CanLockPlayer(entry[1]) then
			if PlayerIsVisible(entry[1]) then
				return entry[1]
			end
		end
	end

	return false
end

--[[
local function GetNearestPlayerToMouse()
	local plrHold = {}
	local distances = {}

	for i, v in pairs(plrs:GetPlayers()) do
		if CanLockPlayer(v) then
			local aim = v.Character:FindFirstChild(data.AimAt)
			if aim ~= nil then
				local dis = (aim.Position - game.Workspace.CurrentCamera.CoordinateFrame.p).magnitude
				local ray = Ray.new(game.Workspace.CurrentCamera.CoordinateFrame.p, (mouse.Hit.p - curCam.CoordinateFrame.p).unit * dis)
				local hit,pos = game.Workspace:FindPartOnRay(ray, game.Workspace)
				local diff = math.floor((pos - aim.Position).magnitude)
				plrHold[v.Name .. i] = {}
				plrHold[v.Name .. i].dis= dis
				plrHold[v.Name .. i].plr = v
				plrHold[v.Name .. i].diff = diff
				table.insert(distances, diff)
			end
		end
	end

	if unpack(distances) == nil then
		return false
	end

	local dis = math.floor(math.min(unpack(distances)))
	if dis > 20 then
		return false
	end

	for i, v in pairs(plrHold) do
		if v.diff == dis then
			return v.plr
		end
	end
	return false
end
]]

--------------------------------------------------------------------------------------

local function ToggleESP(enabled)
	if lastESPToggle ~= enabled then
		lastESPToggle = enabled
		for _, folder in pairs(currentESP) do
			folder.ESP_Highlight.Enabled = enabled
			folder.ESP_Billboard.Enabled = enabled
		end
	end
end

local function RemoveESP(plr, npc)
	if not npc then
		if currentESP[plr.Name] then
			currentESP[plr.Name]:Destroy()
			currentESP[plr.Name] = nil
		end
	else
		if currentESP[plr] then
			currentESP[plr]:Destroy()
			currentESP[plr] = nil
		end
	end
end

local function AddESP(plr)
	if plr:IsA("Player") then
		if CanLockPlayer(plr) then
			RemoveESP(plr)

			local espFolder = gui.ESP:Clone()

			espFolder.Name = plr.Name
			espFolder.Parent = plr.Character
			espFolder.ESP_Billboard.Title.Text = plr.Name

			currentESP[plr.Name] = espFolder

			if plr.Team then
				espFolder.ESP_Highlight.FillColor = plr.TeamColor.Color
				espFolder.ESP_Highlight.OutlineColor = plr.TeamColor.Color
				espFolder.ESP_Billboard.Title.TextColor3 = plr.TeamColor.Color
			else
				espFolder.ESP_Highlight.FillColor = data.ESPDefaultColor
				espFolder.ESP_Highlight.OutlineColor = data.ESPDefaultColor
				espFolder.ESP_Billboard.Title.TextColor3 = data.ESPDefaultColor
			end

			espFolder.ESP_Billboard.Enabled = data.ESP
			espFolder.ESP_Highlight.Enabled = data.ESP
			espFolder.ESP_Billboard.Adornee = plr.Character
			espFolder.ESP_Highlight.Adornee = plr.Character
		end
	else
		if data.RunForRigs then
			RemoveESP(plr, true)
			
			local espFolder = gui.ESP:Clone()

			espFolder.Name = plr.Name
			espFolder.Parent = plr
			espFolder.ESP_Billboard.Title.Text = plr.Name

			currentESP[plr.Name] = espFolder

			espFolder.ESP_Highlight.FillColor = data.ESPDefaultColor_NPC
			espFolder.ESP_Highlight.OutlineColor = data.ESPDefaultColor_NPC
			espFolder.ESP_Billboard.Title.TextColor3 = data.ESPDefaultColor_NPC

			espFolder.ESP_Billboard.Enabled = data.ESP
			espFolder.ESP_Highlight.Enabled = data.ESP
			espFolder.ESP_Billboard.Adornee = plr
			espFolder.ESP_Highlight.Adornee = plr
		else
			RemoveESP(plr, true)
		end
	end
end

local function LoadESP()
	if player.PlayerGui:FindFirstChildOfClass("Highlight") then
		ClearInstanceOfClass(player.PlayerGui,"Highlight",gui)
	end
	
	for _, plr in pairs(plrs:GetPlayers()) do
		if not table.find(currentPlayersESP, plr) then
			AddESP(plr)
			currentESPConnections[#currentESPConnections+1] = plr.CharacterAdded:Connect(function()
				AddESP(plr)
			end)
			currentESPConnections[#currentESPConnections+1] = plr:GetPropertyChangedSignal("Team"):Connect(function()
				AddESP(plr)
			end)
			table.insert(currentPlayersESP, plr)
		end
	end
	
	for _, rig in pairs(GetRigs()) do
		if not table.find(currentPlayersESP, rig) then
			AddESP(rig)
			table.insert(currentPlayersESP, rig)
		end
	end
	
	currentESPConnections[#currentESPConnections+1] = plrs.PlayerAdded:Connect(function(plr)
		if not table.find(currentPlayersESP, plr) then
			AddESP(plr)
			currentESPConnections[#currentESPConnections+1] = plr.CharacterAdded:Connect(function()
				AddESP(plr)
			end)
			currentESPConnections[#currentESPConnections+1] = plr:GetPropertyChangedSignal("Team"):Connect(function()
				AddESP(plr)
			end)
			table.insert(currentPlayersESP, plr)
		end
	end)
	
	currentESPConnections[#currentESPConnections+1] = plrs.PlayerRemoving:Connect(function(plr)
		RemoveESP(plr)
		table.remove(currentPlayersESP, table.find(currentPlayersESP, plr))
	end)
end

local function RefreshESP()
	for _, p in pairs(currentESP) do
		RemoveESP(p)
	end
	for _, c in pairs(currentESPConnections) do
		c:Disconnect()
	end
	
	currentESP = {}
	currentESPConnections = {}
	currentPlayersESP = {}
	
	LoadESP()
end

local function UpdateESP()
	for _, plr in pairs(plrs:GetPlayers()) do
		if PlayerIsVisible(plr.Character) then
			if currentESP[plr] and lastPlayerESPVisibilityChange[plr] == nil or lastPlayerESPVisibilityChange[plr] == false then
				lastPlayerESPVisibilityChange[plr] = true
				ts:Create(currentESP[plr].ESP_Highlight, data.TweenInfo, {FillTransparency = data.ESPFillTransparency_Visible}):Play()
				ts:Create(currentESP[plr].ESP_Highlight, data.TweenInfo, {OutlineTransparency = data.ESPOutlineTransparency_Visible}):Play()
			end
		else
			if currentESP[plr] and lastPlayerESPVisibilityChange[plr] == nil or lastPlayerESPVisibilityChange[plr] == true then
				lastPlayerESPVisibilityChange[plr] = false
				ts:Create(currentESP[plr].ESP_Highlight, data.TweenInfo, {FillTransparency = data.ESPFillTransparency_NonVisible}):Play()
				ts:Create(currentESP[plr].ESP_Highlight, data.TweenInfo, {OutlineTransparency = data.ESPOutlineTransparency_NonVisible}):Play()
			end
		end
	end
end

--------------------------------------------------------------------------------------

local function EnableLock(target)
	local aim = target:FindFirstChild(data.AimAt)
	
	curCam.CFrame = CFrame.lookAt(curCam.CFrame.Position, aim.CFrame.Position)
	--curCam.CFrame = CFrame.new(curCam.CFrame.Position, aim.CFrame.Position) 
	data._currentLockedPlayer = target

	ts:Create(gui.Main, data.TweenInfo, {BackgroundColor3 = data.LockEnabledColor}):Play()
	gui.Main.Target.Text = target.Name
	ToggleLabel(gui.Main.Target, true)
	ToggleLabel(gui.Main.DisabledWarning, false)
end

local function DisableLock()
	data._currentLockedPlayer = nil
	ts:Create(gui.Main, data.TweenInfo, {BackgroundColor3 = data.LockDisabledColor}):Play()
	ToggleLabel(gui.Main.Target, false)
	ToggleLabel(gui.Main.DisabledWarning, true)
end

local function CheckLock()
	local target = FindBestPlayerToLock()
	if target then
		EnableLock(target)
	else
		DisableLock()
	end
end

--------------------------------------------------------------------------------------

local function RunLock()
	if uis:IsKeyDown(data.LockBind) then
		CheckLock()
	else
		DisableLock()
	end
end

local function RunGui()
	gui.Main.DisabledWarning.Text = disabledText
	gui.Info.AimAt.Text = "AimAt: "..data.AimAt
	gui.Info.ESP.Text = "ESP: "..(data.ESP and "On" or "Off")
	gui.Info.FreeForAll.Text = "FFA: "..(data.FreeForAll and "On" or "Off")

	for _, frame in pairs(gui:GetChildren()) do
		if frame:IsA("Frame") and frame.BackgroundTransparency ~= data.GuiTransparency then
			ts:Create(frame, data.TweenInfo, {BackgroundTransparency = data.GuiTransparency}):Play()
		end
	end
end

--------------------------------------------------------------------------------------

CycleAimPart()
RefreshESP()

--if cgui:FindFirstChild(gui.Name) then
--	cgui:FindFirstChild(gui.Name):Destroy()
--end

--------------------------------------------------------------------------------------

uis.InputBegan:connect(function(input, gm)
	if input.KeyCode == data.AimSwitchBind then
		CycleAimPart()
	end
	if input.KeyCode == data.ESPBind then
		data.ESP = not data.ESP
	end
	if input.KeyCode == data.FFASwitchBind then
		data.FreeForAll = not data.FreeForAll
	end
	if input.KeyCode == data.RefreshESPBind then
		RefreshESP()
	end
end)

task.spawn(function()
	while wait(data.ESPRefreshInterval) do
		RefreshESP()
	end
end)

runs.Heartbeat:connect(function()
	RunLock()
	RunGui()
	UpdateESP()
	ToggleESP(data.ESP)
end)
