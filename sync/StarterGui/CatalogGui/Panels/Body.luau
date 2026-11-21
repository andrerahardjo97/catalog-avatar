local AvatarEditorService = game:GetService("AvatarEditorService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Avatar = ReplicatedStorage:WaitForChild("Avatar")
local Look = require(Avatar:WaitForChild("Look"))
local Categories = require(Avatar:WaitForChild("Categories"))
local Ui = require(script.Parent.Parent.Ui)
local Session = require(script.Parent.Parent.Session)

local Body = {}

local listPage = Ui.listPage
local rules = nil
local token = 0
local syncs = {}

local function section(text: string, order: number)
	local label = Ui.Templates.SectionLabel:Clone()
	label.Text = text
	label.LayoutOrder = order
	label.Parent = listPage
end

local function makeSlider(definition: Categories.Scale, order: number)
	local row = Ui.Templates.SliderRow:Clone()
	row.LayoutOrder = order
	local range = rules and rules.Scales and rules.Scales[definition.key]
	local min = if range then range.Min else definition.min
	local max = if range then range.Max else definition.max
	local knob = row.Track.Knob
	local drag = knob.Drag
	local dragging = false
	local placed = knob.Position
	row.NameLabel.Text = definition.label
	local function show(amount: number)
		row.ValueLabel.Text = string.format("%d%%", math.round(amount * 100))
	end
	local function place(amount: number)
		placed = UDim2.fromScale(math.clamp((amount - min) / math.max(max - min, 0.001), 0, 1), 0.5)
		knob.Position = placed
		show(amount)
	end
	place(Session.current.scales[definition.key] or min)
	local pending = 0
	knob:GetPropertyChangedSignal("Position"):Connect(function()
		if knob.Position == placed then
			return
		end
		local amount = math.round((min + (max - min) * math.clamp(knob.Position.X.Scale, 0, 1)) * 100) / 100
		show(amount)
		pending += 1
		local mine = pending
		task.delay(0.35, function(): ()
			if mine ~= pending or math.abs((Session.current.scales[definition.key] or 0) - amount) < 0.005 then
				return
			end
			local look = Look.copy(Session.current)
			look.scales[definition.key] = amount
			if definition.key == "Width" then
				look.scales.Depth = amount
			end
			Session.commit(look)
		end)
	end)
	drag.DragStart:Connect(function()
		dragging = true
	end)
	drag.DragEnd:Connect(function()
		dragging = false
	end)
	table.insert(syncs, function(): ()
		if not dragging then
			place(Session.current.scales[definition.key] or min)
		end
	end)
	row.Parent = listPage
end

local function makeSwatches(order: number)
	local swatches = Ui.Templates.SwatchGrid:Clone()
	swatches.LayoutOrder = order
	for i, entry in if rules then rules.BodyColorsPalette or {} else {} do
		local color = BrickColor.new(entry.BrickColorId).Color
		local swatch = Ui.Templates.Swatch:Clone()
		swatch.LayoutOrder = i
		swatch.BackgroundColor3 = color
		swatch.Activated:Connect(function()
			local look = Look.copy(Session.current)
			for _, bodyPart in look.bodyParts do
				bodyPart.color = color
			end
			Session.commit(look)
		end)
		swatch.Parent = swatches
	end
	local function sync()
		local skin = Session.current.bodyParts.Head.color:ToHex()
		for _, swatch in swatches:GetChildren() do
			if swatch:IsA("GuiButton") then
				if swatch.BackgroundColor3:ToHex() == skin then
					swatch:AddTag("Active")
				else
					swatch:RemoveTag("Active")
				end
			end
		end
	end
	sync()
	table.insert(syncs, sync)
	swatches.Parent = listPage
end

function Body.cancel()
	token += 1
	table.clear(syncs)
end

function Body.sync()
	for _, sync in syncs do
		sync()
	end
end

function Body.render()
	Body.cancel()
	local mine = token
	Ui.clearChildren(listPage)
	Ui.setStatus("")
	if not rules then
		local ok, result = pcall(function(): any
			return AvatarEditorService:GetAvatarRulesAsync()
		end)
		if ok then
			rules = result
		end
	end
	if mine ~= token or Ui.tabKind() ~= "body" then
		return
	end
	section("Skin tone", 1)
	makeSwatches(2)
	section("Body shape", 3)
	for i, definition in Categories.scales do
		makeSlider(definition, 3 + i)
	end
	Ui.selectInside(listPage)
end

return Body
