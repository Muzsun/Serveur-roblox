-- BarreOutils (LocalScript dans StarterPlayer > StarterPlayerScripts)
-- Remplace la barre d'outils de Roblox par des cartes façon carnet, avec l'outil en 3D,
-- son numéro (touches 1 à 9) et son nom. Clic / touche = sortir ou ranger l'outil.
if not game:GetService("RunService"):IsClient() then
	warn("[Outils] BarreOutils doit être un LocalScript dans StarterPlayer > StarterPlayerScripts !")
	return
end
print("[Outils] BarreOutils démarré")

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera

local PAPIER = Color3.fromRGB(253, 250, 240)
local LIGNE = Color3.fromRGB(175, 205, 238)
local MARGE = Color3.fromRGB(238, 128, 128)
local ENCRE = Color3.fromRGB(38, 36, 48)
local OR = Color3.fromRGB(255, 205, 70)
local TOUCHES = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8, [Enum.KeyCode.Nine] = 9,
}

-- Cache la barre d'outils de Roblox (on la remplace)
task.spawn(function()
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then return end
		task.wait(0.5)
	end
end)

---------------------------------------------------------------- Interface

local gui = Instance.new("ScreenGui")
gui.Name = "BarreOutils"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = joueur:WaitForChild("PlayerGui")

local barre = Instance.new("Frame")
barre.Name = "Barre"
barre.AnchorPoint = Vector2.new(0.5, 1)
barre.Position = UDim2.new(0.5, 0, 1, -10)
barre.Size = UDim2.fromOffset(0, 136)
barre.AutomaticSize = Enum.AutomaticSize.X
barre.BackgroundTransparency = 1
barre.Parent = gui
local liste = Instance.new("UIListLayout")
liste.FillDirection = Enum.FillDirection.Horizontal
liste.HorizontalAlignment = Enum.HorizontalAlignment.Center
liste.VerticalAlignment = Enum.VerticalAlignment.Bottom
liste.SortOrder = Enum.SortOrder.LayoutOrder
liste.Padding = UDim.new(0, 12)
liste.Parent = barre
local echelle = Instance.new("UIScale")
echelle.Parent = barre
local function adapter()
	local s = math.clamp(camera.ViewportSize.Y / 950, 0.55, 1)
	if UserInputService.TouchEnabled then s *= 0.85 end
	echelle.Scale = s
end
adapter()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(adapter)

local function arrondi(objet, rayon)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, rayon)
	c.Parent = objet
end

local function contour(objet, epaisseur, couleur, bordure)
	local s = Instance.new("UIStroke")
	s.Thickness = epaisseur
	s.Color = couleur
	s.LineJoinMode = Enum.LineJoinMode.Round
	if bordure then s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end
	s.Parent = objet
	return s
end

-- Outil en 3D dans la carte
local function apercu3D(outil, parent)
	local vue = Instance.new("ViewportFrame")
	vue.BackgroundTransparency = 1
	vue.Size = UDim2.new(1, -12, 1, -34)
	vue.Position = UDim2.fromOffset(6, 12)
	vue.Ambient = Color3.fromRGB(190, 190, 190)
	vue.LightColor = Color3.new(1, 1, 1)
	vue.LightDirection = Vector3.new(-1, -1.5, -1)
	vue.ZIndex = 3
	vue.Parent = parent

	local copie = outil:Clone()
	local modele = Instance.new("Model")
	for _, enfant in copie:GetChildren() do enfant.Parent = modele end
	copie:Destroy()
	for _, d in modele:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ParticleEmitter") then d:Destroy()
		elseif d:IsA("BasePart") then d.Anchored = true d.LocalTransparencyModifier = 0 end
	end
	modele.Parent = vue
	local centre, taille = modele:GetBoundingBox()
	if taille.Magnitude < 0.01 then return end
	local rayon = taille.Magnitude / 2

	local oeil = Instance.new("Camera")
	oeil.FieldOfView = 30
	local distance = rayon / math.tan(math.rad(oeil.FieldOfView / 2)) * 1.02
	local fente = modele:FindFirstChild("Fente", true)
	if fente then
		-- ciseaux : vus à plat, pointes vers le haut à droite
		local haut = (fente.CFrame.RightVector + fente.CFrame.LookVector).Unit
		oeil.CFrame = CFrame.lookAt(centre.Position + fente.CFrame.UpVector * distance, centre.Position, haut)
	else
		oeil.CFrame = CFrame.lookAt(centre.Position + Vector3.new(1, 0.8, 1).Unit * distance, centre.Position)
	end
	oeil.Parent = vue
	vue.CurrentCamera = oeil
end

---------------------------------------------------------------- Cartes

local ordre = {} -- outils dans l'ordre d'arrivée
local cartes = {} -- [outil] = { slot, carte, trait, taille }

local function personnage() return joueur.Character end
local function humain()
	local perso = personnage()
	return perso and perso:FindFirstChildOfClass("Humanoid")
end

local function basculer(outil)
	local h = humain()
	if not h or h.Health <= 0 then return end
	if outil.Parent == personnage() then
		h:UnequipTools()
	else
		h:EquipTool(outil)
	end
end

local function creerCarte(outil)
	local slot = Instance.new("Frame")
	slot.Name = outil.Name
	slot.BackgroundTransparency = 1
	slot.Size = UDim2.fromOffset(96, 132)

	local numero = Instance.new("TextLabel")
	numero.BackgroundTransparency = 1
	numero.Size = UDim2.new(0, 34, 0, 34)
	numero.Position = UDim2.fromOffset(-6, -8)
	numero.Font = Enum.Font.FredokaOne
	numero.TextScaled = true
	numero.TextColor3 = Color3.new(1, 1, 1)
	numero.ZIndex = 6
	numero.Parent = slot
	contour(numero, 3, ENCRE)

	local carte = Instance.new("TextButton")
	carte.Name = "Carte"
	carte.AutoButtonColor = false
	carte.Text = ""
	carte.AnchorPoint = Vector2.new(0.5, 1)
	carte.Position = UDim2.new(0.5, 0, 1, 0)
	carte.Size = UDim2.new(1, 0, 1, -14)
	carte.BackgroundColor3 = PAPIER
	carte.ZIndex = 2
	carte.Parent = slot
	arrondi(carte, 8)
	local trait = contour(carte, 2.5, ENCRE, true)
	local taille = Instance.new("UIScale")
	taille.Parent = carte

	-- lignes du carnet + marge rouge
	for i, y in { 0.34, 0.5, 0.66, 0.82 } do
		local l = Instance.new("Frame")
		l.BorderSizePixel = 0
		l.BackgroundColor3 = LIGNE
		l.Size = UDim2.new(1, -8, 0, 1)
		l.Position = UDim2.new(0, 4, y, 0)
		l.ZIndex = 2
		l.Name = "Ligne" .. i
		l.Parent = carte
	end
	local marge = Instance.new("Frame")
	marge.BorderSizePixel = 0
	marge.BackgroundColor3 = MARGE
	marge.Size = UDim2.new(0, 1, 1, -12)
	marge.Position = UDim2.fromOffset(14, 10)
	marge.ZIndex = 2
	marge.Parent = carte
	-- spirale en haut
	for i = 1, 5 do
		local anneau = Instance.new("Frame")
		anneau.BackgroundColor3 = Color3.fromRGB(70, 72, 82)
		anneau.Size = UDim2.fromOffset(7, 12)
		anneau.AnchorPoint = Vector2.new(0.5, 0.5)
		anneau.Position = UDim2.new(i / 6, 0, 0, 1)
		anneau.ZIndex = 4
		anneau.Parent = carte
		arrondi(anneau, 4)
	end

	if outil.TextureId ~= "" then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = outil.TextureId
		image.ScaleType = Enum.ScaleType.Fit
		image.Size = UDim2.new(1, -16, 1, -36)
		image.Position = UDim2.fromOffset(8, 12)
		image.ZIndex = 3
		image.Parent = carte
	else
		task.spawn(apercu3D, outil, carte)
	end

	local nom = Instance.new("TextLabel")
	nom.BackgroundTransparency = 1
	nom.Size = UDim2.new(1, -10, 0, 18)
	nom.Position = UDim2.new(0, 5, 1, -21)
	nom.Font = Enum.Font.FredokaOne
	nom.TextScaled = true
	nom.TextColor3 = ENCRE
	nom.Text = outil.Name
	nom.ZIndex = 5
	nom.Parent = carte

	carte.Activated:Connect(function() basculer(outil) end)
	carte.MouseEnter:Connect(function()
		if outil.Parent ~= personnage() then
			TweenService:Create(taille, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
		end
	end)
	carte.MouseLeave:Connect(function()
		if outil.Parent ~= personnage() then
			TweenService:Create(taille, TweenInfo.new(0.12), { Scale = 1 }):Play()
		end
	end)

	slot.Parent = barre
	cartes[outil] = { slot = slot, carte = carte, trait = trait, taille = taille, numero = numero }
end

local function rafraichir()
	-- retire les outils perdus
	local perso = personnage()
	local sac = joueur:FindFirstChildOfClass("Backpack")
	for i = #ordre, 1, -1 do
		local outil = ordre[i]
		if outil.Parent == nil or (outil.Parent ~= sac and outil.Parent ~= perso) then
			table.remove(ordre, i)
			if cartes[outil] then cartes[outil].slot:Destroy() cartes[outil] = nil end
		end
	end
	for i, outil in ordre do
		local c = cartes[outil]
		if not c then creerCarte(outil) c = cartes[outil] end
		c.slot.LayoutOrder = i
		c.numero.Text = if i <= 9 then tostring(i) else ""
		local tenu = outil.Parent == perso
		c.trait.Color = if tenu then OR else ENCRE
		c.trait.Thickness = if tenu then 4 else 2.5
		local info = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(c.taille, info, { Scale = if tenu then 1.1 else 1 }):Play()
		TweenService:Create(c.carte, info, {
			Rotation = if tenu then 0 else (if i % 2 == 0 then 2.5 else -2.5),
			Position = UDim2.new(0.5, 0, 1, if tenu then -10 else 0),
		}):Play()
	end
end

local function ajouter(objet)
	if objet:IsA("Tool") and not table.find(ordre, objet) then
		table.insert(ordre, objet)
	end
	task.defer(rafraichir)
end

-- surveille un conteneur (personnage ou sac) ; les anciennes connexions sont coupées quand il change
local function surveiller(conteneur, connexions)
	for _, c in connexions do c:Disconnect() end
	table.clear(connexions)
	for _, c in conteneur:GetChildren() do ajouter(c) end
	table.insert(connexions, conteneur.ChildAdded:Connect(ajouter))
	table.insert(connexions, conteneur.ChildRemoved:Connect(function() task.defer(rafraichir) end))
	task.defer(rafraichir)
end

local connexionsPerso, connexionsSac = {}, {}
if joueur.Character then surveiller(joueur.Character, connexionsPerso) end
joueur.CharacterAdded:Connect(function(perso) surveiller(perso, connexionsPerso) end)
local sacActuel = joueur:FindFirstChildOfClass("Backpack")
if sacActuel then surveiller(sacActuel, connexionsSac) end
joueur.ChildAdded:Connect(function(c)
	if c:IsA("Backpack") then surveiller(c, connexionsSac) end
end)

-- touches 1 à 9
UserInputService.InputBegan:Connect(function(entree, occupe)
	if occupe then return end
	local n = TOUCHES[entree.KeyCode]
	if n and ordre[n] then basculer(ordre[n]) end
end)
