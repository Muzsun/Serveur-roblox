-- CiseauxVue (LocalScript dans StarterPlayer > StarterPlayerScripts)
-- Vue à la 1re personne : les ciseaux suivent la caméra (en bas à droite de l'écran),
-- se balancent quand on tourne ou marche, et font "clic-clac" à chaque coupe.
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

local function estCiseaux(objet)
	return objet:IsA("Tool") and (CollectionService:HasTag(objet, "OutilCiseaux") or objet.Name == "Ciseaux")
end

---------------------------------------------------------------- État

local outil = nil -- les ciseaux tenus en main
local vue = nil -- copie locale affichée devant la caméra
local vueHandle, vueDecalage, vueMoteurs = nil, nil, {}
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
	vue, vueHandle, vueDecalage, vueMoteurs = nil, nil, nil, {}
end

local function creerVue()
	detruireVue()
	local copie = outil:Clone()
	local modele = Instance.new("Model")
	modele.Name = "CiseauxVue"
	for _, enfant in copie:GetChildren() do enfant.Parent = modele end
	copie:Destroy()
	vueHandle = modele:FindFirstChild("Handle")
	local fente = modele:FindFirstChild("Fente", true)
	if not vueHandle or not fente then modele:Destroy() return end
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

local function coupe()
	local maintenant = os.clock()
	if maintenant - debutCoupe < DUREE_COUPE * 0.8 then return end
	debutCoupe, debutClac = maintenant, maintenant
	bruitCiseaux(0.7)
end

---------------------------------------------------------------- Ciseaux en main ou pas

local branches = setmetatable({}, { __mode = "k" })
local function surOutil(nouvel)
	if outil == nouvel then return end
	cacherOutil(false)
	detruireVue()
	outil, outilCache = nouvel, false
	if outil then
		debutClac = os.clock()
		bruitCiseaux(0.4) -- petit clic-clac quand on sort les ciseaux
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
		if estCiseaux(enfant) then surOutil(enfant) end
	end
	perso.ChildAdded:Connect(function(enfant)
		if estCiseaux(enfant) then surOutil(enfant) end
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

	local fente = camera.CFrame * balade * balancement * CFrame.new(REPERE.Position + decalage) * inclinaison * REPERE.Rotation
	vueHandle.CFrame = fente * vueDecalage

	-- lames : deux "clic-clac" pendant la coupe et quand on sort les ciseaux
	local t = (maintenant - debutClac) / DUREE_COUPE
	local fermeture = if t >= 0 and t < 1 then (1 - math.cos(t * 4 * math.pi)) / 2 else 0
	for _, moteur in vueMoteurs do
		moteur.C0 = moteur:GetAttribute("C0Origine") * CFrame.Angles(0, FERMETURE * fermeture * moteur:GetAttribute("Sens"), 0)
	end
end)
