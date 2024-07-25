--local gui = script.Parent:FindFirstChild("Lock_Gui") or game:GetObjects('rbxassetid://18622836850')[1] 

--[[
	IGNORE: USED FOR DEBUGGING
]]

local gui = game:GetObjects('rbxassetid://18622836850')[1]
gui.Parent = game.Players.LocalPlayer.PlayerGui

local defaultSettings = {
	["LockBind"] = Enum.KeyCode.LeftShift,
	["ESPBind"] = Enum.KeyCode.LeftAlt,
	["RefreshESPBind"] = Enum.KeyCode.RightAlt,
	["AimSwitchBind"] = Enum.KeyCode.RightShift,
	["FFASwitchBind"] = Enum.KeyCode.RightControl,

	["FreeForAll"] = false,
	["TeamsToSkip"] = {},
	
	["RunForRigs"] = false,
	
	["LockMaxDistance"] = 500,
	
	["AimAt"] = "Head",
	["AimAtOptions"] = {"Head", "Torso", "LowerTorso"},

	["ESP"] = false,
	["ESPRefreshInterval"] = 10,
	
	["ESPDefaultColor"] = Color3.fromRGB(255, 0, 0),
	["ESPDefaultColor_NPC"] = Color3.fromRGB(0, 255, 0),
	["ESPFillTransparency_Visible"] = 0.6,
	["ESPOutlineTransparency_Visible"] = 0.3,
	["ESPFillTransparency_NonVisible"] = 0.4,
	["ESPOutlineTransparency_NonVisible"] = 0.2,

	["LockEnabledColor"] = Color3.fromRGB(10, 100, 10),
	["LockDisabledColor"] = Color3.fromRGB(100, 10, 10),

	["GuiTransparency"] = 0.4, 
	["TweenInfo"] = TweenInfo.new(0.1, Enum.EasingStyle.Exponential),

	["_currentAimAtPart"] = 0,
	["_currentESPColor"] = 0,
	["_currentLockedPlayer"] = false,
	
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

local function GetDistanceMagnitude(p1, p2)
	return (p1 - p2).Magnitude
end

local function CanLockCharacter(char)
	local plr = plrs:GetPlayerFromCharacter(char)

		if plr then
			if plr ~= player then
				if plr.Team ~= player.Team then
					return true
				else
					return data.FreeForAll
				end
			end
		else
			if data.RunForRigs then
				return true
			end
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
	return (data.RunForRigs and rigs or {})
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

local function CharacterIsVisible(char)
	local cPos = char:FindFirstChild("Head").CFrame.Position

	return table.pack(curCam:WorldToScreenPoint(cPos))[2]

	--if not table.pack(curCam:WorldToScreenPoint(cPos))[2] then
	--	return false
	--end
	--
	--local hit = table.pack(workspace:FindPartOnRay(Ray.new(curCam.CFrame.Position, (cPos - curCam.CFrame.Position).unit * 500)))
	--if hit[1] and hit[1]:IsDescendantOf(char) then
	--	return true
	--end
	--
	--return false
end

--------------------------------------------------------------------------------------

local function GetCharacterToLock()
	local foundChar, foundDis = false, data.LockMaxDistance
	
	local nonVisibleCharacters = {}
	local visibleCharacters = {}
	
	for _, plr in pairs(plrs:GetPlayers()) do
		if CanLockCharacter(plr.Character) then
			if CharacterIsVisible(plr.Character) then
				table.insert(visibleCharacters, {
					char = plr.Character,
					dis = GetDistanceMagnitude(plr.Character.HumanoidRootPart.Position, mouse.Hit.Position),
				})
			else
				table.insert(nonVisibleCharacters, {
					char = plr.Character,
					dis = GetDistanceMagnitude(plr.Character.HumanoidRootPart.Position, mouse.Hit.Position),
				})
			end
		end
	end
	
	if data.RunForRigs then
		for _, rig in pairs(GetRigs()) do
			if CanLockCharacter(rig) then
				if CharacterIsVisible(rig) then
					table.insert(visibleCharacters, {
						char = rig,
						dis = GetDistanceMagnitude(rig.HumanoidRootPart.Position, mouse.Hit.Position),
					})
				else
					table.insert(nonVisibleCharacters, {
						char = rig,
						dis = GetDistanceMagnitude(rig.HumanoidRootPart.Position, mouse.Hit.Position),
					})
				end
			end
		end
	end
	
	table.sort(nonVisibleCharacters, function(a, b) return math.floor(a.dis + 0.5) < math.floor(b.dis + 0.5) end)
	table.sort(visibleCharacters, function(a, b) return math.floor(a.dis + 0.5) < math.floor(b.dis + 0.5) end)
	
	for _, entry in pairs(visibleCharacters) do
		if entry.dis < foundDis then
			foundChar = entry.char
			foundDis = entry.dis
		end
	end
	
	for _, entry in pairs(nonVisibleCharacters) do
		if entry.dis < foundDis then
			foundChar = entry.char
			foundDis = entry.dis
		end
	end
	
	return foundChar
end

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

local function RemoveESP(char)
	if currentESP[char] then
		currentESP[char]:Destroy()
		currentESP[char] = nil
	end
end

local function AddESP(char)
	if CanLockCharacter(char) then
		RemoveESP(char)
		
		local plr = plrs:GetPlayerFromCharacter(char)
		local espFolder = gui.ESP:Clone()

		espFolder.Name = char.Name
		espFolder.Parent = gui
		espFolder.ESP_Billboard.Title.Text = char.Name

		currentESP[char] = espFolder

		if plr and plr.Team then
			espFolder.ESP_Highlight.FillColor = plr.TeamColor.Color
			espFolder.ESP_Highlight.OutlineColor = plr.TeamColor.Color
			espFolder.ESP_Billboard.Title.TextColor3 = plr.TeamColor.Color
		else
			if plr then
				espFolder.ESP_Highlight.FillColor = data.ESPDefaultColor
				espFolder.ESP_Highlight.OutlineColor = data.ESPDefaultColor
				espFolder.ESP_Billboard.Title.TextColor3 = data.ESPDefaultColor
			else
				espFolder.ESP_Highlight.FillColor = data.ESPDefaultColor_NPC
				espFolder.ESP_Highlight.OutlineColor = data.ESPDefaultColor_NPC
				espFolder.ESP_Billboard.Title.TextColor3 = data.ESPDefaultColor_NPC
			end
		end

		espFolder.ESP_Billboard.Enabled = data.ESP
		espFolder.ESP_Highlight.Enabled = data.ESP
		espFolder.ESP_Billboard.Adornee = char
		espFolder.ESP_Highlight.Adornee = char
	end
end

local function LoadESP()
	local function loadPlr(plr)
		if not currentPlayersESP[plr.Character] then
			local char = plr.Character
			AddESP(char)
			currentESPConnections[#currentESPConnections+1] = plr.CharacterAdded:Connect(function(c)
				char = c
				AddESP(char)
			end)
			currentESPConnections[#currentESPConnections+1] = plr:GetPropertyChangedSignal("Team"):Connect(function()
				AddESP(char)
			end)
			currentPlayersESP[char] = true
		end
	end
	local function deloadPlr(plr)
		RemoveESP(plr.Character)
		currentPlayersESP[plr.Character] = nil
	end
	
	for _, rig in pairs(GetRigs()) do
		if not currentPlayersESP[rig] then
			AddESP(rig)
			currentPlayersESP[rig] = true
		end
	end
	
	for _, plr in pairs(plrs:GetPlayers()) do
		loadPlr(plr)
	end
	
	currentESPConnections[#currentESPConnections+1] = plrs.PlayerAdded:Connect(function(plr)
		loadPlr(plr)
	end)
	
	currentESPConnections[#currentESPConnections+1] = plrs.PlayerRemoving:Connect(function(plr)
		deloadPlr(plr)
	end)
end

local function RefreshESP()
	if player.PlayerGui:FindFirstChildOfClass("Highlight") then
		ClearInstanceOfClass(player.PlayerGui,"Highlight",gui)
	end
	
	for char, _ in pairs(currentESP) do
		RemoveESP(char)
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
	--for _, plr in pairs(plrs:GetPlayers()) do
	--	local char = plr.Character
	--	if CharacterIsVisible(char) then
	--		if currentESP[char] and lastPlayerESPVisibilityChange[char] == false then
	--			lastPlayerESPVisibilityChange[char] = true
	--			ts:Create(currentESP[char].ESP_Highlight, data.TweenInfo, {FillTransparency = data.ESPFillTransparency_Visible}):Play()
	--			ts:Create(currentESP[char].ESP_Highlight, data.TweenInfo, {OutlineTransparency = data.ESPOutlineTransparency_Visible}):Play()
	--		end
	--	else
	--		if currentESP[char] and lastPlayerESPVisibilityChange[char] == true then
	--			lastPlayerESPVisibilityChange[char] = false
	--			ts:Create(currentESP[char].ESP_Highlight, data.TweenInfo, {FillTransparency = data.ESPFillTransparency_NonVisible}):Play()
	--			ts:Create(currentESP[char].ESP_Highlight, data.TweenInfo, {OutlineTransparency = data.ESPOutlineTransparency_NonVisible}):Play()
	--		end
	--	end
	--end
end

--------------------------------------------------------------------------------------

local function EnableLock(target)
	local aim = target:FindFirstChild(data.AimAt)
	
	curCam.CFrame = CFrame.lookAt(curCam.CFrame.Position, aim.CFrame.Position)
	data._currentLockedPlayer = target
	
	ts:Create(gui.Main, data.TweenInfo, {BackgroundColor3 = data.LockEnabledColor}):Play()
	gui.Main.Target.Text = target.Name
	ToggleLabel(gui.Main.Target, true)
	ToggleLabel(gui.Main.DisabledWarning, false)
end

local function DisableLock()
	data._currentLockedPlayer = false
	
	ts:Create(gui.Main, data.TweenInfo, {BackgroundColor3 = data.LockDisabledColor}):Play()
	ToggleLabel(gui.Main.Target, false)
	ToggleLabel(gui.Main.DisabledWarning, true)
end

local function CheckLock()
	local target = GetCharacterToLock()
	if target then
		EnableLock(data._currentLockedPlayer or target)
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
