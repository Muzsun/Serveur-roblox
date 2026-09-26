-- CiseauxVue (LocalScript dans StarterPlayer > StarterPlayerScripts)
-- Vue à la 1re personne : l'outil en main (ciseaux, faucille ou débroussailleuse) suit la caméra (en bas à droite de l'écran),
-- se balance quand on tourne ou marche, les ciseaux font "clic-clac" et la faucille donne un coup à chaque coupe.
-- Vue de loin : on voit les ciseaux dans la main du personnage, comme les autres joueurs.
if not game:GetService("RunService"):IsClient() then
	warn("[Ciseaux] CiseauxVue doit être un LocalScript dans StarterPlayer > StarterPlayerScripts !")
	return
end
print("[Ciseaux] CiseauxVue démarré")

local REGLAGES = {
	POSITION = Vector3.new(1.05, -0.7, -2.9), -- place de la vis par rapport à la caméra (droite, bas, devant)
	DIRECTION = Vector3.new(-0.42, 0.7, -0.58), -- vers où pointent les lames (gauche, haut, devant)
	FACE = Vector3.new(0.2, 0.3, 1), -- le côté plat des ciseaux regarde vers la caméra
	BALANCEMENT = 1, -- 0 = les ciseaux ne bougent pas quand on tourne / marche
	FAUCILLE = {
		POSITION = Vector3.new(0.75, -1.3, -2.7), -- place du poing par rapport à la caméra (droite, bas, devant)
		MANCHE = Vector3.new(0.2, 0.85, -0.35), -- vers où pointe le manche (droite, haut, devant)
		FACE = Vector3.new(-0.15, 0, 1), -- le plat de la lame : (-0.15, 0, 1) = croissant vers la droite, (0.15, 0, -1) = vers la gauche
	},
	DEBROUSSAILLEUSE = {
		POSITION = Vector3.new(1.2, -1.25, -0.3), -- place de la poignée arrière par rapport à la caméra
		TUBE = Vector3.new(-0.27, -0.1, -0.96), -- vers où pointe le tube (gauche, bas, devant)
	},
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera

local SON_CISEAUX = "rbxassetid://9114794521" -- bruit des ciseaux (clic-clac)
local FERMETURE = math.rad(11)
local DUREE_COUPE = 0.32
local DUREE_SORTIE = 0.25

-- Repère des ciseaux devant la caméra
local axeLames = REGLAGES.DIRECTION.Unit
local axeFace = (REGLAGES.FACE - axeLames * axeLames:Dot(REGLAGES.FACE)).Unit
local REPERE = CFrame.fromMatrix(REGLAGES.POSITION, axeLames, axeFace, axeLames:Cross(axeFace))
-- Repère de la faucille : X = plat de la lame, Y = le manche (comme dans FaucilleServer)
local RF = REGLAGES.FAUCILLE
local axeManche = RF.MANCHE.Unit
local axePlat = (RF.FACE - axeManche * axeManche:Dot(RF.FACE)).Unit
local REPERE_FAUCILLE = CFrame.fromMatrix(RF.POSITION, axePlat, axeManche, axePlat:Cross(axeManche))
local DUREE_COUP_FAUCILLE = 0.42
-- Repère de la débroussailleuse : X = le tube, Y = le haut (comme dans DebroussailleuseServer)
local RD = REGLAGES.DEBROUSSAILLEUSE
local axeTube = RD.TUBE.Unit
local axeHaut = (Vector3.yAxis - axeTube * axeTube:Dot(Vector3.yAxis)).Unit
local REPERE_DEBROU = CFrame.fromMatrix(RD.POSITION, axeTube, axeHaut, axeTube:Cross(axeHaut))
local DUREE_COUP_DEBROU = 0.5

local function estCiseaux(objet)
	return objet:IsA("Tool") and (CollectionService:HasTag(objet, "OutilCiseaux") or objet.Name == "Ciseaux")
end
local function estFaucille(objet)
	return objet:IsA("Tool") and (CollectionService:HasTag(objet, "OutilFaucille") or objet.Name == "Faucille")
end
local function estDebrou(objet)
	return objet:IsA("Tool") and (CollectionService:HasTag(objet, "OutilDebroussailleuse") or objet.Name == "Debroussailleuse")
end
local function estOutilVue(objet) return estCiseaux(objet) or estFaucille(objet) or estDebrou(objet) end

---------------------------------------------------------------- État

local outil = nil -- les ciseaux tenus en main
local vue = nil -- copie locale affichée devant la caméra
local vueHandle, vueDecalage, vueMoteurs = nil, nil, {}
local faucille = false -- l'outil en main est la faucille (ou la débroussailleuse : pas de clic-clac)
local debrou = false -- l'outil en main est la débroussailleuse
local vueTrainee = nil
local outilCache = false
local debutCoupe, debutClac, debutSortie = -math.huge, -math.huge, -math.huge
local balancement = CFrame.identity
local derniereRotation = camera.CFrame.Rotation
local pas, amplitudePas = 0, 0

local function cacherOutil(cacher)
	if not outil or outilCache == cacher then return end
	outilCache = cacher
	for _, p in outil:GetDescendants() do
		if p:IsA("BasePart") then p.LocalTransparencyModifier = if cacher then 1 else 0 end
	end
end

local function detruireVue()
	if vue then vue:Destroy() end
	vue, vueHandle, vueDecalage, vueMoteurs, vueTrainee = nil, nil, nil, {}, nil
end

local function creerVue()
	detruireVue()
	local copie = outil:Clone()
	local modele = Instance.new("Model")
	modele.Name = "CiseauxVue"
	for _, enfant in copie:GetChildren() do enfant.Parent = modele end
	copie:Destroy()
	vueHandle = modele:FindFirstChild("Handle")
	-- point de repère : la vis des ciseaux, ou le poing (Handle) de la faucille
	local fente = if faucille then vueHandle else modele:FindFirstChild("Fente", true)
	if vueHandle and faucille then
		-- la tête de la débroussailleuse reste sur son moteur (BoutiqueClient la fait tourner)
		for _, d in modele:GetDescendants() do
			if d:IsA("Motor6D") and d.Name == "TeteMoteur" then d.Transform = CFrame.identity end
		end
	end
	if not vueHandle or not fente then modele:Destroy() return end
	vueTrainee = modele:FindFirstChild("Trainee", true)
	for _, d in modele:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.LocalTransparencyModifier = 0
		elseif d:IsA("Motor6D") and d:GetAttribute("C0Origine") then
			d.C0 = d:GetAttribute("C0Origine")
			table.insert(vueMoteurs, d)
		end
	end
	vueHandle.Anchored = true
	vueDecalage = fente.CFrame:ToObjectSpace(vueHandle.CFrame) -- poignée par rapport à la vis
	vue = modele
	vue.Parent = camera
	debutSortie = os.clock()
end

local son = Instance.new("Sound")
son.Name = "BruitCiseaux"
son.SoundId = SON_CISEAUX
son.Parent = game:GetService("SoundService")
local function bruitCiseaux(volume)
	son.Volume = volume
	son.PlaybackSpeed = 0.95 + math.random() * 0.1
	son.TimePosition = 0
	son:Play()
end


-- délai entre 2 coupes (le même que pour couper une herbe, réduit par la Dextérité)
local okCfg, CFG_HERBE = pcall(function() return require(game:GetService("ReplicatedStorage"):WaitForChild("GrassConfig", 10)) end)
if not okCfg or type(CFG_HERBE) ~= "table" then CFG_HERBE = {} end
local function delaiCoupe(qui)
	local nom = if debrou then "Upg_DRapidite" elseif faucille then "Upg_FRapidite" else "Upg_Dexterite"
	local dex = qui and qui:GetAttribute(nom) or 0 -- faucille / débroussailleuse : Rapidité, ciseaux : Dextérité
	return math.max(0.2, (CFG_HERBE.PICK_COOLDOWN or 0.9) * (1 - (CFG_HERBE.DEX_PAR_NIVEAU or 0.08) * dex))
end
local function coupe()
	local maintenant = os.clock()
	-- pas de spam : on attend que le délai pour couper une herbe soit passé
	if maintenant - debutCoupe < math.max(DUREE_COUPE * 0.8, delaiCoupe(joueur) * 0.85) then return end
	debutCoupe, debutClac = maintenant, maintenant
	if not faucille then bruitCiseaux(0.7) end -- la faucille a son propre "swoosh" (FaucilleServer)
	-- débroussailleuse : le moteur accélère tout de suite chez nous (BoutiqueClient)
	if debrou and outil then outil:SetAttribute("CoupeLocale", maintenant) end
end

---------------------------------------------------------------- Ciseaux en main ou pas

local branches = setmetatable({}, { __mode = "k" })
local function surOutil(nouvel)
	if outil == nouvel then return end
	cacherOutil(false)
	detruireVue()
	outil, outilCache = nouvel, false
	debrou = outil ~= nil and estDebrou(outil)
	faucille = outil ~= nil and (estFaucille(outil) or debrou)
	if outil then
		debutClac = os.clock()
		if not faucille then bruitCiseaux(0.4) end -- petit clic-clac quand on sort les ciseaux
		if not branches[outil] then
			branches[outil] = true
			outil.Activated:Connect(function()
				if outil == nouvel then coupe() end
			end)
		end
	end
end

local function surPersonnage(perso)
	surOutil(nil)
	for _, enfant in perso:GetChildren() do
		if estOutilVue(enfant) then surOutil(enfant) end
	end
	perso.ChildAdded:Connect(function(enfant)
		if estOutilVue(enfant) then surOutil(enfant) end
	end)
	perso.ChildRemoved:Connect(function(enfant)
		if enfant == outil then surOutil(nil) end
	end)
end

if joueur.Character then surPersonnage(joueur.Character) end
joueur.CharacterAdded:Connect(surPersonnage)

-- Chaque touffe coupée par nous (aussi en restant appuyé) fait un coup de ciseaux
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("GrassRemotes", 30)
	local picked = remotes and remotes:WaitForChild("Picked", 30)
	if picked then
		picked.OnClientEvent:Connect(function(_, qui)
			if qui == joueur and outil then coupe() end
		end)
	end
end)

---------------------------------------------------------------- Chaque image

local function adoucir(a) return 1 - (1 - a) ^ 2 end

RunService:BindToRenderStep("CiseauxVue", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local perso = joueur.Character
	local tete = perso and perso:FindFirstChild("Head")
	local humain = perso and perso:FindFirstChildOfClass("Humanoid")
	local premierePersonne = tete ~= nil and (camera.CFrame.Position - tete.Position).Magnitude < 1.5

	if not (outil and outil.Parent == perso and premierePersonne and humain and humain.Health > 0) then
		cacherOutil(false)
		detruireVue()
		derniereRotation = camera.CFrame.Rotation
		return
	end
	if not vue then creerVue() end
	if not vue then return end
	cacherOutil(true)

	local maintenant = os.clock()
	local force = REGLAGES.BALANCEMENT

	-- balancement : les ciseaux traînent un peu derrière la caméra quand on tourne
	local rotation = camera.CFrame.Rotation
	local rx, ry = derniereRotation:ToObjectSpace(rotation):ToEulerAnglesYXZ()
	derniereRotation = rotation
	local cible = CFrame.Angles(math.clamp(-rx * 3, -0.15, 0.15) * force, math.clamp(-ry * 3, -0.2, 0.2) * force, 0)
	balancement = balancement:Lerp(cible, math.min(dt * 12, 1))

	-- petit mouvement de marche
	local marche = humain.MoveDirection.Magnitude > 0.1 and humain.FloorMaterial ~= Enum.Material.Air
	amplitudePas += ((if marche then 1 else 0) - amplitudePas) * math.min(dt * 8, 1)
	pas += dt * humain.WalkSpeed * 0.55
	local balade = CFrame.new(math.sin(pas) * 0.05 * amplitudePas * force, -math.abs(math.cos(pas)) * 0.06 * amplitudePas * force, 0)

	-- sortie des ciseaux : ils montent du bas de l'écran
	local s = 1 - adoucir(math.clamp((maintenant - debutSortie) / DUREE_SORTIE, 0, 1))
	-- coup de ciseaux : on plonge vers l'herbe puis on revient
	local c = math.clamp((maintenant - debutCoupe) / DUREE_COUPE, 0, 1)
	local k = if c < 1 then math.sin(c * math.pi) else 0
	local decalage = Vector3.new(-0.15 * k, -1.2 * s - 0.25 * k, -0.3 * k)
	local inclinaison = CFrame.Angles(-0.5 * s - 0.45 * k, 0, 0.12 * k) -- tourne autour de la vis

	if debrou then
		-- débroussailleuse : on arme à droite, on fauche en arc vers la gauche (tête au ras de l'herbe), on revient
		local d = math.clamp((maintenant - debutCoupe) / DUREE_COUP_DEBROU, 0, 1)
		local lacet, plonge = 0, 0
		if d < 1 then
			if d < 0.22 then
				local a = adoucir(d / 0.22)
				lacet, plonge = -0.38 * a, 0.2 * a
			elseif d < 0.72 then
				local a = (d - 0.22) / 0.5
				a = a * a * (3 - 2 * a) -- régulier au milieu du coup
				lacet, plonge = -0.38 + 0.8 * a, 0.2 + 0.8 * math.sin(a * math.pi)
			else
				local a = adoucir((d - 0.72) / 0.28)
				lacet, plonge = 0.42 * (1 - a), 0.2 * (1 - a)
			end
		end
		-- vibrations du moteur : légères au ralenti, fortes pendant la coupe
		local vib = (if d < 1 then 0.03 else 0.008) * force
		local tremble = Vector3.new((math.random() - 0.5) * vib, (math.random() - 0.5) * vib, (math.random() - 0.5) * vib)
		local poing = camera.CFrame * balade * balancement
			* CFrame.new(REPERE_DEBROU.Position + tremble + Vector3.new(0.12 * lacet, -1.2 * s - 0.18 * plonge, -0.1 * plonge))
			* CFrame.Angles(-0.5 * s - 0.1 * plonge, lacet, -0.12 * lacet) * REPERE_DEBROU.Rotation
		vueHandle.CFrame = poing * vueDecalage
		return
	end
	if faucille then
		-- coup de faucille : on arme vers la droite, on balaie vers le bas à gauche, puis on revient
		local d = math.clamp((maintenant - debutCoupe) / DUREE_COUP_FAUCILLE, 0, 1)
		local pos, rot = Vector3.zero, Vector3.zero -- rot = (tangage, lacet, roulis)
		local ARME_P, ARME_R = Vector3.new(0.35, 0.25, 0.1), Vector3.new(0.25, -0.35, -0.35)
		local FRAPPE_P, FRAPPE_R = Vector3.new(-1.45, -0.55, -0.35), Vector3.new(-0.55, 0.55, 0.95)
		if d < 1 then
			if d < 0.22 then
				local a = adoucir(d / 0.22)
				pos, rot = ARME_P * a, ARME_R * a
			elseif d < 0.5 then
				local a = ((d - 0.22) / 0.28) ^ 1.6 -- de plus en plus vite
				pos, rot = ARME_P:Lerp(FRAPPE_P, a), ARME_R:Lerp(FRAPPE_R, a)
			else
				local a = adoucir((d - 0.5) / 0.5)
				pos, rot = FRAPPE_P:Lerp(Vector3.zero, a), FRAPPE_R:Lerp(Vector3.zero, a)
			end
		end
		if vueTrainee then vueTrainee.Enabled = d > 0.2 and d < 0.55 end
		local poing = camera.CFrame * balade * balancement
			* CFrame.new(REPERE_FAUCILLE.Position + pos + Vector3.new(0, -1.2 * s, 0))
			* CFrame.Angles(rot.X - 0.5 * s, rot.Y, rot.Z) * REPERE_FAUCILLE.Rotation
		vueHandle.CFrame = poing * vueDecalage
		return
	end
	local fente = camera.CFrame * balade * balancement * CFrame.new(REPERE.Position + decalage) * inclinaison * REPERE.Rotation
	vueHandle.CFrame = fente * vueDecalage

	-- lames : deux "clic-clac" pendant la coupe et quand on sort les ciseaux
	local t = (maintenant - debutClac) / DUREE_COUPE
	local fermeture = if t >= 0 and t < 1 then (1 - math.cos(t * 4 * math.pi)) / 2 else 0
	for _, moteur in vueMoteurs do
		moteur.C0 = moteur:GetAttribute("C0Origine") * CFrame.Angles(0, FERMETURE * fermeture * moteur:GetAttribute("Sens"), 0)
	end
end)
