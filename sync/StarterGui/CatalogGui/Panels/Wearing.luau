local AvatarEditorService = game:GetService("AvatarEditorService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Look = require(ReplicatedStorage:WaitForChild("Avatar"):WaitForChild("Look"))
local Ui = require(script.Parent.Parent.Ui)
local Session = require(script.Parent.Parent.Session)

local MAX_BULK = 20
local BUNDLE_ONLY = {
	Torso = true,
	LeftArm = true,
	RightArm = true,
	LeftLeg = true,
	RightLeg = true,
	DynamicHead = true,
	IdleAnimation = true,
	WalkAnimation = true,
	RunAnimation = true,
	JumpAnimation = true,
	FallAnimation = true,
	ClimbAnimation = true,
	SwimAnimation = true,
	MoodAnimation = true,
}

local Wearing = {}

local listPage = Ui.listPage
local footer = Ui.footer
local token = 0
local cart = {}

local function fetchDetails(ids: { number }, kind: Enum.AvatarItemType): { any }
	if #ids == 0 then
		return {}
	end
	local ok, result = pcall(function(): { any }
		return AvatarEditorService:GetBatchItemDetailsAsync(ids, kind)
	end)
	return if ok then result else {}
end

function Wearing.cancel()
	token += 1
end

function Wearing.render()
	token += 1
	local mine = token
	local look = Session.current
	local covered = {}
	for _, bundleId in look.bundles do
		local parts = Session.cachedBundle(bundleId)
		if parts then
			for _, id in Look.assetIds(parts) do
				covered[id] = true
			end
		end
	end
	local assets = {}
	for _, id in Look.assetIds(look) do
		if not covered[id] then
			table.insert(assets, id)
		end
	end
	Ui.setStatus(if #assets + #look.bundles == 0 then "" else "Loading...")
	local entries = fetchDetails(look.bundles, Enum.AvatarItemType.Bundle)
	for _, entry in fetchDetails(assets, Enum.AvatarItemType.Asset) do
		table.insert(entries, entry)
	end
	if mine ~= token then
		return
	end
	Ui.clearChildren(listPage)
	Ui.setStatus(if #entries == 0 then "You wear the default look. Pick items from the other tabs." else "")
	local total = 0
	local items = {}
	for i, entry in entries do
		local item = Ui.toItem(entry)
		local row = Ui.Templates.WearingRow:Clone()
		row.LayoutOrder = i
		row.Thumb.ImageContent = Ui.itemThumbnail(item, 150)
		row.Info.NameLabel.Text = item.name
		local bundleOnly = not item.bundle and BUNDLE_ONLY[item.assetType or ""] == true
		local text = if bundleOnly then "Part of a bundle" else Ui.priceText(item)
		local price = if bundleOnly then 0 else item.price or 0
		local forSale = price > 0 or text == "Free"
		row.Info.PriceLabel.Text = if price > 0 then text .. " Robux" else text
		row.BuyButton.Visible = forSale
		row.BuyButton.Text = if price > 0 then "Buy" else "Get"
		row.BuyButton.Activated:Connect(function()
			Session.buy(item)
		end)
		row.RemoveButton.Activated:Connect(function()
			Session.removeItem(item)
		end)
		if forSale and #items < MAX_BULK then
			total += price
			table.insert(items, { id = item.id, bundle = item.bundle })
		end
		row.Parent = listPage
	end
	footer.Total.Text = string.format("%d items · %s Robux", #items, Ui.formatNumber(total))
	footer.BuyAllButton.Visible = #items > 0
	cart = items
	Ui.selectInside(listPage)
end

function Wearing.bind()
	footer.BuyAllButton.Activated:Connect(function()
		if #cart > 0 then
			Session.buyAll(cart)
		end
	end)
end

return Wearing
