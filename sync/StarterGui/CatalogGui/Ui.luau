local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Avatar = ReplicatedStorage:WaitForChild("Avatar")
local Look = require(Avatar:WaitForChild("Look"))
local Categories = require(Avatar:WaitForChild("Categories"))

local gui = script.Parent
local editor = gui.Editor
local panel = editor.Panel
local content = panel.Content
local details = editor.Details
local detailScroll = details.Scroll
local preview = editor.Preview

local Ui = {
	Templates = Avatar:WaitForChild("Templates"),
	gui = gui,
	toast = gui.Toast,
	editor = editor,
	preview = preview,
	orbitPad = preview.Stage.OrbitPad,
	toolbar = preview.Toolbar,
	panel = panel,
	details = details,
	saveMenu = editor.SaveMenu,
	tabsFrame = panel.TabRow.Tabs,
	searchRow = panel.SearchRow,
	filters = panel.Filters,
	usernameRow = panel.UsernameRow,
	content = content,
	grid = content.Grid,
	listPage = content.List,
	status = content.Status,
	footer = panel.Footer,
	detailScroll = detailScroll,
	detailActions = detailScroll.Actions,
	open = false,
	tabIndex = 2,
}

local toastToken = 0

function Ui.isGamepad(): boolean
	return UserInputService.PreferredInput == Enum.PreferredInput.Gamepad
end

function Ui.isTyping(): boolean
	return UserInputService:GetFocusedTextBox() ~= nil
end

function Ui.tabKind(): string
	return Categories.tabs[Ui.tabIndex].kind
end

function Ui.showToast(text: string)
	toastToken += 1
	local token = toastToken
	Ui.toast.Text = text
	Ui.toast.Visible = true
	task.delay(2.8, function(): ()
		if toastToken == token then
			Ui.toast.Visible = false
		end
	end)
end

function Ui.formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	return (string.gsub(formatted, "^,", ""))
end

function Ui.priceText(item: Look.Item): (string, boolean)
	local price = item.price or 0
	if price > 0 then
		return Ui.formatNumber(price), true
	end
	if item.priceStatus and item.priceStatus ~= "" and item.priceStatus ~= "Free" then
		return item.priceStatus, false
	end
	return "Free", false
end

function Ui.thumbnail(kind: string, id: number, size: number): Content
	return Content.fromUri(string.format("rbxthumb://type=%s&id=%d&w=%d&h=%d", kind, id, size, size))
end

function Ui.itemThumbnail(item: Look.Item, size: number): Content
	return Ui.thumbnail(if item.bundle then "BundleThumbnail" else "Asset", item.id, size)
end

function Ui.itemType(item: Look.Item): Enum.AvatarItemType
	return if item.bundle then Enum.AvatarItemType.Bundle else Enum.AvatarItemType.Asset
end

function Ui.toItem(entry: any): Look.Item
	return {
		id = entry.Id,
		bundle = entry.ItemType == "Bundle",
		assetType = entry.AssetType,
		name = entry.Name or "",
		price = entry.Price or entry.LowestPrice,
		priceStatus = entry.PriceStatus,
		creator = entry.CreatorName,
	}
end

function Ui.clearChildren(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function Ui.setStatus(text: string)
	Ui.status.Text = text
	Ui.status.Visible = text ~= ""
end

function Ui.selectInside(container: GuiObject)
	if not Ui.open or not Ui.isGamepad() then
		return
	end
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(Ui.editor) and selected.Visible then
		return
	end
	GuiService:Select(container)
end

return Ui
