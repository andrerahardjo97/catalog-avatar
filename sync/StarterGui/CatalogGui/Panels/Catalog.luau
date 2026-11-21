local AvatarEditorService = game:GetService("AvatarEditorService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Categories = require(ReplicatedStorage:WaitForChild("Avatar"):WaitForChild("Categories"))
local Ui = require(script.Parent.Parent.Ui)
local Session = require(script.Parent.Parent.Session)
local Cards = require(script.Parent.Parent.Cards)

local SEARCH_DELAY = 0.45
local PAGE_SIZE = 60

local Catalog = {}

local grid = Ui.grid
local searchBox = Ui.searchRow.SearchBox
local sortButton = Ui.searchRow.SortButton
local query = nil
local sortIndex = 1
local priceKey = "Any"
local keyword = ""
local searchToken = 0
local asking = false

local function checkScroll()
	local q = query
	if
		q
		and q.pages
		and not q.finished
		and grid.Visible
		and grid.CanvasPosition.Y + grid.AbsoluteWindowSize.Y >= grid.AbsoluteCanvasSize.Y - 400
	then
		task.spawn(Catalog.loadMore)
	end
end

local function renderPage(q: any)
	local page = q.pages:GetCurrentPage()
	for _, entry in page do
		q.count += 1
		q.render(entry, q.count)
	end
	q.finished = q.pages.IsFinished
	Ui.setStatus(if q.count == 0 then q.empty else "")
	Ui.selectInside(grid)
	task.defer(checkScroll)
end

local function newQuery(render: (any, number) -> (), empty: string): any
	local q = { pages = nil, loading = true, finished = false, count = 0, render = render, empty = empty }
	query = q
	Ui.clearChildren(grid)
	grid.CanvasPosition = Vector2.zero
	Ui.setStatus("Loading...")
	return q
end

function Catalog.loadMore()
	local q = query
	if not q or q.loading or q.finished or not q.pages then
		return
	end
	q.loading = true
	local ok = pcall(function(): ()
		q.pages:AdvanceToNextPageAsync()
	end)
	q.loading = false
	if q ~= query then
		return
	end
	if not ok then
		q.finished = true
		return
	end
	renderPage(q)
end

function Catalog.cancel()
	query = nil
end

function Catalog.search()
	if not Ui.open or Ui.tabKind() ~= "catalog" then
		return
	end
	local tab = Categories.tabs[Ui.tabIndex]
	local q = newQuery(function(entry: any, order: number)
		Cards.make(Ui.toItem(entry), grid, order)
	end, "No items found. Try another search or price.")
	local params = CatalogSearchParams.new()
	params.SearchKeyword = keyword
	params.SortType = Categories.sorts[sortIndex].value
	if params.SortType == Enum.CatalogSortType.Bestselling or params.SortType == Enum.CatalogSortType.MostFavorited then
		params.SortAggregation = Enum.CatalogSortAggregation.PastWeek
	end
	local price = Categories.prices[priceKey]
	params.MinPrice = price.min
	if price.max then
		params.MaxPrice = price.max
	end
	if tab.assetTypes then
		params.AssetTypes = tab.assetTypes
	end
	if tab.bundleTypes then
		params.BundleTypes = tab.bundleTypes
	end
	params.Limit = PAGE_SIZE
	local ok, pages = pcall(function(): CatalogPages
		return AvatarEditorService:SearchCatalogAsync(params)
	end)
	if q ~= query then
		return
	end
	q.loading = false
	if not ok then
		q.finished = true
		Ui.setStatus("The marketplace is busy. Try again in a moment.")
		return
	end
	q.pages = pages
	renderPage(q)
end

local function makeOutfitCard(entry: any, order: number): GuiObject
	local card = Ui.Templates.ItemCard:Clone()
	card.Name = tostring(entry.Id)
	card.LayoutOrder = order
	card.Thumb.ImageContent = Ui.thumbnail("Outfit", entry.Id, 150)
	card.NameLabel.Text = entry.Name or "Outfit"
	card.Price.Visible = false
	card.InfoButton.Visible = false
	card.Activated:Connect(function()
		Session.loadLook("outfit", entry.Id, "Outfit loaded.")
	end)
	card.Parent = grid
	return card
end

function Catalog.outfits()
	local q = newQuery(makeOutfitCard, "You have no saved outfits yet. Use Save to make one.")
	if not Session.inventoryAllowed then
		Ui.setStatus("Allow inventory access to see your outfits.")
		if not asking then
			asking = true
			AvatarEditorService:PromptAllowInventoryReadAccess()
		end
		local result = AvatarEditorService.PromptAllowInventoryReadAccessCompleted:Wait()
		asking = false
		if q ~= query then
			return
		end
		if result ~= Enum.AvatarPromptResult.Success then
			q.loading = false
			q.finished = true
			Ui.setStatus("Outfits need inventory access. Open this tab again to retry.")
			return
		end
		Session.inventoryAllowed = true
		Ui.setStatus("Loading...")
	end
	local ok, pages = pcall(function(): OutfitPages
		return AvatarEditorService:GetOutfitsAsync(Enum.OutfitSource.All, Enum.OutfitType.Avatar)
	end)
	if q ~= query then
		return
	end
	q.loading = false
	if not ok then
		q.finished = true
		Ui.setStatus("Your outfits could not be loaded.")
		return
	end
	q.pages = pages
	renderPage(q)
end

function Catalog.bind()
	for _, chip in Ui.filters:GetChildren() do
		if chip:IsA("GuiButton") then
			if chip.Name == priceKey then
				chip:AddTag("Active")
			end
			chip.Activated:Connect(function()
				priceKey = chip.Name
				for _, other in Ui.filters:GetChildren() do
					other:RemoveTag("Active")
				end
				chip:AddTag("Active")
				task.spawn(Catalog.search)
			end)
		end
	end

	sortButton.Text = Categories.sorts[sortIndex].name
	sortButton.Activated:Connect(function()
		sortIndex = sortIndex % #Categories.sorts + 1
		sortButton.Text = Categories.sorts[sortIndex].name
		task.spawn(Catalog.search)
	end)

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		searchToken += 1
		local token = searchToken
		task.delay(SEARCH_DELAY, function(): ()
			local text = searchBox.Text
			if token == searchToken and text ~= keyword then
				keyword = text
				Catalog.search()
			end
		end)
	end)

	searchBox.FocusLost:Connect(function(enterPressed)
		if enterPressed and searchBox.Text ~= keyword then
			searchToken += 1
			keyword = searchBox.Text
			task.spawn(Catalog.search)
		end
	end)

	grid:GetPropertyChangedSignal("CanvasPosition"):Connect(checkScroll)
end

return Catalog
