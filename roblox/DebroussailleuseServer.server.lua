-- DebroussailleuseServer (Script dans ServerScriptService)
-- La débroussailleuse est accrochée au panneau de l'établi (modèle "DebroussailleuseVitrine").
-- On l'achète avec E, elle arrive dans la barre d'outils et fauche beaucoup de touffes d'un coup.
-- Sa tête tourne (BoutiqueClient). À chaque nouvelle partie, il faut la racheter.
if not game:GetService("RunService"):IsServer() then
	warn("[Débroussailleuse] DebroussailleuseServer doit être un Script dans ServerScriptService !")
	return
end
print("[Débroussailleuse] DebroussailleuseServer démarré")

local REGLAGES = {
	PRIX = 24.99,
	TOUFFES_EN_PLUS = 5, -- touffes voisines coupées en plus à chaque coup : 5 = 6 touffes au début
	COUPE_PAR_NIVEAU = 2, -- "Coupe supplémentaire" : +2 touffes par niveau (6 -> 8 -> 10)
	RAYON = 7, -- rayon autour de la touffe visée (studs)
	TAILLE_EN_MAIN = 0.8, -- taille de la débroussailleuse dans la main
	INCLINAISON = 32, -- degrés : la tête descend vers le sol devant toi
	EQUIPER_APRES_ACHAT = true, -- la débroussailleuse arrive directement dans la main
	SON = "rbxasset://sounds/swordslash.wav", -- bruit à chaque coup (mets un son de moteur si tu en as un : "rbxassetid://...")
	SAUVEGARDER = false, -- true = garde l'achat quand le joueur revient (DataStore). false = à racheter à chaque partie
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")

local TAG = "OutilDebroussailleuse"
local NOM = "Debroussailleuse" -- nom de l'outil (et de l'attribut du joueur quand il l'a achetée)
local okCfg, CFG = pcall(function() return require(ReplicatedStorage:WaitForChild("GrassConfig", 10)) end)
if not okCfg or type(CFG) ~= "table" then CFG = {} end

-- infos pour l'écran des joueurs (prix, nombre de touffes)
local achat = ReplicatedStorage:FindFirstChild("DebroussailleuseAchat") or Instance.new("RemoteEvent")
achat.Name = "DebroussailleuseAchat"
achat:SetAttribute("Prix", REGLAGES.PRIX)
achat:SetAttribute("Touffes", 1 + REGLAGES.TOUFFES_EN_PLUS)
achat:SetAttribute("Rayon", REGLAGES.RAYON)
achat.Parent = ReplicatedStorage

---------------------------------------------------------------- Le modèle (le même sur l'établi et dans la main)
-- nom, forme, taille (x, y, z), position (x, y, z), rotation (9 nombres), couleur (r, g, b), matière, reflet, transparence, tête (tourne)
-- Repère : la main (poignée arrière) en (0, 0, 0), le tube vers +X, le moteur derrière, la tête au bout.
local PIECES = {
	{ "Carter", "Cylinder", 0.42, 0.5, 0.5, -0.42, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 58, 60, 66, "SmoothPlastic", 0, 0, false },
	{ "Moteur", "Block", 0.95, 0.72, 0.78, -1.08, 0.06, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 242, 112, 28, "SmoothPlastic", 0, 0, false },
	{ "Capot", "Cylinder", 0.95, 0.8, 0.8, -1.08, 0.3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 242, 112, 28, "SmoothPlastic", 0, 0, false },
	{ "CapotBande", "Block", 0.97, 0.14, 0.82, -1.08, 0.02, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "Logo", "Block", 0.5, 0.03, 0.2, -1.05, 0.705, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 236, 234, 226, "SmoothPlastic", 0, 0, false },
	{ "LogoTrait", "Block", 0.3, 0.035, 0.06, -1.05, 0.707, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 200, 84, 18, "SmoothPlastic", 0, 0, false },
	{ "Lanceur", "Cylinder", 0.16, 0.78, 0.78, -1.62, 0.08, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 58, 60, 66, "SmoothPlastic", 0, 0, false },
	{ "LanceurCentre", "Cylinder", 0.05, 0.3, 0.3, -1.72, 0.08, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "PoigneeLanceur", "Block", 0.14, 0.13, 0.42, -1.78, 0.08, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "Reservoir", "Block", 0.8, 0.36, 0.7, -1.02, -0.47, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 236, 234, 226, "SmoothPlastic", 0, 0.1, false },
	{ "ReservoirBouchon", "Cylinder", 0.12, 0.2, 0.2, -1.02, -0.47, 0.4, 0, 0, -1, 0, 1, 0, 1, 0, 0, 200, 84, 18, "SmoothPlastic", 0, 0, false },
	{ "Filtre", "Block", 0.52, 0.46, 0.14, -0.98, 0.12, 0.45, 1, 0, 0, 0, 1, 0, 0, 0, 1, 200, 84, 18, "SmoothPlastic", 0, 0, false },
	{ "FiltreGrille", "Block", 0.4, 0.04, 0.02, -0.98, 0, 0.525, 1, 0, 0, 0, 1, 0, 0, 0, 1, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "FiltreGrille", "Block", 0.4, 0.04, 0.02, -0.98, 0.12, 0.525, 1, 0, 0, 0, 1, 0, 0, 0, 1, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "FiltreGrille", "Block", 0.4, 0.04, 0.02, -0.98, 0.24, 0.525, 1, 0, 0, 0, 1, 0, 0, 0, 1, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "Pot", "Block", 0.46, 0.34, 0.14, -1, -0.02, -0.45, 1, 0, 0, 0, 1, 0, 0, 0, 1, 178, 184, 194, "Metal", 0.15, 0, false },
	{ "PotFente", "Block", 0.06, 0.24, 0.02, -1.14, -0.02, -0.525, 1, 0, 0, 0, 1, 0, 0, 0, 1, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "PotFente", "Block", 0.06, 0.24, 0.02, -1, -0.02, -0.525, 1, 0, 0, 0, 1, 0, 0, 0, 1, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "PotFente", "Block", 0.06, 0.24, 0.02, -0.86, -0.02, -0.525, 1, 0, 0, 0, 1, 0, 0, 0, 1, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "Bougie", "Cylinder", 0.2, 0.13, 0.13, -1.46, 0.62, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "Poignee", "Cylinder", 0.72, 0.27, 0.27, 0.08, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "PoigneeStrie", "Cylinder", 0.04, 0.285, 0.285, -0.18, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 58, 60, 66, "SmoothPlastic", 0, 0, false },
	{ "PoigneeStrie", "Cylinder", 0.04, 0.285, 0.285, 0.08, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 58, 60, 66, "SmoothPlastic", 0, 0, false },
	{ "PoigneeStrie", "Cylinder", 0.04, 0.285, 0.285, 0.34, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 58, 60, 66, "SmoothPlastic", 0, 0, false },
	{ "Gachette", "Block", 0.26, 0.2, 0.08, 0.1, -0.19, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 214, 40, 40, "SmoothPlastic", 0, 0, false },
	{ "Interrupteur", "Block", 0.1, 0.07, 0.1, -0.16, 0.16, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 214, 40, 40, "SmoothPlastic", 0, 0, false },
	{ "Tube", "Cylinder", 4, 0.16, 0.16, 2.4, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 178, 184, 194, "Metal", 0.2, 0, false },
	{ "Harnais", "Cylinder", 0.1, 0.22, 0.22, 0.85, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "HarnaisAnneau", "Cylinder", 0.05, 0.2, 0.2, 0.85, -0.17, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0, 178, 184, 194, "Metal", 0, 0, false },
	{ "Boucle", "Block", 0.13, 0.13, 0.2252, 1.75, 0.4379, 0.429, 1, 0, 0, 0, -0.2225, 0.9749, 0, -0.9749, -0.2225, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "Boucle", "Block", 0.13, 0.13, 0.2252, 1.75, 0.6143, 0.344, 1, 0, 0, 0, -0.6235, 0.7818, 0, -0.7818, -0.6235, 242, 112, 28, "SmoothPlastic", 0, 0, false },
	{ "Boucle", "Block", 0.13, 0.13, 0.2252, 1.75, 0.7364, 0.1909, 1, 0, 0, 0, -0.901, 0.4339, 0, -0.4339, -0.901, 242, 112, 28, "SmoothPlastic", 0, 0, false },
	{ "Boucle", "Block", 0.13, 0.13, 0.2252, 1.75, 0.78, 0, 1, 0, 0, 0, -1, 0, 0, 0, -1, 242, 112, 28, "SmoothPlastic", 0, 0, false },
	{ "Boucle", "Block", 0.13, 0.13, 0.2252, 1.75, 0.7364, -0.1909, 1, 0, 0, 0, -0.901, -0.4339, 0, 0.4339, -0.901, 242, 112, 28, "SmoothPlastic", 0, 0, false },
	{ "Boucle", "Block", 0.13, 0.13, 0.2252, 1.75, 0.6143, -0.344, 1, 0, 0, 0, -0.6235, -0.7818, 0, 0.7818, -0.6235, 242, 112, 28, "SmoothPlastic", 0, 0, false },
	{ "Boucle", "Block", 0.13, 0.13, 0.2252, 1.75, 0.4379, -0.429, 1, 0, 0, 0, -0.2225, -0.9749, 0, 0.9749, -0.2225, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "Boucle", "Block", 0.13, 0.13, 0.2252, 1.75, 0.2421, -0.429, 1, 0, 0, 0, 0.2225, -0.9749, 0, 0.9749, 0.2225, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "Boucle", "Block", 0.13, 0.13, 0.2252, 1.75, 0.0657, -0.344, 1, 0, 0, 0, 0.6235, -0.7818, 0, 0.7818, 0.6235, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "Boucle", "Block", 0.13, 0.13, 0.2252, 1.75, -0.0564, -0.1909, 1, 0, 0, 0, 0.901, -0.4339, 0, 0.4339, 0.901, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "Boucle", "Block", 0.13, 0.13, 0.2252, 1.75, -0.0564, 0.1909, 1, 0, 0, 0, 0.901, 0.4339, 0, -0.4339, 0.901, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "Boucle", "Block", 0.13, 0.13, 0.2252, 1.75, 0.0657, 0.344, 1, 0, 0, 0, 0.6235, 0.7818, 0, -0.7818, 0.6235, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "Boucle", "Block", 0.13, 0.13, 0.2252, 1.75, 0.2421, 0.429, 1, 0, 0, 0, 0.2225, 0.9749, 0, -0.9749, 0.2225, 30, 30, 34, "SmoothPlastic", 0, 0, false },
	{ "Collier", "Block", 0.2, 0.2, 0.3, 1.75, -0.04, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 58, 60, 66, "SmoothPlastic", 0, 0, false },
	{ "Renvoi", "Block", 0.36, 0.3, 0.3, 4.48, -0.04, 0, 0.848, 0.5299, 0, -0.5299, 0.848, 0, 0, 0, 1, 58, 60, 66, "SmoothPlastic", 0, 0, false },
	{ "Bobine", "Cylinder", 0.22, 0.56, 0.56, 4.7896, -0.2914, 0, -0.5299, -0.848, 0, 0.848, -0.5299, 0, 0, 0, 1, 30, 30, 34, "SmoothPlastic", 0, 0, true },
	{ "BobineBord", "Cylinder", 0.06, 0.6, 0.6, 4.7472, -0.2235, 0, -0.5299, -0.848, 0, 0.848, -0.5299, 0, 0, 0, 1, 242, 112, 28, "SmoothPlastic", 0, 0, true },
	{ "Capuchon", "Cylinder", 0.1, 0.34, 0.34, 4.8691, -0.4186, 0, -0.5299, -0.848, 0, 0.848, -0.5299, 0, 0, 0, 1, 242, 112, 28, "SmoothPlastic", 0, 0, true },
	{ "Fil", "Block", 1.35, 0.035, 0.035, 4.8161, -0.3338, 0, 0.848, -0.5299, 0, 0.5299, 0.848, 0, 0, 0, 1, 255, 196, 40, "SmoothPlastic", 0, 0, true },
	{ "Fil", "Block", 1.35, 0.035, 0.035, 4.8161, -0.3338, 0, 0, -0.5299, -0.848, 0, 0.848, -0.5299, 1, 0, 0, 255, 196, 40, "SmoothPlastic", 0, 0, true },
	{ "Protection", "Block", 0.82, 0.04, 0.3417, 4.6232, -0.1595, 0.4038, -0.1473, -0.5299, -0.8352, -0.092, 0.848, -0.5219, 0.9848, 0, -0.1736, 242, 112, 28, "SmoothPlastic", 0, 0, false },
	{ "ProtectionBord", "Block", 0.05, 0.16, 0.3274, 4.6029, -0.2547, 0.7878, -0.1473, -0.5299, -0.8352, -0.092, 0.848, -0.5219, 0.9848, 0, -0.1736, 200, 84, 18, "SmoothPlastic", 0, 0, false },
	{ "Protection", "Block", 0.82, 0.04, 0.3417, 4.5097, -0.2304, 0.3551, -0.424, -0.5299, -0.7344, -0.265, 0.848, -0.4589, 0.866, 0, -0.5, 242, 112, 28, "SmoothPlastic", 0, 0, false },
	{ "ProtectionBord", "Block", 0.05, 0.16, 0.3274, 4.3815, -0.3931, 0.6928, -0.424, -0.5299, -0.7344, -0.265, 0.848, -0.4589, 0.866, 0, -0.5, 200, 84, 18, "SmoothPlastic", 0, 0, false },
	{ "Protection", "Block", 0.82, 0.04, 0.3417, 4.4172, -0.2882, 0.2635, -0.6496, -0.5299, -0.5451, -0.4059, 0.848, -0.3406, 0.6428, 0, -0.766, 242, 112, 28, "SmoothPlastic", 0, 0, false },
	{ "ProtectionBord", "Block", 0.05, 0.16, 0.3274, 4.201, -0.5059, 0.5142, -0.6496, -0.5299, -0.5451, -0.4059, 0.848, -0.3406, 0.6428, 0, -0.766, 200, 84, 18, "SmoothPlastic", 0, 0, false },
	{ "Protection", "Block", 0.82, 0.04, 0.3417, 4.3569, -0.3259, 0.1402, -0.7969, -0.5299, -0.29, -0.498, 0.848, -0.1812, 0.342, 0, -0.9397, 242, 112, 28, "SmoothPlastic", 0, 0, false },
	{ "ProtectionBord", "Block", 0.05, 0.16, 0.3274, 4.0832, -0.5795, 0.2736, -0.7969, -0.5299, -0.29, -0.498, 0.848, -0.1812, 0.342, 0, -0.9397, 200, 84, 18, "SmoothPlastic", 0, 0, false },
	{ "Protection", "Block", 0.82, 0.04, 0.3417, 4.3359, -0.339, 0, -0.848, -0.5299, 0, -0.5299, 0.848, 0, 0, 0, -1, 242, 112, 28, "SmoothPlastic", 0, 0, false },
	{ "ProtectionBord", "Block", 0.05, 0.16, 0.3274, 4.0422, -0.6051, 0, -0.848, -0.5299, 0, -0.5299, 0.848, 0, 0, 0, -1, 200, 84, 18, "SmoothPlastic", 0, 0, false },
	{ "Protection", "Block", 0.82, 0.04, 0.3417, 4.3569, -0.3259, -0.1402, -0.7969, -0.5299, 0.29, -0.498, 0.848, 0.1812, -0.342, 0, -0.9397, 242, 112, 28, "SmoothPlastic", 0, 0, false },
	{ "ProtectionBord", "Block", 0.05, 0.16, 0.3274, 4.0832, -0.5795, -0.2736, -0.7969, -0.5299, 0.29, -0.498, 0.848, 0.1812, -0.342, 0, -0.9397, 200, 84, 18, "SmoothPlastic", 0, 0, false },
	{ "Protection", "Block", 0.82, 0.04, 0.3417, 4.4172, -0.2882, -0.2635, -0.6496, -0.5299, 0.5451, -0.4059, 0.848, 0.3406, -0.6428, 0, -0.766, 242, 112, 28, "SmoothPlastic", 0, 0, false },
	{ "ProtectionBord", "Block", 0.05, 0.16, 0.3274, 4.201, -0.5059, -0.5142, -0.6496, -0.5299, 0.5451, -0.4059, 0.848, 0.3406, -0.6428, 0, -0.766, 200, 84, 18, "SmoothPlastic", 0, 0, false },
	{ "Protection", "Block", 0.82, 0.04, 0.3417, 4.5097, -0.2304, -0.3551, -0.424, -0.5299, 0.7344, -0.265, 0.848, 0.4589, -0.866, 0, -0.5, 242, 112, 28, "SmoothPlastic", 0, 0, false },
	{ "ProtectionBord", "Block", 0.05, 0.16, 0.3274, 4.3815, -0.3931, -0.6928, -0.424, -0.5299, 0.7344, -0.265, 0.848, 0.4589, -0.866, 0, -0.5, 200, 84, 18, "SmoothPlastic", 0, 0, false },
	{ "Protection", "Block", 0.82, 0.04, 0.3417, 4.6232, -0.1595, -0.4038, -0.1473, -0.5299, 0.8352, -0.092, 0.848, 0.5219, -0.9848, 0, -0.1736, 242, 112, 28, "SmoothPlastic", 0, 0, false },
	{ "ProtectionBord", "Block", 0.05, 0.16, 0.3274, 4.6029, -0.2547, -0.7878, -0.1473, -0.5299, 0.8352, -0.092, 0.848, 0.5219, -0.9848, 0, -0.1736, 200, 84, 18, "SmoothPlastic", 0, 0, false },
	{ "ProtectionPatte", "Block", 0.5, 0.08, 0.14, 4.4292, -0.2807, 0, 0.848, -0.5299, 0, 0.5299, 0.848, 0, 0, 0, 1, 58, 60, 66, "SmoothPlastic", 0, 0, false },
}

local function construire(parent, origine, echelle, ancre)
	local parts = {}
	for _, d in PIECES do
		local p = Instance.new("Part")
		p.Name = d[1]
		p.Shape = Enum.PartType[d[2]]
		p.Size = Vector3.new(d[3], d[4], d[5]) * echelle
		p.CFrame = origine * CFrame.new(d[6] * echelle, d[7] * echelle, d[8] * echelle, d[9], d[10], d[11], d[12], d[13], d[14], d[15], d[16], d[17])
		p.Color = Color3.fromRGB(d[18], d[19], d[20])
		p.Material = Enum.Material[d[21]]
		p.Reflectance = d[22]
		p.Transparency = d[23] or 0
		if d[24] then p:SetAttribute("Tete", true) end
		p.Anchored = ancre
		p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		p.Massless = true
		p.CastShadow = true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = parent
		table.insert(parts, p)
	end
	return parts
end

---------------------------------------------------------------- L'outil
local function construireOutil()
	local E = REGLAGES.TAILLE_EN_MAIN
	local outil = Instance.new("Tool")
	outil.Name = NOM
	outil.ToolTip = "Débroussailleuse : fauche " .. (1 + REGLAGES.TOUFFES_EN_PLUS) .. " touffes d'un coup"
	outil.CanBeDropped = false
	outil:SetAttribute("CoupeEnPlus", REGLAGES.TOUFFES_EN_PLUS) -- lu par GrassServer
	outil:SetAttribute("RayonCoupe", REGLAGES.RAYON)
	outil:SetAttribute("Prefixe", "D") -- ses améliorations : Upg_DMaintenir, Upg_DRapidite, Upg_DCoupe
	outil:SetAttribute("CoupeParNiveau", REGLAGES.COUPE_PAR_NIVEAU)
	CollectionService:AddTag(outil, TAG)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 0.3)
	handle.Transparency = 1
	handle.CanCollide, handle.CanTouch, handle.CanQuery = false, false, false
	handle.Massless = true
	handle.CFrame = CFrame.identity
	handle.Parent = outil
	local modele = Instance.new("Folder")
	modele.Name = "Modele"
	modele.Parent = outil
	local parts = construire(modele, CFrame.identity, E, false)
	-- la tête (bobine + fils) tourne autour de son axe : elle est sur un moteur
	local centre = Vector3.zero
	for _, p in parts do if p:GetAttribute("Tete") and p.Name == "Bobine" then centre = p.Position end end
	local axe = Vector3.new(-math.sin(math.rad(32)), math.cos(math.rad(32)), 0)
	local pivot = Instance.new("Part")
	pivot.Name = "TetePivot"
	pivot.Size = Vector3.new(0.1, 0.1, 0.1)
	pivot.Transparency = 1
	pivot.CanCollide, pivot.CanTouch, pivot.CanQuery = false, false, false
	pivot.Massless = true
	pivot.CFrame = CFrame.fromMatrix(centre, axe:Cross(Vector3.new(0, 0, 1)).Unit, axe) -- Y du pivot = axe de la tête
	pivot.Parent = modele
	local moteur = Instance.new("Motor6D")
	moteur.Name = "TeteMoteur"
	moteur.Part0, moteur.Part1 = handle, pivot
	moteur.C0 = pivot.CFrame
	moteur.Parent = handle
	CollectionService:AddTag(moteur, "TeteDebroussailleuse") -- BoutiqueClient la fait tourner
	for _, p in parts do
		local base = if p:GetAttribute("Tete") then pivot else handle
		local w = Instance.new("Weld")
		w.Part0, w.Part1 = base, p
		w.C0 = base.CFrame:ToObjectSpace(p.CFrame)
		w.Parent = p
	end
	-- dans la main : le tube vers l'avant, la tête qui descend vers le sol
	outil.Grip = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0))
		* CFrame.Angles(math.rad(REGLAGES.INCLINAISON), 0, 0)
	local son = Instance.new("Sound")
	son.Name = "Swoosh"
	son.SoundId = REGLAGES.SON
	son.Volume = 0.45
	son.Parent = handle
	return outil
end
local modeleOutil = construireOutil()

---------------------------------------------------------------- Le coup de débroussailleuse (bras qui balaie l'herbe)
local function trouverEpaule(perso)
	local bras = perso:FindFirstChild("RightUpperArm")
	if bras then return bras:FindFirstChild("RightShoulder") end
	local torse = perso:FindFirstChild("Torso")
	return torse and torse:FindFirstChild("Right Shoulder")
end
local animations = setmetatable({}, { __mode = "k" })
local function animerC0(joint, cible, duree)
	local depart = joint.C0
	local id = (animations[joint] or 0) + 1
	animations[joint] = id
	task.spawn(function()
		local t0 = os.clock()
		while animations[joint] == id do
			local a = math.min((os.clock() - t0) / duree, 1)
			local ok = pcall(function() joint.C0 = depart:Lerp(cible, 1 - (1 - a) ^ 2) end)
			if not ok or a >= 1 then return end
			RunService.Heartbeat:Wait()
		end
	end)
end
local function bras(epaule, tangage, lacet, duree)
	if not (epaule and epaule:IsA("Motor6D")) then return end
	local origine = epaule:GetAttribute("C0Origine")
	if not origine then
		origine = epaule.C0
		epaule:SetAttribute("C0Origine", origine)
	end
	animerC0(epaule, CFrame.new(origine.Position) * CFrame.Angles(math.rad(tangage), math.rad(lacet), 0) * origine.Rotation, duree)
end
-- le buste tourne aussi (R15 : articulation "Waist") pour un vrai geste de fauchage
local function trouverTaille(perso)
	local torse = perso:FindFirstChild("UpperTorso")
	return torse and torse:FindFirstChild("Waist")
end
local function buste(taille, lacet, duree)
	if not (taille and taille:IsA("Motor6D")) then return end
	local origine = taille:GetAttribute("C0Origine")
	if not origine then
		origine = taille.C0
		taille:SetAttribute("C0Origine", origine)
	end
	animerC0(taille, CFrame.new(origine.Position) * CFrame.Angles(0, math.rad(lacet), 0) * origine.Rotation, duree)
end
local function delaiCoupe(qui)
	-- amélioration de vitesse de la débroussailleuse : Rapidité
	local dex = qui and qui:GetAttribute("Upg_DRapidite") or 0
	return math.max(0.2, (CFG.PICK_COOLDOWN or 0.9) * (1 - (CFG.DEX_PAR_NIVEAU or 0.08) * dex))
end

local derniers = setmetatable({}, { __mode = "k" })
local occupes = setmetatable({}, { __mode = "k" })
local function coup(outil)
	local perso = outil.Parent
	local joueur = perso and Players:GetPlayerFromCharacter(perso)
	if not joueur or occupes[outil] then return end
	-- pas de spam : un coup seulement quand le délai pour couper une herbe est passé
	if os.clock() - (derniers[outil] or -math.huge) < delaiCoupe(joueur) * 0.85 then return end
	derniers[outil] = os.clock()
	occupes[outil] = true
	local epaule = trouverEpaule(perso)
	local handle = outil:FindFirstChild("Handle")
	-- fauchage : on arme à droite, on fauche en arc vers la gauche au ras du sol, puis on revient
	-- "EnCoupe" = le moteur accélère (BoutiqueClient : la tête tourne plus vite, l'herbe gicle)
	local taille = trouverTaille(perso)
	local son = handle and handle:FindFirstChild("Swoosh")
	outil:SetAttribute("EnCoupe", true)
	bras(epaule, -30, -50, 0.12)
	buste(taille, -16, 0.12)
	task.wait(0.12)
	if son then son.PlaybackSpeed = 1.1 + math.random() * 0.2 son:Play() end
	bras(epaule, -42, 48, 0.28) -- le coup : la tête passe au ras de l'herbe
	buste(taille, 18, 0.28)
	task.wait(0.3)
	if outil.Parent == perso then
		bras(epaule, -22, 0, 0.2)
		buste(taille, 0, 0.2)
	end
	task.wait(0.08)
	outil:SetAttribute("EnCoupe", false)
	occupes[outil] = nil
end

local branches = setmetatable({}, { __mode = "k" })
local function brancher(outil)
	if not outil:IsA("Tool") or branches[outil] then return end
	branches[outil] = true
	outil.Equipped:Connect(function()
		bras(trouverEpaule(outil.Parent), -22, 0, 0.2)
	end)
	outil.Unequipped:Connect(function()
		outil:SetAttribute("EnCoupe", false)
		local joueur = outil:FindFirstAncestorOfClass("Player")
		local perso = joueur and joueur.Character
		local epaule = perso and trouverEpaule(perso)
		local origine = epaule and epaule:GetAttribute("C0Origine")
		if origine then animerC0(epaule, origine, 0.12) end
		local taille = perso and trouverTaille(perso)
		local o2 = taille and taille:GetAttribute("C0Origine")
		if o2 then animerC0(taille, o2, 0.12) end
	end)
	outil.Activated:Connect(function() coup(outil) end)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(brancher)
for _, o in CollectionService:GetTagged(TAG) do brancher(o) end

-- GrassServer prévient quand une touffe est vraiment coupée (aussi en restant appuyé)
local signal = ServerStorage:WaitForChild("CiseauxCoupe", 5)
if not signal then
	signal = Instance.new("BindableEvent")
	signal.Name = "CiseauxCoupe"
	signal.Parent = ServerStorage
end
signal.Event:Connect(function(joueur)
	local outil = joueur.Character and joueur.Character:FindFirstChildOfClass("Tool")
	if outil and CollectionService:HasTag(outil, TAG) then task.spawn(coup, outil) end
end)

---------------------------------------------------------------- Achat et sauvegarde
local store
if REGLAGES.SAUVEGARDER then
	local ok, s = pcall(function() return DataStoreService:GetDataStore("Debroussailleuse_v1") end)
	if ok then store = s end
end
local avertiSauvegarde = false
local function charger(joueur)
	if not store then return false end
	local ok, v = pcall(function() return store:GetAsync("u" .. joueur.UserId) end)
	if not ok and not avertiSauvegarde then
		avertiSauvegarde = true
		warn("[Débroussailleuse] Sauvegarde impossible. Dans Studio : Home > Game Settings > Security > Enable Studio Access to API Services")
	end
	return ok and v == true
end
local function sauver(joueur)
	if not store then return end
	task.spawn(function()
		for _ = 1, 3 do
			if pcall(function() store:SetAsync("u" .. joueur.UserId, true) end) then return end
			task.wait(3)
		end
	end)
end

local NOMS_ARGENT = { "Money", "Cash", "Argent", "Coins", "Dollars", "Pieces", "Pièces", "$" }
local function argent(joueur)
	local ls = joueur:FindFirstChild("leaderstats")
	if not ls then return nil end
	if CFG.MONEY_STAT and CFG.MONEY_STAT ~= "" then return ls:FindFirstChild(CFG.MONEY_STAT) end
	for _, n in NOMS_ARGENT do
		local v = ls:FindFirstChild(n)
		if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then return v end
	end
	return nil
end

local function donner(joueur, equiper)
	local gear = joueur:FindFirstChild("StarterGear") or joueur:WaitForChild("StarterGear", 5)
	if gear and not gear:FindFirstChild(NOM) then modeleOutil:Clone().Parent = gear end -- gardée après la mort
	local sac = joueur:FindFirstChildOfClass("Backpack") or joueur:WaitForChild("Backpack", 5)
	local perso = joueur.Character
	local outil = (sac and sac:FindFirstChild(NOM)) or (perso and perso:FindFirstChild(NOM))
	if not outil and sac then
		outil = modeleOutil:Clone()
		outil.Parent = sac
	end
	if equiper and outil and sac and outil.Parent == sac and perso then
		local h = perso:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 then h:EquipTool(outil) end
	end
end

local enCours = {}
local function acheter(joueur)
	if enCours[joueur] then return end
	enCours[joueur] = true
	if joueur:GetAttribute(NOM) then
		donner(joueur, true)
	else
		local m = argent(joueur)
		local v = m and tonumber(m.Value) or 0
		local prix = REGLAGES.PRIX
		if m and m:IsA("IntValue") then prix = math.ceil(prix) end
		if not m or v + 1e-6 < prix then
			achat:FireClient(joueur, "manque", prix - v)
		else
			m.Value = if m:IsA("IntValue") then v - prix else math.floor((v - prix) * 100 + 0.5) / 100
			joueur:SetAttribute(NOM, true)
			sauver(joueur)
			donner(joueur, REGLAGES.EQUIPER_APRES_ACHAT)
			achat:FireClient(joueur, "ok")
			print("[Débroussailleuse] " .. joueur.Name .. " a acheté la débroussailleuse")
		end
	end
	task.wait(0.3)
	enCours[joueur] = nil
end

local function arrivee(joueur)
	if charger(joueur) then
		joueur:SetAttribute(NOM, true)
		if not joueur.Character then joueur.CharacterAdded:Wait() end
		task.wait(1)
		donner(joueur, false)
	end
end
-- sécurité : personne n'a la débroussailleuse sans l'avoir achetée (même si une copie traîne dans StarterPack)
local function estFaucille(o) return o:IsA("Tool") and (o.Name == NOM or CollectionService:HasTag(o, TAG)) end
for _, o in game:GetService("StarterPack"):GetChildren() do
	if estFaucille(o) then
		warn("[Débroussailleuse] Une débroussailleuse était dans StarterPack : retirée (il faut l'acheter)")
		o:Destroy()
	end
end
local function surveiller(joueur)
	local function verifier(o)
		if estFaucille(o) and not joueur:GetAttribute(NOM) then task.defer(function() o:Destroy() end) end
	end
	local function suivre(conteneur)
		if not conteneur then return end
		for _, o in conteneur:GetChildren() do verifier(o) end
		conteneur.ChildAdded:Connect(verifier)
	end
	suivre(joueur:FindFirstChild("StarterGear") or joueur:WaitForChild("StarterGear", 10))
	local function surPerso(perso)
		suivre(perso)
		suivre(joueur:FindFirstChildOfClass("Backpack") or joueur:WaitForChild("Backpack", 10))
	end
	if joueur.Character then surPerso(joueur.Character) end
	joueur.CharacterAdded:Connect(surPerso)
end
Players.PlayerAdded:Connect(function(j) task.spawn(surveiller, j) end)
for _, j in Players:GetPlayers() do task.spawn(surveiller, j) end

Players.PlayerAdded:Connect(arrivee)
for _, j in Players:GetPlayers() do task.spawn(arrivee, j) end
Players.PlayerRemoving:Connect(function(joueur) enCours[joueur] = nil end)

---------------------------------------------------------------- La débroussailleuse accrochée à l'établi
local function vitrine()
	local v = workspace:FindFirstChild("DebroussailleuseVitrine", true)
	if v then return v end
	-- pas de vitrine : on l'accroche aux crochets du panneau de l'établi
	local meuble = workspace:FindFirstChild("MeubleOutils", true)
	local place = meuble and meuble:FindFirstChild("Emplacement_Debroussailleuse", true)
	if not (place and place:IsA("BasePart")) then
		warn("[Débroussailleuse] Pas de 'DebroussailleuseVitrine' ni d'établi 'MeubleOutils' : la débroussailleuse n'est pas en vente")
		return nil
	end
	v = Instance.new("Model")
	v.Name = "DebroussailleuseVitrine"
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(7, 0.8, 0.8)
	base.CFrame = place.CFrame
	base.Transparency = 1
	base.Anchored = true
	base.CanCollide, base.CanTouch, base.CanQuery = false, false, false
	base.Parent = v
	v.PrimaryPart = base
	local panneau = base:Clone()
	panneau.Name = "PanneauPrix"
	panneau.Size = Vector3.new(0.2, 0.2, 0.2)
	panneau.CFrame = place.CFrame * CFrame.new(2.4, -2, -0.35)
	panneau.Parent = v
	construire(v, place.CFrame * CFrame.new(2.08, -0.175, 0.05) * CFrame.Angles(0, math.pi, 0), 1, true)
	v.Parent = meuble
	return v
end

local v = vitrine()
if v then
	local base = v.PrimaryPart or v:FindFirstChild("Base")
	local prompt = base:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	prompt.Name = "Acheter"
	prompt.ActionText = "Voir" -- ouvre la fiche de l'outil (BoutiqueClient) ; on achète en cliquant sur le prix
	prompt.ObjectText = "Débroussailleuse"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = base
	-- achat demandé depuis la fiche (bouton du prix) : il faut être près de l'établi
	achat.OnServerEvent:Connect(function(joueur, action)
		if action ~= "acheter" then return end
		local perso = joueur.Character
		local hrp = perso and perso:FindFirstChild("HumanoidRootPart")
		if not hrp or (hrp.Position - base.Position).Magnitude > 35 then return end
		acheter(joueur)
	end)
	print("[Débroussailleuse] En vente sur l'établi : $" .. REGLAGES.PRIX)
end
