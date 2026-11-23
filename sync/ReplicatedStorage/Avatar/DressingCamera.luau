local RunService = game:GetService("RunService")

local BIND_NAME = "DressingCamera"
local MIN_PITCH = math.rad(-55)
local MAX_PITCH = math.rad(40)
local MIN_ZOOM = 0.35
local MAX_ZOOM = 2.2

local DressingCamera = {}

local character: Model? = nil
local camera: Camera? = nil
local active = false
local yaw, targetYaw = math.pi, math.pi
local pitch, targetPitch = -0.12, -0.12
local zoom, targetZoom = 1, 1
local orbitRate = Vector2.zero
local zoomRate = 0
local point: Vector3? = nil

local function update(dt: number)
	local model = character
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
	local boxCFrame, boxSize = model:GetBoundingBox()
	local target = boxCFrame.Position
	local center = if point then point:Lerp(target, alpha) else target
	point = center
	-- Fit the body height in the vertical field of view, with a little margin.
	local distance = boxSize.Y * 0.62 / math.tan(math.rad(camera.FieldOfView) / 2) * zoom
	local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	camera.CFrame = CFrame.new(center) * rotation * CFrame.new(0, 0, distance)
	camera.Focus = CFrame.new(center)
end

-- The model faces -Z at the origin, so yaw = pi puts the camera in front of it.
function DressingCamera.start(viewCamera: Camera)
	character = nil
	camera = viewCamera
	point = nil
	targetYaw, yaw = math.pi, math.pi
	targetPitch, pitch = -0.12, -0.12
	targetZoom, zoom = 1, 1
	if not active then
		active = true
		RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, update)
	end
end

function DressingCamera.setModel(model: Model)
	character = model
end

function DressingCamera.stop()
	if not active then
		return
	end
	active = false
	RunService:UnbindFromRenderStep(BIND_NAME)
	orbitRate = Vector2.zero
	zoomRate = 0
	character = nil
	camera = nil
	point = nil
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
