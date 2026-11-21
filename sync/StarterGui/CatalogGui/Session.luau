local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Avatar = ReplicatedStorage:WaitForChild("Avatar")
local Look = require(Avatar:WaitForChild("Look"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AvatarRemote = Remotes:WaitForChild("Avatar")
local PurchaseRemote = Remotes:WaitForChild("Purchase")
local Ui = require(script.Parent.Ui)

local MAX_HISTORY = 30

local Session = {
	current = Look.new(),
	initialized = false,
	applying = false,
	inventoryAllowed = false,
	changed = function(): () end,
}

local confirmed = Look.new()
local history = {}
local pending = nil
local invoking = false
local bundleLooks = {}

function Session.isWorn(id: number, bundle: boolean): boolean
	if bundle then
		return table.find(Session.current.bundles, id) ~= nil
	end
	return Look.isWearing(Session.current, id)
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
	if Session.applying then
		return
	end
	Session.applying = true
	while pending do
		local look = pending
		pending = nil
		local ok, result = invoke("apply", look)
		if ok then
			confirmed = result
		elseif type(result) == "string" then
			Ui.showToast(result)
		end
		if not pending then
			Session.current = Look.copy(confirmed)
		end
	end
	Session.applying = false
	Session.changed()
end

function Session.commit(look: Look.Look)
	if not Session.initialized then
		Ui.showToast("Loading your avatar, try again in a moment.")
		task.spawn(Session.ensureLook)
		return
	end
	table.insert(history, Session.current)
	if #history > MAX_HISTORY then
		table.remove(history, 1)
	end
	Session.current = look
	pending = Look.copy(look)
	Session.changed()
	task.spawn(sendLook)
end

function Session.undo()
	local previous = table.remove(history)
	if not previous then
		Ui.showToast("Nothing to undo.")
		return
	end
	Session.current = previous
	pending = Look.copy(previous)
	Session.changed()
	task.spawn(sendLook)
end

function Session.ensureLook()
	if Session.initialized then
		return
	end
	local ok, look = invoke("current", nil)
	if ok and not Session.initialized then
		confirmed = look
		Session.current = Look.copy(look)
		Session.initialized = true
		Session.changed()
	end
end

local function fetchLook(kind: string, id: any): Look.Look?
	local ok, result = invoke(kind, id)
	if not ok then
		Ui.showToast(if type(result) == "string" then result else "That look could not be loaded.")
		return nil
	end
	return result
end

function Session.cachedBundle(bundleId: number): Look.Look?
	return bundleLooks[bundleId]
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

function Session.wearItem(item: Look.Item)
	local look = Look.copy(Session.current)
	if item.bundle then
		local parts = bundleLook(item.id)
		if not parts then
			return
		end
		look = Look.copy(Session.current)
		if table.find(look.bundles, item.id) then
			Look.removeBundle(look, parts, item.id)
		else
			Look.addBundle(look, parts, item.id)
		end
	elseif Look.isWearing(look, item.id) then
		Look.remove(look, item.id)
	elseif not Look.wear(look, item.id, item.assetType or "") then
		Ui.showToast("This item cannot be worn here.")
		return
	end
	Session.commit(look)
end

function Session.removeItem(item: Look.Item)
	local look = Look.copy(Session.current)
	if item.bundle then
		local parts = bundleLook(item.id)
		if not parts then
			return
		end
		look = Look.copy(Session.current)
		Look.removeBundle(look, parts, item.id)
	else
		Look.remove(look, item.id)
	end
	Session.commit(look)
end

function Session.loadLook(kind: string, id: any, message: string)
	local look = fetchLook(kind, id)
	if look then
		Session.commit(look)
		Ui.showToast(message)
	end
end

function Session.buy(item: Look.Item)
	PurchaseRemote:FireServer(if item.bundle then "bundle" else "asset", item.id)
end

function Session.buyAll(cart: { any })
	PurchaseRemote:FireServer("bulk", cart)
end

return Session
