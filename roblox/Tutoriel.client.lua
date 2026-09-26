-- Tutoriel (LocalScript dans StarterPlayer > StarterPlayerScripts)
-- Tutoriel sans texte : des icônes et des flèches montrent quoi faire.
-- 1) couper l'herbe  2) vendre au composteur  3) acheter une amélioration dans BOOSTS.
-- Il s'arrête après le premier achat.
if not game:GetService("RunService"):IsClient() then
	warn("[Tutoriel] Tutoriel doit être un LocalScript dans StarterPlayer > StarterPlayerScripts !")
	return
end

local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local TS=game:GetService("TweenService")
local CS=game:GetService("CollectionService")
local UIS=game:GetService("UserInputService")
local lp=Players.LocalPlayer
local cam=workspace.CurrentCamera
local pgui=lp:WaitForChild("PlayerGui")

-- images du jeu
local IMG={
	ciseaux="rbxassetid://98821470151953",
	sac="rbxassetid://124953051791395",
	piece="rbxassetid://103593634628600",
	boost="rbxassetid://113918337226531",
}
local SEUIL_VENTE=.8 -- on montre le composteur quand le sac est rempli à 80 %

local WHITE=Color3.new(1,1,1)
local INK=Color3.fromRGB(20,26,22)
local GREEN=Color3.fromRGB(70,200,90)
local TOUCH=UIS.TouchEnabled and not UIS.KeyboardEnabled
local K=TOUCH and .75 or 1 -- tout un peu plus petit sur téléphone

-- ===== le tutoriel est-il déjà fini ? =====
local UPGRADES={"Maintenir","Dexterite","Saisir"}
local function fini()
	for _,id in UPGRADES do if (lp:GetAttribute("Upg_"..id) or 0)>0 then return true end end
	return false
end
if fini() then return end

-- ===== petits outils de dessin =====
local function new(cls,props,parent)
	local o=Instance.new(cls)
	for k,v in props do o[k]=v end
	if parent then o.Parent=parent end
	return o
end
local function round(o) new("UICorner",{CornerRadius=UDim.new(1,0)},o) end

-- flèche épaisse vers le bas (contour foncé + blanc), dans un cadre w × 1.2w
local function drawArrow(parent,w,color)
	local box=new("Frame",{BackgroundTransparency=1,Size=UDim2.fromOffset(w,w*1.2)},parent)
	local inner=new("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},box)
	local H=w*1.2
	for layer=1,2 do
		local col=layer==1 and INK or (color or WHITE)
		local t=layer==1 and w*.3 or w*.19 -- épaisseur
		local grow=layer==1 and w*.06 or 0
		local stem=new("Frame",{BorderSizePixel=0,BackgroundColor3=col,AnchorPoint=Vector2.new(.5,0),
			Position=UDim2.fromOffset(w/2,-grow),Size=UDim2.fromOffset(t,H*.82+grow*2),ZIndex=layer},inner)
		round(stem)
		local L=w*.62+grow*2
		for s=-1,1,2 do
			local bar=new("Frame",{BorderSizePixel=0,BackgroundColor3=col,AnchorPoint=Vector2.new(.5,.5),
				Position=UDim2.fromOffset(w/2+s*w*.2,H-w*.22),Size=UDim2.fromOffset(t,L),Rotation=s*45,ZIndex=layer},inner)
			round(bar)
		end
	end
	return box,inner
end

-- disque blanc avec une (ou deux) image(s)
local function iconDisc(parent,size,image,extra)
	local d=new("Frame",{BackgroundColor3=WHITE,Size=UDim2.fromOffset(size,size),ZIndex=3},parent)
	round(d)
	new("UIStroke",{Thickness=4,Color=INK},d)
	new("ImageLabel",{BackgroundTransparency=1,Image=image,ScaleType=Enum.ScaleType.Fit,AnchorPoint=Vector2.new(.5,.5),
		Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.82,.82),ZIndex=4},d)
	if extra then -- petite image en bas à droite (ex : pièce sur le sac)
		new("ImageLabel",{BackgroundTransparency=1,Image=extra,ScaleType=Enum.ScaleType.Fit,AnchorPoint=Vector2.new(.5,.5),
			Position=UDim2.fromScale(.86,.84),Size=UDim2.fromScale(.5,.5),ZIndex=5},d)
	end
	return d
end

-- onde qui s'agrandit autour d'un bouton
local function ripple(parent,rond)
	local r=new("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,rond and .45 or .5),
		Size=UDim2.fromScale(1,1),ZIndex=60},parent)
	if rond then new("UIAspectRatioConstraint",{AspectRatio=1},r) round(r)
	else new("UICorner",{CornerRadius=UDim.new(.35,0)},r) end
	local st=new("UIStroke",{Thickness=5,Color=WHITE},r)
	local grand=rond and UDim2.fromScale(1.6,1.6) or UDim2.fromScale(1.18,1.5)
	task.spawn(function()
		while r.Parent do
			r.Size=UDim2.fromScale(1,1) st.Transparency=0
			TS:Create(r,TweenInfo.new(.9,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=grand}):Play()
			local t=TS:Create(st,TweenInfo.new(.9),{Transparency=1}) t:Play() t.Completed:Wait()
		end
	end)
	return r
end

-- ===== écran du tutoriel =====
local gui=new("ScreenGui",{Name="Tutoriel",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=30,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},pgui)

-- repère dans le monde : icône + flèche qui rebondit au-dessus de la cible
local anchor=new("Attachment",{},workspace.Terrain)
local marker=new("BillboardGui",{Adornee=anchor,Size=UDim2.fromOffset(90*K,150*K),AlwaysOnTop=true,LightInfluence=0,
	StudsOffsetWorldSpace=Vector3.new(0,2.2,0),Enabled=false,ResetOnSpawn=false},pgui)
local markerIcon=nil
local markerArrowBox,markerArrow=drawArrow(marker,46*K)
markerArrowBox.AnchorPoint=Vector2.new(.5,1) markerArrowBox.Position=UDim2.fromScale(.5,1)

-- flèche au bord de l'écran quand la cible est hors de vue
local edge=new("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(70*K,70*K),Visible=false},gui)
local edgeIcon=nil
local edgeRot=new("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(0,0)},edge)
local edgeArrowBox=drawArrow(edgeRot,34*K)
edgeArrowBox.AnchorPoint=Vector2.new(.5,0) edgeArrowBox.Position=UDim2.fromOffset(0,40*K)

local function setIcons(image,extra)
	if markerIcon then markerIcon:Destroy() end
	if edgeIcon then edgeIcon:Destroy() end
	markerIcon=iconDisc(marker,66*K,image,extra)
	markerIcon.AnchorPoint=Vector2.new(.5,0) markerIcon.Position=UDim2.fromScale(.5,0)
	edgeIcon=iconDisc(edge,64*K,image,extra)
	edgeIcon.AnchorPoint=Vector2.new(.5,.5) edgeIcon.Position=UDim2.fromScale(.5,.5)
end

-- flèches + ondes accrochées à un bouton de l'interface (barre d'outils, BOOSTS, prix)
local attached,bouncing={},{}
local function clearAttached()
	for _,o in attached do o:Destroy() end
	table.clear(attached) table.clear(bouncing)
end
local function attachTo(target,side,size,rond)
	-- side = "haut" (flèche au-dessus, vers le bas) ou "gauche" (flèche à gauche, vers la droite)
	local holder=new("Frame",{BackgroundTransparency=1,Size=UDim2.fromOffset(0,0),ZIndex=30},target)
	if side=="gauche" then
		holder.Position=UDim2.new(0,-8,.45,0) holder.Rotation=-90
	else
		holder.Position=UDim2.new(.5,0,0,-6) holder.Rotation=0
	end
	local box,inner=drawArrow(holder,size*K)
	box.AnchorPoint=Vector2.new(.5,1) box.Position=UDim2.fromOffset(0,-8)
	for _,d in box:GetDescendants() do if d:IsA("GuiObject") then d.ZIndex+=40 end end
	table.insert(attached,holder)
	table.insert(attached,ripple(target,rond))
	table.insert(bouncing,inner)
	return box
end

-- ===== cibles =====
local function character() return lp.Character end
local function hrp() local c=character() return c and c:FindFirstChild("HumanoidRootPart") end
local function holdingScissors()
	local c=character()
	local t=c and c:FindFirstChildOfClass("Tool")
	return t~=nil and (CS:HasTag(t,"OutilCiseaux") or t.Name=="Ciseaux")
end
local function nearestTuft()
	local folder=workspace:FindFirstChild("GrassHit")
	local r=hrp()
	if not folder or not r then return nil end
	local best,bd=nil,math.huge
	for _,p in folder:GetChildren() do
		if p:IsA("BasePart") then
			local d=(p.Position-r.Position).Magnitude
			if d<bd then best,bd=p,d end
		end
	end
	return best and best.Position+Vector3.new(0,best.Size.Y/2,0)
end
local function nearestCompost()
	local r=hrp()
	if not r then return nil end
	local best,bd=nil,math.huge
	for _,c in CS:GetTagged("GrassCompost") do
		if c:IsA("Model") then
			local cf,size=c:GetBoundingBox()
			local d=(cf.Position-r.Position).Magnitude
			if d<bd then best,bd=cf.Position+Vector3.new(0,size.Y/2,0),d end
		end
	end
	return best
end
-- cherche un écran (ScreenGui) par son nom : le script InventoryUI porte le même nom que son menu !
local function findScreen(name)
	for _,g in pgui:GetChildren() do
		if g:IsA("ScreenGui") and g.Name==name then return g end
	end
	return nil
end
local buttonsCache={}
local function buyButtons()
	if #buttonsCache>0 and buttonsCache[1].Parent then return buttonsCache end
	table.clear(buttonsCache)
	local inv=findScreen("InventoryUI")
	if inv then
		for _,d in inv:GetDescendants() do
			if d:IsA("GuiButton") and d:GetAttribute("UpgradeId") then table.insert(buttonsCache,d) end
		end
	end
	return buttonsCache
end
local function shown(o)
	while o and o:IsA("GuiObject") do
		if not o.Visible then return false end
		o=o.Parent
	end
	return true
end
local function anyAffordable()
	for _,b in buyButtons() do if b:GetAttribute("Achetable") then return true end end
	return false
end
local function affordableVisibleButton()
	for _,b in buyButtons() do if b:GetAttribute("Achetable") and shown(b) then return b end end
	return nil
end

-- ===== intro : ✂ ➜ 🎒 ➜ 🪙 ➜ ⬆ =====
local function intro()
	local strip=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.3),Size=UDim2.fromOffset(0,110*K),
		AutomaticSize=Enum.AutomaticSize.X,BackgroundColor3=Color3.fromRGB(14,24,16),BackgroundTransparency=.35},gui)
	new("UICorner",{CornerRadius=UDim.new(0,28)},strip)
	new("UIPadding",{PaddingLeft=UDim.new(0,18*K),PaddingRight=UDim.new(0,18*K)},strip)
	new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,VerticalAlignment=Enum.VerticalAlignment.Center,
		HorizontalAlignment=Enum.HorizontalAlignment.Center,Padding=UDim.new(0,10*K),SortOrder=Enum.SortOrder.LayoutOrder},strip)
	local stripScale=new("UIScale",{},strip)
	local items={}
	local steps={{IMG.ciseaux},{IMG.sac},{IMG.sac,IMG.piece},{IMG.boost}}
	for i,st in steps do
		local slot=new("Frame",{BackgroundTransparency=1,Size=UDim2.fromOffset(84*K,84*K),LayoutOrder=i*2},strip)
		local d=iconDisc(slot,84*K,st[1],st[2])
		local sc=new("UIScale",{Scale=0},d)
		table.insert(items,sc)
		if i<#steps then
			local aslot=new("Frame",{BackgroundTransparency=1,Size=UDim2.fromOffset(40*K,84*K),LayoutOrder=i*2+1},strip)
			local rot=new("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
				Size=UDim2.fromOffset(0,0),Rotation=-90},aslot)
			local box=drawArrow(rot,30*K)
			box.AnchorPoint=Vector2.new(.5,.5) box.Position=UDim2.fromOffset(0,0)
			local asc=new("UIScale",{Scale=0},box)
			table.insert(items,asc)
		end
	end
	for _,sc in items do
		TS:Create(sc,TweenInfo.new(.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
		task.wait(.22)
	end
	task.wait(2.6)
	local t=TS:Create(stripScale,TweenInfo.new(.3,Enum.EasingStyle.Back,Enum.EasingDirection.In),{Scale=0})
	t:Play() t.Completed:Wait()
	strip:Destroy()
end

-- ===== bravo : grand ✓ vert =====
local function bravo()
	local d=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.4),Size=UDim2.fromOffset(130*K,130*K),BackgroundColor3=GREEN},gui)
	round(d)
	new("UIStroke",{Thickness=6,Color=INK},d)
	local w=130*K
	for layer=1,2 do
		local col=layer==1 and INK or WHITE
		local t=layer==1 and w*.16 or w*.1
		local short=new("Frame",{BorderSizePixel=0,BackgroundColor3=col,AnchorPoint=Vector2.new(.5,.5),
			Position=UDim2.fromOffset(w*.36,w*.56),Size=UDim2.fromOffset(t,w*.3),Rotation=-45,ZIndex=layer+1},d)
		round(short)
		local long=new("Frame",{BorderSizePixel=0,BackgroundColor3=col,AnchorPoint=Vector2.new(.5,.5),
			Position=UDim2.fromOffset(w*.56,w*.46),Size=UDim2.fromOffset(t,w*.56),Rotation=40,ZIndex=layer+1},d)
		round(long)
	end
	local sc=new("UIScale",{Scale=0},d)
	TS:Create(sc,TweenInfo.new(.45,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
	task.wait(1.4)
	local t=TS:Create(sc,TweenInfo.new(.3,Enum.EasingStyle.Back,Enum.EasingDirection.In),{Scale=0})
	t:Play() t.Completed:Wait()
end

-- ===== première vente =====
-- après la première vente, on laisse le joueur couper tranquille ;
-- on revient seulement quand il peut acheter sa première amélioration.
local aVendu=false
task.spawn(function()
	local remotes=game:GetService("ReplicatedStorage"):WaitForChild("GrassRemotes",30)
	local dep=remotes and remotes:WaitForChild("Deposited",30)
	if dep then dep.OnClientEvent:Connect(function(plr) if plr==lp then aVendu=true end end) end
end)

-- ===== boucle du tutoriel =====
local step,target=nil,nil
local function decide()
	if fini() then return "fin" end
	if lp:GetAttribute("IntroEnCours") then return "rien" end -- on attend la fin de l'intro du chiot
	if lp:GetAttribute("MenuOuvert") then return "menu" end
	if anyAffordable() then return "acheter" end
	if aVendu then return "rien" end
	local bag,max=lp:GetAttribute("Bag") or 0,lp:GetAttribute("BagMax") or 25
	if bag>0 and bag>=max*SEUIL_VENTE then return "vendre" end
	if not holdingScissors() then return "outil" end
	return "couper"
end

local function enterStep(s)
	step=s
	clearAttached()
	marker.Enabled=false edge.Visible=false
	if s=="couper" then setIcons(IMG.ciseaux)
	elseif s=="vendre" then setIcons(IMG.sac,IMG.piece)
	elseif s=="outil" then
		-- montre la bulle des ciseaux dans la barre d'outils
		local barre=findScreen("BarreOutils")
		local slot=barre and barre:FindFirstChild("Ciseaux",true)
		if slot then attachTo(slot,"haut",40,true) end
	elseif s=="acheter" then
		-- montre le bouton BOOSTS
		local b=findScreen("BoostsBouton")
		local holder=b and b:FindFirstChild("BoostsHolder")
		if holder then attachTo(holder,"gauche",36,true) end -- petite flèche vers BOOSTS
	end
end

local menuButton=nil
local acc=0
local conn
conn=Run.RenderStepped:Connect(function(dt)
	acc+=dt
	if acc>=.25 then
		acc=0
		local s=decide()
		if s=="fin" then
			conn:Disconnect()
			clearAttached()
			marker.Enabled=false edge.Visible=false
			task.spawn(function() bravo() gui:Destroy() marker:Destroy() anchor:Destroy() end)
			return
		end
		if s~=step then enterStep(s) menuButton=nil end
		-- dans le menu : flèche sur le bouton de prix à acheter
		if s=="menu" then
			local b=affordableVisibleButton()
			if b~=menuButton then
				clearAttached()
				menuButton=b
				if b then attachTo(b,"haut",36,false) end
			end
		end
		target=(s=="couper" and nearestTuft()) or (s=="vendre" and nearestCompost()) or nil
	end
	local bounce=math.abs(math.sin(os.clock()*5))*8*K
	for _,inner in bouncing do inner.Position=UDim2.fromOffset(0,bounce) end
	-- repère dans le monde ou au bord de l'écran
	if not target then marker.Enabled=false edge.Visible=false return end
	anchor.WorldPosition=target
	local p,onScreen=cam:WorldToViewportPoint(target+Vector3.new(0,2.2,0))
	if onScreen and p.Z>0 then
		marker.Enabled=true edge.Visible=false
		markerArrow.Position=UDim2.fromOffset(0,bounce) -- rebond
	else
		marker.Enabled=false edge.Visible=true
		local v=cam.ViewportSize
		local c=Vector2.new(v.X/2,v.Y/2)
		local d=Vector2.new(p.X,p.Y)-c
		if p.Z<0 then d=-d end
		if d.Magnitude<1 then d=Vector2.new(0,1) end
		local m=80*K
		local sx=(v.X/2-m)/math.max(math.abs(d.X),1e-3)
		local sy=(v.Y/2-m)/math.max(math.abs(d.Y),1e-3)
		local pos=c+d*math.min(sx,sy)
		edge.Position=UDim2.fromOffset(pos.X,pos.Y)
		edgeRot.Rotation=math.deg(math.atan2(d.Y,d.X))-90
	end
end)

-- l'intro au tout début
task.spawn(function()
	if not lp.Character then lp.CharacterAdded:Wait() end
	task.wait(1.5)
	while lp:GetAttribute("IntroEnCours") do task.wait(0.25) end -- après l'intro du chiot
	if not fini() then intro() end
end)
