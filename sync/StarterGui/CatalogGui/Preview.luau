local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DressingCamera = require(ReplicatedStorage:WaitForChild("Avatar"):WaitForChild("DressingCamera"))
local Ui = require(script.Parent.Ui)

local view = Ui.preview.Stage.View
local world = view.WorldModel
local shadow = world.Shadow
-- Cameras do not replicate from StarterGui, so the view camera is made here.
local camera = Instance.new("Camera")
camera.FieldOfView = 40
camera.Parent = view
view.CurrentCamera = camera

local Preview = {}

local source: Model? = nil
local copy: Model? = nil
local connections: { RBXScriptConnection } = {}
local token = 0

local function rebuild()
	local character = source
	if not character or not character.Parent then
		return
	end
	local archivable = character.Archivable
	character.Archivable = true
	local model = character:Clone()
	character.Archivable = archivable
	if not model then
		return
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BaseScript") or item:IsA("Sound") or item:IsA("ForceField") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	model:PivotTo(CFrame.new())
	model.Parent = world
	if copy then
		copy:Destroy()
	end
	copy = model
	-- Accessories make the bounding box too wide and too low, so use the floor under the root part.
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") then
		local floor = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
		local diameter = root.Size.X * 1.8
		shadow.Size = Vector3.new(0.05, diameter, diameter)
		shadow.CFrame = CFrame.new(root.Position.X, floor, root.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	end
	DressingCamera.setModel(model)
end

-- Many parts change at once when the server dresses the character, so wait until they settle.
function Preview.refresh()
	token += 1
	local mine = token
	task.delay(0.2, function(): ()
		if mine == token then
			rebuild()
		end
	end)
end

function Preview.start(character: Model)
	Preview.stop()
	source = character
	table.insert(connections, character.DescendantAdded:Connect(Preview.refresh))
	table.insert(connections, character.DescendantRemoving:Connect(Preview.refresh))
	DressingCamera.start(camera)
	rebuild()
end

function Preview.stop()
	token += 1
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	source = nil
	if copy then
		copy:Destroy()
		copy = nil
	end
	DressingCamera.stop()
end

return Preview
