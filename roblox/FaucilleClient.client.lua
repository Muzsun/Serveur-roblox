-- FaucilleClient (LocalScript dans StarterPlayer > StarterPlayerScripts)
-- Panneau de prix au-dessus de la faucille sur l'établi (pièce + prix), et petite fête quand on l'achète.
if not game:GetService("RunService"):IsClient() then
	warn("[Faucille] FaucilleClient doit être un LocalScript dans StarterPlayer > StarterPlayerScripts !")
	return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local COIN = "rbxassetid://103593634628600" -- l'icône des pièces
local lp = Players.LocalPlayer
local pgui = lp:WaitForChild("PlayerGui")
local cam = workspace.CurrentCamera
local achat = ReplicatedStorage:WaitForChild("FaucilleAchat", 30)
if not achat then return end

local BLANC, ENCRE = Color3.new(1, 1, 1), Color3.fromRGB(26, 22, 28)
local OR, VERT, ROUGE = Color3.fromRGB(255, 215, 70), Color3.fromRGB(150, 245, 90), Color3.fromRGB(255, 96, 80)
local BOIS_A, BOIS_B, BOIS_BORD = Color3.fromRGB(170, 114, 64), Color3.fromRGB(122, 78, 42), Color3.fromRGB(72, 44, 22)

local function prix() return achat:GetAttribute("Prix") or 7.99 end
local function argentTexte(v) return string.format("$%.2f", v) end

local function coin(o, r) local c = Instance.new("UICorner") c.CornerRadius = r or UDim.new(1, 0) c.Parent = o end
local function contour(o, e, c, bord)
	local s = Instance.new("UIStroke")
	s.Thickness = e
	s.Color = c
	s.LineJoinMode = Enum.LineJoinMode.Round
	if bord then s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end
	s.Parent = o
	return s
end
local function texte(parent, t, police, pos, taille, couleur)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = t
	l.Font = police
	l.TextScaled = true
	l.TextColor3 = couleur or BLANC
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = pos
	l.Size = taille
	l.Parent = parent
	contour(l, 3, ENCRE)
	return l
end

-- argent du joueur (même recherche que le reste du jeu)
local okCfg, CFG = pcall(function() return require(ReplicatedStorage:WaitForChild("GrassConfig", 10)) end)
if not okCfg or type(CFG) ~= "table" then CFG = {} end
local function argent()
	local ls = lp:FindFirstChild("leaderstats")
	if not ls then return 0 end
	local v
	if CFG.MONEY_STAT and CFG.MONEY_STAT ~= "" then v = ls:FindFirstChild(CFG.MONEY_STAT) end
	if not v then
		for _, n in { "Money", "Cash", "Argent", "Coins", "Dollars", "Pieces", "Pièces", "$" } do
			v = ls:FindFirstChild(n)
			if v then break end
		end
	end
	return v and tonumber(v.Value) or 0
end

---------------------------------------------------------------- Panneau au-dessus de la faucille
local panneau
local function creerPanneau(vitrine)
	local base = vitrine.PrimaryPart or vitrine:WaitForChild("Base", 10)
	if not base then return end
	local g = Instance.new("BillboardGui")
	g.Name = "FaucillePrix"
	g.Adornee = base
	-- taille fixe dans le monde (en studs) : il ne grossit pas quand on s'éloigne
	g.Size = UDim2.fromScale(4.2, 2)
	g.SizeOffset = Vector2.new(0, 0.5)
	g.StudsOffsetWorldSpace = Vector3.new(0, 1.3, 0)
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	g.MaxDistance = 70
	g.ResetOnSpawn = false
	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(420, 200)
	root.BackgroundColor3 = BLANC
	root.Parent = g
	coin(root, UDim.new(0, 26))
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(206, 150, 94)),
		ColorSequenceKeypoint.new(0.12, BOIS_A),
		ColorSequenceKeypoint.new(1, BOIS_B),
	})
	grad.Parent = root
	local bord = contour(root, 6, BOIS_BORD, true)
	local echelle = Instance.new("UIScale")
	echelle.Parent = root
	local pop = Instance.new("UIScale")
	-- clous aux 4 coins
	for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		local n = Instance.new("Frame")
		n.AnchorPoint = Vector2.new(0.5, 0.5)
		n.Size = UDim2.fromOffset(12, 12)
		n.Position = UDim2.new(c[1], c[1] == 0 and 18 or -18, c[2], c[2] == 0 and 18 or -18)
		n.BackgroundColor3 = Color3.fromRGB(64, 62, 66)
		n.Parent = root
		coin(n)
	end
	texte(root, "FAUCILLE", Enum.Font.FredokaOne, UDim2.new(0.5, 0, 0, 12), UDim2.fromOffset(300, 52))
	-- ligne du prix : [pièce] $7.99
	local ligne = Instance.new("Frame")
	ligne.BackgroundTransparency = 1
	ligne.AnchorPoint = Vector2.new(0.5, 0)
	ligne.Position = UDim2.new(0.5, 0, 0, 66)
	ligne.Size = UDim2.fromOffset(380, 76)
	ligne.Parent = root
	pop.Parent = ligne
	local liste = Instance.new("UIListLayout")
	liste.FillDirection = Enum.FillDirection.Horizontal
	liste.HorizontalAlignment = Enum.HorizontalAlignment.Center
	liste.VerticalAlignment = Enum.VerticalAlignment.Center
	liste.Padding = UDim.new(0, 8)
	liste.Parent = ligne
	local piece = Instance.new("ImageLabel")
	piece.BackgroundTransparency = 1
	piece.Image = COIN
	piece.ScaleType = Enum.ScaleType.Fit
	piece.Size = UDim2.fromOffset(68, 68)
	piece.LayoutOrder = 1
	piece.Parent = ligne
	local valeur = Instance.new("TextLabel")
	valeur.BackgroundTransparency = 1
	valeur.Font = Enum.Font.LuckiestGuy
	valeur.TextSize = 60
	valeur.Size = UDim2.fromOffset(0, 70)
	valeur.AutomaticSize = Enum.AutomaticSize.X
	valeur.TextColor3 = BLANC
	valeur.Text = argentTexte(prix())
	valeur.LayoutOrder = 2
	valeur.Parent = ligne
	contour(valeur, 4, ENCRE)
	local vg = Instance.new("UIGradient")
	vg.Rotation = 90
	vg.Color = ColorSequence.new(BLANC, Color3.fromRGB(255, 228, 140))
	vg.Parent = valeur
	local info = texte(root, "Coupe " .. (achat:GetAttribute("Touffes") or 4) .. " touffes d'un coup !", Enum.Font.FredokaOne,
		UDim2.new(0.5, 0, 0, 148), UDim2.fromOffset(360, 36), Color3.fromRGB(255, 240, 205))
	g.Parent = pgui
	panneau = { g = g, root = root, echelle = echelle, pop = pop, bord = bord, piece = piece, valeur = valeur, vg = vg, info = info, base = base }
end

local function majPanneau(t)
	if not panneau or not panneau.g.Parent then return end
	local p = panneau
	p.echelle.Scale = p.g.AbsoluteSize.X / 420
	if lp:GetAttribute("Faucille") then
		p.piece.Visible = false
		p.vg.Enabled = false
		p.valeur.Text = "✓ ACHETÉE"
		p.valeur.TextColor3 = VERT
		p.info.Text = "Elle est dans ta barre d'outils"
		p.bord.Color = BOIS_BORD
		p.pop.Scale = 1
	else
		local assez = argent() + 1e-6 >= prix()
		p.piece.Visible = true
		p.vg.Enabled = true
		p.valeur.Text = argentTexte(prix())
		p.valeur.TextColor3 = BLANC
		-- tu as assez d'argent : le panneau brille doucement
		p.bord.Color = assez and OR or BOIS_BORD
		p.pop.Scale = assez and 1 + 0.05 * math.abs(math.sin(t * 3)) or 1
	end
end

-- on cache le bouton "Acheter" si on l'a déjà
local function majBouton()
	if not panneau then return end
	local prompt = panneau.base:FindFirstChildOfClass("ProximityPrompt")
	if prompt then prompt.Enabled = not lp:GetAttribute("Faucille") end
end

task.spawn(function()
	local vitrine = workspace:FindFirstChild("FaucilleVitrine", true)
	for _ = 1, 30 do
		if vitrine then break end
		task.wait(1)
		vitrine = workspace:FindFirstChild("FaucilleVitrine", true)
	end
	if not vitrine then return end
	creerPanneau(vitrine)
	majBouton()
	if panneau then panneau.base.ChildAdded:Connect(majBouton) end
end)
lp:GetAttributeChangedSignal("Faucille"):Connect(majBouton)

RunService.RenderStepped:Connect(function()
	if not panneau then return end
	local proche = (cam.CFrame.Position - panneau.base.Position).Magnitude < 80
	panneau.g.Enabled = proche and not lp:GetAttribute("IntroEnCours")
	if panneau.g.Enabled then majPanneau(os.clock()) end
end)

---------------------------------------------------------------- Réponse du serveur
local ecran = Instance.new("ScreenGui")
ecran.Name = "FaucilleMessages"
ecran.ResetOnSpawn = false
ecran.DisplayOrder = 20
ecran.Parent = pgui

local function son(id, vol)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol or 0.6
	s.Parent = ecran
	s:Play()
	game:GetService("Debris"):AddItem(s, 4)
end

local function message(t, couleur, duree)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, 0.3)
	l.Size = UDim2.fromScale(0.7, 0.1)
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = t
	l.TextColor3 = couleur
	l.Parent = ecran
	local st = contour(l, 5, ENCRE)
	local sc = Instance.new("UIScale")
	sc.Scale = 0
	sc.Parent = l
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(duree, function()
		TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 1, Position = UDim2.fromScale(0.5, 0.25) }):Play()
		TweenService:Create(st, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		task.wait(0.35)
		l:Destroy()
	end)
end

achat.OnClientEvent:Connect(function(quoi, manque)
	if quoi == "ok" then
		son("rbxassetid://129348077985519", 0.7)
		message("✨ FAUCILLE ACHETÉE ! ✨", OR, 2.2)
	elseif quoi == "manque" then
		message("Il te manque " .. argentTexte(math.max(0, tonumber(manque) or 0)), ROUGE, 1.6)
		-- le prix tremble en rouge
		if panneau then
			local p = panneau
			task.spawn(function()
				for i = 1, 8 do
					p.valeur.TextColor3 = ROUGE
					p.root.Rotation = (i % 2 == 0 and 3 or -3)
					task.wait(0.04)
				end
				p.root.Rotation = 0
				p.valeur.TextColor3 = BLANC
			end)
		end
	end
end)
