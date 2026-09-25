-- BoutiqueCiseaux : panneau d'achat + outil ciseaux (tenue, animation de coupe, coupe de l'herbe)
-- À mettre dans un Script dans ServerScriptService.
-- Il faut que les ciseaux posés sur l'étagère s'appellent "Ciseaux" dans le Workspace.

local CONFIG = {
	PRIX = 7.99,
	MONNAIE = "Argent", -- nom de ta monnaie dans le leaderboard (ex : "Cash", "Money")
	CREER_MONNAIE = true, -- crée la monnaie si ton jeu n'en a pas encore
	ARGENT_DE_DEPART = 100,
	NOM_AFFICHE = "Ciseaux de jardin",
	VITRINE = "Ciseaux", -- le modèle posé sur l'étagère
	RAYON_COUPE = 5, -- distance de coupe devant le joueur (studs)
	REPOUSSE = 15, -- secondes avant que l'herbe repousse
	GAIN_PAR_HERBE = 0, -- argent gagné par herbe coupée (0 = rien)
	TOURNER_EN_MAIN = 0, -- degrés : tourne les ciseaux dans la main si besoin
}

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local TAG_OUTIL = "OutilCiseaux"
local TAG_HERBE = "Herbe"
local NOMS_HERBE = { Herbe = true, Grass = true }
local ANGLE_TENUE = math.rad(-15) -- bras légèrement baissé quand on tient les ciseaux
local ANGLE_COUPE = math.rad(-55) -- bras baissé vers le sol pendant la coupe
local FERMETURE = math.rad(11) -- rotation de chaque lame pour fermer les ciseaux

local VERT = Color3.fromRGB(120, 230, 120)
local ROUGE = Color3.fromRGB(255, 110, 110)
local JAUNE = Color3.fromRGB(255, 220, 110)

---------------------------------------------------------------- Monnaie

local function trouverArgent(joueur)
	local stats = joueur:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild(CONFIG.MONNAIE)
end

local function preparerJoueur(joueur)
	local stats = joueur:WaitForChild("leaderstats", 3)
	if not stats and CONFIG.CREER_MONNAIE then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = joueur
	end
	if stats and not stats:FindFirstChild(CONFIG.MONNAIE) then
		if CONFIG.CREER_MONNAIE then
			local argent = Instance.new("NumberValue")
			argent.Name = CONFIG.MONNAIE
			argent.Value = CONFIG.ARGENT_DE_DEPART
			argent.Parent = stats
		else
			warn("[BoutiqueCiseaux] Monnaie \"" .. CONFIG.MONNAIE .. "\" introuvable dans leaderstats de " .. joueur.Name)
		end
	end
end

Players.PlayerAdded:Connect(preparerJoueur)
for _, joueur in Players:GetPlayers() do
	task.spawn(preparerJoueur, joueur)
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

---------------------------------------------------------------- Coupe de l'herbe

local function effetHerbe(position)
	local point = Instance.new("Attachment")
	point.Parent = workspace.Terrain
	point.WorldPosition = position
	local brins = Instance.new("ParticleEmitter")
	brins.Color = ColorSequence.new(Color3.fromRGB(110, 210, 90), Color3.fromRGB(45, 140, 50))
	brins.Size = NumberSequence.new(0.25, 0.05)
	brins.Lifetime = NumberRange.new(0.5, 0.9)
	brins.Speed = NumberRange.new(5, 9)
	brins.SpreadAngle = Vector2.new(50, 50)
	brins.Acceleration = Vector3.new(0, -25, 0)
	brins.RotSpeed = NumberRange.new(-180, 180)
	brins.Rate = 0
	brins.Parent = point
	brins:Emit(18)
	Debris:AddItem(point, 1.5)
end

local function estHerbe(objet)
	return CollectionService:HasTag(objet, TAG_HERBE) or NOMS_HERBE[objet.Name] == true
end

local function cibleHerbe(p)
	if estHerbe(p) then return p end
	local modele = p:FindFirstAncestorWhichIsA("Model")
	if modele and estHerbe(modele) then return modele end
	return nil
end

local function couperHerbe(joueur, perso, racine)
	local centre = (racine.CFrame * CFrame.new(0, -2.5, -3.5)).Position
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { perso }
	local faites = {}
	for _, p in workspace:GetPartBoundsInRadius(centre, CONFIG.RAYON_COUPE, params) do
		local herbe = cibleHerbe(p)
		if herbe and not faites[herbe] and not herbe:GetAttribute("Coupee") then
			faites[herbe] = true
			herbe:SetAttribute("Coupee", true)
			local pieces = {}
			if herbe:IsA("BasePart") then
				table.insert(pieces, herbe)
			else
				for _, d in herbe:GetDescendants() do
					if d:IsA("BasePart") then table.insert(pieces, d) end
				end
			end
			local avant = {}
			for _, bp in pieces do
				avant[bp] = { bp.Transparency, bp.CanCollide }
				bp.CanCollide = false
				TweenService:Create(bp, TweenInfo.new(0.25), { Transparency = 1 }):Play()
			end
			effetHerbe(if herbe:IsA("Model") then herbe:GetPivot().Position else herbe.Position)
			local argent = trouverArgent(joueur)
			if argent and CONFIG.GAIN_PAR_HERBE ~= 0 then
				argent.Value = math.round((argent.Value + CONFIG.GAIN_PAR_HERBE) * 100) / 100
			end
			task.delay(CONFIG.REPOUSSE, function()
				for bp, valeurs in avant do
					if bp.Parent then
						bp.CanCollide = valeurs[2]
						TweenService:Create(bp, TweenInfo.new(1), { Transparency = valeurs[1] }):Play()
					end
				end
				herbe:SetAttribute("Coupee", nil)
			end)
		end
	end
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
			if coup == 1 then couperHerbe(joueur, perso, racine) end
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
		message(joueur, "Monnaie \"" .. CONFIG.MONNAIE .. "\" introuvable", ROUGE)
		return
	end
	if argent.Value < CONFIG.PRIX then
		message(joueur, string.format("Pas assez d'argent : il te manque $%.2f", CONFIG.PRIX - argent.Value), ROUGE)
		return
	end
	argent.Value = math.round((argent.Value - CONFIG.PRIX) * 100) / 100
	local sac = joueur:FindFirstChildOfClass("Backpack")
	if sac then modeleOutil:Clone().Parent = sac end
	local equipement = joueur:FindFirstChild("StarterGear")
	if equipement then modeleOutil:Clone().Parent = equipement end
	message(joueur, "Ciseaux achetés ! Équipe-les et clique pour couper l'herbe", VERT)
end)

print("[BoutiqueCiseaux] Boutique prête : " .. CONFIG.NOM_AFFICHE .. " à $" .. string.format("%.2f", CONFIG.PRIX))
