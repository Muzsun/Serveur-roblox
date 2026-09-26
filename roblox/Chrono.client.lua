-- Chrono (LocalScript dans StarterPlayer > StarterPlayerScripts)
-- Chronomètre en bas à droite : un petit chrono dessiné + le temps, dans le même style que le reste du jeu.
-- Il part de 0 à la fin de l'intro et s'arrête (en doré) quand toute l'herbe est coupée.
if not game:GetService("RunService"):IsClient() then
	warn("[Chrono] Chrono doit être un LocalScript dans StarterPlayer > StarterPlayerScripts !")
	return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local lp = Players.LocalPlayer
local pgui = lp:WaitForChild("PlayerGui")
local cam = workspace.CurrentCamera
local TOUCH = UIS.TouchEnabled and not UIS.KeyboardEnabled

local BLANC, ENCRE, OR = Color3.new(1, 1, 1), Color3.fromRGB(26, 22, 28), Color3.fromRGB(255, 215, 70)
local TAILLE_TEXTE = 44

local gui = Instance.new("ScreenGui")
gui.Name = "Chrono"
gui.ResetOnSpawn = false
pcall(function() gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets end)
gui.Parent = pgui

local boite = Instance.new("Frame")
boite.BackgroundTransparency = 1
boite.Size = UDim2.fromOffset(0, 54)
boite.AutomaticSize = Enum.AutomaticSize.X
boite.Parent = gui
local echelle = Instance.new("UIScale") echelle.Parent = boite -- taille selon l'écran
local liste = Instance.new("UIListLayout")
liste.FillDirection = Enum.FillDirection.Horizontal
liste.VerticalAlignment = Enum.VerticalAlignment.Center
liste.SortOrder = Enum.SortOrder.LayoutOrder
liste.Padding = UDim.new(0, 8)
liste.Parent = boite

local function rond(o) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = o end
local function disque(parent, d, couleur)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.new(0.5, 0, 0.5, 4)
	f.Size = UDim2.fromOffset(d, d)
	f.BackgroundColor3 = couleur
	f.BorderSizePixel = 0
	f.Parent = parent
	rond(f)
	return f
end

-- le petit chrono dessiné : contour noir, anneau blanc, cadran sombre, aiguille qui tourne
local icone = Instance.new("Frame")
icone.BackgroundTransparency = 1
icone.Size = UDim2.fromOffset(46, 54)
icone.LayoutOrder = 1
icone.Parent = boite
local pop = Instance.new("UIScale") pop.Parent = icone
local bouton = Instance.new("Frame")
bouton.AnchorPoint = Vector2.new(0.5, 0)
bouton.Position = UDim2.new(0.5, 0, 0, 1)
bouton.Size = UDim2.fromOffset(12, 9)
bouton.BackgroundColor3 = BLANC
bouton.BorderSizePixel = 0
bouton.Parent = icone
local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 3) bc.Parent = bouton
local bs = Instance.new("UIStroke") bs.Thickness = 2.5 bs.Color = ENCRE bs.Parent = bouton
disque(icone, 44, ENCRE)
local anneau = disque(icone, 37, BLANC)
disque(icone, 27, Color3.fromRGB(44, 40, 48))
local aiguille = Instance.new("Frame") -- tourne autour du centre du cadran
aiguille.BackgroundTransparency = 1
aiguille.AnchorPoint = Vector2.new(0.5, 0.5)
aiguille.Position = UDim2.new(0.5, 0, 0.5, 4)
aiguille.Size = UDim2.fromOffset(24, 24)
aiguille.Parent = icone
local barre = Instance.new("Frame")
barre.AnchorPoint = Vector2.new(0.5, 1)
barre.Position = UDim2.fromScale(0.5, 0.56)
barre.Size = UDim2.fromOffset(4, 11)
barre.BackgroundColor3 = BLANC
barre.BorderSizePixel = 0
barre.Parent = aiguille
rond(barre)
local centre = disque(aiguille, 6, BLANC)
centre.Position = UDim2.fromScale(0.5, 0.5)

-- le temps
local texte = Instance.new("TextLabel")
texte.BackgroundTransparency = 1
texte.Font = Enum.Font.LuckiestGuy
texte.TextSize = TAILLE_TEXTE
texte.TextColor3 = BLANC
texte.TextXAlignment = Enum.TextXAlignment.Left
texte.Text = "00:00"
texte.LayoutOrder = 2
texte.Parent = boite
local contour = Instance.new("UIStroke") contour.Thickness = 4 contour.Color = ENCRE contour.LineJoinMode = Enum.LineJoinMode.Round contour.Parent = texte
-- largeur fixe (les chiffres n'ont pas tous la même largeur : sinon le chrono bougerait)
local function largeur(modele)
	local ok, v = pcall(TextService.GetTextSize, TextService, modele, TAILLE_TEXTE, Enum.Font.LuckiestGuy, Vector2.new(1000, 100))
	return ok and v.X + 6 or #modele * 26
end
local L_COURT, L_LONG = largeur("00:00"), largeur("0:00:00")
texte.Size = UDim2.fromOffset(L_COURT, 54)

-- en bas à droite (sur téléphone : en haut à droite, le bouton de saut est en bas à droite)
local function placer()
	local s = math.clamp(cam.ViewportSize.Y / 950, 0.6, 1)
	if TOUCH then s = math.clamp(s, 0.6, 0.75) end
	echelle.Scale = s
	if TOUCH then
		boite.AnchorPoint = Vector2.new(1, 0)
		boite.Position = UDim2.new(1, -12, 0, 6)
	else
		boite.AnchorPoint = Vector2.new(1, 1)
		boite.Position = UDim2.new(1, -18, 1, -14)
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
local derniere = -1
RunService.Heartbeat:Connect(function()
	if fini then return end
	if not depart then
		-- on attend la fin de l'intro du chiot
		if os.clock() < pret or lp:GetAttribute("IntroEnCours") then return end
		depart = os.clock()
	end
	local t = os.clock() - depart
	aiguille.Rotation = (t % 60) * 6 -- un tour par minute, comme un vrai chrono
	local sec = math.floor(t)
	if sec ~= derniere then
		derniere = sec
		texte.Text = format(t)
		texte.Size = UDim2.fromOffset(sec >= 3600 and L_LONG or L_COURT, 54)
	end
	if jeuFini() then
		-- terminé : le chrono s'arrête et passe en doré
		fini = true
		lp:SetAttribute("TempsFinal", t) -- pour l'écran des statistiques de fin (IntroChien)
		texte.TextColor3 = OR
		anneau.BackgroundColor3 = OR
		barre.BackgroundColor3 = OR
		centre.BackgroundColor3 = OR
		bouton.BackgroundColor3 = OR
		pop.Scale = 1.4
		TweenService:Create(pop, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end)
