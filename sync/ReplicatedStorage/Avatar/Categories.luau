local A = Enum.AvatarAssetType
local B = Enum.BundleType

export type Scale = { key: string, label: string, min: number, max: number }

local Categories = {}

Categories.tabs = {
	{ name = "Wearing", kind = "wearing" },
	{ name = "Popular", kind = "catalog" },
	{ name = "Hats", kind = "catalog", assetTypes = { A.Hat } },
	{ name = "Hair", kind = "catalog", assetTypes = { A.HairAccessory } },
	{ name = "Head", kind = "catalog", assetTypes = { A.DynamicHead, A.FaceAccessory, A.Face } },
	{
		name = "Makeup",
		kind = "catalog",
		assetTypes = { A.FaceMakeup, A.LipMakeup, A.EyeMakeup, A.EyebrowAccessory, A.EyelashAccessory },
	},
	{
		name = "Tops",
		kind = "catalog",
		assetTypes = { A.TShirtAccessory, A.ShirtAccessory, A.JacketAccessory, A.SweaterAccessory },
	},
	{
		name = "Bottoms",
		kind = "catalog",
		assetTypes = { A.PantsAccessory, A.ShortsAccessory, A.DressSkirtAccessory },
	},
	{ name = "Shoes", kind = "catalog", bundleTypes = { B.Shoes } },
	{
		name = "Accessories",
		kind = "catalog",
		assetTypes = { A.NeckAccessory, A.ShoulderAccessory, A.FrontAccessory, A.BackAccessory, A.WaistAccessory },
	},
	{ name = "Classic", kind = "catalog", assetTypes = { A.Shirt, A.Pants, A.TShirt } },
	{ name = "Bodies", kind = "catalog", bundleTypes = { B.BodyParts, B.DynamicHeadAvatar } },
	{ name = "Animations", kind = "catalog", bundleTypes = { B.Animations } },
	{ name = "Skin & Shape", kind = "body" },
	{ name = "Outfits", kind = "outfits" },
	{ name = "Players", kind = "players" },
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
