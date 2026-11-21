local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Look = require(ReplicatedStorage:WaitForChild("Avatar"):WaitForChild("Look"))
local Ui = require(script.Parent.Ui)
local Session = require(script.Parent.Session)

local Cards = {
	openDetails = function(_item: Look.Item): () end,
}

local liveCards = {}

function Cards.update(card: Instance)
	local id = card:GetAttribute("ItemId")
	local check = card:FindFirstChild("Check")
	if type(id) ~= "number" or not check or not check:IsA("GuiObject") then
		return
	end
	local worn = Session.isWorn(id, card:GetAttribute("Bundle") == true)
	check.Visible = worn
	if worn then
		card:AddTag("Worn")
	else
		card:RemoveTag("Worn")
	end
end

function Cards.refresh()
	for card in liveCards do
		Cards.update(card)
	end
end

function Cards.make(item: Look.Item, parent: Instance, order: number): GuiObject
	local card = Ui.Templates.ItemCard:Clone()
	card.Name = tostring(item.id)
	card.LayoutOrder = order
	card:SetAttribute("ItemId", item.id)
	card:SetAttribute("Bundle", item.bundle)
	card.Thumb.ImageContent = Ui.itemThumbnail(item, 150)
	card.NameLabel.Text = item.name
	local text, icon = Ui.priceText(item)
	card.Price.Amount.Text = text
	card.Price.Icon.Visible = icon
	card.Activated:Connect(function()
		Session.wearItem(item)
	end)
	card.InfoButton.Activated:Connect(function()
		Cards.openDetails(item)
	end)
	liveCards[card] = true
	card.Destroying:Once(function()
		liveCards[card] = nil
	end)
	Cards.update(card)
	card.Parent = parent
	return card
end

return Cards
