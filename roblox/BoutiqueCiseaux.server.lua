-- BoutiqueCiseaux : panneau d'achat + outil ciseaux (tenue, animation de coupe, coupe de l'herbe)
-- À mettre dans un Script dans ServerScriptService.
-- Il faut que les ciseaux posés sur l'étagère s'appellent "Ciseaux" dans le Workspace,
-- et que l'ajout "CISEAUX" soit collé en bas de GrassServer.

local CONFIG = {
	PRIX = 7.99,
	NOM_AFFICHE = "Ciseaux de jardin",
	VITRINE = "Ciseaux", -- le modèle posé sur l'étagère
	RAYON_COUPE = 4, -- rayon de coupe devant le joueur (studs)
	MAX_PAR_COUPE = 6, -- nombre max de touffes coupées par coup de ciseaux
	TOURNER_EN_MAIN = 0, -- degrés : tourne les ciseaux dans la main si besoin
}

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

-- Même monnaie que le système d'herbe (GrassConfig.MONEY_STAT, sinon détection auto)
local moduleConfig = ReplicatedStorage:WaitForChild("GrassConfig", 10)
local MONEY_STAT = moduleConfig and require(moduleConfig).MONEY_STAT or ""
local NOMS_MONNAIE = { "Money", "Cash", "Argent", "Coins", "Dollars", "Pieces", "Pièces", "$" }

local TAG_OUTIL = "OutilCiseaux"
local ANGLE_TENUE = math.rad(-15) -- bras légèrement baissé quand on tient les ciseaux
local ANGLE_COUPE = math.rad(-55) -- bras baissé vers le sol pendant la coupe
local FERMETURE = math.rad(11) -- rotation de chaque lame pour fermer les ciseaux

local VERT = Color3.fromRGB(120, 230, 120)
local ROUGE = Color3.fromRGB(255, 110, 110)
local JAUNE = Color3.fromRGB(255, 220, 110)

---------------------------------------------------------------- Monnaie

local function trouverArgent(joueur)
	local stats = joueur:FindFirstChild("leaderstats")
	if not stats then return nil end
	if MONEY_STAT ~= "" then return stats:FindFirstChild(MONEY_STAT) end
	for _, nom in NOMS_MONNAIE do
		local valeur = stats:FindFirstChild(nom)
		if valeur and (valeur:IsA("IntValue") or valeur:IsA("NumberValue")) then return valeur end
	end
	return nil
end

local function message(joueur, texte, couleur)
	local playerGui = joueur:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return end
	local ancien = playerGui:FindFirstChild("MessageBoutique")
	if ancien then ancien:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "MessageBoutique"
	gui.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.12)
	label.Size = UDim2.fromScale(0.6, 0.07)
	label.BackgroundTransparency = 1
	label.Text = texte
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = couleur
	local contour = Instance.new("UIStroke")
	contour.Thickness = 3
	contour.Color = Color3.fromRGB(25, 30, 28)
	contour.Parent = label
	label.Parent = gui
	gui.Parent = playerGui
	Debris:AddItem(gui, 2.5)
end

---------------------------------------------------------------- Construction de l'outil

local vitrine = workspace:WaitForChild(CONFIG.VITRINE, 10)
if not vitrine then
	warn("[BoutiqueCiseaux] Aucun modèle \"" .. CONFIG.VITRINE .. "\" dans le Workspace : pose d'abord les ciseaux sur l'étagère.")
	return
end
local fente = vitrine:FindFirstChild("Fente", true)
if not fente then
	warn("[BoutiqueCiseaux] Le modèle \"" .. CONFIG.VITRINE .. "\" n'est pas le build de ciseaux attendu (pièce \"Fente\" introuvable).")
	return
end

local function preparerPiece(p)
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
end

local function souder(base, p)
	local soudure = Instance.new("Weld")
	soudure.Part0 = base
	soudure.Part1 = p
	soudure.C0 = base.CFrame:ToObjectSpace(p.CFrame)
	soudure.Parent = p
end

local function construireOutil()
	-- Repère des ciseaux : X vers les pointes, Y vers le haut, axe de la vis au centre
	local axe = fente.CFrame
	local outil = Instance.new("Tool")
	outil.Name = "Ciseaux"
	outil.ToolTip = "Clique pour couper l'herbe"
	outil.CanBeDropped = false
	-- Tenue façon épée classique : les pointes vers l'avant
	outil.GripPos = Vector3.zero
	outil.GripForward = Vector3.new(-1, 0, 0)
	outil.GripRight = Vector3.new(0, 1, 0)
	outil.GripUp = Vector3.new(0, 0, 1)
	CollectionService:AddTag(outil, TAG_OUTIL)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 0.3)
	handle.Transparency = 1
	handle.CFrame = axe * CFrame.new(-1, -0.13, 0)
		* CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0))
		* CFrame.Angles(0, 0, math.rad(CONFIG.TOURNER_EN_MAIN))
	preparerPiece(handle)
	handle.Parent = outil

	for _, nom in { "BranchePouce", "BrancheDoigts", "Vis" } do
		local source = vitrine:FindFirstChild(nom)
		if source then
			local dossier = Instance.new("Folder")
			dossier.Name = nom
			dossier.Parent = outil
			local base = handle
			if nom ~= "Vis" then
				-- Chaque branche tourne autour de la vis grâce à un Motor6D
				base = Instance.new("Part")
				base.Name = "Pivot"
				base.Size = Vector3.new(0.1, 0.1, 0.1)
				base.Transparency = 1
				base.CFrame = axe
				preparerPiece(base)
				base.Parent = dossier
				local moteur = Instance.new("Motor6D")
				moteur.Name = nom
				moteur.Part0 = handle
				moteur.Part1 = base
				moteur.C0 = handle.CFrame:ToObjectSpace(axe)
				moteur:SetAttribute("C0Origine", moteur.C0)
				moteur:SetAttribute("Sens", if nom == "BranchePouce" then 1 else -1)
				moteur.Parent = handle
			end
			for _, p in source:GetDescendants() do
				if p:IsA("BasePart") then
					local copie = p:Clone()
					preparerPiece(copie)
					copie.Parent = dossier
					souder(base, copie)
				end
			end
		end
	end
	outil.Parent = ServerStorage
	return outil
end

local modeleOutil = construireOutil()

---------------------------------------------------------------- Animations

local function trouverEpaule(perso)
	local bras = perso:FindFirstChild("RightUpperArm")
	if bras then
		return bras:FindFirstChild("RightShoulder") -- R15
	end
	local torse = perso:FindFirstChild("Torso")
	return torse and torse:FindFirstChild("Right Shoulder") -- R6
end

local function bougerBras(epaule, angle, duree)
	if not epaule then return end
	local origine = epaule:GetAttribute("C0Origine")
	if not origine then
		origine = epaule.C0
		epaule:SetAttribute("C0Origine", origine)
	end
	local cible = CFrame.new(origine.Position) * CFrame.Angles(angle, 0, 0) * origine.Rotation
	TweenService:Create(epaule, TweenInfo.new(duree, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = cible }):Play()
end

local function remettreBras(epaule)
	local origine = epaule and epaule:GetAttribute("C0Origine")
	if origine then
		TweenService:Create(epaule, TweenInfo.new(0.15), { C0 = origine }):Play()
	end
end

local function lames(outil, fermees, duree)
	for _, moteur in outil.Handle:GetChildren() do
		if moteur:IsA("Motor6D") then
			local angle = if fermees then FERMETURE * moteur:GetAttribute("Sens") else 0
			local cible = moteur:GetAttribute("C0Origine") * CFrame.Angles(0, angle, 0)
			TweenService:Create(moteur, TweenInfo.new(duree, Enum.EasingStyle.Sine), { C0 = cible }):Play()
		end
	end
end

---------------------------------------------------------------- Coupe de l'herbe (via GrassServer)

local avertiCoupe = false

local function couperHerbe(joueur, racine)
	local couper = ServerStorage:FindFirstChild("CutGrassArea")
	if not couper then
		if not avertiCoupe then
			avertiCoupe = true
			warn("[BoutiqueCiseaux] CutGrassArea introuvable : colle l'ajout CISEAUX en bas de GrassServer.")
		end
		return
	end
	-- point au sol, un peu devant le joueur
	local centre = (racine.CFrame * CFrame.new(0, -3, -3)).Position
	couper:Invoke(joueur, centre, CONFIG.RAYON_COUPE, CONFIG.MAX_PAR_COUPE)
end

---------------------------------------------------------------- Comportement de l'outil

local branches = {}

local function brancherOutil(outil)
	if not outil:IsA("Tool") or branches[outil] then return end
	branches[outil] = true
	local occupe = false
	local perso = nil

	local function tenu()
		return perso ~= nil and outil.Parent == perso
	end

	outil.Equipped:Connect(function()
		perso = outil.Parent
		bougerBras(trouverEpaule(perso), ANGLE_TENUE, 0.25)
		-- petit "clic clac" quand on sort les ciseaux
		lames(outil, true, 0.1)
		task.delay(0.12, lames, outil, false, 0.12)
	end)

	outil.Unequipped:Connect(function()
		if perso then remettreBras(trouverEpaule(perso)) end
		lames(outil, false, 0.1)
		perso = nil
	end)

	outil.Activated:Connect(function()
		if occupe or not tenu() then return end
		local humain = perso:FindFirstChildOfClass("Humanoid")
		local racine = perso:FindFirstChild("HumanoidRootPart")
		local joueur = Players:GetPlayerFromCharacter(perso)
		if not humain or humain.Health <= 0 or not racine or not joueur then return end
		occupe = true
		local epaule = trouverEpaule(perso)
		bougerBras(epaule, ANGLE_COUPE, 0.18)
		task.wait(0.18)
		for coup = 1, 3 do
			if not tenu() then break end
			lames(outil, true, 0.07)
			task.wait(0.08)
			if coup == 1 then task.spawn(couperHerbe, joueur, racine) end
			lames(outil, false, 0.07)
			task.wait(0.08)
		end
		if tenu() then bougerBras(epaule, ANGLE_TENUE, 0.2) end
		task.wait(0.2)
		occupe = false
	end)
end

CollectionService:GetInstanceAddedSignal(TAG_OUTIL):Connect(brancherOutil)
for _, outil in CollectionService:GetTagged(TAG_OUTIL) do
	brancherOutil(outil)
end

---------------------------------------------------------------- Panneau + achat

local centre = vitrine:GetBoundingBox()
local zone = Instance.new("Part")
zone.Name = "ZoneAchat"
zone.Size = Vector3.new(1, 1, 1)
zone.CFrame = centre
zone.Anchored = true
zone.CanCollide = false
zone.CanTouch = false
zone.Transparency = 1
zone.Parent = vitrine

local panneau = Instance.new("BillboardGui")
panneau.Size = UDim2.fromScale(7, 2.6) -- en studs : grossit/rétrécit avec la distance
panneau.StudsOffset = Vector3.new(0, 2.6, 0)
panneau.LightInfluence = 0
panneau.MaxDistance = 60
panneau.Parent = zone

local function texte(contenu, positionY, couleurContour)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.5)
	label.Position = UDim2.fromScale(0, positionY)
	label.BackgroundTransparency = 1
	label.Text = contenu
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(236, 243, 255)
	local contour = Instance.new("UIStroke")
	contour.Thickness = 3
	contour.LineJoinMode = Enum.LineJoinMode.Round
	contour.Color = couleurContour
	contour.Parent = label
	label.Parent = panneau
	return label
end

texte(CONFIG.NOM_AFFICHE, 0, Color3.fromRGB(25, 35, 30))
local prix = texte(string.format("$%.2f", CONFIG.PRIX), 0.5, Color3.fromRGB(15, 60, 30))
prix.TextColor3 = Color3.new(1, 1, 1)
local degrade = Instance.new("UIGradient")
degrade.Color = ColorSequence.new(Color3.fromRGB(200, 255, 200), Color3.fromRGB(40, 190, 90))
degrade.Rotation = 90
degrade.Parent = prix

local invite = Instance.new("ProximityPrompt")
invite.ActionText = "Acheter"
invite.ObjectText = string.format("%s - $%.2f", CONFIG.NOM_AFFICHE, CONFIG.PRIX)
invite.HoldDuration = 0.3
invite.MaxActivationDistance = 10
invite.RequiresLineOfSight = false
invite.Parent = zone

local function possede(joueur)
	for _, endroit in { joueur:FindFirstChildOfClass("Backpack"), joueur.Character, joueur:FindFirstChild("StarterGear") } do
		if endroit and endroit:FindFirstChild(modeleOutil.Name) then return true end
	end
	return false
end

invite.Triggered:Connect(function(joueur)
	if possede(joueur) then
		message(joueur, "Tu as déjà les ciseaux !", JAUNE)
		return
	end
	local argent = trouverArgent(joueur)
	if not argent then
		message(joueur, "Monnaie introuvable dans leaderstats", ROUGE)
		return
	end
	local solde = tonumber(argent.Value) or 0
	if solde < CONFIG.PRIX then
		message(joueur, string.format("Pas assez d'argent : il te manque $%.2f", CONFIG.PRIX - solde), ROUGE)
		return
	end
	if argent:IsA("IntValue") then
		argent.Value = math.floor(solde - CONFIG.PRIX)
	else
		argent.Value = math.floor((solde - CONFIG.PRIX) * 100 + 0.5) / 100
	end
	local sac = joueur:FindFirstChildOfClass("Backpack")
	if sac then modeleOutil:Clone().Parent = sac end
	local equipement = joueur:FindFirstChild("StarterGear")
	if equipement then modeleOutil:Clone().Parent = equipement end
	message(joueur, "Ciseaux achetés ! Équipe-les et clique pour couper l'herbe", VERT)
end)

print("[BoutiqueCiseaux] Boutique prête : " .. CONFIG.NOM_AFFICHE .. " à $" .. string.format("%.2f", CONFIG.PRIX))
