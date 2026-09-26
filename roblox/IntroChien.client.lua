-- IntroChien (LocalScript dans StarterPlayer > StarterPlayerScripts)
-- Cinématique d'intro : le chiot projette sa balle beaucoup trop loin... jusqu'à la dernière zone !
-- Ensuite il suit le joueur, et une colonne de lumière montre où est tombée la balle.
-- FIN : quand toute l'herbe est coupée, "Va chercher la balle !" -> on la ramasse -> cinématique
-- avec le chiot (il attrape la balle en plein vol) -> "BRAVO !" -> écran des statistiques.
if not game:GetService("RunService"):IsClient() then
	warn("[Intro] IntroChien doit être un LocalScript dans StarterPlayer > StarterPlayerScripts !")
	return
end

local REGLAGES = {
	TITRE = "RETROUVE LA BALLE !",
	SOUS_TITRE = "Coupe l'herbe pour ouvrir les zones",
	-- Où tombe la balle : un repère "PointBalle" dans le Workspace (le plus précis),
	-- sinon la zone nommée ici, sinon la zone la plus loin du départ.
	DERNIERE_ZONE = "",
	CHIEN_SUIT_LE_JOUEUR = true,
	CHIENS_DES_AUTRES = true, -- on voit aussi le chiot des autres joueurs
	SONS = {
		lancer = "rbxasset://sounds/swordlunge.wav", -- le "whoosh" de la balle
		rebond = "rbxasset://sounds/action_jump.mp3", -- le coup de tête
		atterrir = "rbxasset://sounds/action_jump_land.mp3",
		pop = "rbxassetid://129348077985519", -- le "?" et le titre
		aboiement = "", -- mets un son d'aboiement ici si tu en as un : "rbxassetid://..."
		victoire = "", -- musique / son de victoire pour la fin (optionnel) : "rbxassetid://..."
	},
}

local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local TS = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera
local pgui = lp:WaitForChild("PlayerGui")
lp:SetAttribute("IntroEnCours", true)

local UP = Vector3.new(0, 1, 0)
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(20, 22, 26)

--[[CHIEN_DEBUT]]
---------------------------------------------------------------- Le chiot (construit en pièces)
local FUR = Color3.fromRGB(232, 150, 72)
local CREAM = Color3.fromRGB(252, 240, 218)
local DARK = Color3.fromRGB(46, 34, 30)
local PINK = Color3.fromRGB(255, 150, 162)
local RED = Color3.fromRGB(222, 48, 58)
local GOLDC = Color3.fromRGB(252, 200, 64)
local EYE = Color3.fromRGB(22, 20, 26)

local function R(x, y, z) return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0)) end

local function construireChien()
	local model = Instance.new("Model")
	model.Name = "Chiot"
	local rig = {} -- { part, joint, offset }
	local function piece(joint, nom, taille, offset, couleur, forme, classe)
		local p = Instance.new(classe or "Part")
		p.Name = nom
		if forme then p.Shape = forme end
		p.Size = taille
		p.Color = couleur
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		table.insert(rig, { part = p, joint = joint, offset = offset })
		return p
	end
	local V = Vector3.new
	local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
	-- corps (forme de gélule) + poitrail crème
	piece("root", "Corps", V(1.5, 1.3, 1.3), CFrame.new(0, 1.15, 0.1) * R(0, 90, 0), FUR, CYL)
	piece("root", "Poitrine", V(1.3, 1.3, 1.3), CFrame.new(0, 1.15, -0.65), FUR, BALL)
	piece("root", "Fesses", V(1.3, 1.3, 1.3), CFrame.new(0, 1.15, 0.85), FUR, BALL)
	piece("root", "Poitrail", V(1.0, 1.0, 1.0), CFrame.new(0, 1.0, -0.92), CREAM, BALL)
	-- collier + médaille
	piece("root", "Collier", V(0.22, 1.26, 1.26), CFrame.new(0, 1.5, -0.72) * R(0, 0, 90), RED, CYL)
	piece("root", "Medaille", V(0.06, 0.3, 0.3), CFrame.new(0, 1.3, -1.34) * R(0, 90, 0), GOLDC, CYL)
	-- pattes
	for _, h in { { "PatteAG", -0.38, -0.6 }, { "PatteAD", 0.38, -0.6 }, { "PatteArG", -0.4, 0.8 }, { "PatteArD", 0.4, 0.8 } } do
		piece(h[1], "Patte", V(0.62, 0.42, 0.42), CFrame.new(0, -0.31, 0) * R(0, 0, 90), FUR, CYL)
		piece(h[1], "Pied", V(0.5, 0.5, 0.5), CFrame.new(0, -0.6, -0.06), CREAM, BALL)
	end
	-- queue en boucle
	piece("queue", "Queue1", V(0.5, 0.5, 0.5), CFrame.new(0, 0.18, 0.12), FUR, BALL)
	piece("queue", "Queue2", V(0.45, 0.45, 0.45), CFrame.new(0, 0.45, 0.18), FUR, BALL)
	piece("queue", "Queue3", V(0.4, 0.4, 0.4), CFrame.new(0, 0.7, 0.1), FUR, BALL)
	piece("queue", "QueueBout", V(0.32, 0.32, 0.32), CFrame.new(0, 0.88, -0.02), CREAM, BALL)
	-- tête (grosse, style chiot)
	piece("cou", "Tete", V(1.5, 1.5, 1.5), CFrame.new(0, 0.45, -0.2), FUR, BALL)
	piece("cou", "Museau", V(0.8, 0.8, 0.8), CFrame.new(0, 0.18, -0.8), CREAM, BALL)
	piece("cou", "Truffe", V(0.3, 0.3, 0.3), CFrame.new(0, 0.36, -1.17), DARK, BALL)
	piece("cou", "Langue", V(0.24, 0.05, 0.22), CFrame.new(0, -0.1, -1.02) * R(-25, 0, 0), PINK)
	for s = -1, 1, 2 do
		piece("cou", "Oeil", V(0.3, 0.3, 0.3), CFrame.new(0.33 * s, 0.62, -0.82), EYE, BALL)
		piece("cou", "Reflet", V(0.1, 0.1, 0.1), CFrame.new(0.29 * s, 0.69, -0.95), WHITE, BALL)
		local joue = piece("cou", "Joue", V(0.24, 0.24, 0.24), CFrame.new(0.52 * s, 0.33, -0.72), PINK, BALL)
		joue.Transparency = 0.35
		piece(s < 0 and "sourcilG" or "sourcilD", "Sourcil", V(0.3, 0.07, 0.07), CFrame.new(), DARK)
		local oreille = s < 0 and "oreilleG" or "oreilleD"
		-- oreille triangulaire (2 coins), intérieur rose
		piece(oreille, "Oreille", V(0.1, 0.75, 0.28), CFrame.new(0, 0.35, 0.14) * R(0, 180, 0), FUR, nil, "WedgePart")
		piece(oreille, "Oreille", V(0.1, 0.75, 0.28), CFrame.new(0, 0.35, -0.14), FUR, nil, "WedgePart")
		piece(oreille, "OreilleIn", V(0.08, 0.5, 0.18), CFrame.new(0.03, 0.3, 0.09) * R(0, 180, 0), PINK, nil, "WedgePart")
		piece(oreille, "OreilleIn", V(0.08, 0.5, 0.18), CFrame.new(0.03, 0.3, -0.09), PINK, nil, "WedgePart")
	end
	return model, rig
end

-- pose du chiot : position + expression
local function nouvellePose(cf)
	return {
		cf = cf, -- position au sol, regarde vers LookVector
		saut = 0, -- hauteur (saut / rebond)
		tangage = 0, -- corps penché avant (+) / arrière (-), en degrés
		accroupi = 0, -- 0..1 (se prépare à sauter)
		couTangage = 0, couLacet = 0, couRoulis = 0, -- tête : haut/bas, gauche/droite, penchée
		oreilles = 12, -- écartement des oreilles (12 = droites, 70 = tombantes)
		triste = 0, -- 0 = content, 1 = triste (sourcils)
		queueAmp = 35, queueVitesse = 9, queueTangage = 0,
		marche = 0, pas = 0, -- amplitude et phase de marche
		langue = 1, -- 1 = langue visible
	}
end

local function calculerChien(rig, pose, t)
	local base = pose.cf * CFrame.new(0, pose.saut - pose.accroupi * 0.25, 0) * R(-pose.tangage - pose.accroupi * 8, 0, 0)
	local cou = base * CFrame.new(0, 1.75, -0.95) * R(pose.couTangage - pose.accroupi * 18, pose.couLacet, pose.couRoulis)
	local wag = math.sin(t * pose.queueVitesse) * pose.queueAmp
	local joints = {
		root = base,
		cou = cou,
		queue = base * CFrame.new(0, 1.45, 1.35) * R(-15 + pose.queueTangage, wag, 0),
		oreilleG = cou * CFrame.new(-0.45, 1.0, -0.1) * R(0, 0, pose.oreilles) * R(0, 90, 0),
		oreilleD = cou * CFrame.new(0.45, 1.0, -0.1) * R(0, 0, -pose.oreilles) * R(0, 90, 0),
		sourcilG = cou * CFrame.new(-0.33, 0.9 + 0.03 * (1 - pose.triste), -0.72) * R(0, 0, 30 * pose.triste),
		sourcilD = cou * CFrame.new(0.33, 0.9 + 0.03 * (1 - pose.triste), -0.72) * R(0, 0, -30 * pose.triste),
	}
	local swing = math.sin(pose.pas) * 35 * pose.marche
	joints.PatteAG = base * CFrame.new(-0.38, 0.8, -0.6) * R(swing, 0, 0)
	joints.PatteArD = base * CFrame.new(0.4, 0.8, 0.8) * R(swing, 0, 0)
	joints.PatteAD = base * CFrame.new(0.38, 0.8, -0.6) * R(-swing, 0, 0)
	joints.PatteArG = base * CFrame.new(-0.4, 0.8, 0.8) * R(-swing, 0, 0)
	local parts, cfs = {}, {}
	for i, e in rig do
		parts[i] = e.part
		cfs[i] = joints[e.joint] * e.offset
		local nom = e.part.Name
		if nom == "Langue" then e.part.Transparency = 1 - pose.langue
		elseif nom == "Oeil" then local d = 0.3 + 0.05 * pose.triste e.part.Size = Vector3.new(d, d, d) -- yeux de chiot
		elseif nom == "Reflet" then local d = 0.1 + 0.05 * pose.triste e.part.Size = Vector3.new(d, d, d) end
	end
	return parts, cfs, cou
end

-- balle rouge avec une bande blanche
local function construireBalle()
	local m = Instance.new("Model")
	m.Name = "BalleDuChien"
	local b = Instance.new("Part")
	b.Name = "Balle"
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.new(0.75, 0.75, 0.75)
	b.Color = Color3.fromRGB(235, 58, 58)
	b.Material = Enum.Material.SmoothPlastic
	b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch = true, false, false, false
	b.Parent = m
	local band = Instance.new("Part")
	band.Name = "Bande"
	band.Shape = Enum.PartType.Cylinder
	band.Size = Vector3.new(0.14, 0.77, 0.77)
	band.Color = WHITE
	band.Material = Enum.Material.SmoothPlastic
	band.Anchored, band.CanCollide, band.CanQuery, band.CanTouch = true, false, false, false
	band.Parent = m
	return m, b, band
end
--[[CHIEN_FIN]]

---------------------------------------------------------------- Les chiots des autres joueurs
-- Chaque joueur a son chiot qui le suit : on dessine ici ceux des AUTRES joueurs
-- (le tien est géré plus bas, avec la cinématique).
if REGLAGES.CHIENS_DES_AUTRES then
	local dossierAutres = Instance.new("Folder")
	dossierAutres.Name = "ChiotsDesAutres"
	dossierAutres.Parent = workspace
	local autres = {} -- [joueur] = { model, rig, pose, piste, marque, bloque, t, perso }
	local paramsA = RaycastParams.new()
	paramsA.FilterType = Enum.RaycastFilterType.Exclude
	local function majFiltre()
		local l = { dossierAutres }
		for _, n in { "GrassHit", "GrassFX", "GrassVisuals", "Chiot", "BalleDuChien" } do
			local f = workspace:FindFirstChild(n)
			if f then table.insert(l, f) end
		end
		for _, p in Players:GetPlayers() do
			if p.Character then table.insert(l, p.Character) end
		end
		paramsA.FilterDescendantsInstances = l
	end
	-- rayon qui ignore les pièces invisibles et celles qu'on traverse (CanCollide désactivé)
	local function rayonA(origine, direction)
		local liste = paramsA.FilterDescendantsInstances
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		for _ = 1, 8 do
			params.FilterDescendantsInstances = liste
			local hit = workspace:Raycast(origine, direction, params)
			if not hit then return nil end
			local inst = hit.Instance
			if inst:IsA("BasePart") and (inst.Transparency >= 0.9 or not inst.CanCollide) then
				liste = table.clone(liste)
				table.insert(liste, inst)
			else
				return hit
			end
		end
		return nil
	end
	local function solA(p, depuisY)
		local hit = rayonA(Vector3.new(p.X, depuisY, p.Z), -UP * 60)
		return hit and hit.Position or nil
	end
	local function plat(v) return Vector3.new(v.X, 0, v.Z) end

	local function retirer(joueur)
		local a = autres[joueur]
		if a then a.model:Destroy() autres[joueur] = nil end
	end
	local function placerPres(a, r)
		local derriere = (r.CFrame * CFrame.new(2.5, 0, 3.5)).Position
		local p = solA(derriere, r.Position.Y + 2) or (r.Position - UP * 3)
		local dir = plat(r.CFrame.LookVector)
		a.pose.cf = CFrame.lookAt(p, p + (dir.Magnitude > 0.01 and dir.Unit or Vector3.new(0, 0, -1)))
		a.piste, a.marque, a.bloque = {}, nil, 0
	end
	local function ajouter(joueur)
		if joueur == lp or autres[joueur] then return end
		local model, rig = construireChien()
		model.Name = "Chiot_" .. joueur.Name
		local a = { model = model, rig = rig, pose = nouvellePose(CFrame.new(0, -500, 0)), piste = {}, bloque = 0, t = math.random() * 10 }
		a.pose.langue = 1
		autres[joueur] = a
	end
	majFiltre()
	for _, j in Players:GetPlayers() do ajouter(j) end
	Players.PlayerAdded:Connect(ajouter)
	Players.PlayerRemoving:Connect(retirer)

	local acc = 0
	Run.Heartbeat:Connect(function(dt)
		acc += dt
		if acc > 1 then acc = 0 majFiltre() end
		local camPos = cam.CFrame.Position
		local parts, cfs = {}, {}
		for joueur, a in autres do
			local c = joueur.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			local h = c and c:FindFirstChildOfClass("Humanoid")
			-- trop loin de nous (ou pas de personnage) : on ne l'affiche pas, ça évite le lag
			if not r or not h or h.Health <= 0 or (r.Position - camPos).Magnitude > 220 then
				if a.model.Parent then a.model.Parent = nil end
				a.perso = nil
				continue
			end
			if a.perso ~= c or not a.model.Parent then
				a.perso = c
				placerPres(a, r)
				a.model.Parent = dossierAutres
			end
			local pose = a.pose
			-- il retient le chemin de son maître (pour ne pas traverser les murs)
			if not a.marque or plat(r.Position - a.marque).Magnitude > 1.5 then
				table.insert(a.piste, r.Position)
				a.marque = r.Position
				if #a.piste > 80 then table.remove(a.piste, 1) end
			end
			local cur = pose.cf.Position
			local dist = plat(r.Position - cur).Magnitude
			if dist > 50 then placerPres(a, r) cur = pose.cf.Position dist = plat(r.Position - cur).Magnitude end
			local cible
			if dist > 4.5 then
				local bas, haut = cur + UP * 0.7, cur + UP * 1.8
				if not rayonA(bas, r.Position - UP * 1.5 - bas) and not rayonA(haut, r.Position - haut) then
					cible = r.Position
					a.piste = { r.Position }
				else
					while a.piste[1] and plat(a.piste[1] - cur).Magnitude < 1.2 do table.remove(a.piste, 1) end
					cible = a.piste[1]
				end
			else
				a.piste = { r.Position }
			end
			local vitesse = 0
			local dir = pose.cf.LookVector
			if cible then
				local vec = plat(cible - cur)
				if vec.Magnitude > 0.05 then
					vitesse = math.clamp(dist * 2.2, 8, 26)
					cur += vec.Unit * math.min(vitesse * dt, vec.Magnitude)
					dir = dir:Lerp(vec.Unit, math.min(dt * 10, 1))
				end
				a.bloque = 0
			elseif dist > 8 then
				a.bloque += dt
				if a.bloque > 1.5 then placerPres(a, r) cur = pose.cf.Position end
			else
				local vers = plat(r.Position - cur)
				if vers.Magnitude > 0.1 then dir = dir:Lerp(vers.Unit, math.min(dt * 3, 1)) end
			end
			local p = solA(cur, r.Position.Y + 2) or cur
			local y = pose.cf.Position.Y + (p.Y - pose.cf.Position.Y) * math.min(dt * 12, 1)
			local pos = Vector3.new(cur.X, y, cur.Z)
			local d = plat(dir)
			pose.cf = CFrame.lookAt(pos, pos + (d.Magnitude > 0.01 and d.Unit or Vector3.new(0, 0, -1)))
			pose.marche += ((vitesse > 0 and 1 or 0) - pose.marche) * math.min(dt * 8, 1)
			pose.pas += dt * (6 + vitesse * 0.5)
			pose.saut = math.abs(math.sin(pose.pas)) * 0.15 * pose.marche
			a.t += dt
			local ps, cs = calculerChien(a.rig, pose, a.t)
			table.move(ps, 1, #ps, #parts + 1, parts)
			table.move(cs, 1, #cs, #cfs + 1, cfs)
		end
		if #parts > 0 then workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
	end)
end

---------------------------------------------------------------- Préparation
local character = lp.Character or lp.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart", 10)
local humanoid = character:WaitForChild("Humanoid", 10)
local head = character:WaitForChild("Head", 10)
if not (hrp and humanoid and head) then lp:SetAttribute("IntroEnCours", false) return end
task.wait(1) -- laisse le monde et l'herbe apparaître

-- zones d'herbe
local function trouverZones()
	local folderName = "ZonesHerbe"
	local cfgModule = RS:FindFirstChild("GrassConfig")
	if cfgModule then
		local ok, cfg = pcall(require, cfgModule)
		if ok and type(cfg) == "table" and cfg.ZONES_FOLDER then folderName = cfg.ZONES_FOLDER end
	end
	local list = {}
	local zf = workspace:FindFirstChild(folderName)
	if zf then for _, z in zf:GetDescendants() do if z:IsA("BasePart") then table.insert(list, z) end end end
	if #list == 0 then
		for _, z in workspace:GetDescendants() do
			if z:IsA("BasePart") and z.Name:sub(1, 4) == "Zone" then table.insert(list, z) end
		end
	end
	return list
end
local zones = trouverZones()
local depart = hrp.Position

local cible = nil
for _, z in zones do if REGLAGES.DERNIERE_ZONE ~= "" and z.Name == REGLAGES.DERNIERE_ZONE then cible = z end end
if not cible then
	local best = -1
	for _, z in zones do
		local d = (Vector3.new(z.Position.X, 0, z.Position.Z) - Vector3.new(depart.X, 0, depart.Z)).Magnitude
		if d > best then cible, best = z, d end
	end
end

-- repère posé à la main dans Studio : la balle tombe exactement dessus
local repere = workspace:FindFirstChild("PointBalle", true)
if repere and repere:IsA("BasePart") then
	repere.Transparency = 1
	repere.CanCollide = false
	repere.CanQuery = false
else
	repere = nil
end

local exclus = { character }
for _, n in { "GrassHit", "GrassFX", "GrassVisuals", "ChiotsDesAutres" } do
	local f = workspace:FindFirstChild(n)
	if f then table.insert(exclus, f) end
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function majExclus(extra)
	local l = table.clone(exclus)
	for _, e in extra or {} do table.insert(l, e) end
	rayParams.FilterDescendantsInstances = l
end
majExclus()
local function sol(p, depuisY)
	local origine = depuisY and Vector3.new(p.X, depuisY, p.Z) or (p + UP * 12)
	local hit = workspace:Raycast(origine, -UP * 60, rayParams)
	return hit and hit.Position or nil
end
-- rayon qui traverse les pièces invisibles (murs invisibles...) : seuls les vrais obstacles comptent
local function rayVisible(origine, direction)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local liste = rayParams.FilterDescendantsInstances
	for _ = 1, 8 do
		params.FilterDescendantsInstances = liste
		local hit = workspace:Raycast(origine, direction, params)
		if not hit then return nil end
		local inst = hit.Instance
		if inst and inst:IsA("BasePart") and inst.Transparency >= 0.9 then
			liste = table.clone(liste)
			table.insert(liste, inst)
		else
			return hit
		end
	end
	return nil
end
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
-- nombre de pièces visibles autour d'un point (arbres, haies, murs...)
local function encombre(centre, rayon)
	overlap.FilterDescendantsInstances = rayParams.FilterDescendantsInstances
	local n = 0
	for _, part in workspace:GetPartBoundsInRadius(centre, rayon, overlap) do
		if part.Transparency < 0.9 then n += 1 end
	end
	return n
end
-- un endroit libre pour le chiot : rien de solide autour, et visible depuis "depuis"
local function placeLibre(p, depuis)
	overlap.FilterDescendantsInstances = rayParams.FilterDescendantsInstances
	for _, part in workspace:GetPartBoundsInBox(CFrame.new(p + UP * 1.7), Vector3.new(2.4, 2.6, 3.4), overlap) do
		if part.CanCollide and part.Transparency < 0.9 then return false end
	end
	return rayVisible(depuis, (p + UP * 1.5) - depuis) == nil
end

local function dansUneZone(p)
	for _, z in zones do
		local rel = z.CFrame:PointToObjectSpace(p)
		if math.abs(rel.X) <= z.Size.X / 2 and math.abs(rel.Z) <= z.Size.Z / 2 then return true end
	end
	return false
end

-- point d'atterrissage de la balle
local atterrissage
if cible then
	local top = cible.Position + UP * (cible.Size.Y / 2 + 40)
	local hit = workspace:Raycast(top, -UP * (cible.Size.Y + 200), rayParams)
	atterrissage = hit and hit.Position or (cible.Position - UP * cible.Size.Y / 2)
else
	atterrissage = sol(depart + hrp.CFrame.LookVector * 80) or (depart + hrp.CFrame.LookVector * 80 - UP * 3)
end
if repere then
	local hit = workspace:Raycast(repere.Position + UP * 20, -UP * 80, rayParams)
	atterrissage = hit and hit.Position or (repere.Position - UP * repere.Size.Y / 2)
end
local vers = Vector3.new(atterrissage.X - depart.X, 0, atterrissage.Z - depart.Z)
if vers.Magnitude < 1 then vers = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z) end
vers = vers.Unit

-- place du chiot : devant le joueur, hors de l'herbe si possible
local solDepart = sol(depart) or (depart - UP * 3)
local placeChien, secours = nil, nil
for _, dist in { 6, 4.5, 7.5 } do
	for _, angle in { 0, 35, -35, 70, -70, 110, -110, 150, -150, 180 } do
		local dir = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(vers)
		local p = sol(depart + dir * dist)
		if p and math.abs(p.Y - solDepart.Y) < 3 and placeLibre(p, depart) then
			if not dansUneZone(p) then placeChien = p break end
			secours = secours or p
		end
	end
	if placeChien then break end
end
placeChien = placeChien or secours or sol(depart + vers * 6) or (solDepart + vers * 6)
local droite = vers:Cross(UP).Unit

---------------------------------------------------------------- Construction
local chienModel, rig = construireChien()
local pose = nouvellePose(CFrame.lookAt(placeChien, placeChien + vers))
chienModel.Parent = workspace
local balleModel, balle, bande = construireBalle()
balleModel.Parent = workspace
majExclus({ chienModel, balleModel })

local function sonJouer(id, volume, vitesse, position)
	if not id or id == "" then return end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = vitesse or 1
	if position then
		local a = Instance.new("Attachment")
		a.Parent = workspace.Terrain
		a.WorldPosition = position
		s.Parent = a
		game:GetService("Debris"):AddItem(a, 4)
	else
		s.Parent = pgui
		game:GetService("Debris"):AddItem(s, 4)
	end
	s:Play()
end

local balleCF = nil -- nil = dans la gueule
local balleSpin = 0
local horloge = 0
local function majChien(dt)
	horloge += dt
	local parts, cfs, cou = calculerChien(rig, pose, horloge)
	local bcf = balleCF or (cou * CFrame.new(0, -0.2, -1.45))
	bcf = bcf * CFrame.Angles(balleSpin, 0, balleSpin * 0.4)
	table.insert(parts, balle) table.insert(cfs, bcf)
	table.insert(parts, bande) table.insert(cfs, bcf * CFrame.Angles(0, 0, math.rad(30)))
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	return cou
end
local function teteChien()
	local _, _, cou = calculerChien(rig, pose, horloge)
	return (cou * CFrame.new(0, 0.45, -0.2)).Position
end

-- traînée derrière la balle
local a0 = Instance.new("Attachment") a0.Position = Vector3.new(0, 0.25, 0) a0.Parent = balle
local a1 = Instance.new("Attachment") a1.Position = Vector3.new(0, -0.25, 0) a1.Parent = balle
local trail = Instance.new("Trail")
trail.Attachment0, trail.Attachment1 = a0, a1
trail.Lifetime = 0.35
trail.LightEmission = 0.6
trail.FaceCamera = true
trail.Color = ColorSequence.new(Color3.fromRGB(255, 240, 180), WHITE)
trail.Transparency = NumberSequence.new(0.1, 1)
trail.WidthScale = NumberSequence.new(1, 0)
trail.Enabled = false
trail.Parent = balle

---------------------------------------------------------------- La balise (colonne de lumière) : reste toute la partie
local balise = Instance.new("Part")
balise.Name = "BaliseBalle"
balise.Anchored, balise.CanCollide, balise.CanQuery, balise.CanTouch = true, false, false, false
balise.Transparency = 1
balise.Size = Vector3.new(0.2, 0.2, 0.2)
balise.CFrame = CFrame.new(atterrissage)
balise.Parent = workspace
local b0 = Instance.new("Attachment") b0.Parent = balise
local b1 = Instance.new("Attachment") b1.Position = Vector3.new(0, 0.1, 0) b1.Parent = balise
local rayon = Instance.new("Beam")
rayon.Attachment0, rayon.Attachment1 = b0, b1
rayon.Width0, rayon.Width1 = 1.8, 0.5
rayon.FaceCamera = true
rayon.LightEmission = 1
rayon.LightInfluence = 0
rayon.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), WHITE)
rayon.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.7, 0.75), NumberSequenceKeypoint.new(1, 1) })
rayon.Parent = balise
local eclat = Instance.new("ParticleEmitter")
eclat.Color = ColorSequence.new(Color3.fromRGB(255, 225, 110))
eclat.LightEmission = 1 eclat.Size = NumberSequence.new(0.5, 0) eclat.Speed = NumberRange.new(1, 3)
eclat.SpreadAngle = Vector2.new(180, 180) eclat.Lifetime = NumberRange.new(0.8, 1.4) eclat.Rate = 8
eclat.Enabled = false -- s'allume quand la balle tombe
eclat.Parent = b0
local lumiere = Instance.new("PointLight")
lumiere.Color = Color3.fromRGB(255, 220, 120) lumiere.Range = 12 lumiere.Brightness = 2 lumiere.Enabled = false
lumiere.Parent = balise
local function grandirBalise(duree)
	eclat.Enabled = true
	lumiere.Enabled = true
	TS:Create(b1, TweenInfo.new(duree, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = Vector3.new(0, 70, 0) }):Play()
end
---------------------------------------------------------------- Interface de la cinématique
local gui = Instance.new("ScreenGui")
gui.Name = "IntroChien"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Parent = pgui

local function cadre(props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do f[k] = v end
	f.Parent = props.Parent or gui
	return f
end
local noir = cadre({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 20 })
local barreHaut = cadre({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.11), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 10 })
local barreBas = cadre({ AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.11), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 10 })

local passer = Instance.new("TextButton")
passer.AnchorPoint = Vector2.new(1, 1)
passer.Position = UDim2.new(1, -24, 1, -22)
passer.Size = UDim2.fromOffset(150, 44)
passer.BackgroundColor3 = Color3.fromRGB(20, 24, 22)
passer.BackgroundTransparency = 0.25
passer.Text = "PASSER  »"
passer.Font = Enum.Font.FredokaOne
passer.TextSize = 22
passer.TextColor3 = WHITE
passer.ZIndex = 30
passer.AutoButtonColor = true
passer.Parent = gui
Instance.new("UICorner", passer).CornerRadius = UDim.new(1, 0)
local ps = Instance.new("UIStroke", passer) ps.Color = WHITE ps.Transparency = 0.5 ps.Thickness = 2 ps.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
if UIS.TouchEnabled and not UIS.KeyboardEnabled then passer.Size = UDim2.fromOffset(120, 38) passer.TextSize = 18 end

-- bulle "?" au-dessus du chiot
local attTete = Instance.new("Attachment") attTete.Parent = workspace.Terrain
local bulle = Instance.new("BillboardGui")
bulle.Adornee = attTete
bulle.Size = UDim2.fromOffset(70, 70)
bulle.StudsOffsetWorldSpace = Vector3.new(0, 1.8, 0)
bulle.AlwaysOnTop = true
bulle.LightInfluence = 0
bulle.Enabled = false
bulle.Parent = pgui
local rond = cadre({ Parent = bulle, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE })
Instance.new("UICorner", rond).CornerRadius = UDim.new(1, 0)
local rs = Instance.new("UIStroke", rond) rs.Thickness = 4 rs.Color = INK
local q = Instance.new("TextLabel")
q.BackgroundTransparency = 1 q.Size = UDim2.fromScale(1, 1) q.Text = "?" q.Font = Enum.Font.LuckiestGuy
q.TextScaled = true q.TextColor3 = INK q.Parent = rond
Instance.new("UIPadding", q).PaddingTop = UDim.new(0.18, 0)
local bulleScale = Instance.new("UIScale", rond) bulleScale.Scale = 0

---------------------------------------------------------------- Mise en place (caméra, contrôles, interface)
local passe = false
passer.Activated:Connect(function() passe = true end)
local connPasser = UIS.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Return then passe = true end
end)

lp:SetAttribute("MenuOuvert", true) -- les ciseaux ne coupent pas pendant l'intro
local controles = nil
pcall(function()
	controles = require(lp:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)):GetControls()
	controles:Disable()
end)
local guisCaches = {}
for _, g in pgui:GetChildren() do
	if g:IsA("ScreenGui") and g ~= gui and g.Enabled then g.Enabled = false table.insert(guisCaches, g) end
end
local coreTypes = { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Chat, Enum.CoreGuiType.EmotesMenu, Enum.CoreGuiType.Health }
local coreAvant = {}
for _, ct in coreTypes do
	local ok, v = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, ct)
	coreAvant[ct] = ok and v
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, ct, false)
end
local fovAvant = cam.FieldOfView
cam.CameraType = Enum.CameraType.Scriptable
-- l'herbe est cachée pendant la cinématique (elle bouchait la vue sur les petits chemins)
local herbeCachee = {}
for _, n in { "GrassVisuals", "GrassFX" } do
	local f = workspace:FindFirstChild(n)
	if f then f.Parent = nil table.insert(herbeCachee, f) end
end

local flou = Instance.new("DepthOfFieldEffect")
flou.Name = "FlouIntro"
flou.FarIntensity = 0.35
flou.NearIntensity = 0
flou.InFocusRadius = 10
flou.FocusDistance = 10
flou.Parent = Lighting

-- caméra qui ne rentre pas dans les murs
local function camSure(regard, voulu)
	local d = voulu - regard
	if d.Magnitude < 0.01 then return voulu end
	local hit = rayVisible(regard, d)
	if hit then return hit.Position - d.Unit * 0.8 end
	return voulu
end
-- essaie plusieurs angles autour de "centre" et garde la vue la plus dégagée
local TOUR = { 0, 25, -25, 50, -50, 80, -80, 110, -110, 140, -140, 180 }
local DEVANT = { 0, 20, -20, 40, -40, 60, -60, 80, -80 }
local function meilleurAngle(centre, base, distance, dy, angles)
	local bestDir, bestScore = base, -math.huge
	for i, ang in angles do
		local dir = CFrame.Angles(0, math.rad(ang), 0):VectorToWorldSpace(base)
		local voulu = centre + dir * distance + UP * dy
		local d = voulu - centre
		local hit = rayVisible(centre, d)
		local libre = hit and (hit.Position - centre).Magnitude / d.Magnitude or 1
		local score = libre * 10 - encombre(voulu, 1.6) * 3 - i * 0.05
		if score > bestScore then bestDir, bestScore = dir, score end
	end
	return bestDir
end
local function aPlat(v) local f = Vector3.new(v.X, 0, v.Z) return f.Magnitude > 0.01 and f.Unit or Vector3.new(0, 0, -1) end

local function ease(a) return a < 0.5 and 2 * a * a or 1 - (-2 * a + 2) ^ 2 / 2 end -- doux au début et à la fin
local function jouer(duree, f)
	local t0 = os.clock()
	while not passe do
		local a = math.min((os.clock() - t0) / duree, 1)
		local dt = Run.RenderStepped:Wait()
		f(a, dt)
		if a >= 1 then break end
	end
end

---------------------------------------------------------------- LA CINÉMATIQUE
local sujet = placeChien + UP * 1.4
local dirA = meilleurAngle(sujet, aPlat(droite * 4.8 + vers * 2.2), 5.3, 0.6, TOUR)
local A0 = camSure(sujet, sujet + dirA * 7.7 + UP * 1.4)
local A1 = camSure(sujet, sujet + dirA * 5.3 + UP * 0.6)
local camCF = CFrame.lookAt(A0, sujet)
cam.CFrame = camCF
cam.FieldOfView = 55
majChien(0)

TS:Create(noir, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
TS:Create(barreHaut, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0, 0.11) }):Play()
TS:Create(barreBas, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0, 0.89) }):Play()

local ok, erreur = pcall(function()
	-- 1) le chiot content, balle dans la gueule... il se prépare... et hop !
	local lance = false
	jouer(2.4, function(a, dt)
		local t = a * 2.4
		cam.CFrame = CFrame.lookAt(A0:Lerp(A1, ease(a)), sujet)
		flou.FocusDistance = (cam.CFrame.Position - sujet).Magnitude
		if t < 1.2 then -- petits sauts de joie
			pose.saut = math.abs(math.sin(t * 7)) * 0.28
			pose.couRoulis = math.sin(t * 3) * 8
			pose.queueAmp, pose.queueVitesse = 38, 11
		elseif t < 1.7 then -- se prépare
			local k = (t - 1.2) / 0.5
			pose.saut = 0 pose.couRoulis = 0
			pose.accroupi = ease(k)
		elseif t < 1.95 then -- coup de tête !
			local k = (t - 1.7) / 0.25
			pose.accroupi = 1 - k
			pose.couTangage = 45 * k
			pose.saut = math.sin(k * math.pi) * 0.6
			if not lance and k > 0.55 then
				lance = true
				sonJouer(REGLAGES.SONS.rebond, 0.7, 1.3)
				-- petit éclat blanc au moment du coup de tête
				local _, _, c = calculerChien(rig, pose, horloge)
				local att = Instance.new("Attachment") att.Parent = workspace.Terrain att.WorldPosition = (c * CFrame.new(0, 0, -1.3)).Position
				local pe = Instance.new("ParticleEmitter")
				pe.Color = ColorSequence.new(WHITE) pe.LightEmission = 1 pe.Size = NumberSequence.new(0.6, 0)
				pe.Speed = NumberRange.new(6, 10) pe.SpreadAngle = Vector2.new(180, 180) pe.Lifetime = NumberRange.new(0.25, 0.4)
				pe.Rate = 0 pe.Parent = att pe:Emit(14)
				game:GetService("Debris"):AddItem(att, 1)
			end
		else
			local k = (t - 1.95) / 0.45
			pose.couTangage = 45 * (1 - k) + 20 * k
			pose.saut = 0
		end
		majChien(dt)
	end)

	-- 2) la balle s'envole... beaucoup trop loin !
	local _, _, cou = calculerChien(rig, pose, horloge)
	local p0 = (cou * CFrame.new(0, -0.2, -1.45)).Position
	local p1 = atterrissage + UP * 0.38
	local distance = (p1 - p0).Magnitude
	local hauteur = math.clamp(distance * 0.35, 25, 90)
	local function vol(u) return p0:Lerp(p1, u) + UP * (4 * hauteur * u * (1 - u)) end
	local dirVue = meilleurAngle(p1 + UP, aPlat(-vers * 8 + droite * 3), 8.5, 10, TOUR)
	local vueAtterrissage = camSure(p1 + UP, p1 + UP + dirVue * 8.5 + UP * 10)
	trail.Enabled = true
	sonJouer(REGLAGES.SONS.lancer, 0.8, 0.9)
	local camPos = cam.CFrame.Position
	local teteDepart = teteChien()
	jouer(2.0, function(a, dt)
		local bp = vol(a)
		balleCF = CFrame.new(bp)
		balleSpin += dt * 14
		pose.couTangage = 20 + math.min(a * 3, 1) * 5 -- le chiot regarde la balle partir
		pose.queueAmp = 38
		local voulu, regard
		if a < 0.85 then
			-- juste derrière la balle, à sa hauteur : on la voit filer au-dessus du jardin vers la zone d'arrivée
			voulu = bp - vers * 6 + UP * 2 + droite * 1.2
			regard = bp:Lerp(p1, math.clamp((a - 0.03) / 0.2, 0, 1) * 0.25)
		else
			-- la caméra ralentit et prend de la hauteur pour voir où la balle tombe
			voulu = vueAtterrissage
			regard = bp
		end
		if a < 0.12 then regard = teteDepart:Lerp(regard, a / 0.12) end -- on quitte le chiot en douceur
		voulu = camSure(bp, voulu) -- jamais à travers un mur, un toit ou un arbre
		camPos = camPos:Lerp(voulu, 1 - math.exp(-dt * (a < 0.15 and 6 or 14)))
		local secousse = a < 0.12 and (Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 0.3 * (1 - a / 0.12)) or Vector3.zero
		cam.CFrame = CFrame.lookAt(camPos + secousse, regard)
		cam.FieldOfView = 55 + 17 * math.sin(math.min(a * 2.5, 1) * math.pi / 2)
		flou.FocusDistance = (camPos - bp).Magnitude
		majChien(dt)
	end)

	-- 3) atterrissage dans la dernière zone
	trail.Enabled = false
	local vue = vueAtterrissage
	local vueProche = camSure(p1 + UP, p1 + UP + dirVue * 6.4 + UP * 7)
	local camDepart = cam.CFrame.Position
	local rebonds, colonne = false, false
	jouer(1.5, function(a, dt)
		local t = a * 1.5
		if not colonne and t > 0.3 then
			colonne = true
			grandirBalise(0.7) -- la colonne de lumière s'élève : c'est ici !
			eclat:Emit(25)
		end
		-- deux petits rebonds
		local h = 0
		if t < 0.3 then h = math.sin(t / 0.3 * math.pi) * 1.3
		elseif t < 0.5 then h = math.sin((t - 0.3) / 0.2 * math.pi) * 0.4 end
		balleCF = CFrame.new(p1 + UP * h)
		balleSpin += dt * (1 - a) * 8
		if not rebonds then
			rebonds = true
			sonJouer(REGLAGES.SONS.atterrir, 1, 1.1, p1)
			local att = Instance.new("Attachment") att.Parent = workspace.Terrain att.WorldPosition = p1
			local brins = Instance.new("ParticleEmitter")
			brins.Color = ColorSequence.new(Color3.fromRGB(120, 210, 80), Color3.fromRGB(60, 150, 50))
			brins.Size = NumberSequence.new(0.35, 0) brins.Speed = NumberRange.new(8, 15) brins.SpreadAngle = Vector2.new(70, 70)
			brins.Lifetime = NumberRange.new(0.6, 1) brins.Acceleration = Vector3.new(0, -30, 0) brins.Rate = 0
			brins.EmissionDirection = Enum.NormalId.Top brins.RotSpeed = NumberRange.new(-200, 200) brins.Parent = att
			local poussiere = Instance.new("ParticleEmitter")
			poussiere.Color = ColorSequence.new(Color3.fromRGB(230, 220, 190))
			poussiere.Size = NumberSequence.new(1, 2.5) poussiere.Transparency = NumberSequence.new(0.4, 1)
			poussiere.Speed = NumberRange.new(3, 5) poussiere.SpreadAngle = Vector2.new(80, 80) poussiere.Lifetime = NumberRange.new(0.8, 1)
			poussiere.Rate = 0 poussiere.Parent = att
			brins:Emit(22) poussiere:Emit(8)
			game:GetService("Debris"):AddItem(att, 2)
		end
		local cp = camDepart:Lerp(vue:Lerp(vueProche, ease(a)), 1 - math.exp(-dt * 6) * (1 - a))
		cam.CFrame = CFrame.lookAt(cp, p1 + UP * (0.5 + 4 * ease(math.clamp((t - 0.3) / 0.9, 0, 1))))
		cam.FieldOfView = 72 - 10 * ease(a)
		flou.FocusDistance = (cp - p1).Magnitude
		majChien(dt)
	end)
end)
if not ok then warn("[Intro] " .. tostring(erreur)) end

balleCF = CFrame.new(atterrissage + UP * 0.38)

---------------------------------------------------------------- 4) le chiot triste, puis 5) il se retourne vers toi
local ok2, erreur2 = pcall(function()
	if passe then return end
	task.wait(0.05)
	-- petit fondu noir entre les plans
	TS:Create(noir, TweenInfo.new(0.1), { BackgroundTransparency = 0 }):Play()
	task.wait(0.12)
	local tete = teteChien()
	local dirD = meilleurAngle(tete, aPlat(vers * 4.4 + droite * 0.9), 4.5, 0.5, DEVANT)
	local D0 = camSure(tete, tete + dirD * 4.5 + UP * 0.5)
	local D1 = camSure(tete, tete + dirD * 3.7 + UP * 0.35)
	cam.CFrame = CFrame.lookAt(D0, tete)
	cam.FieldOfView = 45
	pose.couTangage = 18 pose.couLacet = 0
	TS:Create(noir, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
	attTete.WorldPosition = tete
	local pop = false
	jouer(1.8, function(a, dt)
		local t = a * 1.8
		cam.CFrame = CFrame.lookAt(D0:Lerp(D1, ease(a)), tete)
		flou.FocusDistance = (cam.CFrame.Position - tete).Magnitude
		if t > 0.35 then -- les oreilles tombent, sourcils tristes, queue basse
			local k = ease(math.min((t - 0.35) / 0.5, 1))
			pose.oreilles = 12 + 58 * k
			pose.triste = k
			pose.langue = 1 - k
			pose.queueAmp = 38 - 30 * k
			pose.queueVitesse = 11 - 8 * k
			pose.queueTangage = -45 * k
			pose.couTangage = 18 - 30 * k
		end
		if not pop and t > 0.75 then
			pop = true
			bulle.Enabled = true
			sonJouer(REGLAGES.SONS.pop, 0.6, 1.2)
			TS:Create(bulleScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		if pop then rond.Rotation = math.sin(t * 6) * 8 end
		majChien(dt)
	end)

	-- il se retourne vers toi (yeux de chiot) et la caméra revient dans tes yeux
	local cfDepart = CFrame.lookAt(placeChien, placeChien + vers)
	-- un peu devant ton visage (sinon on verrait l'intérieur de ta tête et de tes accessoires)
	local oeil = head.Position + UP * 0.25 + aPlat(placeChien - head.Position) * 1.6
	local teteFixe = placeChien + UP * 2.2
	local offsetCam = cam.CFrame.Position - teteFixe -- la caméra tourne autour du chiot avec lui : on voit toujours son visage
	jouer(1.4, function(a, dt)
		local t = a * 1.4
		local k = ease(math.min(t / 0.5, 1))
		local orbite = camSure(teteFixe, teteFixe + CFrame.Angles(0, math.pi * k, 0):VectorToWorldSpace(offsetCam))
		local vers_oeil = ease(math.clamp((t - 0.45) / 0.95, 0, 1))
		pose.cf = cfDepart * CFrame.Angles(0, math.pi * k, 0) -- demi-tour vers le joueur
		pose.saut = math.sin(math.min(t / 0.5, 1) * math.pi) * 0.4
		pose.couTangage = -12 + 4 * k
		pose.couRoulis = 16 * ease(math.clamp((t - 0.5) / 0.4, 0, 1)) -- tête penchée
		bulleScale.Scale = 1 - ease(math.clamp((t - 0.2) / 0.3, 0, 1))
		attTete.WorldPosition = teteChien()
		cam.CFrame = CFrame.lookAt(orbite:Lerp(oeil, vers_oeil), teteFixe:Lerp(placeChien + UP * 1.6, vers_oeil))
		cam.FieldOfView = 45 + (fovAvant - 45) * vers_oeil
		flou.FocusDistance = (cam.CFrame.Position - placeChien).Magnitude
		majChien(dt)
	end)
end)
if not ok2 then warn("[Intro] " .. tostring(erreur2)) end

---------------------------------------------------------------- Fin : on rend la main au joueur
if passe then -- intro passée : on met tout à sa place d'un coup
	b1.Position = Vector3.new(0, 70, 0)
	eclat.Enabled = true
	lumiere.Enabled = true
	pose = nouvellePose(CFrame.lookAt(placeChien, placeChien - vers))
end
bulle:Destroy()
attTete:Destroy()
trail.Enabled = false
connPasser:Disconnect()
passer:Destroy()
flou:Destroy()
cam.FieldOfView = fovAvant
for _, f in herbeCachee do f.Parent = workspace end -- l'herbe revient
cam.CameraType = Enum.CameraType.Custom
cam.CameraSubject = humanoid
TS:Create(barreHaut, TweenInfo.new(0.4), { Position = UDim2.fromScale(0, 0) }):Play()
TS:Create(barreBas, TweenInfo.new(0.4), { Position = UDim2.fromScale(0, 1) }):Play()
noir.BackgroundTransparency = 0.3
TS:Create(noir, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
for _, g in guisCaches do if g.Parent then g.Enabled = true end end
for ct, v in coreAvant do pcall(StarterGui.SetCoreGuiEnabled, StarterGui, ct, v) end
if controles then pcall(function() controles:Enable() end) end
lp:SetAttribute("MenuOuvert", false)

-- le chiot reprend espoir : la queue repart, la langue ressort
pose.triste, pose.oreilles, pose.langue = 0.3, 25, 1
pose.queueAmp, pose.queueVitesse, pose.queueTangage = 38, 11, 0
pose.couRoulis, pose.couTangage = 0, 0
sonJouer(REGLAGES.SONS.aboiement, 0.8, 1)

---------------------------------------------------------------- Titre "RETROUVE LA BALLE !"
task.spawn(function()
	local titre = Instance.new("Frame")
	titre.BackgroundTransparency = 1
	titre.AnchorPoint = Vector2.new(0.5, 0.5)
	titre.Position = UDim2.fromScale(0.5, 0.24)
	titre.Size = UDim2.fromScale(0.7, 0.16)
	titre.Parent = gui
	local sc = Instance.new("UIScale", titre) sc.Scale = 0
	local grand = Instance.new("TextLabel")
	grand.BackgroundTransparency = 1 grand.Size = UDim2.fromScale(1, 0.68) grand.Text = REGLAGES.TITRE
	grand.Font = Enum.Font.LuckiestGuy grand.TextScaled = true grand.TextColor3 = WHITE grand.Parent = titre
	local gs = Instance.new("UIStroke", grand) gs.Thickness = 5 gs.Color = INK gs.LineJoinMode = Enum.LineJoinMode.Round
	local gg = Instance.new("UIGradient", grand) gg.Rotation = 90 gg.Color = ColorSequence.new(WHITE, Color3.fromRGB(255, 214, 90))
	local petit = Instance.new("TextLabel")
	petit.BackgroundTransparency = 1 petit.Position = UDim2.fromScale(0.1, 0.7) petit.Size = UDim2.fromScale(0.8, 0.3)
	petit.Text = REGLAGES.SOUS_TITRE petit.Font = Enum.Font.FredokaOne petit.TextScaled = true petit.TextColor3 = WHITE petit.Parent = titre
	local pst = Instance.new("UIStroke", petit) pst.Thickness = 3 pst.Color = INK
	sonJouer(REGLAGES.SONS.pop, 0.6, 1)
	TS:Create(sc, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.wait(2.6)
	TS:Create(titre, TweenInfo.new(0.35), { Position = UDim2.fromScale(0.5, 0.18) }):Play()
	TS:Create(grand, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
	TS:Create(gs, TweenInfo.new(0.35), { Transparency = 1 }):Play()
	TS:Create(petit, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
	TS:Create(pst, TweenInfo.new(0.35), { Transparency = 1 }):Play()
	task.wait(0.4)
	gui:Destroy()
	lp:SetAttribute("IntroEnCours", false)
end)

---------------------------------------------------------------- Le chiot te suit (sur ton chemin : il ne traverse pas les murs)
local dernierPerso = nil
local piste, derniereMarque, bloque = {}, nil, 0
local function aPlat3(v) return Vector3.new(v.X, 0, v.Z) end
local function teleporterPres(r)
	for _, off in { Vector3.new(3, 0, 3.5), Vector3.new(-3, 0, 3.5), Vector3.new(0, 0, 4.5), Vector3.new(3, 0, -2), Vector3.new(-3, 0, -2) } do
		local p = sol((r.CFrame * CFrame.new(off)).Position, r.Position.Y + 2)
		if p and placeLibre(p, r.Position) then
			pose.cf = CFrame.lookAt(p, p + aPlat(r.CFrame.LookVector))
			piste, derniereMarque, bloque = {}, nil, 0
			return
		end
	end
	local p = sol(r.Position, r.Position.Y + 2) or (r.Position - UP * 3)
	pose.cf = CFrame.lookAt(p, p + aPlat(r.CFrame.LookVector))
	piste, derniereMarque, bloque = {}, nil, 0
end
local function suivre(dt)
	local c = lp.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if not r then majChien(dt) return end
	if c ~= dernierPerso then
		local reapparition = dernierPerso ~= nil
		dernierPerso = c
		exclus[1] = c
		majExclus({ chienModel, balleModel })
		if reapparition then teleporterPres(r) end -- après une réapparition, il te rejoint
	end
	-- on retient le chemin du joueur
	if not derniereMarque or aPlat3(r.Position - derniereMarque).Magnitude > 1.5 then
		table.insert(piste, r.Position)
		derniereMarque = r.Position
		if #piste > 80 then table.remove(piste, 1) end
	end
	local cur = pose.cf.Position
	local distJoueur = aPlat3(r.Position - cur).Magnitude
	if distJoueur > 50 then teleporterPres(r) majChien(dt) return end
	local cible = nil
	if distJoueur > 4.5 then
		-- s'il te voit sans obstacle (en bas et en haut), il vient directement
		local bas, haut = cur + UP * 0.7, cur + UP * 1.8
		if not rayVisible(bas, r.Position - UP * 1.5 - bas) and not rayVisible(haut, r.Position - haut) then
			cible = r.Position
			piste = { r.Position }
		else
			-- sinon il suit ton chemin, point par point
			while piste[1] and aPlat3(piste[1] - cur).Magnitude < 1.2 do table.remove(piste, 1) end
			cible = piste[1]
		end
	else
		piste = { r.Position } -- il est à côté de toi : il repartira d'ici
	end
	local vitesse = 0
	local dir = pose.cf.LookVector
	if cible then
		local vec = aPlat3(cible - cur)
		if vec.Magnitude > 0.05 then
			vitesse = math.clamp(distJoueur * 2.2, 8, 26)
			cur += vec.Unit * math.min(vitesse * dt, vec.Magnitude)
			dir = dir:Lerp(vec.Unit, math.min(dt * 10, 1))
		end
		bloque = 0
	elseif distJoueur > 8 then
		bloque += dt
		if bloque > 1.5 then teleporterPres(r) majChien(dt) return end -- coincé : il te rejoint d'un coup
	else
		local versJoueur = aPlat3(r.Position - cur)
		if versJoueur.Magnitude > 0.1 then dir = dir:Lerp(versJoueur.Unit, math.min(dt * 3, 1)) end
	end
	local p = sol(cur, r.Position.Y + 2) or cur -- au niveau du joueur (pas sur les toits)
	local y = pose.cf.Position.Y + (p.Y - pose.cf.Position.Y) * math.min(dt * 12, 1)
	local pos = Vector3.new(cur.X, y, cur.Z)
	pose.cf = CFrame.lookAt(pos, pos + aPlat(dir))
	pose.marche = pose.marche + ((vitesse > 0 and 1 or 0) - pose.marche) * math.min(dt * 8, 1)
	pose.pas += dt * (6 + vitesse * 0.5)
	pose.saut = math.abs(math.sin(pose.pas)) * 0.15 * pose.marche
	pose.triste = math.max(pose.triste - dt * 0.2, 0)
	majChien(dt)
end


---------------------------------------------------------------- LA FIN DU JEU
-- Quand toute l'herbe est coupée (le stade était la dernière zone) : "Va chercher la balle !"
-- On ramasse la balle -> cinématique de fin avec le chiot -> écran des statistiques.
local finEnCours = false -- pendant la fin, c'est la cinématique qui bouge le chiot (pas "suivre")
task.spawn(function()
	local ok, err = pcall(function()
		local remotes = RS:WaitForChild("GrassRemotes", 60)
		if not remotes then return end
		-- le temps de jeu commence à la fin de l'intro (si le chrono n'a pas donné son temps)
		while lp:GetAttribute("IntroEnCours") do task.wait(0.2) end
		local debutPartie = os.clock()
		local function tempsJeu() return os.clock() - debutPartie end
		-- on attend que toute l'herbe soit coupée
		while true do
			local total, reste = remotes:GetAttribute("GrassTotal"), remotes:GetAttribute("GrassLeft")
			if total and total > 0 and reste and reste <= 0 and not lp:GetAttribute("IntroEnCours") then break end
			task.wait(0.5)
		end
		task.wait(1)

		---------------------------------------------------------------- interface de la fin
		local fg = Instance.new("ScreenGui")
		fg.Name = "FinChien"
		fg.IgnoreGuiInset = true
		fg.ResetOnSpawn = false
		fg.DisplayOrder = 60
		fg.Parent = pgui
		local function nouveau(classe, props, parent)
			local o = Instance.new(classe)
			for k, v in props do o[k] = v end
			o.Parent = parent
			return o
		end
		local function coin(o, r) return nouveau("UICorner", { CornerRadius = r or UDim.new(1, 0) }, o) end
		local function trait(o, e, c, bord)
			local s = nouveau("UIStroke", { Thickness = e, Color = c or INK, LineJoinMode = Enum.LineJoinMode.Round }, o)
			if bord then s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end
			return s
		end
		local function degrade(o, couleurs, rot)
			local k = {}
			for i, c in couleurs do table.insert(k, ColorSequenceKeypoint.new((i - 1) / (#couleurs - 1), c)) end
			return nouveau("UIGradient", { Rotation = rot or 90, Color = ColorSequence.new(k) }, o)
		end
		local OR = Color3.fromRGB(255, 214, 90)
		local echelles = {}
		local function echelle(o) table.insert(echelles, nouveau("UIScale", {}, o)) return o end
		local function adapter()
			local s = math.clamp(cam.ViewportSize.Y / 1080, 0.42, 1.2)
			for _, u in echelles do u.Scale = s end
		end
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(adapter)

		-- grand titre qui pop (comme dans l'intro)
		local function grandTitre(texte, sous, duree, y)
			local titre = nouveau("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, y or 0.24), Size = UDim2.fromScale(0.74, 0.17), ZIndex = 5 }, fg)
			local sc = nouveau("UIScale", { Scale = 0 }, titre)
			local grand = nouveau("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.68), Text = texte, Font = Enum.Font.LuckiestGuy, TextScaled = true, TextColor3 = WHITE, ZIndex = 5 }, titre)
			local gs = trait(grand, 5)
			degrade(grand, { WHITE, OR })
			local petit = nouveau("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.1, 0.7), Size = UDim2.fromScale(0.8, 0.3), Text = sous or "", Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = WHITE, ZIndex = 5 }, titre)
			local pst = trait(petit, 3)
			TS:Create(sc, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			task.delay(duree, function()
				TS:Create(titre, TweenInfo.new(0.35), { Position = UDim2.fromScale(0.5, (y or 0.24) - 0.06) }):Play()
				for _, o in { grand, petit } do TS:Create(o, TweenInfo.new(0.35), { TextTransparency = 1 }):Play() end
				for _, o in { gs, pst } do TS:Create(o, TweenInfo.new(0.35), { Transparency = 1 }):Play() end
				task.wait(0.4)
				titre:Destroy()
			end)
		end

		---------------------------------------------------------------- 1) "Va chercher la balle !"
		local posBalle = atterrissage + UP * 0.38
		sonJouer(REGLAGES.SONS.pop, 0.7, 1)
		grandTitre("TOUTE L'HERBE EST COUPÉE !", "Va chercher la balle de ton chiot !", 3.2)
		-- la colonne de lumière s'élargit et brille plus fort
		rayon.Width0, rayon.Width1 = 3, 1.2
		eclat.Enabled = true
		eclat.Rate = 22
		lumiere.Enabled = true
		lumiere.Range = 18
		b1.Position = Vector3.new(0, 90, 0)
		-- la balle brille (contour blanc) et flotte
		local brille = nouveau("Highlight", { Adornee = balleModel, FillColor = WHITE, FillTransparency = 0.6, OutlineColor = OR, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, balleModel)
		-- flèche qui rebondit au-dessus de la balle
		local attFleche = nouveau("Attachment", { WorldPosition = posBalle + UP * 3.2 }, workspace.Terrain)
		local fleche = nouveau("BillboardGui", { Adornee = attFleche, Size = UDim2.fromOffset(120, 130), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 400 }, fg)
		local flecheIn = nouveau("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, fleche)
		local balleTxt = nouveau("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Text = "BALLE", Font = Enum.Font.LuckiestGuy, TextSize = 34, TextColor3 = WHITE }, flecheIn)
		trait(balleTxt, 4)
		for _, s in { -1, 1 } do -- chevron vers le bas
			local b = nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, s * 15, 0, 80), Size = UDim2.fromOffset(46, 16), Rotation = -40 * s, BackgroundColor3 = OR, BorderSizePixel = 0 }, flecheIn)
			coin(b)
			trait(b, 3, INK, true)
		end
		-- bandeau en haut de l'écran + flèche au bord quand la balle n'est pas à l'écran
		local bandeau = echelle(nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(520, 64), BackgroundColor3 = Color3.fromRGB(14, 34, 20), BackgroundTransparency = 0.1 }, fg))
		coin(bandeau)
		trait(bandeau, 4, INK, true)
		local bt = nouveau("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 3), Text = "🎾 VA CHERCHER LA BALLE !", Font = Enum.Font.LuckiestGuy, TextSize = 34, TextColor3 = WHITE }, bandeau)
		trait(bt, 4)
		degrade(bt, { WHITE, OR })
		local bord = nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(76, 76), BackgroundTransparency = 1, Visible = false }, fg)
		local bordRot = nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, bord)
		for _, s in { -1, 1 } do
			local b = nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, s * 13, 0.5, 0), Size = UDim2.fromOffset(44, 15), Rotation = -40 * s, BackgroundColor3 = OR, BorderSizePixel = 0 }, bordRot)
			coin(b)
			trait(b, 3, INK, true)
		end
		adapter()

		local ramassee = false
		local conn
		conn = Run.RenderStepped:Connect(function(dt)
			local t = os.clock()
			-- la balle flotte et tourne doucement dans sa colonne de lumière
			balleCF = CFrame.new(posBalle + UP * (0.35 + 0.18 * math.sin(t * 3))) * CFrame.Angles(0, t * 1.5, 0)
			flecheIn.Position = UDim2.fromOffset(0, -math.abs(math.sin(t * 4)) * 14)
			rayon.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1 + 0.15 * math.sin(t * 4) ^ 2), NumberSequenceKeypoint.new(0.7, 0.7), NumberSequenceKeypoint.new(1, 1) })
			bandeau.Rotation = math.sin(t * 2) * 1.2
			-- flèche au bord de l'écran si la balle est hors champ
			local p, vu = cam:WorldToViewportPoint(posBalle + UP)
			if vu and p.Z > 0 then
				bord.Visible = false
			else
				bord.Visible = true
				local v = cam.ViewportSize
				local c = Vector2.new(v.X / 2, v.Y / 2)
				local d = Vector2.new(p.X, p.Y) - c
				if p.Z < 0 then d = -d end
				if d.Magnitude < 1 then d = Vector2.new(0, 1) end
				local m = 70
				local k = math.min((v.X / 2 - m) / math.max(math.abs(d.X), 1e-3), (v.Y / 2 - m) / math.max(math.abs(d.Y), 1e-3))
				local pos = c + d * k
				bord.Position = UDim2.fromOffset(pos.X, pos.Y)
				bordRot.Rotation = math.deg(math.atan2(d.Y, d.X)) - 90
			end
			-- on ramasse la balle en passant dessus
			local ch = lp.Character
			local r = ch and ch:FindFirstChild("HumanoidRootPart")
			if r and (Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(posBalle.X, 0, posBalle.Z)).Magnitude < 4.5 and math.abs(r.Position.Y - posBalle.Y) < 8 then
				ramassee = true
			end
		end)
		while not ramassee do task.wait() end
		conn:Disconnect()
		bandeau:Destroy()
		bord:Destroy()
		fleche:Destroy()
		attFleche:Destroy()
		brille:Destroy()
		-- la colonne de lumière se referme sur la balle (elle cacherait la scène)
		TS:Create(b1, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = Vector3.new(0, 0.1, 0) }):Play()
		TS:Create(lumiere, TweenInfo.new(0.5), { Brightness = 0 }):Play()
		eclat.Enabled = false

		---------------------------------------------------------------- 2) La cinématique de fin
		finEnCours = true
		local ch = lp.Character
		local r = ch and ch:FindFirstChild("HumanoidRootPart")
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if not (r and hum) then finEnCours = false return end
		exclus[1] = ch
		majExclus({ chienModel, balleModel })
		pcall(function() hum:UnequipTools() end)
		-- on cache l'interface, on fige le personnage
		local cachees = {}
		for _, g in pgui:GetChildren() do
			if g:IsA("ScreenGui") and g ~= fg and g.Enabled then g.Enabled = false table.insert(cachees, g) end
		end
		local coreAv = {}
		for _, ct in { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Chat, Enum.CoreGuiType.EmotesMenu, Enum.CoreGuiType.Health, Enum.CoreGuiType.Backpack } do
			local okc, v = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, ct)
			coreAv[ct] = okc and v
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, ct, false)
		end
		lp:SetAttribute("MenuOuvert", true)
		local vitesse0, saut0 = hum.WalkSpeed, hum.JumpPower
		hum.WalkSpeed, hum.JumpPower = 0, 0
		hum.AutoRotate = false
		r.Anchored = true
		local fov0 = cam.FieldOfView
		cam.CameraType = Enum.CameraType.Scriptable
		local flouFin = nouveau("DepthOfFieldEffect", { Name = "FlouFin", FarIntensity = 0.3, NearIntensity = 0, InFocusRadius = 12, FocusDistance = 10 }, Lighting)

		-- bandes noires de cinéma + bouton passer
		local haut = nouveau("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.11), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 3 }, fg)
		local bas = nouveau("Frame", { Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.11), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 3 }, fg)
		local voileNoir = nouveau("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 20 }, fg)
		TS:Create(haut, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0, 0.11) }):Play()
		TS:Create(bas, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0, 0.89) }):Play()
		local sauter = false
		local btnPasser = nouveau("TextButton", {
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -22), Size = UDim2.fromOffset(150, 44), BackgroundColor3 = Color3.fromRGB(20, 24, 22),
			BackgroundTransparency = 0.25, Text = "PASSER  »", Font = Enum.Font.FredokaOne, TextSize = 22, TextColor3 = WHITE, ZIndex = 30,
		}, fg)
		coin(btnPasser)
		btnPasser.Activated:Connect(function() sauter = true end)
		local connSauter = UIS.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Return then sauter = true end
		end)

		local lent = 1 -- ralenti (1 = vitesse normale)
		local function scene(duree, f)
			local t = 0
			while not sauter and t < duree do
				local dt = Run.RenderStepped:Wait()
				t = math.min(t + dt * lent, duree)
				f(t / duree, dt * lent, t)
			end
		end

		-- le bras droit du personnage (animation faite à la main, marche en R15 et R6)
		local epaule
		local brasHaut = ch:FindFirstChild("RightUpperArm")
		if brasHaut then epaule = brasHaut:FindFirstChild("RightShoulder") else
			local torse = ch:FindFirstChild("Torso")
			epaule = torse and torse:FindFirstChild("Right Shoulder")
		end
		local c0 = epaule and epaule.C0
		local function bras(deg)
			if epaule and c0 then pcall(function() epaule.C0 = CFrame.new(c0.Position) * CFrame.Angles(math.rad(deg), 0, 0) * c0.Rotation end) end
		end
		local main = ch:FindFirstChild("RightHand") or ch:FindFirstChild("Right Arm")
		local function dansLaMain()
			if not main then return r.CFrame * CFrame.new(1, 0.5, -1) end
			return main.CFrame * CFrame.new(0, -main.Size.Y / 2 - 0.3, 0)
		end
		local function tourner(dir) -- le personnage regarde dans une direction
			local p = r.Position
			r.CFrame = CFrame.lookAt(p, p + aPlat(dir))
		end
		local function courir(cible, vitesse, dt)
			local cur = pose.cf.Position
			local vec = Vector3.new(cible.X - cur.X, 0, cible.Z - cur.Z)
			local d = vec.Magnitude
			local dir = pose.cf.LookVector
			local v = 0
			if d > 0.05 then
				v = vitesse
				cur += vec.Unit * math.min(v * dt, d)
				dir = dir:Lerp(vec.Unit, math.min(dt * 12, 1))
			end
			local g = sol(cur, cur.Y + 3) or cur
			local y = pose.cf.Position.Y + (g.Y - pose.cf.Position.Y) * math.min(dt * 14, 1)
			local pos = Vector3.new(cur.X, y, cur.Z)
			pose.cf = CFrame.lookAt(pos, pos + aPlat(dir))
			pose.marche += ((v > 0 and 1 or 0) - pose.marche) * math.min(dt * 10, 1)
			pose.pas += dt * (6 + v * 0.55)
			return d
		end
		local function regarderChien(cible, dt)
			local cur = pose.cf.Position
			local dir = pose.cf.LookVector:Lerp(aPlat(cible - cur), math.min(dt * 8, 1))
			pose.cf = CFrame.lookAt(cur, cur + aPlat(dir))
		end
		local function eclatA(pos, couleur, n, vitesseP)
			local att = nouveau("Attachment", { WorldPosition = pos }, workspace.Terrain)
			local pe = nouveau("ParticleEmitter", {
				Color = ColorSequence.new(couleur), LightEmission = 1, Size = NumberSequence.new(0.5, 0), Speed = NumberRange.new(vitesseP or 6, (vitesseP or 6) * 1.6),
				SpreadAngle = Vector2.new(180, 180), Lifetime = NumberRange.new(0.35, 0.6), Rate = 0,
			}, att)
			pe:Emit(n)
			game:GetService("Debris"):AddItem(att, 1.5)
		end
		-- coeurs qui montent au-dessus du chiot
		local function coeur()
			local att = nouveau("Attachment", { WorldPosition = teteChien() + UP * 1.2 + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) }, workspace.Terrain)
			local g = nouveau("BillboardGui", { Adornee = att, Size = UDim2.fromOffset(46, 46), AlwaysOnTop = true, LightInfluence = 0 }, fg)
			local l = nouveau("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "❤", TextScaled = true, Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(255, 70, 110) }, g)
			local st = trait(l, 3, WHITE)
			task.spawn(function()
				local p0 = att.WorldPosition
				local t0 = os.clock()
				while os.clock() - t0 < 1.2 do
					local a = (os.clock() - t0) / 1.2
					att.WorldPosition = p0 + UP * (a * 2.4) + Vector3.new(math.sin(a * 9) * 0.3, 0, 0)
					l.TextTransparency, st.Transparency = math.max(0, a * 1.4 - 0.4), math.max(0, a * 1.4 - 0.4)
					Run.RenderStepped:Wait()
				end
				att:Destroy()
				g:Destroy()
			end)
		end
		-- bulle "!" au-dessus du chiot
		local attBulle = nouveau("Attachment", {}, workspace.Terrain)
		local bulleFin = nouveau("BillboardGui", { Adornee = attBulle, Size = UDim2.fromOffset(74, 74), StudsOffsetWorldSpace = Vector3.new(0, 1.9, 0), AlwaysOnTop = true, LightInfluence = 0, Enabled = false }, fg)
		local rondB = nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE }, bulleFin)
		coin(rondB)
		trait(rondB, 4)
		local ex = nouveau("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "!", Font = Enum.Font.LuckiestGuy, TextScaled = true, TextColor3 = Color3.fromRGB(235, 60, 55) }, rondB)
		nouveau("UIPadding", { PaddingTop = UDim.new(0.16, 0), PaddingBottom = UDim.new(0.04, 0) }, ex)
		local bulleSc = nouveau("UIScale", { Scale = 0 }, rondB)

		-- placements : le joueur devant la balle, le chiot un peu plus loin, dans un endroit dégagé
		local dirBalle = aPlat(posBalle - r.Position)
		local sP = sol(posBalle - dirBalle * 2.2, posBalle.Y + 3) or (posBalle - dirBalle * 2.2)
		local solSous = sol(r.Position, r.Position.Y + 1)
		local hauteurHanches = solSous and math.clamp(r.Position.Y - solSous.Y, 1, 6) or (hum.HipHeight + r.Size.Y / 2)
		r.CFrame = CFrame.lookAt(sP + UP * hauteurHanches, sP + UP * hauteurHanches + dirBalle)
		local P = sP
		local placeD
		for _, dist in { 10, 8, 12, 6.5 } do
			for _, ang in { 150, -150, 120, -120, 180, 90, -90, 60, -60 } do
				local d = CFrame.Angles(0, math.rad(ang), 0):VectorToWorldSpace(dirBalle)
				local q = sol(P + d * dist, P.Y + 3)
				if q and math.abs(q.Y - P.Y) < 2.5 and placeLibre(q, P + UP * 1.5) then placeD = q break end
			end
			if placeD then break end
		end
		placeD = placeD or (sol(P - dirBalle * 8, P.Y + 3) or (P - dirBalle * 8))
		pose = nouvellePose(CFrame.lookAt(placeD, placeD + aPlat(P - placeD)))
		pose.oreilles, pose.triste, pose.langue = 30, 0.35, 1
		pose.queueAmp, pose.queueVitesse = 20, 6
		majChien(0)
		local droiteJ = dirBalle:Cross(UP).Unit

		local okCine, errCine = pcall(function()
			---------------- plan 1 : il ramasse la balle et la lève bien haut
			-- face au joueur, un peu du côté du chiot : on le voit au loin qui dresse les oreilles
			local coteChien = (placeD - P):Dot(droiteJ) >= 0 and 1 or -1
			local dirCam1 = (dirBalle + droiteJ * coteChien * 0.45).Unit
			local C0 = camSure(P + UP * 2.6, P + dirCam1 * 9.2 + UP * 2.1)
			local C1 = camSure(P + UP * 2.6, P + dirCam1 * 8.1 + UP * 2.4)
			cam.FieldOfView = 52
			local sol0 = balleCF.Position
			local attrapee, brillee = false, false
			scene(1.9, function(a, dt, t)
				cam.CFrame = CFrame.lookAt(C0:Lerp(C1, ease(a)), P + UP * (2.8 + 1.1 * ease(math.clamp((t - 0.6) / 0.9, 0, 1))))
				cam.FieldOfView = 52 - 3 * ease(a)
				flouFin.FocusDistance = (cam.CFrame.Position - (P + UP * 2.6)).Magnitude
				-- le bras descend vers la balle, puis la lève
				if t < 0.35 then bras(70 * ease(t / 0.35))
				elseif t < 0.8 then bras(70)
				else bras(70 + 80 * ease(math.min((t - 0.8) / 0.5, 1))) end
				if t < 0.3 then
					balleCF = CFrame.new(sol0 + UP * (0.15 * math.sin(t * 12)))
				else
					-- la balle saute dans la main
					local k = math.min((t - 0.3) / 0.45, 1)
					local m = dansLaMain().Position
					balleCF = CFrame.new(sol0:Lerp(m, ease(k)) + UP * math.sin(k * math.pi) * 1.2) * CFrame.Angles(k * 8, 0, 0)
					if not attrapee and k >= 1 then
						attrapee = true
						sonJouer(REGLAGES.SONS.pop, 0.7, 1.3)
						eclatA(m, Color3.fromRGB(255, 240, 180), 16, 5)
					end
					if k >= 1 then balleCF = dansLaMain() end
				end
				if not brillee and t > 1.25 then
					brillee = true
					eclatA(dansLaMain().Position, Color3.fromRGB(255, 214, 90), 30, 9)
					sonJouer(REGLAGES.SONS.pop, 0.6, 1.6)
				end
				-- pendant ce temps, le chiot (hors champ) dresse les oreilles
				pose.oreilles = 30 - 18 * math.min(t / 1.9, 1)
				majChien(dt)
			end)

			---------------- plan 2 : le chiot a vu la balle ! "!"
			local tete = teteChien()
			local dirC = meilleurAngle(tete, aPlat(P - placeD), 4.4, 0.5, DEVANT)
			local D0 = camSure(tete, tete + dirC * 4.6 + UP * 0.6)
			local D1 = camSure(tete, tete + dirC * 3.5 + UP * 0.35)
			cam.FieldOfView = 46
			attBulle.WorldPosition = tete
			local pop = false
			scene(1.6, function(a, dt, t)
				cam.CFrame = CFrame.lookAt(D0:Lerp(D1, ease(a)), tete)
				flouFin.FocusDistance = (cam.CFrame.Position - tete).Magnitude
				pose.triste = math.max(0, 0.35 - t)
				pose.oreilles = 12
				pose.queueAmp, pose.queueVitesse = 45, 16
				pose.langue = 1
				pose.couRoulis = math.sin(t * 5) * 10
				if t > 0.25 then pose.saut = math.abs(math.sin((t - 0.25) * 9)) * 0.45 end
				if not pop and t > 0.2 then
					pop = true
					bulleFin.Enabled = true
					sonJouer(REGLAGES.SONS.pop, 0.6, 1.35)
					TS:Create(bulleSc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				end
				rondB.Rotation = math.sin(t * 10) * 10
				attBulle.WorldPosition = teteChien()
				majChien(dt)
			end)
			bulleFin.Enabled = false

			---------------- plan 3 : il court vers toi et saute de joie
			local versChien = aPlat(placeD - P)
			local arrivee = P + versChien * 2.8
			arrivee = sol(arrivee, P.Y + 3) or arrivee
			local cote = versChien:Cross(UP).Unit
			local milieu = (P + placeD) / 2
			local dirV = meilleurAngle(milieu + UP * 1.5, cote, 10, 2.2, { 0, 180, 25, -25, 155, -155 })
			local camPos = camSure(milieu + UP * 1.8, milieu + dirV * 10.5 + UP * 3.2)
			cam.CFrame = CFrame.lookAt(camPos, (pose.cf.Position + UP * 1.3):Lerp(P + UP * 3, 0.5))
			cam.FieldOfView = 55
			local vitesseC = (placeD - arrivee).Magnitude / 1.1
			pose.saut, pose.couRoulis = 0, 0
			scene(2.0, function(a, dt, t)
				tourner(versChien)
				bras(115 - 25 * ease(math.min(t / 0.5, 1))) -- la balle tendue devant
				balleCF = dansLaMain()
				local reste = courir(arrivee, vitesseC, dt)
				if reste < 0.2 then
					regarderChien(P, dt)
					local k = math.clamp((t - 1.15) / 0.6, 0, 1)
					pose.saut = math.sin(k * math.pi) * 1.3 -- saut de joie !
					pose.tangage = -25 * math.sin(k * math.pi)
				else
					pose.saut = math.abs(math.sin(pose.pas)) * 0.35
				end
				pose.queueAmp, pose.queueVitesse = 45, 18
				local regard = pose.cf.Position + UP * 1.3
				camPos = camPos:Lerp(camSure(regard, (pose.cf.Position + P) / 2 + dirV * 10 + UP * 3.1), 1 - math.exp(-dt * 3))
				cam.CFrame = CFrame.lookAt(camPos, regard:Lerp(P + UP * 3, 0.5))
				flouFin.FocusDistance = (camPos - regard).Magnitude
				majChien(dt)
			end)
			pose.saut, pose.tangage = 0, 0

			---------------- plan 4 : tu lances la balle... il l'attrape en plein vol !
			-- direction de lancer : un endroit bien dégagé
			local dirL, L
			for _, ang in { 0, 30, -30, 60, -60, 90, -90, 135, -135, 180 } do
				local d = CFrame.Angles(0, math.rad(ang), 0):VectorToWorldSpace(versChien)
				local q = sol(P + d * 11, P.Y + 4)
				if q and math.abs(q.Y - P.Y) < 2 and not rayVisible(P + UP * 2, d * 11 + UP * 1) then dirL, L = d, q break end
			end
			dirL = dirL or versChien
			L = L or (P + versChien * 11)
			local ligneL = dirL:Cross(UP).Unit
			local depart3 = pose.cf.Position
			local cote4 = meilleurAngle((P + L) / 2 + UP * 1.5, ligneL, 9, 2.5, { 0, 180, 15, -15, 165, -165 })
			-- de côté sur le joueur qui arme son bras, puis la caméra file le long du lancer jusqu'au chiot
			local CA = camSure(P + UP * 2.5, P + cote4 * 7.8 + dirL * 1.2 + UP * 2.4)
			local CB = camSure(L + UP * 2, L + cote4 * 6.6 - dirL * 2.4 + UP * 2.1)
			local regardA = P + UP * 2.9 + dirL * 1.6
			cam.CFrame = CFrame.lookAt(CA, regardA)
			cam.FieldOfView = 55
			local p0, envol, attrapeVol = nil, 0, false
			local VOL = 1.15
			scene(3.1, function(a, dt, t)
				tourner(dirL)
				pose.queueAmp, pose.queueVitesse = 50, 20
				if not p0 then cam.CFrame = CFrame.lookAt(CA + dirL * (0.4 * t), regardA) end
				if t < 0.42 then
					bras(90 - 140 * ease(t / 0.42)) -- on arme le bras en arrière
					balleCF = dansLaMain()
					regarderChien(P + dirL * 3, dt)
					pose.accroupi = ease(t / 0.42) -- le chiot se prépare
				elseif t < 0.56 then
					bras(-50 + 180 * ease((t - 0.42) / 0.14)) -- et hop !
					balleCF = dansLaMain()
					p0 = balleCF.Position
				else
					bras(130 - 60 * ease(math.min((t - 0.56) / 0.6, 1)))
					if not attrapeVol then
						envol = math.min(envol + dt / VOL, 1)
						local u = envol
						local bp = p0:Lerp(L + UP * 0.4, u) + UP * (4 * 5.5 * u * (1 - u))
						balleCF = CFrame.new(bp) * CFrame.Angles(u * 20, 0, u * 7)
						trail.Enabled = true
						if u < 0.05 then sonJouer(REGLAGES.SONS.lancer, 0.6, 1.2) end
						-- ralenti juste avant l'attrapé
						lent = (u > 0.62 and u < 0.9) and 0.35 or 1
						-- on s'écarte un peu quand la balle est tout en haut, puis on zoome sur l'attrapé
						local f1 = 55 + 7 * math.sin(math.pi * math.clamp(u / 0.62, 0, 1))
						cam.FieldOfView = f1 + (44 - f1) * math.clamp((u - 0.55) / 0.3, 0, 1)
						-- le chiot fonce sous la balle et saute
						pose.accroupi = math.max(0, pose.accroupi - dt * 6)
						local sous = L - dirL * 1.2
						courir(sous, (sous - depart3).Magnitude / (VOL * 0.8), dt)
						if u > 0.68 then
							local k = math.clamp((u - 0.68) / 0.3, 0, 1)
							pose.saut = math.sin(k * math.pi) * 2.1
							pose.tangage = -30 * math.sin(k * math.pi)
							pose.couTangage = -25 * math.sin(k * math.pi)
						end
						local _, _, cou = calculerChien(rig, pose, horloge)
						local gueule = (cou * CFrame.new(0, -0.2, -1.45)).Position
						if u > 0.8 and (gueule - bp).Magnitude < 2.2 or u >= 1 then
							attrapeVol = true
							balleCF = nil -- dans la gueule !
							trail.Enabled = false
							lent = 1
							sonJouer(REGLAGES.SONS.rebond, 0.8, 1.2)
							eclatA(gueule, WHITE, 18, 7)
						end
						local regard = bp:Lerp(pose.cf.Position + UP * 1.5, 0.45 + 0.35 * u)
						local recul = math.sin(math.pi * u)
						local posC = CA:Lerp(CB, ease(u)) + cote4 * (3 * recul) + UP * recul
						cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(posC, regard), 1 - math.exp(-dt * 8))
					else
						-- il retombe et s'arrête, tout fier
						pose.saut = math.max(0, pose.saut - dt * 6)
						pose.tangage, pose.couTangage = 0, 0
						courir(pose.cf.Position + pose.cf.LookVector * 0.6, 3, dt)
						cam.FieldOfView = cam.FieldOfView + (52 - cam.FieldOfView) * math.min(dt * 4, 1)
						local regard = pose.cf.Position + UP * 1.4
						cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, regard), 1 - math.exp(-dt * 5))
					end
				end
				flouFin.FocusDistance = (cam.CFrame.Position - pose.cf.Position).Magnitude
				majChien(dt)
			end)
			lent = 1
			trail.Enabled = false
			balleCF = nil
			pose.accroupi, pose.saut, pose.tangage, pose.couTangage = 0, 0, 0, 0

			---------------- plan 5 : il revient, fait des tours de joie autour de toi, puis s'assoit
			local centreT = P
			local rayonT = 3.3
			local angle0 = math.atan2(pose.cf.Position.Z - P.Z, pose.cf.Position.X - P.X)
			local orbite0 = math.atan2(cam.CFrame.Position.Z - P.Z, cam.CFrame.Position.X - P.X)
			local devantJ = aPlat(r.CFrame.LookVector)
			local assis = P + devantJ * 2.6
			assis = sol(assis, P.Y + 3) or assis
			local phase, tours = "retour", 0
			local nextCoeur = 0
			scene(3.0, function(a, dt, t)
				bras(70 * (1 - ease(math.min(t / 0.5, 1))))
				pose.queueAmp, pose.queueVitesse = 50, 20
				if phase == "retour" then
					local cible = centreT + Vector3.new(math.cos(angle0), 0, math.sin(angle0)) * rayonT
					if courir(cible, 16, dt) < 0.5 then phase = "tours" end
				elseif phase == "tours" then
					tours += dt * 4.2 -- tours de joie
					local ang = angle0 + tours
					local cible = centreT + Vector3.new(math.cos(ang), 0, math.sin(ang)) * rayonT
					courir(cible, 20, dt)
					if tours > math.pi * 2 then phase = "assis" end
				else
					local reste = courir(assis, 10, dt)
					if reste < 0.3 then
						regarderChien(P, dt)
						pose.tangage = pose.tangage + (-20 - pose.tangage) * math.min(dt * 6, 1) -- assis
						pose.accroupi = pose.accroupi + (0.45 - pose.accroupi) * math.min(dt * 6, 1)
						pose.couRoulis = math.sin(t * 3) * 12
						if t > nextCoeur then nextCoeur = t + 0.28 coeur() end
					end
				end
				if phase ~= "assis" then pose.saut = math.abs(math.sin(pose.pas)) * 0.3 end
				tourner(aPlat(pose.cf.Position - P):Lerp(devantJ, 0.5))
				local o = orbite0 + t * 0.35
				local voulu = camSure(P + UP * 2.4, P + Vector3.new(math.cos(o), 0, math.sin(o)) * 11 + UP * 4.8)
				cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(voulu, P + UP * 2.4), 1 - math.exp(-dt * 3))
				cam.FieldOfView = cam.FieldOfView + (55 - cam.FieldOfView) * math.min(dt * 3, 1)
				flouFin.FocusDistance = (cam.CFrame.Position - P).Magnitude
				majChien(dt)
			end)
		end)
		if not okCine then warn("[Fin] " .. tostring(errCine)) end
		lent = 1
		trail.Enabled = false
		balleCF = nil
		bras(0)

		---------------- plan 6 : BRAVO ! (la caméra s'envole, confettis)
		local P6 = (lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") or r).Position
		local centre6 = (P6 + pose.cf.Position) / 2
		local lat6 = meilleurAngle(centre6 + UP * 2, aPlat(pose.cf.Position - P6):Cross(UP).Unit, 9, 3, { 0, 180, 25, -25, 155, -155 })
		local ang6 = math.atan2(lat6.Z, lat6.X)
		-- la caméra tourne du côté où l'on voit ton visage (jamais le chiot caché derrière toi)
		local versC6 = aPlat(pose.cf.Position - P6)
		local sgn6 = (-math.sin(ang6) * versC6.X + math.cos(ang6) * versC6.Z) >= 0 and 1 or -1
		-- confettis : de petits papiers de couleur qui tombent en tournant
		local COULEURS = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 200, 60), Color3.fromRGB(90, 200, 255), Color3.fromRGB(130, 230, 100), Color3.fromRGB(230, 120, 255), WHITE }
		local confettis = {}
		local dossierC = nouveau("Folder", { Name = "Confettis" }, workspace)
		local function lancerConfettis(n)
			for _ = 1, n do
				local p = nouveau("Part", {
					Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.SmoothPlastic,
					Size = Vector3.new(0.28, 0.03, 0.18), Color = COULEURS[math.random(1, #COULEURS)],
				}, dossierC)
				local a = math.random() * math.pi * 2
				local rr = math.random() * 9
				table.insert(confettis, {
					p = p, pos = centre6 + Vector3.new(math.cos(a) * rr, 9 + math.random() * 6, math.sin(a) * rr),
					v = math.random(35, 60) / 10, ph = math.random() * 6.28, rot = Vector3.new(math.random() * 6, math.random() * 6, math.random() * 6), age = 0,
				})
			end
		end
		local connC = Run.RenderStepped:Connect(function(dt)
			local parts, cfs = {}, {}
			for i = #confettis, 1, -1 do
				local c = confettis[i]
				c.age += dt
				c.pos += Vector3.new(math.sin(c.age * 3 + c.ph) * 1.2 * dt, -c.v * dt, math.cos(c.age * 2.5 + c.ph) * 1.2 * dt)
				if c.age > 5 then
					c.p:Destroy()
					table.remove(confettis, i)
				else
					table.insert(parts, c.p)
					table.insert(cfs, CFrame.new(c.pos) * CFrame.Angles(c.rot.X * c.age, c.rot.Y * c.age, c.rot.Z * c.age))
				end
			end
			if #parts > 0 then workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
		end)
		if not sauter then
			local okB, errB = pcall(function()
				lancerConfettis(90)
				sonJouer(REGLAGES.SONS.pop, 0.8, 0.9)
				if REGLAGES.SONS.victoire and REGLAGES.SONS.victoire ~= "" then sonJouer(REGLAGES.SONS.victoire, 0.8, 1) end
				grandTitre("BRAVO !", "Tu as retrouvé la balle de ton chiot !", 2.6, 0.26)
				local nextCoeur, relance = 0, false
				scene(3.2, function(a, dt, t)
					local o = ang6 + sgn6 * ease(a) * 0.4
					local distC = 8 + 6 * ease(a)
					local voulu = camSure(centre6 + UP * 2, centre6 + Vector3.new(math.cos(o), 0, math.sin(o)) * distC + UP * (2.6 + 6 * ease(a)))
					cam.CFrame = CFrame.lookAt(voulu, centre6 + UP * (2 - 0.5 * a))
					flouFin.FocusDistance = (voulu - centre6).Magnitude
					-- le chiot saute de joie autour de sa balle
					pose.tangage, pose.accroupi = 0, 0
					pose.saut = math.abs(math.sin(t * 6)) * 0.8
					pose.couRoulis = math.sin(t * 4) * 12
					if t > nextCoeur then nextCoeur = t + 0.35 coeur() end
					if not relance and t > 1.4 then relance = true lancerConfettis(60) end
					majChien(dt)
				end)
			end)
			if not okB then warn("[Fin] " .. tostring(errB)) end
		end
		pose.saut, pose.couRoulis = 0, 0
		connSauter:Disconnect()
		btnPasser:Destroy()

		---------------------------------------------------------------- 3) L'écran des statistiques
		-- la caméra tourne lentement autour de toi et du chiot pendant que tu lis
		local P7 = r.Position
		local centre7 = (P7 + pose.cf.Position) / 2
		local t7 = 0
		local large = cam.ViewportSize.X / math.max(cam.ViewportSize.Y, 1) > 1.25
		local connCam = Run.RenderStepped:Connect(function(dt)
			t7 += dt
			-- balancement lent autour de vous deux (toujours de trois quarts : on vous voit tous les deux)
			local ang7 = ang6 + sgn6 * (0.4 - 0.3 * math.sin(t7 * 0.22))
			local voulu = camSure(centre7 + UP * 2, centre7 + Vector3.new(math.cos(ang7), 0, math.sin(ang7)) * 12 + UP * 5)
			local vise = centre7 + UP * 1.8
			if large then vise += aPlat(centre7 - voulu):Cross(UP).Unit * 3.8 end -- vous deux à gauche, la carte à droite
			cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(voulu, vise), 1 - math.exp(-dt * 2))
			pose.saut = math.abs(math.sin(os.clock() * 3)) * 0.1
			majChien(dt)
		end)
		TS:Create(haut, TweenInfo.new(0.4), { Position = UDim2.fromScale(0, 0) }):Play()
		TS:Create(bas, TweenInfo.new(0.4), { Position = UDim2.fromScale(0, 1) }):Play()

		-- les chiffres
		local function nb(a) return tonumber(lp:GetAttribute(a)) or 0 end
		local temps = lp:GetAttribute("TempsFinal") or tempsJeu()
		local outils = 1 + (lp:GetAttribute("Faucille") and 1 or 0) + (lp:GetAttribute("Debroussailleuse") and 1 or 0)
		local amelios = 0
		for nom, v in lp:GetAttributes() do
			if nom:sub(1, 4) == "Upg_" and type(v) == "number" then amelios += v end
		end
		local function formatTemps(t)
			t = math.floor(t)
			local h, m, s = math.floor(t / 3600), math.floor(t / 60) % 60, t % 60
			if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
			return string.format("%02d:%02d", m, s)
		end
		local function milliers(n)
			local s = tostring(math.floor(n))
			local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
			return (out:gsub("^ ", ""))
		end
		local STATS = {
			{ "⏱", "TEMPS", temps, formatTemps },
			{ "🌿", "TOUFFES COUPÉES", nb("TouffesCoupees"), milliers },
			{ "💰", "ARGENT GAGNÉ", nb("ArgentGagne"), function(v) return string.format("$%.2f", v) end },
			{ "♻️", "SACS VIDÉS", nb("SacsVides"), milliers },
			{ "✨", "HERBES RARES", nb("HerbesRares"), milliers },
			{ "🛠️", "OUTILS", outils, function(v) return math.floor(v) .. " / 3" end },
			{ "⬆️", "AMÉLIORATIONS", amelios, milliers },
		}

		-- la carte (même style que les menus du jeu)
		local fond = nouveau("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 14, 8), BackgroundTransparency = 1, BorderSizePixel = 0 }, fg)
		if large then -- on assombrit surtout derrière la carte
			nouveau("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.45, 0.6), NumberSequenceKeypoint.new(1, 0) }) }, fond)
		end
		TS:Create(fond, TweenInfo.new(0.5), { BackgroundTransparency = large and 0.35 or 0.45 }):Play()
		local xCarte = large and 0.7 or 0.5
		local carte = echelle(nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(xCarte, 1.6), Size = UDim2.fromOffset(640, 900) }, fg))
		coin(carte, UDim.new(0, 34))
		trait(carte, 5, INK, true)
		degrade(carte, { Color3.fromRGB(66, 124, 74), Color3.fromRGB(30, 66, 42) })
		local rim = nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -16, 1, -16), BackgroundTransparency = 1 }, carte)
		coin(rim, UDim.new(0, 28))
		trait(rim, 2, WHITE, true).Transparency = 0.7
		local reflet = nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 9), Size = UDim2.new(1, -24, 0, 120), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, carte)
		coin(reflet, UDim.new(0, 26))
		nouveau("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.8, 1) }, reflet)
		local etiq = nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(300, 54), Rotation = -2, ZIndex = 3 }, carte)
		coin(etiq, UDim.new(0, 20))
		trait(etiq, 4, INK, true)
		degrade(etiq, { Color3.fromRGB(255, 226, 112), Color3.fromRGB(240, 160, 32) })
		local et = nouveau("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 3), Text = "PARTIE TERMINÉE", Font = Enum.Font.LuckiestGuy, TextSize = 30, TextColor3 = WHITE, ZIndex = 4 }, etiq)
		trait(et, 3)
		local bravo = nouveau("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 96), Text = "BRAVO !", Font = Enum.Font.LuckiestGuy, TextSize = 92, TextColor3 = WHITE }, carte)
		trait(bravo, 6)
		degrade(bravo, { WHITE, OR })
		nouveau("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(30, 138), Size = UDim2.new(1, -60, 0, 36), Text = lp.DisplayName .. " a retrouvé la balle de son chiot !",
			Font = Enum.Font.FredokaOne, TextSize = 27, TextColor3 = Color3.fromRGB(226, 242, 216), TextScaled = true,
		}, carte)
		local valeurs = {}
		for i, s in STATS do
			local l = nouveau("Frame", { Position = UDim2.fromOffset(28, 188 + (i - 1) * 80), Size = UDim2.new(1, -56, 0, 70) }, carte)
			coin(l, UDim.new(0, 22))
			trait(l, 4, INK, true)
			degrade(l, { Color3.fromRGB(252, 249, 240), Color3.fromRGB(236, 230, 212) })
			local sc = nouveau("UIScale", { Scale = 0 }, l)
			nouveau("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(54, 54), Text = s[1], TextScaled = true, Font = Enum.Font.FredokaOne }, l)
			nouveau("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(80, 0), Size = UDim2.new(0.6, 0, 1, 0), Text = s[2], Font = Enum.Font.LuckiestGuy, TextSize = 29, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(60, 90, 64), TextYAlignment = Enum.TextYAlignment.Center }, l)
			local v = nouveau("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 4), Size = UDim2.fromOffset(230, 62), Text = "", Font = Enum.Font.LuckiestGuy, TextSize = 44, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = WHITE }, l)
			trait(v, 5)
			valeurs[i] = { sc = sc, v = v }
		end
		-- bouton continuer
		local bouton = nouveau("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -28), Size = UDim2.new(1, -120, 0, 104) }, carte)
		local socle = nouveau("Frame", { Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 1, -12) }, bouton)
		coin(socle, UDim.new(0, 30))
		trait(socle, 4, INK, true)
		degrade(socle, { Color3.fromRGB(36, 112, 42), Color3.fromRGB(20, 68, 26) })
		local face = nouveau("Frame", { Size = UDim2.new(1, 0, 1, -14) }, bouton)
		coin(face, UDim.new(0, 30))
		trait(face, 4, INK, true)
		degrade(face, { Color3.fromRGB(168, 244, 120), Color3.fromRGB(56, 170, 62) })
		local ct = nouveau("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 4), Text = "CONTINUER", Font = Enum.Font.LuckiestGuy, TextSize = 52, TextColor3 = WHITE }, face)
		trait(ct, 5)
		bouton.MouseButton1Down:Connect(function() face.Position = UDim2.fromOffset(0, 8) end)
		bouton.MouseButton1Up:Connect(function() face.Position = UDim2.fromOffset(0, 0) end)
		bouton.MouseLeave:Connect(function() face.Position = UDim2.fromOffset(0, 0) end)
		nouveau("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1), Modal = true }, fg) -- souris libre
		Run:BindToRenderStep("FinSouris", Enum.RenderPriority.Last.Value, function()
			UIS.MouseBehavior = Enum.MouseBehavior.Default
			UIS.MouseIconEnabled = true
		end)
		adapter()
		TS:Create(carte, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(xCarte, 0.5) }):Play()
		task.wait(0.5)
		-- les lignes arrivent une par une, les chiffres montent
		for i, s in STATS do
			local x = valeurs[i]
			TS:Create(x.sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			sonJouer(REGLAGES.SONS.pop, 0.35, 1 + i * 0.08)
			local t0 = os.clock()
			while os.clock() - t0 < 0.45 do
				local k = ease(math.min((os.clock() - t0) / 0.45, 1))
				x.v.Text = s[4](s[3] * k)
				Run.RenderStepped:Wait()
			end
			x.v.Text = s[4](s[3])
		end
		if UIS.GamepadEnabled then game:GetService("GuiService").SelectedObject = bouton end

		-- CONTINUER : on rend la main au joueur, le chiot garde sa balle et te suit
		local fini = false
		bouton.Activated:Connect(function() fini = true end)
		local connK = UIS.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Return then fini = true end
		end)
		while not fini do task.wait() end
		connK:Disconnect()
		TS:Create(voileNoir, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
		task.wait(0.32)
		-- on relance une partie toute neuve (le serveur nous téléporte sur un nouveau serveur)
		local msgRelance = nouveau("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.08), Text = "RETOUR AU LOBBY...", Font = Enum.Font.LuckiestGuy, TextScaled = true, TextColor3 = WHITE, ZIndex = 21 }, fg)
		trait(msgRelance, 4)
		local relancer = remotes:FindFirstChild("RelancerPartie")
		local echec = not relancer
		if relancer then
			relancer.OnClientEvent:Connect(function() echec = true end)
			relancer:FireServer()
			local t0 = os.clock()
			while not echec and os.clock() - t0 < 15 do task.wait(0.2) end
		end
		-- pas de téléportation possible (dans Studio par exemple) : on quitte, il suffit de relancer
		if Run:IsStudio() then
			msgRelance.Text = "PARTIE TERMINÉE ! (dans Studio : arrête et relance le test)"
			task.wait(2.5)
		end
		lp:Kick("Partie terminée ! Relance le jeu pour retourner au lobby 🐶")
		task.wait(1)
		msgRelance:Destroy()
		connCam:Disconnect()
		connC:Disconnect()
		dossierC:Destroy()
		flouFin:Destroy()
		pcall(function() Run:UnbindFromRenderStep("FinSouris") end)
		bras(0)
		r.Anchored = false
		hum.WalkSpeed, hum.JumpPower = vitesse0, saut0
		hum.AutoRotate = true
		cam.FieldOfView = fov0
		cam.CameraType = Enum.CameraType.Custom
		cam.CameraSubject = hum
		for _, g in cachees do if g.Parent then g.Enabled = true end end
		for ctp, v in coreAv do pcall(StarterGui.SetCoreGuiEnabled, StarterGui, ctp, v) end
		lp:SetAttribute("MenuOuvert", false)
		lp:SetAttribute("PartieFinie", true)
		balise:Destroy() -- plus besoin de la colonne de lumière
		carte:Destroy()
		fond:Destroy()
		finEnCours = false
		TS:Create(voileNoir, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		task.wait(0.45)
		fg:Destroy()
	end)
	if not ok then
		warn("[Fin] " .. tostring(err))
		finEnCours = false
		pcall(function()
			local ch = lp.Character
			local r = ch and ch:FindFirstChild("HumanoidRootPart")
			if r then r.Anchored = false end
			cam.CameraType = Enum.CameraType.Custom
			lp:SetAttribute("MenuOuvert", false)
		end)
	end
end)

local attendre = 0
Run.RenderStepped:Connect(function(dt)
	if not chienModel.Parent or finEnCours then return end
	attendre += dt
	if REGLAGES.CHIEN_SUIT_LE_JOUEUR and attendre > 0.8 then suivre(dt) else majChien(dt) end
end)
