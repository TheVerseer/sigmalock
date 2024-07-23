local gui = game:GetObjects('rbxassetid://18622836850')[1]
gui.Parent = game.Players.LocalPlayer.PlayerGui

local defaults = {
	["LockBind"] = Enum.KeyCode.LeftShift,
	["ESPBind"] = Enum.KeyCode.LeftAlt,
	["AimSwitchBind"] = Enum.KeyCode.RightShift,

	["FreeForAll"] = true,
	["TeamsToHide"] = {},

	["AimAt"] = "Head",
	["AimAtOptions"] = {"Head", "Torso", "UpperTorso"},

	["ESP"] = false,
	["ESPTransparency"] = 0.5,
	["ESPColor"] = "Red",
	["ESPColorOptions"] = {
		{"Red", 		Color3.new(100,0,0)}, 
		{"Green", 		Color3.new(0,100,0)}, 
		{"Blue", 		Color3.new(0,0,100)},
	}
}

--------------------------------------------------------------------------------------

local data = _G._Aim or {}

for gIndex, gValue in pairs(defaults) do
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

local defaultSizes = {}
local disabledText = `Hold "{data.LockBind.Name}" to Enable`

local enabledColor = Color3.fromRGB(10, 100, 10)
local disabledColor = Color3.fromRGB(100, 10, 10)

local currentAimAtPart = 0
local currentESPColor = 0
local currentESPContainer = nil

local ti = TweenInfo.new(0.1, Enum.EasingStyle.Exponential)

--------------------------------------------------------------------------------------

local function GetNearestPlayerToMouse()
	local plrHold = {}
	local distances = {}

	for i, v in pairs(game.Players:GetPlayers()) do
		if v == player then continue end

		local aim = v.Character:FindFirstChild(data.AimAt)
		if aim ~= nil then
			if data.FreeForAll then
				local dis = (aim.Position - game.Workspace.CurrentCamera.CoordinateFrame.p).magnitude
				local ray = Ray.new(game.Workspace.CurrentCamera.CoordinateFrame.p, (mouse.Hit.p - curCam.CoordinateFrame.p).unit * dis)
				local hit,pos = game.Workspace:FindPartOnRay(ray, game.Workspace)
				local diff = math.floor((pos - aim.Position).magnitude)
				plrHold[v.Name .. i] = {}
				plrHold[v.Name .. i].dis= dis
				plrHold[v.Name .. i].plr = v
				plrHold[v.Name .. i].diff = diff
				table.insert(distances, diff)
			else
				if v and (v.Character) ~= nil and v.TeamColor ~= player.TeamColor then
					local dis = (aim.Position - game.Workspace.CurrentCamera.CoordinateFrame.p).magnitude
					local ray = Ray.new(game.Workspace.CurrentCamera.CoordinateFrame.p, (mouse.Hit.p - curCam.CoordinateFrame.p).unit * dis)
					local hit, pos = game.Workspace:FindPartOnRay(ray, game.Workspace)
					local diff = math.floor((pos - aim.Position).magnitude)
					plrHold[v.Name .. i] = {}
					plrHold[v.Name .. i].dist = dis
					plrHold[v.Name .. i].plr  = v
					plrHold[v.Name .. i].diff = diff
					table.insert(distances, diff)
				end
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

local function ClearModelOfScripts(m)
	for _, s in pairs(m:GetDescendants()) do
		if s:IsA("LuaSourceContainer") then
			s:Destroy()
		end
	end
end

local function AddPlayerToESP(plr)
	if plr==player or not plr.Character then return end

	if not table.find(data.TeamsToHide, plr.Team) or data.FreeForAll then
		pcall(function()
			plr.Character.Archivable = true
			local char = plr.Character:Clone()
			ClearModelOfScripts(char)

			char.Parent = gui.ESP
			plr.Character.Archivable = false
		end)
	end
end

local function ToggleLabel(label, enabled)
	task.spawn(function()
		if enabled then
			if not defaultSizes[label] then
				defaultSizes[label] = label.UITextSizeConstraint.MaxTextSize
			end
			--ts:Create(label.UITextSizeConstraint, ti, {MaxTextSize = defaultSizes[label]}):Play() wait(ti.Time)
			--label.UITextSizeConstraint.MaxTextSize = defaultSizes[label]
			label.Visible = true
		else
			label.Visible = false
			--label.UITextSizeConstraint.MaxTextSize = 0
			--ts:Create(label.UITextSizeConstraint, ti, {MaxTextSize = 0}):Play()
		end
	end)
end

local function CycleAimPart()
	local function add()
		if currentAimAtPart+1 > #data.AimAtOptions then 
			currentAimAtPart = 1 
		else
			currentAimAtPart+=1
		end
	end

	add()

	if not player.Character:FindFirstChild(data.AimAtOptions[currentAimAtPart]) then 
		repeat add() until player.Character:FindFirstChild(data.AimAtOptions[currentAimAtPart])
	end

	data.AimAt = data.AimAtOptions[currentAimAtPart]
	gui.AimAt.Title.Text = "AimAt: "..data.AimAt
end

local function CycleESPColor()
	if currentESPColor+1 > #data.ESPColorOptions then 
		currentESPColor = 1 
	else
		currentESPColor+=1
	end

	local clr = data.ESPColorOptions[currentESPColor]

	currentESPContainer = clr
	data.ESPColor = clr[1]
end

local function UpdateESPSettings()
	task.spawn(function()
		gui.ESP.Visible = data.ESP
		ts:Create(gui.ESP, ti, {ImageTransparency = data.ESPTransparency}):Play()
		ts:Create(gui.ESP, ti, {Ambient = currentESPContainer[2]}):Play()
	end)
end

local function UpdateESPMain()
	gui.ESP:ClearAllChildren()
	gui.ESP.CurrentCamera = curCam
	gui.Info.ESP.Text = "ESP: "..(data.ESP and "On" or "Off")

	for _, plr in pairs(plrs:GetPlayers()) do
		AddPlayerToESP(plr)
	end
end

local function UpdateLock()
	gui.Main.DisabledWarning.Text = disabledText
end

local function EnableLock(target)
	local aim = target.Character:FindFirstChild(data.AimAt)
	if aim then curCam.CoordinateFrame = CFrame.new(curCam.CoordinateFrame.Position, aim.CFrame.Position) end

	ts:Create(gui.Main, ti, {BackgroundColor3 = enabledColor}):Play()
	gui.Main.Info.Text = target.Name
	ToggleLabel(gui.Main.Target, true)
	ToggleLabel(gui.Main.DisabledWarning, false)
end

local function DisableLock()
	ts:Create(gui.Main, ti, {BackgroundColor3 = disabledColor}):Play()
	ToggleLabel(gui.Main.Target, false)
	ToggleLabel(gui.Main.DisabledWarning, true)
end

local function CheckLock()
	local target = GetNearestPlayerToMouse()
	if target then
		EnableLock(target)
	else
		DisableLock()
	end
end

--------------------------------------------------------------------------------------

local function RunESP()
	UpdateESPSettings()
	UpdateESPMain()
end

local function RunLock()
	UpdateLock()

	if uis:IsKeyDown(data.LockBind) then
		CheckLock()
	else
		DisableLock()
	end
end

--------------------------------------------------------------------------------------

CycleAimPart()
CycleESPColor()



--if cgui:FindFirstChild(gui.Name) then
--	cgui:FindFirstChild(gui.Name):Destroy()
--end

--------------------------------------------------------------------------------------

uis.InputBegan:connect(function(input, gm)
	if input.KeyCode == data.AimSwitchBind then
		CycleAimPart()
	end
	if input.KeyCode == data.ESPBind then
		CycleESPColor()
		data.ESP = not data.ESP
	end
end)

runs.Heartbeat:connect(function()
	RunLock()
	RunESP()
end)
