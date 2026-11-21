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

local function section(text: string, order: number)
	local label = Ui.Templates.SectionLabel:Clone()
	label.Text = text
	label.LayoutOrder = order
	label.Parent = listPage
end

local function sliderValue(knob: GuiObject, track: GuiObject): number
	local width = track.AbsoluteSize.X
	if width <= 0 then
		return 0
	end
	local center = knob.AbsolutePosition.X + knob.AbsoluteSize.X / 2
	return math.clamp((center - track.AbsolutePosition.X) / width, 0, 1)
end

local function makeSlider(definition: Categories.Scale, order: number)
	local row = Ui.Templates.SliderRow:Clone()
	row.LayoutOrder = order
	local range = rules and rules.Scales and rules.Scales[definition.key]
	local min = if range then range.Min else definition.min
	local max = if range then range.Max else definition.max
	local track = row.Track
	local knob = track.Knob
	local drag = knob.Drag
	row.NameLabel.Text = definition.label
	local value = Session.current.scales[definition.key] or min
	local function show(amount: number)
		row.ValueLabel.Text = string.format("%d%%", math.round(amount * 100))
	end
	local function place(amount: number)
		knob.Position = UDim2.fromScale(math.clamp((amount - min) / math.max(max - min, 0.001), 0, 1), 0.5)
	end
	place(value)
	show(value)
	local token = 0
	knob:GetPropertyChangedSignal("Position"):Connect(function()
		local amount = math.round((min + (max - min) * sliderValue(knob, track)) * 100) / 100
		show(amount)
		token += 1
		local mine = token
		task.delay(0.35, function(): ()
			if mine ~= token or math.abs((Session.current.scales[definition.key] or 0) - amount) < 0.005 then
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
	drag.DragEnd:Connect(function()
		place(min + (max - min) * sliderValue(knob, track))
	end)
	row.Parent = listPage
end

function Body.render()
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
	if Ui.tabKind() ~= "body" then
		return
	end
	section("Skin tone", 1)
	local swatches = Ui.Templates.SwatchGrid:Clone()
	swatches.LayoutOrder = 2
	local skin = Session.current.bodyParts.Head.color
	for i, entry in if rules then rules.BodyColorsPalette or {} else {} do
		local color = BrickColor.new(entry.BrickColorId).Color
		local swatch = Ui.Templates.Swatch:Clone()
		swatch.LayoutOrder = i
		swatch.BackgroundColor3 = color
		if color:ToHex() == skin:ToHex() then
			swatch:AddTag("Active")
		end
		swatch.Activated:Connect(function()
			local look = Look.copy(Session.current)
			for _, bodyPart in look.bodyParts do
				bodyPart.color = color
			end
			Session.commit(look)
			for _, other in swatches:GetChildren() do
				other:RemoveTag("Active")
			end
			swatch:AddTag("Active")
		end)
		swatch.Parent = swatches
	end
	swatches.Parent = listPage
	section("Body shape", 3)
	for i, definition in Categories.scales do
		makeSlider(definition, 3 + i)
	end
	Ui.selectInside(listPage)
end

return Body
