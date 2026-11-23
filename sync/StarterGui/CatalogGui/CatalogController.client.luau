local AvatarEditorService = game:GetService("AvatarEditorService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

local Avatar = ReplicatedStorage:WaitForChild("Avatar")
local Look = require(Avatar:WaitForChild("Look"))
local Categories = require(Avatar:WaitForChild("Categories"))
local DressingCamera = require(Avatar:WaitForChild("DressingCamera"))
local Icon = require(ReplicatedStorage:WaitForChild("Icon"))
local Inputs = ReplicatedStorage:WaitForChild("Inputs")
local ToggleContext = Inputs:WaitForChild("EditorToggle")
local EditorContext = Inputs:WaitForChild("Editor")
local Ui = require(script.Parent.Ui)
local Session = require(script.Parent.Session)
local Cards = require(script.Parent.Cards)
local Catalog = require(script.Parent.Panels.Catalog)
local Wearing = require(script.Parent.Panels.Wearing)
local Body = require(script.Parent.Panels.Body)
local PlayersPanel = require(script.Parent.Panels.Players)
local Details = require(script.Parent.Panels.Details)
local Preview = require(script.Parent.Preview)

local PLAYER_CONTEXTS = { "CharacterContext", "CameraContext" }

local player = Players.LocalPlayer
local gui = Ui.gui
local editor = Ui.editor
local orbitPad = Ui.orbitPad
local toolbar = Ui.toolbar
local preview = Ui.preview
local panel = Ui.panel
local details = Ui.details
local saveMenu = Ui.saveMenu
local tabsFrame = Ui.tabsFrame
local grid = Ui.grid
local gridLayout = grid.UIGridLayout
local listPage = Ui.listPage

local savedContexts = {}
local touchControls = true
local shopIcon = Icon.new():setName("AvatarShop"):setLabel("Avatar Shop"):setCaptionHint(Enum.KeyCode.C)

Session.changed = function(): ()
	if not Session.applying then
		Preview.refresh()
	end
	Cards.refresh()
	Details.refresh()
	if not Ui.open then
		return
	end
	local kind = Ui.tabKind()
	if kind == "wearing" and not Session.applying then
		task.spawn(Wearing.render)
	elseif kind == "body" then
		Body.sync()
	end
end
Cards.openDetails = Details.open

local function selectTab(index: number)
	Ui.tabIndex = index
	local tab = Categories.tabs[index]
	for _, button in tabsFrame:GetChildren() do
		if button:IsA("GuiButton") then
			if button.LayoutOrder == index then
				button:AddTag("Active")
				local left = button.AbsolutePosition.X - tabsFrame.AbsolutePosition.X + tabsFrame.CanvasPosition.X
				tabsFrame.CanvasPosition = Vector2.new(math.max(0, left - 48), 0)
			else
				button:RemoveTag("Active")
			end
		end
	end
	Details.hide()
	local catalog = tab.kind == "catalog"
	local gridKind = catalog or tab.kind == "outfits"
	Ui.searchRow.Visible = catalog
	Ui.filters.Visible = catalog
	Ui.usernameRow.Visible = tab.kind == "players"
	Ui.footer.Visible = tab.kind == "wearing"
	grid.Visible = gridKind
	listPage.Visible = not gridKind
	Catalog.cancel()
	Wearing.cancel()
	Body.cancel()
	Ui.setStatus("")
	if not gridKind then
		Ui.clearChildren(listPage)
	end
	if Ui.open and Ui.isGamepad() then
		GuiService.SelectedObject = nil
	end
	if catalog then
		task.spawn(Catalog.search)
	elseif tab.kind == "outfits" then
		task.spawn(Catalog.outfits)
	elseif tab.kind == "wearing" then
		task.spawn(Wearing.render)
	elseif tab.kind == "body" then
		task.spawn(Body.render)
	elseif tab.kind == "players" then
		PlayersPanel.render()
	end
end

local function shiftTab(step: number)
	selectTab((Ui.tabIndex - 1 + step) % #Categories.tabs + 1)
end

local function relayout()
	local size = gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local margin = 12
	local panelWidth
	if size.Y > size.X then
		local previewHeight = math.floor(size.Y * 0.4)
		preview.Size = UDim2.new(1, -2 * margin, 0, previewHeight - margin)
		panel.Position = UDim2.fromOffset(margin, previewHeight + margin)
		panel.Size = UDim2.new(1, -2 * margin, 1, -previewHeight - 2 * margin)
		panelWidth = size.X - 2 * margin
	else
		local previewWidth = math.max(math.floor(size.X / 3), 300)
		preview.Size = UDim2.new(0, previewWidth - margin, 1, -2 * margin)
		panel.Position = UDim2.fromOffset(previewWidth + margin, margin)
		panel.Size = UDim2.new(1, -previewWidth - 2 * margin, 1, -2 * margin)
		panelWidth = size.X - previewWidth - 2 * margin
	end
	preview.Position = UDim2.fromOffset(margin, margin)
	panel.AnchorPoint = Vector2.zero
	details.AnchorPoint = panel.AnchorPoint
	details.Position = panel.Position
	details.Size = panel.Size
	local inner = panelWidth - 24 - 10
	local columns = math.max(2, math.floor((inner + 8) / 128))
	local cell = math.floor((inner - (columns - 1) * 8) / columns)
	gridLayout.CellSize = UDim2.fromOffset(cell, math.floor(cell * 1.32))
end

local function setPlayerInput(enabled: boolean)
	local module = StarterPlayer:FindFirstChild("PlayerModule")
	local contexts = if module then module:FindFirstChild("InputContexts") else nil
	if not contexts then
		return
	end
	for _, name in PLAYER_CONTEXTS do
		local context = contexts:FindFirstChild(name)
		if context and context:IsA("InputContext") then
			if enabled then
				context.Enabled = savedContexts[name] ~= false
			else
				savedContexts[name] = context.Enabled
				context.Enabled = false
			end
		end
	end
end

local function setOpen(value: boolean)
	if Ui.open == value then
		return
	end
	Ui.open = value
	editor.Visible = value
	if value then
		shopIcon:select()
	else
		shopIcon:deselect()
	end
	EditorContext.Enabled = value
	setPlayerInput(not value)
	if value then
		touchControls = GuiService.TouchControlsEnabled
		GuiService.TouchControlsEnabled = false
	else
		GuiService.TouchControlsEnabled = touchControls
	end
	if value then
		relayout()
		local character = player.Character
		if character then
			Preview.start(character)
		end
		task.spawn(Session.ensureLook)
		selectTab(Ui.tabIndex)
	else
		Preview.stop()
		Details.hide()
		saveMenu.Visible = false
		Catalog.cancel()
		Wearing.cancel()
		Body.cancel()
		Ui.clearChildren(grid)
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
			GuiService.SelectedObject = nil
		end
	end
end

local function rigType(): Enum.HumanoidRigType
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return if humanoid then humanoid.RigType else Enum.HumanoidRigType.R15
end

local function updateHint(hint: Instance)
	if hint:IsA("InputActionLabel") then
		hint.Visible = UserInputService.PreferredInput ~= Enum.PreferredInput.Touch
			and (hint.ResolvedText ~= "" or hint.ResolvedImageContent.SourceType ~= Enum.ContentSourceType.None)
		local keycap = hint:FindFirstChild("Keycap")
		if keycap and keycap:IsA("GuiObject") then
			keycap.Visible = hint.ResolvedText ~= ""
		end
	end
end

local function updateHints()
	for _, hint in gui:QueryDescendants(".Hint") do
		updateHint(hint)
	end
end

for _, hint in gui:QueryDescendants(".Hint") do
	if hint:IsA("InputActionLabel") then
		hint:GetPropertyChangedSignal("ResolvedText"):Connect(function()
			updateHint(hint)
		end)
		hint:GetPropertyChangedSignal("ResolvedImageContent"):Connect(function()
			updateHint(hint)
		end)
	end
end

for i, tab in Categories.tabs do
	local button = Ui.Templates.TabButton:Clone()
	button.Name = tab.name
	button.Text = tab.name
	button.LayoutOrder = i
	button.Activated:Connect(function()
		selectTab(i)
	end)
	button.Parent = tabsFrame
end

Catalog.bind()
Wearing.bind()
PlayersPanel.bind()
Details.bind()

shopIcon.toggled:Connect(function(isSelected)
	setOpen(isSelected)
end)
toolbar.CloseButton.Activated:Connect(function()
	setOpen(false)
end)
toolbar.UndoButton.Activated:Connect(Session.undo)
toolbar.ResetButton.Activated:Connect(function()
	Session.loadLook("user", player.UserId, "Back to your Roblox avatar.")
end)
toolbar.SaveButton.Activated:Connect(function()
	saveMenu.Visible = true
	if Ui.isGamepad() then
		GuiService:Select(saveMenu)
	end
end)
saveMenu.CancelButton.Activated:Connect(function()
	saveMenu.Visible = false
end)
saveMenu.SaveAvatarButton.Activated:Connect(function()
	saveMenu.Visible = false
	AvatarEditorService:PromptSaveAvatar(Look.toDescription(Session.current), rigType())
end)
saveMenu.SaveOutfitButton.Activated:Connect(function()
	saveMenu.Visible = false
	AvatarEditorService:PromptCreateOutfit(Look.toDescription(Session.current), rigType())
end)

AvatarEditorService.PromptSaveAvatarCompleted:Connect(function(result)
	if result == Enum.AvatarPromptResult.Success then
		Ui.showToast("Your Roblox avatar is updated.")
	elseif result == Enum.AvatarPromptResult.Failed then
		Ui.showToast("The avatar could not be saved.")
	end
end)
AvatarEditorService.PromptCreateOutfitCompleted:Connect(function(result)
	if result == Enum.AvatarPromptResult.Success then
		Ui.showToast("Outfit saved.")
		if Ui.open and Ui.tabKind() == "outfits" then
			selectTab(Ui.tabIndex)
		end
	elseif result == Enum.AvatarPromptResult.Failed then
		Ui.showToast("The outfit could not be saved.")
	end
end)

local lastDrag = nil
orbitPad.Drag.DragStart:Connect(function(position)
	lastDrag = position
end)
orbitPad.Drag.DragContinue:Connect(function(position)
	if lastDrag then
		DressingCamera.orbit(position - lastDrag)
	end
	lastDrag = position
end)
orbitPad.Drag.DragEnd:Connect(function()
	lastDrag = nil
end)

-- Same sign as a drag: the right button turns the avatar like a drag to the right.
for button, direction in { [preview.Stage.RotateLeftButton] = -1, [preview.Stage.RotateRightButton] = 1 } do
	button.MouseButton1Down:Connect(function()
		DressingCamera.setOrbitRate(Vector2.new(direction, 0))
	end)
	button.MouseButton1Up:Connect(function()
		DressingCamera.setOrbitRate(Vector2.zero)
	end)
	button.MouseLeave:Connect(function()
		DressingCamera.setOrbitRate(Vector2.zero)
	end)
end

ToggleContext.Toggle.Pressed:Connect(function()
	if not Ui.isTyping() then
		setOpen(not Ui.open)
	end
end)
EditorContext.NextTab.Pressed:Connect(function()
	if not Ui.isTyping() then
		shiftTab(1)
	end
end)
EditorContext.PrevTab.Pressed:Connect(function()
	if not Ui.isTyping() then
		shiftTab(-1)
	end
end)
EditorContext.Undo.Pressed:Connect(function()
	if not Ui.isTyping() then
		Session.undo()
	end
end)
EditorContext.Close.Pressed:Connect(function()
	if saveMenu.Visible then
		saveMenu.Visible = false
	elseif Details.isOpen() then
		Details.close()
	else
		setOpen(false)
	end
end)
EditorContext.Orbit.StateChanged:Connect(function(value)
	DressingCamera.setOrbitRate(value)
end)
EditorContext.Zoom.StateChanged:Connect(function(value)
	DressingCamera.setZoomRate(value)
end)
orbitPad.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		DressingCamera.zoomBy(math.sign(input.Position.Z))
	end
end)
local lastPinch = 1
orbitPad.TouchPinch:Connect(function(_, scale, _, state)
	if state == Enum.UserInputState.Begin then
		lastPinch = 1
	end
	DressingCamera.zoomBy((scale - lastPinch) * 5)
	lastPinch = scale
end)

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(updateHints)
player.CharacterAdded:Connect(function(character)
	if Ui.open then
		Preview.start(character)
	end
end)

updateHints()
relayout()
