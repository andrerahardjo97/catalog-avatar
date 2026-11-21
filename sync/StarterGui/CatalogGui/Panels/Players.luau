local Players = game:GetService("Players")

local Ui = require(script.Parent.Parent.Ui)
local Session = require(script.Parent.Parent.Session)

local PlayersPanel = {}

local player = Players.LocalPlayer
local listPage = Ui.listPage
local usernameRow = Ui.usernameRow

function PlayersPanel.render(leaving: Player?)
	Ui.clearChildren(listPage)
	Ui.setStatus("")
	for i, other in Players:GetPlayers() do
		if other == leaving then
			continue
		end
		local row = Ui.Templates.PlayerRow:Clone()
		row.LayoutOrder = if other == player then 0 else i
		row.Thumb.ImageContent = Ui.thumbnail("AvatarHeadShot", other.UserId, 150)
		row.NameLabel.Text = string.format("%s (@%s)", other.DisplayName, other.Name)
		row.Action.Text = if other == player then "My avatar" else "Copy look"
		row.Activated:Connect(function()
			Session.loadLook("user", other.UserId, "Copied " .. other.DisplayName .. "'s look.")
		end)
		row.Parent = listPage
	end
	Ui.selectInside(listPage)
end

local function copyUsername()
	local name = string.gsub(usernameRow.UsernameBox.Text, "%s", "")
	if name ~= "" then
		task.spawn(Session.loadLook, "name", name, "Copied @" .. name .. "'s look.")
	end
end

function PlayersPanel.bind()
	usernameRow.CopyButton.Activated:Connect(copyUsername)
	usernameRow.UsernameBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			copyUsername()
		end
	end)
	Players.PlayerAdded:Connect(function()
		if Ui.open and Ui.tabKind() == "players" then
			PlayersPanel.render()
		end
	end)
	Players.PlayerRemoving:Connect(function(leaving)
		if Ui.open and Ui.tabKind() == "players" then
			PlayersPanel.render(leaving)
		end
	end)
end

return PlayersPanel
