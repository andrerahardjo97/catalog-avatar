local AvatarEditorService = game:GetService("AvatarEditorService")

export type Accessory = { id: number, type: string, layered: boolean, order: number }
export type Makeup = { id: number, type: string, order: number }
export type BodyPart = { id: number, color: Color3 }
export type Look = {
	accessories: { Accessory },
	makeup: { Makeup },
	bodyParts: { [string]: BodyPart },
	clothing: { [string]: number },
	animations: { [string]: number },
	scales: { [string]: number },
	bundles: { number },
}
export type Item = {
	id: number,
	bundle: boolean,
	assetType: string?,
	bundleType: string?,
	name: string,
	price: number?,
	priceStatus: string?,
	creator: string?,
}

local BODY_PARTS = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
local CLOTHING_PROPS = { "Shirt", "Pants", "GraphicTShirt", "Face" }
local ANIMATION_PROPS = {
	"IdleAnimation",
	"WalkAnimation",
	"RunAnimation",
	"JumpAnimation",
	"FallAnimation",
	"ClimbAnimation",
	"SwimAnimation",
	"MoodAnimation",
}
local CLOTHING_ASSETS = { Shirt = "Shirt", Pants = "Pants", TShirt = "GraphicTShirt", Face = "Face" }
local BODY_ASSETS = {
	Head = "Head",
	DynamicHead = "Head",
	Torso = "Torso",
	LeftArm = "LeftArm",
	RightArm = "RightArm",
	LeftLeg = "LeftLeg",
	RightLeg = "RightLeg",
}
local MAKEUP_ASSETS = { FaceMakeup = "Face", LipMakeup = "Lip", EyeMakeup = "Eye" }
local LAYERED = {
	TShirt = true,
	Shirt = true,
	Pants = true,
	Jacket = true,
	Sweater = true,
	Shorts = true,
	LeftShoe = true,
	RightShoe = true,
	DressSkirt = true,
	Eyebrow = true,
	Eyelash = true,
}
local SCALES = {
	Height = { min = 0.9, max = 1.05, default = 1 },
	Width = { min = 0.7, max = 1, default = 1 },
	Depth = { min = 0.7, max = 1, default = 1 },
	Head = { min = 0.95, max = 1, default = 1 },
	BodyType = { min = 0, max = 1, default = 0 },
	Proportion = { min = 0, max = 1, default = 0 },
}
local TYPE_LIMITS = { Hat = 3 }
local MAX_ACCESSORIES = 50
local MAX_MAKEUP = 10
local MAX_BUNDLES = 20
local DEFAULT_COLOR = Color3.fromRGB(204, 142, 105)

local Look = {}

function Look.isId(value: any): boolean
	return type(value) == "number" and value > 0 and value < 2 ^ 53 and value % 1 == 0
end

local function isIdOrZero(value: any): boolean
	return value == 0 or Look.isId(value)
end

function Look.new(): Look
	local look = {
		accessories = {},
		makeup = {},
		bodyParts = {},
		clothing = {},
		animations = {},
		scales = {},
		bundles = {},
	}
	for _, part in BODY_PARTS do
		look.bodyParts[part] = { id = 0, color = DEFAULT_COLOR }
	end
	for _, prop in CLOTHING_PROPS do
		look.clothing[prop] = 0
	end
	for _, prop in ANIMATION_PROPS do
		look.animations[prop] = 0
	end
	for name, range in SCALES do
		look.scales[name] = range.default
	end
	return look
end

function Look.copy(look: Look): Look
	local out = Look.new()
	for i, accessory in look.accessories do
		out.accessories[i] = table.clone(accessory)
	end
	for i, makeup in look.makeup do
		out.makeup[i] = table.clone(makeup)
	end
	for part, bodyPart in look.bodyParts do
		out.bodyParts[part] = table.clone(bodyPart)
	end
	out.clothing = table.clone(look.clothing)
	out.animations = table.clone(look.animations)
	out.scales = table.clone(look.scales)
	out.bundles = table.clone(look.bundles)
	return out
end

function Look.fromDescription(description: HumanoidDescription): Look
	local look = Look.new()
	for _, child in description:GetChildren() do
		if child:IsA("AccessoryDescription") then
			table.insert(look.accessories, {
				id = child.AssetId,
				type = child.AccessoryType.Name,
				layered = child.IsLayered,
				order = child.Order,
			})
		elseif child:IsA("BodyPartDescription") then
			look.bodyParts[child.BodyPart.Name] = { id = child.AssetId, color = child.Color }
		elseif child:IsA("MakeupDescription") then
			table.insert(look.makeup, { id = child.AssetId, type = child.MakeupType.Name, order = child.Order })
		end
	end
	for _, prop in CLOTHING_PROPS do
		look.clothing[prop] = description[prop]
	end
	for _, prop in ANIMATION_PROPS do
		look.animations[prop] = description[prop]
	end
	for name in SCALES do
		look.scales[name] = description[name .. "Scale"]
	end
	return look
end

function Look.toDescription(look: Look): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	for _, prop in CLOTHING_PROPS do
		description[prop] = look.clothing[prop] or 0
	end
	for _, prop in ANIMATION_PROPS do
		description[prop] = look.animations[prop] or 0
	end
	for name, value in look.scales do
		description[name .. "Scale"] = value
	end
	for part, bodyPart in look.bodyParts do
		local child = Instance.new("BodyPartDescription")
		child.BodyPart = Enum.BodyPart[part]
		child.AssetId = bodyPart.id
		child.Color = bodyPart.color
		child.Parent = description
	end
	for _, accessory in look.accessories do
		local child = Instance.new("AccessoryDescription")
		child.AssetId = accessory.id
		child.AccessoryType = Enum.AccessoryType[accessory.type]
		child.IsLayered = accessory.layered
		child.Order = accessory.order
		child.Parent = description
	end
	for _, makeup in look.makeup do
		local child = Instance.new("MakeupDescription")
		child.AssetId = makeup.id
		child.MakeupType = Enum.MakeupType[makeup.type]
		child.Order = makeup.order
		child.Parent = description
	end
	return description
end

function Look.isWearing(look: Look, id: number): boolean
	for _, accessory in look.accessories do
		if accessory.id == id then
			return true
		end
	end
	for _, makeup in look.makeup do
		if makeup.id == id then
			return true
		end
	end
	for _, bodyPart in look.bodyParts do
		if bodyPart.id == id then
			return true
		end
	end
	for _, value in look.clothing do
		if value == id then
			return true
		end
	end
	for _, value in look.animations do
		if value == id then
			return true
		end
	end
	return false
end

function Look.remove(look: Look, id: number): boolean
	local removed = false
	for i = #look.accessories, 1, -1 do
		if look.accessories[i].id == id then
			table.remove(look.accessories, i)
			removed = true
		end
	end
	for i = #look.makeup, 1, -1 do
		if look.makeup[i].id == id then
			table.remove(look.makeup, i)
			removed = true
		end
	end
	for _, bodyPart in look.bodyParts do
		if bodyPart.id == id then
			bodyPart.id = 0
			removed = true
		end
	end
	for prop, value in look.clothing do
		if value == id then
			look.clothing[prop] = 0
			removed = true
		end
	end
	for prop, value in look.animations do
		if value == id then
			look.animations[prop] = 0
			removed = true
		end
	end
	return removed
end

local function nextOrder(look: Look): number
	local order = 0
	for _, accessory in look.accessories do
		order = math.max(order, accessory.order)
	end
	for _, makeup in look.makeup do
		order = math.max(order, makeup.order)
	end
	return order + 1
end

local function addAccessory(look: Look, accessory: Accessory)
	Look.remove(look, accessory.id)
	local limit = TYPE_LIMITS[accessory.type] or 1
	local same = {}
	for i, other in look.accessories do
		if other.type == accessory.type then
			table.insert(same, i)
		end
	end
	for i = #same - limit + 1, 1, -1 do
		table.remove(look.accessories, same[i])
	end
	table.insert(look.accessories, {
		id = accessory.id,
		type = accessory.type,
		layered = accessory.layered,
		order = if accessory.layered then nextOrder(look) else 0,
	})
end

local function addMakeup(look: Look, id: number, makeupType: string)
	for i = #look.makeup, 1, -1 do
		if look.makeup[i].type == makeupType then
			table.remove(look.makeup, i)
		end
	end
	table.insert(look.makeup, { id = id, type = makeupType, order = nextOrder(look) })
end

function Look.wear(look: Look, id: number, assetType: string): boolean
	local clothing = CLOTHING_ASSETS[assetType]
	if clothing then
		look.clothing[clothing] = id
		return true
	end
	if table.find(ANIMATION_PROPS, assetType) then
		look.animations[assetType] = id
		return true
	end
	local part = BODY_ASSETS[assetType]
	if part then
		look.bodyParts[part].id = id
		return true
	end
	local makeupType = MAKEUP_ASSETS[assetType]
	if makeupType then
		addMakeup(look, id, makeupType)
		return true
	end
	local avatarAssetType = Enum.AvatarAssetType:FromName(assetType)
	if not avatarAssetType then
		return false
	end
	local accessoryType = AvatarEditorService:GetAccessoryType(avatarAssetType)
	if accessoryType == Enum.AccessoryType.Unknown then
		return false
	end
	addAccessory(look, {
		id = id,
		type = accessoryType.Name,
		layered = LAYERED[accessoryType.Name] == true,
		order = 0,
	})
	return true
end

function Look.assetIds(look: Look): { number }
	local ids = {}
	local function add(id: number)
		if id ~= 0 and not table.find(ids, id) then
			table.insert(ids, id)
		end
	end
	for _, accessory in look.accessories do
		add(accessory.id)
	end
	for _, makeup in look.makeup do
		add(makeup.id)
	end
	for _, part in BODY_PARTS do
		add(look.bodyParts[part].id)
	end
	for _, prop in CLOTHING_PROPS do
		add(look.clothing[prop])
	end
	for _, prop in ANIMATION_PROPS do
		add(look.animations[prop])
	end
	return ids
end

function Look.addBundle(look: Look, bundleLook: Look, bundleId: number)
	for part, bodyPart in bundleLook.bodyParts do
		if bodyPart.id ~= 0 then
			look.bodyParts[part].id = bodyPart.id
		end
	end
	for prop, value in bundleLook.animations do
		if value ~= 0 then
			look.animations[prop] = value
		end
	end
	for prop, value in bundleLook.clothing do
		if value ~= 0 then
			look.clothing[prop] = value
		end
	end
	for _, accessory in bundleLook.accessories do
		addAccessory(look, accessory)
	end
	for _, makeup in bundleLook.makeup do
		addMakeup(look, makeup.id, makeup.type)
	end
	if not table.find(look.bundles, bundleId) then
		table.insert(look.bundles, bundleId)
		if #look.bundles > MAX_BUNDLES then
			table.remove(look.bundles, 1)
		end
	end
end

function Look.removeBundle(look: Look, bundleLook: Look, bundleId: number)
	for _, id in Look.assetIds(bundleLook) do
		Look.remove(look, id)
	end
	local index = table.find(look.bundles, bundleId)
	if index then
		table.remove(look.bundles, index)
	end
end

function Look.sanitize(raw: any): Look?
	if type(raw) ~= "table" then
		return nil
	end
	local look = Look.new()
	if type(raw.accessories) == "table" then
		for _, accessory in raw.accessories do
			if #look.accessories >= MAX_ACCESSORIES then
				break
			end
			if
				type(accessory) == "table"
				and Look.isId(accessory.id)
				and type(accessory.type) == "string"
				and accessory.type ~= "Unknown"
				and Enum.AccessoryType:FromName(accessory.type)
			then
				table.insert(look.accessories, {
					id = accessory.id,
					type = accessory.type,
					layered = accessory.layered == true,
					order = if type(accessory.order) == "number" and accessory.order == accessory.order
						then math.clamp(math.floor(accessory.order), 0, 1000)
						else 0,
				})
			end
		end
	end
	if type(raw.makeup) == "table" then
		for _, makeup in raw.makeup do
			if #look.makeup >= MAX_MAKEUP then
				break
			end
			if
				type(makeup) == "table"
				and Look.isId(makeup.id)
				and type(makeup.type) == "string"
				and Enum.MakeupType:FromName(makeup.type)
			then
				table.insert(look.makeup, {
					id = makeup.id,
					type = makeup.type,
					order = if type(makeup.order) == "number" and makeup.order == makeup.order
						then math.clamp(math.floor(makeup.order), 0, 1000)
						else 0,
				})
			end
		end
	end
	local bodyParts = if type(raw.bodyParts) == "table" then raw.bodyParts else {}
	for _, part in BODY_PARTS do
		local bodyPart = bodyParts[part]
		if type(bodyPart) == "table" then
			if isIdOrZero(bodyPart.id) then
				look.bodyParts[part].id = bodyPart.id
			end
			if typeof(bodyPart.color) == "Color3" then
				look.bodyParts[part].color = bodyPart.color
			end
		end
	end
	local clothing = if type(raw.clothing) == "table" then raw.clothing else {}
	for _, prop in CLOTHING_PROPS do
		if isIdOrZero(clothing[prop]) then
			look.clothing[prop] = clothing[prop]
		end
	end
	local animations = if type(raw.animations) == "table" then raw.animations else {}
	for _, prop in ANIMATION_PROPS do
		if isIdOrZero(animations[prop]) then
			look.animations[prop] = animations[prop]
		end
	end
	local scales = if type(raw.scales) == "table" then raw.scales else {}
	for name, range in SCALES do
		local value = scales[name]
		if type(value) == "number" and value == value then
			look.scales[name] = math.clamp(value, range.min, range.max)
		end
	end
	if type(raw.bundles) == "table" then
		for _, id in raw.bundles do
			if #look.bundles >= MAX_BUNDLES then
				break
			end
			if Look.isId(id) and not table.find(look.bundles, id) then
				table.insert(look.bundles, id)
			end
		end
	end
	return look
end

return Look
