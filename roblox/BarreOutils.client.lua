-- BarreOutils (LocalScript dans StarterPlayer > StarterPlayerScripts)
-- Remplace la barre d'outils de Roblox par des bulles rondes avec l'image de l'outil
-- et son numéro (touches 1 à 9). Clic / touche = sortir ou ranger l'outil.
if not game:GetService("RunService"):IsClient() then
	warn("[Outils] BarreOutils doit être un LocalScript dans StarterPlayer > StarterPlayerScripts !")
	return
end
print("[Outils] BarreOutils démarré")

-- Images des outils : identifiant de l'image, inclinaison (degrés) et taille dans la bulle (1 = toute la bulle).
-- Pour un nouvel outil, ajoute une ligne : NomDeLOutil = { image = "rbxassetid://...", rotation = 0, taille = 0.85 },
-- Sans image, la bulle montre l'outil en 3D. (Un outil avec une TextureId l'utilise aussi.)
local IMAGES = {
	Ciseaux = { image = "rbxassetid://98821470151953", rotation = -20, taille = 0.85 },
}

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera

local TAILLE_BULLE = 78
local BLANC = Color3.new(1, 1, 1)
local ENCRE = Color3.fromRGB(28, 30, 38)
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
barre.Position = UDim2.new(0.5, 0, 1, -14)
barre.Size = UDim2.fromOffset(0, TAILLE_BULLE + 22)
barre.AutomaticSize = Enum.AutomaticSize.X
barre.BackgroundTransparency = 1
barre.Parent = gui
local liste = Instance.new("UIListLayout")
liste.FillDirection = Enum.FillDirection.Horizontal
liste.HorizontalAlignment = Enum.HorizontalAlignment.Center
liste.VerticalAlignment = Enum.VerticalAlignment.Bottom
liste.SortOrder = Enum.SortOrder.LayoutOrder
liste.Padding = UDim.new(0, 18)
liste.Parent = barre
local echelle = Instance.new("UIScale")
echelle.Parent = barre
local function adapter()
	local s = math.clamp(camera.ViewportSize.Y / 950, 0.6, 1)
	if UserInputService.TouchEnabled then s *= 0.85 end
	echelle.Scale = s
end
adapter()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(adapter)

local function rond(objet)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = objet
end

-- Outil en 3D dans la bulle (en attendant une image)
local function apercu3D(outil, parent)
	local vue = Instance.new("ViewportFrame")
	vue.BackgroundTransparency = 1
	vue.AnchorPoint = Vector2.new(0.5, 0.5)
	vue.Position = UDim2.fromScale(0.5, 0.5)
	vue.Size = UDim2.fromScale(0.82, 0.82)
	vue.Ambient = Color3.fromRGB(200, 200, 200)
	vue.LightColor = BLANC
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

	local oeil = Instance.new("Camera")
	oeil.FieldOfView = 30
	local distance = taille.Magnitude / 2 / math.tan(math.rad(oeil.FieldOfView / 2))
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

---------------------------------------------------------------- Bulles

local ordre = {} -- outils dans l'ordre d'arrivée
local bulles = {} -- [outil] = { slot, bulle, contour, taille, numero, reflet }

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

local function creerBulle(outil)
	local slot = Instance.new("Frame")
	slot.Name = outil.Name
	slot.BackgroundTransparency = 1
	slot.Size = UDim2.fromOffset(TAILLE_BULLE, TAILLE_BULLE + 22)

	-- la bulle ronde, façon verre
	local bulle = Instance.new("TextButton")
	bulle.Name = "Bulle"
	bulle.AutoButtonColor = false
	bulle.Text = ""
	bulle.AnchorPoint = Vector2.new(0.5, 1)
	bulle.Position = UDim2.new(0.5, 0, 1, 0)
	bulle.Size = UDim2.fromOffset(TAILLE_BULLE, TAILLE_BULLE)
	bulle.BackgroundColor3 = BLANC
	bulle.BackgroundTransparency = 0.6
	bulle.ZIndex = 2
	bulle.Parent = slot
	rond(bulle)
	local degrade = Instance.new("UIGradient")
	degrade.Rotation = 90
	degrade.Color = ColorSequence.new(BLANC, Color3.fromRGB(175, 185, 200))
	degrade.Parent = bulle
	local contour = Instance.new("UIStroke")
	contour.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	contour.Color = BLANC
	contour.Thickness = 2
	contour.Transparency = 0.35
	contour.Parent = bulle
	local taille = Instance.new("UIScale")
	taille.Parent = bulle

	-- petit reflet en haut à gauche
	local reflet = Instance.new("Frame")
	reflet.BackgroundColor3 = BLANC
	reflet.BackgroundTransparency = 0.55
	reflet.Size = UDim2.fromScale(0.3, 0.14)
	reflet.Position = UDim2.fromScale(0.2, 0.12)
	reflet.Rotation = -30
	reflet.ZIndex = 4
	reflet.Parent = bulle
	rond(reflet)

	-- image de l'outil (ou l'outil en 3D)
	local reglage = IMAGES[outil.Name]
	if type(reglage) == "string" then reglage = { image = reglage } end
	reglage = reglage or {}
	local image = if reglage.image and reglage.image ~= "" then reglage.image else outil.TextureId
	local icone = nil
	if image ~= "" then
		icone = Instance.new("ImageLabel")
		icone.BackgroundTransparency = 1
		icone.Image = image
		icone.ScaleType = Enum.ScaleType.Fit
		icone.AnchorPoint = Vector2.new(0.5, 0.5)
		icone.Position = UDim2.fromScale(0.5, 0.5)
		icone.Size = UDim2.fromScale(reglage.taille or 0.85, reglage.taille or 0.85)
		icone.Rotation = reglage.rotation or 0
		icone:SetAttribute("Rotation0", icone.Rotation)
		icone.ZIndex = 3
		icone.Parent = bulle
	else
		task.spawn(apercu3D, outil, bulle)
	end

	-- numéro en haut à gauche
	local numero = Instance.new("TextLabel")
	numero.BackgroundTransparency = 1
	numero.Size = UDim2.fromOffset(28, 28)
	numero.Position = UDim2.fromOffset(-8, -4)
	numero.Font = Enum.Font.FredokaOne
	numero.TextScaled = true
	numero.TextColor3 = BLANC
	numero.ZIndex = 6
	numero.Parent = slot
	local contourNum = Instance.new("UIStroke")
	contourNum.Thickness = 3
	contourNum.Color = ENCRE
	contourNum.LineJoinMode = Enum.LineJoinMode.Round
	contourNum.Parent = numero

	bulle.Activated:Connect(function() basculer(outil) end)
	bulle.MouseEnter:Connect(function()
		if outil.Parent ~= personnage() then
			TweenService:Create(taille, TweenInfo.new(0.12), { Scale = 1.06 }):Play()
		end
	end)
	bulle.MouseLeave:Connect(function()
		if outil.Parent ~= personnage() then
			TweenService:Create(taille, TweenInfo.new(0.12), { Scale = 1 }):Play()
		end
	end)

	slot.Parent = barre
	bulles[outil] = { slot = slot, bulle = bulle, contour = contour, taille = taille, numero = numero, icone = icone, tenu = false }
end

local function rafraichir()
	local perso = personnage()
	local sac = joueur:FindFirstChildOfClass("Backpack")
	-- retire les outils perdus
	for i = #ordre, 1, -1 do
		local outil = ordre[i]
		if outil.Parent == nil or (outil.Parent ~= sac and outil.Parent ~= perso) then
			table.remove(ordre, i)
			if bulles[outil] then bulles[outil].slot:Destroy() bulles[outil] = nil end
		end
	end
	for i, outil in ordre do
		local b = bulles[outil]
		if not b then creerBulle(outil) b = bulles[outil] end
		b.slot.LayoutOrder = i
		b.numero.Text = if i <= 9 then tostring(i) else ""
		-- l'outil tenu : bulle plus claire, plus nette et un peu plus grande
		local tenu = outil.Parent == perso
		if tenu and not b.tenu and b.icone then
			-- petit coup de ciseaux de l'icône quand on sort l'outil
			local r0 = b.icone:GetAttribute("Rotation0")
			b.icone.Rotation = r0 - 18
			TweenService:Create(b.icone, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = r0 }):Play()
		end
		b.tenu = tenu
		local info = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(b.taille, info, { Scale = if tenu then 1.1 else 1 }):Play()
		TweenService:Create(b.bulle, TweenInfo.new(0.15), { BackgroundTransparency = if tenu then 0.25 else 0.6 }):Play()
		TweenService:Create(b.contour, TweenInfo.new(0.15), {
			Transparency = if tenu then 0 else 0.35,
			Thickness = if tenu then 3 else 2,
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
