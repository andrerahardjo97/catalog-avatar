local A = Enum.AvatarAssetType
local B = Enum.BundleType

export type Tab = {
	name: string,
	kind: string,
	focus: string,
	assetTypes: { Enum.AvatarAssetType }?,
	bundleTypes: { Enum.BundleType }?,
}

export type Sort = { name: string, value: Enum.CatalogSortType }
export type Price = { name: string, min: number, max: number? }
export type Scale = { key: string, label: string, min: number, max: number }

local Categories = {}

Categories.tabs = {
	{ name = "Wearing", kind = "wearing", focus = "Full" },
	{ name = "Popular", kind = "catalog", focus = "Full" },
	{ name = "Hats", kind = "catalog", focus = "Head", assetTypes = { A.Hat } },
	{ name = "Hair", kind = "catalog", focus = "Head", assetTypes = { A.HairAccessory } },
	{ name = "Head", kind = "catalog", focus = "Head", assetTypes = { A.DynamicHead, A.FaceAccessory, A.Face } },
	{
		name = "Makeup",
		kind = "catalog",
		focus = "Head",
		assetTypes = { A.FaceMakeup, A.LipMakeup, A.EyeMakeup, A.EyebrowAccessory, A.EyelashAccessory },
	},
	{
		name = "Tops",
		kind = "catalog",
		focus = "Torso",
		assetTypes = { A.TShirtAccessory, A.ShirtAccessory, A.JacketAccessory, A.SweaterAccessory },
	},
	{
		name = "Bottoms",
		kind = "catalog",
		focus = "Legs",
		assetTypes = { A.PantsAccessory, A.ShortsAccessory, A.DressSkirtAccessory },
	},
	{ name = "Shoes", kind = "catalog", focus = "Feet", bundleTypes = { B.Shoes } },
	{
		name = "Accessories",
		kind = "catalog",
		focus = "Torso",
		assetTypes = { A.NeckAccessory, A.ShoulderAccessory, A.FrontAccessory, A.BackAccessory, A.WaistAccessory },
	},
	{ name = "Classic", kind = "catalog", focus = "Full", assetTypes = { A.Shirt, A.Pants, A.TShirt } },
	{ name = "Bodies", kind = "catalog", focus = "Full", bundleTypes = { B.BodyParts, B.DynamicHeadAvatar } },
	{ name = "Animations", kind = "catalog", focus = "Full", bundleTypes = { B.Animations } },
	{ name = "Skin & Shape", kind = "body", focus = "Full" },
	{ name = "Outfits", kind = "outfits", focus = "Full" },
	{ name = "Players", kind = "players", focus = "Full" },
}

Categories.sorts = {
	{ name = "Relevance", value = Enum.CatalogSortType.Relevance },
	{ name = "Best selling", value = Enum.CatalogSortType.Bestselling },
	{ name = "Favorites", value = Enum.CatalogSortType.MostFavorited },
	{ name = "Newest", value = Enum.CatalogSortType.RecentlyCreated },
	{ name = "Price: low", value = Enum.CatalogSortType.PriceLowToHigh },
	{ name = "Price: high", value = Enum.CatalogSortType.PriceHighToLow },
}

Categories.prices = {
	Any = { name = "Any", min = 0 },
	Free = { name = "Free", min = 0, max = 0 },
	Under100 = { name = "Under100", min = 0, max = 100 },
	Under500 = { name = "Under500", min = 0, max = 500 },
	Over500 = { name = "Over500", min = 500 },
}

Categories.scales = {
	{ key = "Height", label = "Height", min = 0.9, max = 1.05 },
	{ key = "Width", label = "Width", min = 0.7, max = 1 },
	{ key = "Head", label = "Head size", min = 0.95, max = 1 },
	{ key = "BodyType", label = "Body type", min = 0, max = 1 },
	{ key = "Proportion", label = "Proportions", min = 0, max = 1 },
}

return Categories
