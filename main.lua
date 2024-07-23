local gui = game:GetObjects('rbxassetid://18622836850')[1]
gui.Parent = game.Players.LocalPlayer.PlayerGui

local defaults = {
	["LockBind"] = Enum.KeyCode.LeftShift,
	["ESPBind"] = Enum.KeyCode.LeftAlt,
	["AimSwitchBind"] = Enum.KeyCode.RightShift,

	["FreeForAll"] = true,
	["TeamsToSkip"] = {},

	["AimAt"] = "Head",
	["AimAtOptions"] = {"Head", "Torso", "UpperTorso"},

	["ESP"] = false,
	
	["GuiTransparency"] = 0.4
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

local function DisabledESP(skip)
	for _, esp in pairs(gui.ESP.Players:GetChildren()) do
		if esp:IsA("Folder") then
			if not plrs[esp.Name] or skip then
				esp:Destroy()
			end
		end
	end
end

local function EnabledESP()
	for _, plr in pairs(plrs:GetPlayers()) do
		if plr ~= player and plr.Character then
			if not table.find(data.TeamsToSkip, plr.Team) or data.FreeForAll then
				pcall(function()
					local espFolder

					if gui.ESP.Players[plr.Name] then
						espFolder = gui.ESP.Players[plr.Name]
					else
						espFolder = gui.ESP.Template:Clone()
						espFolder.ESP_Billboard.Title.Text = plr.Name
						espFolder.ESP_Billboard.Enabled = true
						espFolder.Name = plr.Name
						espFolder.Parent = gui.ESP.Players
					end

					espFolder.ESP_Highlight.FillColor = plr.TeamColor.Color
					espFolder.ESP_Highlight.OutlineColor = plr.TeamColor.Color
					espFolder.ESP_Billboard.Title.TextColor = plr.TeamColor.Color
					espFolder.ESP_Billboard.Title.Stroke.Color = plr.TeamColor.Color

					espFolder.ESP_Highlight.Adornee = plr.Character
					espFolder.ESP_Billboard.Adornee = plr.Character
				end)
			end
		end
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
end

local function UpdateESPMain()
	if data.ESP then
		EnabledESP()
	else
		DisabledESP(true)
	end
	
	DisabledESP()
end


local function EnableLock(target)
	if not table.find(data.TeamsToSkip, target.Team) or data.FreeForAll then
		local aim = target.Character:FindFirstChild(data.AimAt)
		if aim then curCam.CoordinateFrame = CFrame.new(curCam.CoordinateFrame.Position, aim.CFrame.Position) end

		ts:Create(gui.Main, ti, {BackgroundColor3 = enabledColor}):Play()
		gui.Main.Info.Text = target.Name
		ToggleLabel(gui.Main.Target, true)
		ToggleLabel(gui.Main.DisabledWarning, false)
	end
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
	UpdateESPMain()
end

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
			ts:Create(frame, ti, {BackgroundTransparency = data.GuiTransparency}):Play()
		end
	end
end

--------------------------------------------------------------------------------------

CycleAimPart()

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
end)

runs.Heartbeat:connect(function()
	RunLock()
	RunESP()
	RunGui()
end)
