local AvatarEditorService = game:GetService("AvatarEditorService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Look = require(ReplicatedStorage:WaitForChild("Avatar"):WaitForChild("Look"))
local Ui = require(script.Parent.Parent.Ui)
local Session = require(script.Parent.Parent.Session)
local Cards = require(script.Parent.Parent.Cards)

local Details = {}

local details = Ui.details
local detailScroll = Ui.detailScroll
local detailActions = Ui.detailActions
local detailsItem = nil
local detailsFavorite = false
local favoriteItem = nil

function Details.isOpen(): boolean
	return details.Visible
end

function Details.refresh()
	if detailsItem then
		detailActions.TryButton.Text = if Session.isWorn(detailsItem.id, detailsItem.bundle) then "Take off" else "Try on"
	end
end

function Details.hide()
	details.Visible = false
	detailsItem = nil
end

function Details.close()
	details.Visible = false
	Ui.panel.Visible = true
	detailsItem = nil
	if Ui.isGamepad() then
		GuiService:Select(Ui.content)
	end
end

function Details.open(item: Look.Item)
	detailsItem = item
	detailsFavorite = false
	details.Visible = true
	detailScroll.CanvasPosition = Vector2.zero
	detailScroll.Thumb.ImageContent = Ui.itemThumbnail(item, 420)
	detailScroll.NameLabel.Text = item.name
	detailScroll.CreatorLabel.Text = if item.creator then "By " .. item.creator else ""
	local text, icon = Ui.priceText(item)
	detailScroll.Price.Amount.Text = text
	detailScroll.Price.Icon.Visible = icon
	detailScroll.DescriptionLabel.Text = ""
	detailActions.TryButton.Text = if Session.isWorn(item.id, item.bundle) then "Take off" else "Try on"
	detailActions.BuyButton.Text = if (item.price or 0) > 0 then "Buy" else "Get"
	detailActions.FavoriteButton.Text = "Favorite"
	Ui.clearChildren(detailScroll.Similar)
	if Ui.isGamepad() then
		GuiService:Select(detailActions)
	end
	task.spawn(function(): ()
		local ok, info = pcall(function(): any
			return AvatarEditorService:GetItemDetailsAsync(item.id, Ui.itemType(item))
		end)
		if detailsItem ~= item then
			return
		end
		if ok then
			detailScroll.DescriptionLabel.Text = info.Description or ""
			if info.CreatorName then
				detailScroll.CreatorLabel.Text = "By " .. info.CreatorName
			end
			if info.Owned then
				detailActions.BuyButton.Text = "Owned"
			elseif info.IsPurchasable == false then
				detailActions.BuyButton.Text = "Off sale"
			end
		end
		if Session.inventoryAllowed then
			local okFavorite, favorite = pcall(function(): boolean
				return AvatarEditorService:GetFavoriteAsync(item.id, Ui.itemType(item))
			end)
			if okFavorite and detailsItem == item then
				detailsFavorite = favorite
				detailActions.FavoriteButton.Text = if favorite then "Unfavorite" else "Favorite"
			end
		end
		local okSimilar, similar = pcall(function(): { any }
			if item.bundle then
				return AvatarEditorService:GetRecommendedBundlesAsync(item.id)
			end
			local assetType = Enum.AvatarAssetType:FromName(item.assetType or "")
			if not assetType then
				return {}
			end
			return AvatarEditorService:GetRecommendedAssetsAsync(assetType, item.id)
		end)
		if detailsItem ~= item or not okSimilar then
			return
		end
		for i, entry in similar do
			if i > 12 then
				break
			end
			local product = entry.Product or {}
			local similarItem = if item.bundle
				then {
					id = entry.Id,
					bundle = true,
					name = entry.Name or "",
					price = product.PriceInRobux,
					priceStatus = if product.IsForSale == false then "Off sale" else nil,
					creator = entry.Creator and entry.Creator.Name,
				}
				else {
					id = entry.Item.AssetId,
					bundle = false,
					assetType = item.assetType,
					name = entry.Item.Name or "",
					price = product.PriceInRobux or entry.Item.Price,
					priceStatus = if product.IsForSale == false then "Off sale" else nil,
					creator = entry.Creator and entry.Creator.Name,
				}
			Cards.make(similarItem, detailScroll.Similar, i)
		end
	end)
end

function Details.bind()
	AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(result)
		local item = favoriteItem
		favoriteItem = nil
		if result == Enum.AvatarPromptResult.Success and item and detailsItem == item then
			detailsFavorite = not detailsFavorite
			detailActions.FavoriteButton.Text = if detailsFavorite then "Unfavorite" else "Favorite"
		end
	end)
	details:GetPropertyChangedSignal("Visible"):Connect(function()
		Ui.panel.Visible = not details.Visible
	end)
	details.Header.BackButton.Activated:Connect(Details.close)
	detailActions.TryButton.Activated:Connect(function()
		if detailsItem then
			Session.wearItem(detailsItem)
		end
	end)
	detailActions.BuyButton.Activated:Connect(function()
		if detailsItem then
			Session.buy(detailsItem)
		end
	end)
	detailActions.FavoriteButton.Activated:Connect(function()
		if detailsItem then
			favoriteItem = detailsItem
			AvatarEditorService:PromptSetFavorite(detailsItem.id, Ui.itemType(detailsItem), not detailsFavorite)
		end
	end)
end

return Details
