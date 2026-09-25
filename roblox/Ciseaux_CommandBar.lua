-- Ciseaux détaillés : colle tout dans la Barre de commande de Roblox Studio, puis Entrée
local cam = workspace.CurrentCamera.CFrame
local dir = Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z)
if dir.Magnitude < 0.01 then dir = Vector3.new(0, 0, -1) end
local devant = cam.Position + dir.Unit * 8
local hit = workspace:Raycast(devant + Vector3.new(0, 50, 0), Vector3.new(0, -500, 0))
local sol = if hit then hit.Position else Vector3.new(devant.X, 0, devant.Z)
local origine = CFrame.lookAt(sol, sol + dir)

local S, OFF, V = 0.85, Vector3.new(0.00636, 0.017, -0.01891), Vector3.new
local ACIER, FIL, DOS = Color3.fromRGB(188, 194, 203), Color3.fromRGB(242, 244, 247), Color3.fromRGB(120, 126, 136)
local ROUGE, ROUGE_CLAIR = Color3.fromRGB(200, 30, 35), Color3.fromRGB(240, 90, 90)
local NOIR, LAITON, FENTE = Color3.fromRGB(38, 40, 46), Color3.fromRGB(201, 162, 72), Color3.fromRGB(60, 48, 22)
local METAL, LISSE = Enum.Material.Metal, Enum.Material.SmoothPlastic
local HAUT = CFrame.fromMatrix(Vector3.zero, V(0, 1, 0), V(-1, 0, 0), V(0, 0, 1)) -- cylindre vertical

local modele = Instance.new("Model")
modele.Name = "Ciseaux"
local rot = CFrame.identity -- rotation de la branche en cours

local function dossier(nom, parent)
	local d = Instance.new("Folder")
	d.Name = nom
	d.Parent = parent
	return d
end

local function piece(parent, nom, taille, c, couleur, mat, forme, reflet, classe)
	local p = Instance.new(classe or "Part")
	p.Name = nom
	if forme then p.Shape = forme end
	p.Size = taille * S
	local w = rot * c
	p.CFrame = origine * CFrame.new(w.Position * S + OFF) * w.Rotation
	p.Color, p.Material, p.Reflectance = couleur, mat or LISSE, reflet or 0
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
end

local function tube(parent, nom, a, b, d, couleur, boule)
	local ex = (b - a).Unit
	local ey = (V(0, 1, 0) - ex * ex.Y).Unit
	piece(parent, nom, V((b - a).Magnitude + 0.004, d, d), CFrame.fromMatrix((a + b) / 2, ex, ey, ex:Cross(ey)),
		couleur, LISSE, Enum.PartType.Cylinder)
	if boule ~= false then
		piece(parent, nom .. "Joint", V(d, d, d), CFrame.new(a), couleur, LISSE, Enum.PartType.Ball)
	end
end

local function anneau(parent, nom, cx, cz, y, a, b, d, couleur)
	for i = 0, 23 do
		local t1, t2 = math.pi * i / 12, math.pi * (i + 1) / 12
		tube(parent, nom, V(cx + a * math.cos(t1), y, cz + b * math.sin(t1)),
			V(cx + a * math.cos(t2), y, cz + b * math.sin(t2)), d, couleur)
	end
end

local function branche(nom, s, y, ra, rb, angle)
	rot = CFrame.Angles(0, angle, 0)
	local g = dossier(nom, modele)
	local lame, poignee = dossier("Lame", g), dossier("Poignee", g)
	piece(lame, "CorpsLame", V(0.55, 0.08, 0.3), CFrame.new(0.275, y, s * 0.13), ACIER, METAL)
	piece(lame, "Pointe", V(0.08, 0.3, 1.3), CFrame.fromMatrix(V(1.2, y, s * 0.13), V(0, -s, 0), V(0, 0, s), V(-1, 0, 0)),
		ACIER, METAL, nil, 0, "WedgePart")
	piece(lame, "FilDeCoupe", V(1.4, 0.086, 0.06), CFrame.new(0.85, y, s * 0.01), FIL, LISSE, nil, 0.45)
	piece(lame, "DosLame", V(0.45, 0.084, 0.025), CFrame.new(0.325, y, s * 0.2675), DOS, METAL)
	piece(lame, "Talon", V(0.08, 0.38, 0.38), CFrame.new(0, y, 0) * HAUT, ACIER, METAL, Enum.PartType.Cylinder)
	piece(lame, "Tige", V(0.72, 0.08, 0.16), CFrame.new(-0.36, y, 0), ACIER, METAL)

	local p0, p1 = V(-0.5, 0.09, 0), V(-0.78, 0.09, -s * 0.05)
	local cx, cz = -0.86 - ra, -s * 0.16
	local t0 = math.atan2((p1.Z - cz) / rb, (p1.X - cx) / ra)
	local p2 = V(cx + ra * math.cos(t0), 0.09, cz + rb * math.sin(t0))
	tube(poignee, "Manche", p0, p1, 0.19, ROUGE)
	tube(poignee, "Manche", p1, p2, 0.18, ROUGE)
	piece(poignee, "MancheJoint", V(0.18, 0.18, 0.18), CFrame.new(p2), ROUGE, LISSE, Enum.PartType.Ball)
	tube(poignee, "Bague", V(-0.47, 0.09, 0), V(-0.53, 0.09, -s * 0.001), 0.22, ROUGE_CLAIR, false)
	anneau(poignee, "Anneau", cx, cz, 0.09, ra, rb, 0.17, ROUGE)
	anneau(poignee, "Grip", cx, cz, 0.09, ra - 0.075, rb - 0.075, 0.1, NOIR)
end

branche("BranchePouce", 1, 0.13, 0.3, 0.3, -math.rad(12))
branche("BrancheDoigts", -1, 0.05, 0.47, 0.3, math.rad(12))

rot = CFrame.identity
local vis = dossier("Vis", modele)
piece(vis, "Rondelle", V(0.025, 0.27, 0.27), CFrame.new(0, 0.1825, 0) * HAUT, ACIER, METAL, Enum.PartType.Cylinder, 0.2)
piece(vis, "TeteDeVis", V(0.05, 0.2, 0.2), CFrame.new(0, 0.22, 0) * HAUT, LAITON, LISSE, Enum.PartType.Cylinder, 0.35)
piece(vis, "Fente", V(0.16, 0.012, 0.028), CFrame.new(0, 0.2445, 0), FENTE)

modele.WorldPivot = origine
modele.Parent = workspace
pcall(function() game:GetService("Selection"):Set({ modele }) end)
print("Ciseaux créés !")
