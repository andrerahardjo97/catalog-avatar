local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BIND_NAME = "DressingCamera"
local FOCUS = {
	Full = { parts = {}, distance = 1.35 },
	Head = { parts = { "Head" }, distance = 0.5 },
	Torso = { parts = { "UpperTorso", "Torso" }, distance = 0.8 },
	Legs = { parts = { "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }, distance = 0.85 },
	Feet = { parts = { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }, distance = 0.6 },
}
local MIN_PITCH = math.rad(-55)
local MAX_PITCH = math.rad(40)
local MIN_ZOOM = 0.35
local MAX_ZOOM = 2.2

local DressingCamera = {}

local character = nil
local active = false
local focusName = "Full"
local yaw, targetYaw = 0, 0
local pitch, targetPitch = -0.12, -0.12
local zoom, targetZoom = 1, 1
local orbitRate = Vector2.zero
local zoomRate = 0
local offset = Vector2.zero
local distanceScale = 1
local point = nil

local function focusPoint(model: Model): (Vector3, number)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local definition = FOCUS[focusName] or FOCUS.Full
	local sum = Vector3.zero
	local count = 0
	for _, name in definition.parts do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			sum += part.Position
			count += 1
		end
	end
	local target = if count > 0 then sum / count else boxCFrame.Position
	return target, boxSize.Y * definition.distance + 1.5
end

local function update(dt: number)
	local model = character
	local camera = Workspace.CurrentCamera
	if not model or not model.Parent or not camera then
		return
	end
	targetYaw -= orbitRate.X * dt * 2.6
	targetPitch = math.clamp(targetPitch + orbitRate.Y * dt * 1.8, MIN_PITCH, MAX_PITCH)
	targetZoom = math.clamp(targetZoom * (1 + zoomRate * dt * 1.6), MIN_ZOOM, MAX_ZOOM)
	local alpha = 1 - math.exp(-dt * 10)
	yaw += (targetYaw - yaw) * alpha
	pitch += (targetPitch - pitch) * alpha
	zoom += (targetZoom - zoom) * alpha
	local target, distance = focusPoint(model)
	point = if point then point:Lerp(target, alpha) else target
	distance *= zoom * distanceScale
	local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local halfHeight = distance * math.tan(math.rad(camera.FieldOfView) / 2)
	local viewport = camera.ViewportSize
	local halfWidth = halfHeight * viewport.X / math.max(viewport.Y, 1)
	camera.CFrame = CFrame.new(point) * rotation * CFrame.new(-offset.X * halfWidth, -offset.Y * halfHeight, distance)
	camera.Focus = CFrame.new(point)
end

function DressingCamera.setCharacter(model: Model)
	character = model
	point = nil
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local _, facing = root.CFrame:ToEulerAnglesYXZ()
		targetYaw = facing + math.pi
		yaw = targetYaw
	end
end

function DressingCamera.start(model: Model)
	DressingCamera.setCharacter(model)
	targetPitch, pitch = -0.12, -0.12
	targetZoom, zoom = 1, 1
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	if not active then
		active = true
		RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, update)
	end
end

function DressingCamera.stop()
	if not active then
		return
	end
	active = false
	RunService:UnbindFromRenderStep(BIND_NAME)
	orbitRate = Vector2.zero
	zoomRate = 0
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

function DressingCamera.setFocus(name: string)
	if FOCUS[name] then
		focusName = name
		targetZoom = 1
	end
end

function DressingCamera.setOffset(value: Vector2, scale: number)
	offset = value
	distanceScale = scale
end

function DressingCamera.orbit(delta: Vector2)
	targetYaw -= delta.X * 0.008
	targetPitch = math.clamp(targetPitch - delta.Y * 0.006, MIN_PITCH, MAX_PITCH)
end

function DressingCamera.zoomBy(step: number)
	targetZoom = math.clamp(targetZoom * (1 - step * 0.12), MIN_ZOOM, MAX_ZOOM)
end

function DressingCamera.setOrbitRate(value: Vector2)
	orbitRate = value
end

function DressingCamera.setZoomRate(value: number)
	zoomRate = value
end

return DressingCamera
