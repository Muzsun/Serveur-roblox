-- Chrono (LocalScript dans StarterPlayer > StarterPlayerScripts)
-- Minuteur en bas à droite : part de 0 à la fin de l'intro et s'arrête quand toute l'herbe est coupée (jeu terminé).
if not game:GetService("RunService"):IsClient() then
	warn("[Chrono] Chrono doit être un LocalScript dans StarterPlayer > StarterPlayerScripts !")
	return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local lp = Players.LocalPlayer
local pgui = lp:WaitForChild("PlayerGui")
local cam = workspace.CurrentCamera
local TOUCH = UIS.TouchEnabled and not UIS.KeyboardEnabled

local BLANC, ENCRE, OR = Color3.new(1, 1, 1), Color3.fromRGB(26, 22, 28), Color3.fromRGB(255, 215, 70)

local gui = Instance.new("ScreenGui")
gui.Name = "Chrono"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
pcall(function() gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets end)
gui.Parent = pgui

local boite = Instance.new("Frame")
boite.Size = UDim2.fromOffset(190, 58)
boite.BackgroundColor3 = Color3.fromRGB(20, 24, 18)
boite.BackgroundTransparency = 0.35
boite.Parent = gui
local coin = Instance.new("UICorner") coin.CornerRadius = UDim.new(1, 0) coin.Parent = boite
local bord = Instance.new("UIStroke") bord.Thickness = 3 bord.Color = BLANC bord.Transparency = 0.1 bord.ApplyStrokeMode = Enum.ApplyStrokeMode.Border bord.Parent = boite
local echelle = Instance.new("UIScale") echelle.Parent = boite

local icone = Instance.new("TextLabel")
icone.BackgroundTransparency = 1
icone.Size = UDim2.fromOffset(44, 44)
icone.Position = UDim2.fromOffset(8, 7)
icone.Text = "⏱"
icone.TextScaled = true
icone.Font = Enum.Font.FredokaOne
icone.TextColor3 = BLANC
icone.Parent = boite

local texte = Instance.new("TextLabel")
texte.BackgroundTransparency = 1
texte.Size = UDim2.new(1, -62, 1, -14)
texte.Position = UDim2.fromOffset(54, 7)
texte.Font = Enum.Font.LuckiestGuy
texte.TextScaled = true
texte.TextXAlignment = Enum.TextXAlignment.Left
texte.TextColor3 = BLANC
texte.Text = "00:00"
texte.Parent = boite
local contour = Instance.new("UIStroke") contour.Thickness = 3 contour.Color = ENCRE contour.Parent = texte

-- en bas à droite (sur téléphone : en haut à droite, le bouton de saut est en bas à droite)
local function placer()
	local s = math.clamp(cam.ViewportSize.Y / 950, 0.55, 1)
	if TOUCH then s = math.clamp(s, 0.55, 0.7) end
	echelle.Scale = s
	if TOUCH then
		boite.AnchorPoint = Vector2.new(1, 0)
		boite.Position = UDim2.new(1, -12, 0, 8)
	else
		boite.AnchorPoint = Vector2.new(1, 1)
		boite.Position = UDim2.new(1, -16, 1, -16)
	end
end
placer()
cam:GetPropertyChangedSignal("ViewportSize"):Connect(placer)

local function format(t)
	t = math.floor(t)
	local h, m, s = math.floor(t / 3600), math.floor(t / 60) % 60, t % 60
	if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
	return string.format("%02d:%02d", m, s)
end

-- fin du jeu : il ne reste plus d'herbe
local remotes = RS:WaitForChild("GrassRemotes", 30)
local function jeuFini()
	if not remotes then return false end
	local total, reste = remotes:GetAttribute("GrassTotal"), remotes:GetAttribute("GrassLeft")
	return total ~= nil and total > 0 and reste ~= nil and reste <= 0
end

local depart, fini = nil, false
local pret = os.clock() + 2 -- laisse le temps à l'intro de démarrer
RunService.Heartbeat:Connect(function()
	if fini then return end
	if not depart then
		-- on attend la fin de l'intro du chiot
		if os.clock() < pret or lp:GetAttribute("IntroEnCours") then return end
		depart = os.clock()
	end
	texte.Text = format(os.clock() - depart)
	if jeuFini() then
		fini = true
		texte.TextColor3 = OR
		bord.Color = OR
		echelle.Scale *= 1.25
		TweenService:Create(echelle, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = echelle.Scale / 1.25 }):Play()
	end
end)
