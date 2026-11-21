local AvatarEditorService = game:GetService("AvatarEditorService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Avatar = ReplicatedStorage:WaitForChild("Avatar")
local Look = require(Avatar:WaitForChild("Look"))
local Categories = require(Avatar:WaitForChild("Categories"))
local DressingCamera = require(Avatar:WaitForChild("DressingCamera"))
local Templates = Avatar:WaitForChild("Templates")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AvatarRemote = Remotes:WaitForChild("Avatar")
local PurchaseRemote = Remotes:WaitForChild("Purchase")
local Inputs = ReplicatedStorage:WaitForChild("Inputs")
local ToggleContext = Inputs:WaitForChild("EditorToggle")
local EditorContext = Inputs:WaitForChild("Editor")

local player = Players.LocalPlayer
local gui = script.Parent
local hud = gui.Hud
local toast = gui.Toast
local editor = gui.Editor
local orbitPad = editor.OrbitPad
local toolbar = editor.Toolbar
local panel = editor.Panel
local details = editor.Details
local saveMenu = editor.SaveMenu
local tabsFrame = panel.TabRow.Tabs
local searchRow = panel.SearchRow
local searchBox = searchRow.SearchBox
local sortButton = searchRow.SortButton
local filters = panel.Filters
local usernameRow = panel.UsernameRow
local content = panel.Content
local grid = content.Grid
local gridLayout = grid.UIGridLayout
local listPage = content.List
local status = content.Status
local footer = panel.Footer
local detailScroll = details.Scroll
local detailActions = detailScroll.Actions

local MAX_HISTORY = 30
local MAX_BULK = 20
local SEARCH_DELAY = 0.45
local PAGE_SIZE = 60
local PLAYER_CONTEXTS = { "CharacterContext", "CameraContext" }
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

local current = Look.new()
local confirmed = Look.new()
local initialized = false
local history = {}
local pending = nil
local applying = false
local invoking = false
local bundleLooks = {}
local liveCards = {}
local open = false
local tabIndex = 2
local sortIndex = 1
local priceKey = "Any"
local keyword = ""
local query = { token = 0 }
local searchToken = 0
local toastToken = 0
local wearingToken = 0
local rules = nil
local savedContexts = {}
local touchControls = true
local inventoryAllowed = false
local detailsItem = nil
local detailsFavorite = false
local view = {}

local function isGamepad(): boolean
	return UserInputService.PreferredInput == Enum.PreferredInput.Gamepad
end

local function isTyping(): boolean
	return UserInputService:GetFocusedTextBox() ~= nil
end

local function showToast(text: string)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.Visible = true
	task.delay(2.8, function(): ()
		if toastToken == token then
			toast.Visible = false
		end
	end)
end

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	return (string.gsub(formatted, "^,", ""))
end

local function priceText(item: Look.Item): (string, boolean)
	local price = item.price or 0
	if price > 0 then
		return formatNumber(price), true
	end
	if item.priceStatus and item.priceStatus ~= "" and item.priceStatus ~= "Free" then
		return item.priceStatus, false
	end
	return "Free", false
end

local function thumbnail(kind: string, id: number, size: number): Content
	return Content.fromUri(string.format("rbxthumb://type=%s&id=%d&w=%d&h=%d", kind, id, size, size))
end

local function itemThumbnail(item: Look.Item, size: number): Content
	return thumbnail(if item.bundle then "BundleThumbnail" else "Asset", item.id, size)
end

local function itemType(item: Look.Item): Enum.AvatarItemType
	return if item.bundle then Enum.AvatarItemType.Bundle else Enum.AvatarItemType.Asset
end

local function toItem(entry: any): Look.Item
	return {
		id = entry.Id,
		bundle = entry.ItemType == "Bundle",
		assetType = entry.AssetType,
		bundleType = entry.BundleType,
		name = entry.Name or "",
		price = entry.Price or entry.LowestPrice,
		priceStatus = entry.PriceStatus,
		creator = entry.CreatorName,
	}
end

local function isWorn(id: number, bundle: boolean): boolean
	if bundle then
		return table.find(current.bundles, id) ~= nil
	end
	return Look.isWearing(current, id)
end

local function updateCard(card: Instance)
	local id = card:GetAttribute("ItemId")
	local check = card:FindFirstChild("Check")
	if type(id) ~= "number" or not check or not check:IsA("GuiObject") then
		return
	end
	local worn = isWorn(id, card:GetAttribute("Bundle") == true)
	check.Visible = worn
	if worn then
		card:AddTag("Worn")
	else
		card:RemoveTag("Worn")
	end
end

local function refreshWorn()
	for card in liveCards do
		updateCard(card)
	end
	if detailsItem then
		detailActions.TryButton.Text = if isWorn(detailsItem.id, detailsItem.bundle) then "Take off" else "Try on"
	end
	view.lookChanged()
end

local function invoke(kind: string, payload: any): (boolean, any)
	while invoking do
		task.wait()
	end
	invoking = true
	local ok, success, result = pcall(function(): (boolean, any)
		return AvatarRemote:InvokeServer(kind, payload)
	end)
	invoking = false
	if not ok then
		return false, "The server did not answer."
	end
	return success, result
end

local function sendLook()
	if applying then
		return
	end
	applying = true
	while pending do
		local look = pending
		pending = nil
		local ok, result = invoke("apply", look)
		if ok then
			confirmed = result
		elseif type(result) == "string" then
			showToast(result)
		end
		if not pending then
			current = Look.copy(confirmed)
		end
	end
	applying = false
	refreshWorn()
end

local function commit(look: Look.Look)
	if not initialized then
		showToast("Loading your avatar, try again in a moment.")
		return
	end
	table.insert(history, current)
	if #history > MAX_HISTORY then
		table.remove(history, 1)
	end
	current = look
	pending = Look.copy(look)
	refreshWorn()
	task.spawn(sendLook)
end

local function undo()
	local previous = table.remove(history)
	if not previous then
		showToast("Nothing to undo.")
		return
	end
	current = previous
	pending = Look.copy(previous)
	refreshWorn()
	task.spawn(sendLook)
end

local function ensureLook()
	if initialized then
		return
	end
	local ok, look = invoke("current", nil)
	if ok and not initialized then
		confirmed = look
		current = Look.copy(look)
		initialized = true
		refreshWorn()
	end
end

local function fetchLook(kind: string, id: any): Look.Look?
	local ok, result = invoke(kind, id)
	if not ok then
		showToast(if type(result) == "string" then result else "That look could not be loaded.")
		return nil
	end
	return result
end

local function bundleLook(bundleId: number): Look.Look?
	local saved = bundleLooks[bundleId]
	if saved then
		return saved
	end
	local look = fetchLook("bundle", bundleId)
	if look then
		bundleLooks[bundleId] = look
	end
	return look
end

local function wearItem(item: Look.Item)
	local look = Look.copy(current)
	if item.bundle then
		local parts = bundleLook(item.id)
		if not parts then
			return
		end
		look = Look.copy(current)
		if table.find(look.bundles, item.id) then
			Look.removeBundle(look, parts, item.id)
		else
			Look.addBundle(look, parts, item.id)
		end
	elseif Look.isWearing(look, item.id) then
		Look.remove(look, item.id)
	elseif not Look.wear(look, item.id, item.assetType or "") then
		showToast("This item cannot be worn here.")
		return
	end
	commit(look)
end

local function removeItem(item: Look.Item)
	local look = Look.copy(current)
	if item.bundle then
		local parts = bundleLook(item.id)
		if not parts then
			return
		end
		look = Look.copy(current)
		Look.removeBundle(look, parts, item.id)
	else
		Look.remove(look, item.id)
	end
	commit(look)
end

local function loadLook(kind: string, id: any, message: string)
	local look = fetchLook(kind, id)
	if look then
		commit(look)
		showToast(message)
	end
end

local function buy(item: Look.Item)
	PurchaseRemote:FireServer(if item.bundle then "bundle" else "asset", item.id)
end

local function clearChildren(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function setStatus(text: string)
	status.Text = text
	status.Visible = text ~= ""
end

local function selectInside(container: GuiObject)
	if not open or not isGamepad() then
		return
	end
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(editor) and selected.Visible then
		return
	end
	GuiService:Select(container)
end

local function makeCard(item: Look.Item, parent: Instance, order: number): GuiObject
	local card = Templates.ItemCard:Clone()
	card.Name = tostring(item.id)
	card.LayoutOrder = order
	card:SetAttribute("ItemId", item.id)
	card:SetAttribute("Bundle", item.bundle)
	card.Thumb.ImageContent = itemThumbnail(item, 150)
	card.NameLabel.Text = item.name
	local text, icon = priceText(item)
	card.Price.Amount.Text = text
	card.Price.Icon.Visible = icon
	card.Activated:Connect(function()
		wearItem(item)
	end)
	card.InfoButton.Activated:Connect(function()
		view.openDetails(item)
	end)
	liveCards[card] = true
	card.Destroying:Once(function()
		liveCards[card] = nil
	end)
	updateCard(card)
	card.Parent = parent
	return card
end

local function makeOutfitCard(entry: any, order: number): GuiObject
	local card = Templates.ItemCard:Clone()
	card.Name = tostring(entry.Id)
	card.LayoutOrder = order
	card.Thumb.ImageContent = thumbnail("Outfit", entry.Id, 150)
	card.NameLabel.Text = entry.Name or "Outfit"
	card.Price.Visible = false
	card.InfoButton.Visible = false
	card.Activated:Connect(function()
		loadLook("outfit", entry.Id, "Outfit loaded.")
	end)
	card.Parent = grid
	return card
end

local function checkScroll()
	if
		query.pages
		and not query.finished
		and grid.Visible
		and grid.CanvasPosition.Y + grid.AbsoluteWindowSize.Y >= grid.AbsoluteCanvasSize.Y - 400
	then
		task.spawn(view.loadMore)
	end
end

local function renderPage(q: any)
	local page = q.pages:GetCurrentPage()
	for _, entry in page do
		q.count += 1
		q.render(entry, q.count)
	end
	q.finished = q.pages.IsFinished
	setStatus(if q.count == 0 then q.empty else "")
	selectInside(grid)
	task.defer(checkScroll)
end

local function newQuery(render: (any, number) -> (), empty: string): any
	local q = { pages = nil, loading = true, finished = false, count = 0, render = render, empty = empty }
	query = q
	clearChildren(grid)
	grid.CanvasPosition = Vector2.zero
	setStatus("Loading...")
	return q
end

function view.loadMore()
	local q = query
	if q.loading or q.finished or not q.pages then
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

local function runSearch()
	local tab = Categories.tabs[tabIndex]
	local q = newQuery(function(entry: any, order: number)
		makeCard(toItem(entry), grid, order)
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
		setStatus("The marketplace is busy. Try again in a moment.")
		return
	end
	q.pages = pages
	renderPage(q)
end

local function showOutfits()
	local q = newQuery(makeOutfitCard, "You have no saved outfits yet. Use Save to make one.")
	if not inventoryAllowed then
		setStatus("Allow inventory access to see your outfits.")
		AvatarEditorService:PromptAllowInventoryReadAccess()
		local result = AvatarEditorService.PromptAllowInventoryReadAccessCompleted:Wait()
		if q ~= query then
			return
		end
		if result ~= Enum.AvatarPromptResult.Success then
			q.loading = false
			q.finished = true
			setStatus("Outfits need inventory access. Open this tab again to retry.")
			return
		end
		inventoryAllowed = true
		setStatus("Loading...")
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
		setStatus("Your outfits could not be loaded.")
		return
	end
	q.pages = pages
	renderPage(q)
end

local function section(text: string, order: number)
	local label = Templates.SectionLabel:Clone()
	label.Text = text
	label.LayoutOrder = order
	label.Parent = listPage
end

local function fetchDetails(ids: { number }, kind: Enum.AvatarItemType): { any }
	if #ids == 0 then
		return {}
	end
	local ok, result = pcall(function(): { any }
		return AvatarEditorService:GetBatchItemDetailsAsync(ids, kind)
	end)
	return if ok then result else {}
end

local function renderWearing()
	wearingToken += 1
	local token = wearingToken
	local look = current
	local covered = {}
	for _, bundleId in look.bundles do
		local parts = bundleLooks[bundleId]
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
	setStatus(if #assets + #look.bundles == 0 then "" else "Loading...")
	local entries = fetchDetails(look.bundles, Enum.AvatarItemType.Bundle)
	for _, entry in fetchDetails(assets, Enum.AvatarItemType.Asset) do
		table.insert(entries, entry)
	end
	if token ~= wearingToken then
		return
	end
	clearChildren(listPage)
	setStatus(if #entries == 0 then "You wear the default look. Pick items from the other tabs." else "")
	local total = 0
	local cart = {}
	for i, entry in entries do
		local item = toItem(entry)
		local row = Templates.WearingRow:Clone()
		row.LayoutOrder = i
		row.Thumb.ImageContent = itemThumbnail(item, 150)
		row.Info.NameLabel.Text = item.name
		local bundleOnly = not item.bundle and BUNDLE_ONLY[item.assetType or ""] == true
		local text = if bundleOnly then "Part of a bundle" else priceText(item)
		local price = if bundleOnly then 0 else item.price or 0
		local forSale = price > 0 or text == "Free"
		row.Info.PriceLabel.Text = if price > 0 then text .. " Robux" else text
		row.BuyButton.Visible = forSale
		row.BuyButton.Text = if price > 0 then "Buy" else "Get"
		row.BuyButton.Activated:Connect(function()
			buy(item)
		end)
		row.RemoveButton.Activated:Connect(function()
			removeItem(item)
		end)
		if forSale and #cart < MAX_BULK then
			total += price
			table.insert(cart, { id = item.id, bundle = item.bundle })
		end
		row.Parent = listPage
	end
	footer.Total.Text = string.format("%d items · %s Robux", #cart, formatNumber(total))
	footer.BuyAllButton.Visible = #cart > 0
	view.cart = cart
	selectInside(listPage)
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
	local row = Templates.SliderRow:Clone()
	row.LayoutOrder = order
	local range = rules and rules.Scales and rules.Scales[definition.key]
	local min = if range then range.Min else definition.min
	local max = if range then range.Max else definition.max
	local track = row.Track
	local knob = track.Knob
	local drag = knob.Drag
	row.NameLabel.Text = definition.label
	local value = current.scales[definition.key] or min
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
			if mine ~= token or math.abs((current.scales[definition.key] or 0) - amount) < 0.005 then
				return
			end
			local look = Look.copy(current)
			look.scales[definition.key] = amount
			if definition.key == "Width" then
				look.scales.Depth = amount
			end
			commit(look)
		end)
	end)
	drag.DragEnd:Connect(function()
		place(min + (max - min) * sliderValue(knob, track))
	end)
	row.Parent = listPage
end

local function renderBody()
	clearChildren(listPage)
	setStatus("")
	if not rules then
		local ok, result = pcall(function(): any
			return AvatarEditorService:GetAvatarRulesAsync()
		end)
		if ok then
			rules = result
		end
	end
	if Categories.tabs[tabIndex].kind ~= "body" then
		return
	end
	section("Skin tone", 1)
	local swatches = Templates.SwatchGrid:Clone()
	swatches.LayoutOrder = 2
	local skin = current.bodyParts.Head.color
	for i, entry in if rules then rules.BodyColorsPalette or {} else {} do
		local color = BrickColor.new(entry.BrickColorId).Color
		local swatch = Templates.Swatch:Clone()
		swatch.LayoutOrder = i
		swatch.BackgroundColor3 = color
		if color:ToHex() == skin:ToHex() then
			swatch:AddTag("Active")
		end
		swatch.Activated:Connect(function()
			local look = Look.copy(current)
			for _, bodyPart in look.bodyParts do
				bodyPart.color = color
			end
			commit(look)
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
	selectInside(listPage)
end

local function renderPlayers()
	clearChildren(listPage)
	setStatus("")
	for i, other in Players:GetPlayers() do
		local row = Templates.PlayerRow:Clone()
		row.LayoutOrder = if other == player then 0 else i
		row.Thumb.ImageContent = thumbnail("AvatarHeadShot", other.UserId, 150)
		row.NameLabel.Text = string.format("%s (@%s)", other.DisplayName, other.Name)
		row.Action.Text = if other == player then "My avatar" else "Copy look"
		row.Activated:Connect(function()
			loadLook("user", other.UserId, "Copied " .. other.DisplayName .. "'s look.")
		end)
		row.Parent = listPage
	end
	selectInside(listPage)
end

local function selectTab(index: number)
	tabIndex = index
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
	DressingCamera.setFocus(tab.focus)
	details.Visible = false
	detailsItem = nil
	local catalog = tab.kind == "catalog"
	local gridKind = catalog or tab.kind == "outfits"
	searchRow.Visible = catalog
	filters.Visible = catalog
	usernameRow.Visible = tab.kind == "players"
	footer.Visible = tab.kind == "wearing"
	grid.Visible = gridKind
	listPage.Visible = not gridKind
	query = { token = 0 }
	wearingToken += 1
	setStatus("")
	if not gridKind then
		clearChildren(listPage)
	end
	if open and isGamepad() then
		GuiService.SelectedObject = nil
	end
	if catalog then
		task.spawn(runSearch)
	elseif tab.kind == "outfits" then
		task.spawn(showOutfits)
	elseif tab.kind == "wearing" then
		task.spawn(renderWearing)
	elseif tab.kind == "body" then
		task.spawn(renderBody)
	elseif tab.kind == "players" then
		renderPlayers()
	end
end

local function shiftTab(step: number)
	selectTab((tabIndex - 1 + step) % #Categories.tabs + 1)
end

function view.lookChanged()
	local kind = Categories.tabs[tabIndex].kind
	if open and kind == "wearing" and not applying then
		task.spawn(renderWearing)
	end
end

function view.openDetails(item: Look.Item)
	detailsItem = item
	detailsFavorite = false
	details.Visible = true
	detailScroll.CanvasPosition = Vector2.zero
	detailScroll.Thumb.ImageContent = itemThumbnail(item, 420)
	detailScroll.NameLabel.Text = item.name
	detailScroll.CreatorLabel.Text = if item.creator then "By " .. item.creator else ""
	local text, icon = priceText(item)
	detailScroll.Price.Amount.Text = text
	detailScroll.Price.Icon.Visible = icon
	detailScroll.DescriptionLabel.Text = ""
	detailActions.TryButton.Text = if isWorn(item.id, item.bundle) then "Take off" else "Try on"
	detailActions.BuyButton.Text = if (item.price or 0) > 0 then "Buy" else "Get"
	detailActions.FavoriteButton.Text = "Favorite"
	clearChildren(detailScroll.Similar)
	if isGamepad() then
		GuiService:Select(detailActions)
	end
	task.spawn(function(): ()
		local ok, info = pcall(function(): any
			return AvatarEditorService:GetItemDetailsAsync(item.id, itemType(item))
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
		if inventoryAllowed then
			local okFavorite, favorite = pcall(function(): boolean
				return AvatarEditorService:GetFavoriteAsync(item.id, itemType(item))
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
					bundleType = entry.BundleType,
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
			makeCard(similarItem, detailScroll.Similar, i)
		end
	end)
end

local function closeDetails()
	details.Visible = false
	panel.Visible = true
	detailsItem = nil
	if isGamepad() then
		GuiService:Select(content)
	end
end

local function frameCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local inset = GuiService:GetGuiInset()
	local panelTop = panel.AbsolutePosition + inset
	if gui.AbsoluteSize.Y > gui.AbsoluteSize.X then
		local top = toolbar.AbsolutePosition.Y + toolbar.AbsoluteSize.Y + inset.Y
		local free = math.max(panelTop.Y - top, 1)
		DressingCamera.setOffset(
			Vector2.new(0, 1 - (top + panelTop.Y) / viewport.Y),
			math.clamp(0.6 * viewport.Y / free, 1, 2.2)
		)
	else
		local bottom = toolbar.AbsolutePosition.Y + inset.Y
		DressingCamera.setOffset(
			Vector2.new(panelTop.X / viewport.X - 1, 1 - bottom / viewport.Y),
			math.clamp(0.85 * viewport.Y / math.max(bottom, 1), 1, 2.2)
		)
	end
end

local function relayout()
	local size = gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local portrait = size.Y > size.X
	local panelWidth
	if portrait then
		local height = math.floor(size.Y * 0.56)
		panelWidth = size.X - 16
		panel.AnchorPoint = Vector2.new(0, 1)
		panel.Position = UDim2.new(0, 8, 1, -8)
		panel.Size = UDim2.new(1, -16, 0, height)
		toolbar.AnchorPoint = Vector2.zero
		toolbar.Position = UDim2.fromOffset(8, 8)
	else
		panelWidth = math.clamp(math.floor(size.X * 0.44), math.min(330, size.X - 24), 620)
		panel.AnchorPoint = Vector2.new(1, 0)
		panel.Position = UDim2.new(1, -12, 0, 12)
		panel.Size = UDim2.new(0, panelWidth, 1, -24)
		toolbar.AnchorPoint = Vector2.new(0, 1)
		toolbar.Position = UDim2.new(0, 12, 1, -12)
	end
	task.defer(frameCamera)
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
	if open == value then
		return
	end
	open = value
	editor.Visible = value
	hud.Visible = not value
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
			DressingCamera.start(character)
		end
		task.spawn(ensureLook)
		selectTab(tabIndex)
	else
		DressingCamera.stop()
		details.Visible = false
		saveMenu.Visible = false
		detailsItem = nil
		query = { token = 0 }
		clearChildren(grid)
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
	local button = Templates.TabButton:Clone()
	button.Name = tab.name
	button.Text = tab.name
	button.LayoutOrder = i
	button.Activated:Connect(function()
		selectTab(i)
	end)
	button.Parent = tabsFrame
end

for _, chip in filters:GetChildren() do
	if chip:IsA("GuiButton") then
		if chip.Name == priceKey then
			chip:AddTag("Active")
		end
		chip.Activated:Connect(function()
			priceKey = chip.Name
			for _, other in filters:GetChildren() do
				other:RemoveTag("Active")
			end
			chip:AddTag("Active")
			task.spawn(runSearch)
		end)
	end
end

sortButton.Text = Categories.sorts[sortIndex].name
sortButton.Activated:Connect(function()
	sortIndex = sortIndex % #Categories.sorts + 1
	sortButton.Text = Categories.sorts[sortIndex].name
	task.spawn(runSearch)
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	searchToken += 1
	local token = searchToken
	task.delay(SEARCH_DELAY, function(): ()
		local text = searchBox.Text
		if token == searchToken and text ~= keyword then
			keyword = text
			runSearch()
		end
	end)
end)

searchBox.FocusLost:Connect(function(enterPressed)
	if enterPressed and searchBox.Text ~= keyword then
		searchToken += 1
		keyword = searchBox.Text
		task.spawn(runSearch)
	end
end)

grid:GetPropertyChangedSignal("CanvasPosition"):Connect(checkScroll)

local function copyUsername()
	local name = string.gsub(usernameRow.UsernameBox.Text, "%s", "")
	if name ~= "" then
		task.spawn(loadLook, "name", name, "Copied @" .. name .. "'s look.")
	end
end
usernameRow.CopyButton.Activated:Connect(copyUsername)
usernameRow.UsernameBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		copyUsername()
	end
end)

footer.BuyAllButton.Activated:Connect(function()
	if view.cart and #view.cart > 0 then
		PurchaseRemote:FireServer("bulk", view.cart)
	end
end)

hud.OpenButton.Activated:Connect(function()
	setOpen(true)
end)
toolbar.CloseButton.Activated:Connect(function()
	setOpen(false)
end)
toolbar.UndoButton.Activated:Connect(undo)
toolbar.ResetButton.Activated:Connect(function()
	loadLook("user", player.UserId, "Back to your Roblox avatar.")
end)
toolbar.SaveButton.Activated:Connect(function()
	saveMenu.Visible = true
	if isGamepad() then
		GuiService:Select(saveMenu)
	end
end)
saveMenu.CancelButton.Activated:Connect(function()
	saveMenu.Visible = false
end)
saveMenu.SaveAvatarButton.Activated:Connect(function()
	saveMenu.Visible = false
	AvatarEditorService:PromptSaveAvatar(Look.toDescription(current), rigType())
end)
saveMenu.SaveOutfitButton.Activated:Connect(function()
	saveMenu.Visible = false
	AvatarEditorService:PromptCreateOutfit(Look.toDescription(current), rigType())
end)

AvatarEditorService.PromptSaveAvatarCompleted:Connect(function(result)
	if result == Enum.AvatarPromptResult.Success then
		showToast("Your Roblox avatar is updated.")
	elseif result == Enum.AvatarPromptResult.Failed then
		showToast("The avatar could not be saved.")
	end
end)
AvatarEditorService.PromptCreateOutfitCompleted:Connect(function(result)
	if result == Enum.AvatarPromptResult.Success then
		showToast("Outfit saved.")
		if open and Categories.tabs[tabIndex].kind == "outfits" then
			selectTab(tabIndex)
		end
	elseif result == Enum.AvatarPromptResult.Failed then
		showToast("The outfit could not be saved.")
	end
end)
AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(result)
	if result == Enum.AvatarPromptResult.Success and detailsItem then
		detailsFavorite = not detailsFavorite
		detailActions.FavoriteButton.Text = if detailsFavorite then "Unfavorite" else "Favorite"
	end
end)

details:GetPropertyChangedSignal("Visible"):Connect(function()
	panel.Visible = not details.Visible
end)
details.Header.BackButton.Activated:Connect(closeDetails)
detailActions.TryButton.Activated:Connect(function()
	if detailsItem then
		wearItem(detailsItem)
	end
end)
detailActions.BuyButton.Activated:Connect(function()
	if detailsItem then
		buy(detailsItem)
	end
end)
detailActions.FavoriteButton.Activated:Connect(function()
	if detailsItem then
		AvatarEditorService:PromptSetFavorite(detailsItem.id, itemType(detailsItem), not detailsFavorite)
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

ToggleContext.Toggle.Pressed:Connect(function()
	if not isTyping() then
		setOpen(not open)
	end
end)
EditorContext.NextTab.Pressed:Connect(function()
	if not isTyping() then
		shiftTab(1)
	end
end)
EditorContext.PrevTab.Pressed:Connect(function()
	if not isTyping() then
		shiftTab(-1)
	end
end)
EditorContext.Undo.Pressed:Connect(function()
	if not isTyping() then
		undo()
	end
end)
EditorContext.Close.Pressed:Connect(function()
	if saveMenu.Visible then
		saveMenu.Visible = false
	elseif details.Visible then
		closeDetails()
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
Players.PlayerAdded:Connect(function()
	if open and Categories.tabs[tabIndex].kind == "players" then
		renderPlayers()
	end
end)
Players.PlayerRemoving:Connect(function()
	if open and Categories.tabs[tabIndex].kind == "players" then
		task.defer(renderPlayers)
	end
end)
player.CharacterAdded:Connect(function(character)
	if open then
		DressingCamera.start(character)
	end
end)

updateHints()
relayout()
