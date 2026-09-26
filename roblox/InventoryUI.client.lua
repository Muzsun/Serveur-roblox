-- InventoryUI (LocalScript dans StarterGui)
-- Menu des améliorations des outils : bouton BOOSTS (ou touche TAB) -> panneau au centre.
if not game:GetService("RunService"):IsClient() then
	warn("[Améliorations] InventoryUI doit être un LocalScript dans StarterGui !")
	return
end

local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local TS=game:GetService("TweenService")
local UIS=game:GetService("UserInputService")
local Lighting=game:GetService("Lighting")
local StarterGui=game:GetService("StarterGui")
local GuiService=game:GetService("GuiService")
local player=Players.LocalPlayer
local cam=workspace.CurrentCamera

-- plateformes : téléphone / tablette (pas de clavier) et manette (PlayStation / Xbox)
local TOUCH=UIS.TouchEnabled and not UIS.KeyboardEnabled
local PADS={[Enum.UserInputType.Gamepad1]=true,[Enum.UserInputType.Gamepad2]=true,[Enum.UserInputType.Gamepad3]=true,[Enum.UserInputType.Gamepad4]=true}
local function usingGamepad() return PADS[UIS:GetLastInputType()]==true end

-- ================= À COMPLÉTER =================
local BAG_ICON="rbxassetid://113918337226531"
local TAB_ICON="rbxassetid://91367185656178"
local COIN_ICON="rbxassetid://103593634628600"      -- image de la pièce (vide = pièce dessinée)
local CLICK_SOUND="rbxassetid://129348077985519"
local MONEY_STAT=""     -- nom de ta monnaie dans leaderstats ("" = auto : Money, Cash, Argent...)
-- Outils et leurs améliorations. Le niveau est l'attribut du joueur "Upg_<id>".
-- Le prix et le niveau max viennent de GrassServer (UPGRADES) ; ceux d'ici servent si le serveur ne répond pas.
local OUTILS={
	{name="Ciseaux",icon="rbxassetid://98821470151953",color=Color3.fromRGB(255,120,110),items={
		{id="Maintenir",name="Maintenir",icon="rbxassetid://71762308286130",price=1.10,max=1,
			desc="Reste appuyé sur le clic pour couper en continu là où tu vises."},
		{id="Dexterite",name="Dextérité",icon="rbxassetid://78716197209384",price=0.60,max=5,
			desc="Tes ciseaux coupent un peu plus vite : -8 % d'attente par niveau."},
		{id="Saisir",name="Saisir",icon="rbxassetid://120921144181867",price=0.85,max=2,
			desc="Chaque coup coupe aussi une touffe voisine de plus par niveau."},
	}},
	-- requires = il faut posséder l'outil (attribut du joueur) pour acheter ses améliorations
	{name="Faucille",icon="rbxassetid://138905055767473",color=Color3.fromRGB(120,190,255),requires="Faucille",items={
		{id="FMaintenir",name="Maintenir",icon="rbxassetid://71762308286130",price=3.50,max=1,
			desc="Reste appuyé sur le clic pour faucher en continu."},
		{id="FRapidite",name="Rapidité",icon="rbxassetid://78716197209384",price=2.00,max=5,
			desc="Ta faucille frappe plus vite : -8 % d'attente par niveau."},
		{id="FCoupe",name="Coupe supplémentaire",icon="rbxassetid://120921144181867",price=3.00,max=2,
			desc="+1 touffe par coup de faucille : 3, puis 4, puis 5 touffes."},
	}},
	{name="Débroussailleuse",locked=true,color=Color3.fromRGB(150,220,110),items={{locked=true},{locked=true},{locked=true}}},
}
-- ===============================================

local INK=Color3.fromRGB(20,30,22)
local WHITE=Color3.new(1,1,1)
local CREAM=Color3.fromRGB(252,249,240)
local CREAM2=Color3.fromRGB(236,230,212)
local GRAY_TEXT=Color3.fromRGB(104,98,86)
local EMPTY_PIP=Color3.fromRGB(222,214,196)

local function new(cls,props,parent)
	local o=Instance.new(cls)
	for k,v in props do o[k]=v end
	if parent then o.Parent=parent end
	return o
end
local function corner(p,r) return new("UICorner",{CornerRadius=r or UDim.new(0,14)},p) end
local function stroke(p,th,col,tr,text)
	local s=new("UIStroke",{Thickness=th,Color=col or INK,Transparency=tr or 0,LineJoinMode=Enum.LineJoinMode.Round})
	if not text then s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border end
	s.Parent=p return s
end
local function seq(colors)
	local k={} for i,c in ipairs(colors) do k[i]=ColorSequenceKeypoint.new((i-1)/(#colors-1),c) end
	return ColorSequence.new(k)
end
local function gradient(p,colors,rot)
	p.BackgroundColor3=WHITE
	return new("UIGradient",{Rotation=rot or 90,Color=seq(colors)},p)
end
local function lbl(parent,t,pos,size,o)
	o=o or {}
	local l=new("TextLabel",{BackgroundTransparency=1,Text=t,Font=o.font or Enum.Font.FredokaOne,TextScaled=true,
		TextWrapped=o.wrap or false,Position=pos,Size=size,TextColor3=o.color or INK,
		TextXAlignment=o.align or Enum.TextXAlignment.Left,TextTransparency=o.transp or 0,
		AnchorPoint=o.anchor or Vector2.zero,ZIndex=o.z or 3},parent)
	if o.stroke then stroke(l,o.stroke,o.strokeColor or INK,0,true) end
	if o.grad then l.TextColor3=WHITE new("UIGradient",{Rotation=90,Color=seq(o.grad)},l) end
	if l.Font==Enum.Font.LuckiestGuy then new("UIPadding",{PaddingTop=UDim.new(.1,0)},l) end
	return l
end
local function lighter(c,a) return c:Lerp(WHITE,a or .45) end

local gui=new("ScreenGui",{Name="InventoryUI",ResetOnSpawn=false,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=10},player:WaitForChild("PlayerGui"))
local clickSound=new("Sound",{SoundId=CLICK_SOUND,Volume=1},gui)
local function playClick() clickSound.TimePosition=0 clickSound:Play() end

-- cadenas dessiné
local function padlock(parent,z)
	local dark=Color3.fromRGB(34,40,36)
	local sh=new("Frame",{AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,.16),Size=UDim2.fromScale(.4,.46),BackgroundTransparency=1,ZIndex=z},parent)
	corner(sh,UDim.new(1,0)) stroke(sh,4,dark)
	local body=new("Frame",{AnchorPoint=Vector2.new(.5,1),Position=UDim2.fromScale(.5,.84),Size=UDim2.fromScale(.6,.42),BackgroundColor3=dark,ZIndex=z+1},parent)
	corner(body,UDim.new(.22,0))
	local hole=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.16,.38),BackgroundColor3=Color3.fromRGB(120,230,130),ZIndex=z+2},body)
	corner(hole,UDim.new(1,0))
end

-- ================= PRIX / NIVEAUX / ARGENT =================
local buyRemote=RS:FindFirstChild("BuyUpgrade")
local moneyValue
local function money() return moneyValue and tonumber(moneyValue.Value) or 0 end
local function level(it) return player:GetAttribute("Upg_"..it.id) or 0 end
-- prix du prochain niveau : envoyé par GrassServer pour chaque niveau (sinon prix de base × Growth^niveau)
local function price(it)
	local exact=buyRemote and buyRemote:GetAttribute("Price_"..it.id.."_"..(level(it)+1))
	if exact then return exact end
	local base=(buyRemote and buyRemote:GetAttribute("Price_"..it.id)) or it.price
	local growth=(buyRemote and buyRemote:GetAttribute("Growth")) or 1.5
	return math.floor(base*growth^level(it)*100+.5)/100
end
local function owned(outil) return not outil.requires or player:GetAttribute(outil.requires)==true end
local function maxLevel(it) return (buyRemote and buyRemote:GetAttribute("Max_"..it.id)) or it.max end
local function fmt(v) return string.format("%.2f$",v) end

-- ================= BOUTON BOOSTS (à droite de l'écran) =================
local SIZE=138
-- le bouton a son propre écran, dans la zone sûre (encoche des téléphones, bords des télés)
local boostGui=new("ScreenGui",{Name="BoostsBouton",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=9},player:WaitForChild("PlayerGui"))
pcall(function() boostGui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets end)
local holder=new("Frame",{Name="BoostsHolder",BackgroundTransparency=1,AnchorPoint=Vector2.new(1,.5),
	Position=UDim2.new(1,-16,.5,0),Size=UDim2.fromOffset(SIZE,SIZE+10)},boostGui)
local fitScale=new("UIScale",{},holder)
local function fit()
	local s=math.clamp(cam.ViewportSize.Y/900,.45,1)
	if TOUCH then s=math.clamp(s,.45,.6) end
	fitScale.Scale=s
end
fit() cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
local button=new("TextButton",{Name="Boosts",Text="",AutoButtonColor=false,Size=UDim2.fromScale(1,1),BackgroundTransparency=1},holder)
local disc=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.44),Size=UDim2.fromScale(.84,.8),ZIndex=2},button)
new("UIAspectRatioConstraint",{AspectRatio=1},disc)
corner(disc,UDim.new(1,0)) stroke(disc,4)
gradient(disc,{Color3.fromRGB(96,170,96),Color3.fromRGB(38,86,48)})
local discRim=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(1,-10,1,-10),BackgroundTransparency=1,ZIndex=2},disc)
corner(discRim,UDim.new(1,0)) stroke(discRim,2,WHITE,.55)
local icon=new("ImageLabel",{BackgroundTransparency=1,Image=BAG_ICON,ScaleType=Enum.ScaleType.Fit,AnchorPoint=Vector2.new(.5,.5),
	Position=UDim2.fromScale(.5,.4),Size=UDim2.fromScale(.95,.9),ZIndex=5},button)
lbl(button,"BOOSTS",UDim2.new(0,-10,1,-34),UDim2.new(1,20,0,34),{font=Enum.Font.LuckiestGuy,align=Enum.TextXAlignment.Center,stroke=4,grad={WHITE,Color3.fromRGB(210,255,190)},z=6})
local tabKey=new("ImageLabel",{Name="TabKey",BackgroundTransparency=1,Image=TAB_ICON,ScaleType=Enum.ScaleType.Fit,AnchorPoint=Vector2.new(.5,.5),
	Position=UDim2.fromOffset(8,10),Size=UDim2.fromOffset(60,40),Rotation=-10,ZIndex=8,Visible=not TOUCH},button)
-- manette : icône du bouton Y / Triangle
local padKey=new("Frame",{Name="PadKey",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(12,12),
	Size=UDim2.fromOffset(44,44),ZIndex=8,Visible=false},button)
local padImage="" pcall(function() padImage=UIS:GetImageForKeyCode(Enum.KeyCode.ButtonY) end)
if padImage~="" then new("ImageLabel",{BackgroundTransparency=1,Image=padImage,ScaleType=Enum.ScaleType.Fit,Size=UDim2.fromScale(1,1),ZIndex=8},padKey)
else lbl(padKey,"Y",UDim2.fromScale(0,0),UDim2.fromScale(1,1),{font=Enum.Font.LuckiestGuy,color=WHITE,stroke=3,align=Enum.TextXAlignment.Center,z=8}) end
-- pastille "!" quand une amélioration est achetable
local badge=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.88,.12),Size=UDim2.fromOffset(36,36),Visible=false,ZIndex=9},button)
corner(badge,UDim.new(1,0)) stroke(badge,3)
gradient(badge,{Color3.fromRGB(150,255,120),Color3.fromRGB(40,180,60)})
lbl(badge,"!",UDim2.fromScale(.15,.08),UDim2.fromScale(.7,.84),{font=Enum.Font.LuckiestGuy,color=WHITE,stroke=2,align=Enum.TextXAlignment.Center,z=10})
local badgeScale=new("UIScale",{},badge)
TS:Create(badgeScale,TweenInfo.new(.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Scale=1.18}):Play()
local bScale=new("UIScale",{},button)
local hovered=false
local function upd()
	TS:Create(bScale,TweenInfo.new(.12,Enum.EasingStyle.Quad),{Scale=hovered and 1.08 or 1}):Play()
	TS:Create(icon,TweenInfo.new(.15,Enum.EasingStyle.Back),{Rotation=hovered and -8 or 0}):Play()
end
button.MouseEnter:Connect(function() hovered=true upd() end)
button.MouseLeave:Connect(function() hovered=false upd() end)

-- ================= FOND =================
local backdrop=new("TextButton",{Name="Backdrop",Text="",AutoButtonColor=false,Size=UDim2.fromScale(1,1),Selectable=false,
	BackgroundColor3=Color3.fromRGB(6,14,8),BackgroundTransparency=1,Visible=false,ZIndex=20},gui)
local blur=new("BlurEffect",{Name="InventoryBlur",Size=0},Lighting)

-- ================= PANNEAU =================
local panel=new("CanvasGroup",{Name="Panel",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
	Size=UDim2.fromScale(.9,.86),BackgroundTransparency=1,GroupTransparency=1,Visible=false,ZIndex=21},gui)
local panelRatio=new("UIAspectRatioConstraint",{AspectRatio=1.7},panel)
new("UISizeConstraint",{MaxSize=Vector2.new(1180,700)},panel)
local pScale=new("UIScale",{},panel)
local card=new("Frame",{Name="Card",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(1,-16,1,-16)},panel)
corner(card,UDim.new(0,28)) stroke(card,5)
gradient(card,{Color3.fromRGB(66,124,74),Color3.fromRGB(30,66,42)})
local rim=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(1,-14,1,-14),BackgroundTransparency=1},card)
corner(rim,UDim.new(0,24)) stroke(rim,2,WHITE,.7)
-- reflet doux en haut
local shine=new("Frame",{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,8),Size=UDim2.new(1,-24,.13,0),BackgroundColor3=WHITE,BorderSizePixel=0},card)
corner(shine,UDim.new(0,22))
new("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.82),NumberSequenceKeypoint.new(1,1)})},shine)

-- en-tête
local rIcon=new("ImageLabel",{BackgroundTransparency=1,Image=BAG_ICON,ScaleType=Enum.ScaleType.Fit,AnchorPoint=Vector2.new(.5,.5),
	Position=UDim2.fromScale(.075,.085),Size=UDim2.fromScale(.1,.17),Rotation=-12,ZIndex=6},card)
lbl(card,"AMÉLIORATIONS",UDim2.fromScale(.13,.035),UDim2.fromScale(.44,.1),{font=Enum.Font.LuckiestGuy,stroke=4,grad={WHITE,Color3.fromRGB(215,255,190)},z=5})

-- argent
local moneyPill=new("Frame",{Position=UDim2.fromScale(.66,.04),Size=UDim2.fromScale(.215,.09),BackgroundColor3=Color3.fromRGB(14,34,20),BackgroundTransparency=.05,ZIndex=4},card)
corner(moneyPill,UDim.new(1,0)) stroke(moneyPill,3)
local coin=new("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.02,.5),Size=UDim2.fromScale(.3,1.35),ZIndex=6},moneyPill)
new("UIAspectRatioConstraint",{AspectRatio=1,DominantAxis=Enum.DominantAxis.Height},coin)
if COIN_ICON~="" then
	new("ImageLabel",{BackgroundTransparency=1,Image=COIN_ICON,ScaleType=Enum.ScaleType.Fit,Size=UDim2.fromScale(1,1),ZIndex=6},coin)
else
	local c=new("Frame",{Size=UDim2.fromScale(1,1),ZIndex=6},coin)
	corner(c,UDim.new(1,0)) stroke(c,3)
	gradient(c,{Color3.fromRGB(255,226,110),Color3.fromRGB(240,150,30)})
	lbl(c,"$",UDim2.fromScale(.15,.12),UDim2.fromScale(.7,.8),{font=Enum.Font.LuckiestGuy,color=WHITE,stroke=2,align=Enum.TextXAlignment.Center,z=7})
end
local moneyLbl=lbl(moneyPill,"$0.00",UDim2.fromScale(.24,.1),UDim2.fromScale(.7,.82),{font=Enum.Font.LuckiestGuy,align=Enum.TextXAlignment.Right,stroke=3,grad={WHITE,Color3.fromRGB(255,228,140)},z=5})

-- bouton fermer
local close=new("TextButton",{Name="Close",Text="",AutoButtonColor=false,AnchorPoint=Vector2.new(.5,.5),
	Position=UDim2.fromScale(.945,.085),Size=UDim2.fromScale(.065,.11),ZIndex=10},card)
new("UIAspectRatioConstraint",{AspectRatio=1},close)
corner(close,UDim.new(1,0)) stroke(close,4)
gradient(close,{Color3.fromRGB(255,150,140),Color3.fromRGB(235,60,55),Color3.fromRGB(160,24,30)})
for layer=1,2 do
	for _,rot in {45,-45} do
		local b=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
			Size=layer==1 and UDim2.fromScale(.62,.22) or UDim2.fromScale(.52,.12),Rotation=rot,
			BackgroundColor3=layer==1 and INK or WHITE,BorderSizePixel=0,ZIndex=layer==1 and 11 or 12},close)
		corner(b,UDim.new(1,0))
	end
end
local closeScale=new("UIScale",{},close)
close.MouseEnter:Connect(function() TS:Create(closeScale,TweenInfo.new(.12),{Scale=1.12}):Play() end)
close.MouseLeave:Connect(function() TS:Create(closeScale,TweenInfo.new(.12),{Scale=1}):Play() end)

-- titres des colonnes
lbl(card,"OUTILS",UDim2.fromScale(.03,.165),UDim2.fromScale(.26,.05),{color=WHITE,transp=.15,z=3})
local pageTitle=lbl(card,"",UDim2.fromScale(.32,.165),UDim2.fromScale(.6,.05),{color=WHITE,transp=.15,z=3})
local aide=lbl(card,"",UDim2.fromScale(.32,.915),UDim2.fromScale(.65,.045),
	{color=WHITE,transp=.4,align=Enum.TextXAlignment.Center,z=3})
local descs={} -- descriptions (cachées sur les petits écrans pour rester lisible)

local tabsFrame=new("Frame",{BackgroundTransparency=1,Position=UDim2.fromScale(.03,.225),Size=UDim2.fromScale(.265,.68)},card)
new("UIListLayout",{Padding=UDim.new(.04,0),SortOrder=Enum.SortOrder.LayoutOrder},tabsFrame)
local pagesFrame=new("Frame",{BackgroundTransparency=1,Position=UDim2.fromScale(.32,.225),Size=UDim2.fromScale(.65,.68)},card)

-- ================= ONGLETS + LIGNES =================
local tabs,rows={},{}
local current=1
local selectOutil -- défini plus bas

local function buyStyle(r,style)
	local faces={
		green={{Color3.fromRGB(160,244,118),Color3.fromRGB(56,170,62)},{Color3.fromRGB(36,112,42),Color3.fromRGB(20,68,26)},WHITE},
		gray={{Color3.fromRGB(226,222,208),Color3.fromRGB(186,182,168)},{Color3.fromRGB(140,136,124),Color3.fromRGB(104,100,90)},Color3.fromRGB(110,104,94)},
		gold={{Color3.fromRGB(255,232,120),Color3.fromRGB(240,160,30)},{Color3.fromRGB(170,100,12),Color3.fromRGB(110,62,6)},WHITE},
	}
	local f=faces[style]
	r.faceGrad.Color=seq(f[1]) r.baseGrad.Color=seq(f[2]) r.buyText.TextColor3=f[3]
	r.buyStroke.Enabled=f[3]==WHITE
end

local function makeRow(page,outil,item,i)
	local row=new("Frame",{Size=UDim2.fromScale(1,.3),LayoutOrder=i,ZIndex=3},page)
	corner(row,UDim.new(.22,0))
	local st=stroke(row,3)
	gradient(row,item.locked and {Color3.fromRGB(206,208,196),Color3.fromRGB(176,180,166)} or {CREAM,CREAM2})
	local sc=new("UIScale",{},row)
	-- icône
	local ih=new("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(0,.5),Position=UDim2.fromScale(.022,.5),Size=UDim2.fromScale(.2,.78),ZIndex=4},row)
	new("UIAspectRatioConstraint",{AspectRatio=1,DominantAxis=Enum.DominantAxis.Height},ih)
	local plate=new("Frame",{Size=UDim2.fromScale(1,1),ZIndex=4},ih)
	corner(plate,UDim.new(.28,0)) stroke(plate,2.5)
	if item.locked then
		gradient(plate,{Color3.fromRGB(236,232,220),Color3.fromRGB(200,196,184)})
		padlock(plate,5)
	else
		gradient(plate,{lighter(outil.color,.6),lighter(outil.color,.15)})
		new("ImageLabel",{BackgroundTransparency=1,Image=item.icon or "",ScaleType=Enum.ScaleType.Fit,AnchorPoint=Vector2.new(.5,.5),
			Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1.15,1.15),ZIndex=5},plate)
	end
	-- textes
	lbl(row,item.locked and "???" or item.name,UDim2.fromScale(.19,.1),UDim2.fromScale(.4,.3),{z=4})
	local descLbl=lbl(row,item.locked and "Bientôt disponible" or item.desc or "",UDim2.fromScale(.19,.42),UDim2.fromScale(.5,.26),{z=4,color=GRAY_TEXT,wrap=true})
	table.insert(descs,descLbl)
	-- niveau
	local pips,lv={},nil
	if not item.locked then
		local mx=item.max
		local w=(.37-(mx-1)*.012)/mx
		for p=1,mx do
			local f=new("Frame",{Position=UDim2.fromScale(.19+(p-1)*(w+.012),.74),Size=UDim2.fromScale(w,.12),BackgroundColor3=EMPTY_PIP,ZIndex=4},row)
			corner(f,UDim.new(1,0)) stroke(f,1.5,Color3.fromRGB(130,112,92))
			pips[p]={frame=f,scale=new("UIScale",{},f)}
		end
		lv=lbl(row,"",UDim2.fromScale(.59,.66),UDim2.fromScale(.11,.26),{z=4,color=GRAY_TEXT,align=Enum.TextXAlignment.Right})
	end
	-- bouton d'achat en relief
	local buy=new("TextButton",{Text="",AutoButtonColor=false,AnchorPoint=Vector2.new(1,.5),Position=UDim2.fromScale(.975,.5),
		Size=UDim2.fromScale(.26,.62),BackgroundTransparency=1,ZIndex=4},row)
	buy:SetAttribute("UpgradeId",item.id or "") -- repère pour le tutoriel
	local base=new("Frame",{Position=UDim2.fromScale(0,.12),Size=UDim2.fromScale(1,.88),ZIndex=4},buy)
	corner(base,UDim.new(.35,0)) stroke(base,3)
	local baseGrad=gradient(base,{WHITE,WHITE})
	local face=new("Frame",{Size=UDim2.fromScale(1,.88),ZIndex=5},buy)
	corner(face,UDim.new(.35,0)) stroke(face,3)
	local faceGrad=gradient(face,{WHITE,WHITE})
	local gloss=new("Frame",{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,3),Size=UDim2.new(1,-12,.42,0),BackgroundColor3=WHITE,BorderSizePixel=0,ZIndex=5},face)
	corner(gloss,UDim.new(1,0))
	new("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(1,1)})},gloss)
	local buyText=lbl(face,"",UDim2.fromScale(.08,.12),UDim2.fromScale(.84,.76),{font=Enum.Font.LuckiestGuy,color=WHITE,align=Enum.TextXAlignment.Center,z=7})
	local buyStroke=stroke(buyText,2.5,INK,0,true)
	local buyScale=new("UIScale",{},buy)
	local r={row=row,stroke=st,scale=sc,item=item,outil=outil,pips=pips,lv=lv,buy=buy,face=face,faceGrad=faceGrad,desc=descLbl,
		baseGrad=baseGrad,buyText=buyText,buyStroke=buyStroke,buyScale=buyScale,lastLevel=item.locked and 0 or level(item)}
	table.insert(rows,r)

	buy.MouseEnter:Connect(function() TS:Create(buyScale,TweenInfo.new(.12),{Scale=1.06}):Play() end)
	buy.MouseLeave:Connect(function() TS:Create(buyScale,TweenInfo.new(.12),{Scale=1}):Play() face.Position=UDim2.fromScale(0,0) end)
	buy.MouseButton1Down:Connect(function() face.Position=UDim2.fromScale(0,.1) end)
	buy.MouseButton1Up:Connect(function() face.Position=UDim2.fromScale(0,0) end)
	buy.Activated:Connect(function()
		playClick()
		if item.locked or level(item)>=maxLevel(item) then return end
		if not owned(outil) or money()<price(item) then
			-- pas assez d'argent : le bouton tremble
			local p0=buy.Position
			for k=1,4 do
				TS:Create(buy,TweenInfo.new(.04),{Position=p0+UDim2.fromOffset(k%2==0 and -5 or 5,0)}):Play() task.wait(.04)
			end
			buy.Position=p0
			return
		end
		if buyRemote then buyRemote:FireServer(item.id)
		else warn("[Améliorations] RemoteEvent 'BuyUpgrade' introuvable dans ReplicatedStorage (GrassServer le crée)") end
	end)
	row.MouseEnter:Connect(function() st.Color=Color3.fromRGB(255,214,90) end)
	row.MouseLeave:Connect(function() st.Color=INK end)
end

for i,outil in ipairs(OUTILS) do
	-- onglet
	local t=new("TextButton",{Text="",AutoButtonColor=false,Size=UDim2.fromScale(1,.3),LayoutOrder=i,ZIndex=3},tabsFrame)
	corner(t,UDim.new(.24,0))
	local st=stroke(t,3)
	local grad=gradient(t,{WHITE,WHITE})
	local sc=new("UIScale",{},t)
	local ih=new("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(0,.5),Position=UDim2.fromScale(.05,.5),Size=UDim2.fromScale(.3,.76),ZIndex=4},t)
	new("UIAspectRatioConstraint",{AspectRatio=1,DominantAxis=Enum.DominantAxis.Height},ih)
	local d=new("Frame",{Size=UDim2.fromScale(1,1),ZIndex=4},ih)
	corner(d,UDim.new(1,0)) stroke(d,2.5)
	if outil.locked then
		gradient(d,{Color3.fromRGB(236,232,220),Color3.fromRGB(196,192,180)})
		padlock(d,5)
	else
		gradient(d,{lighter(outil.color,.65),lighter(outil.color,.2)})
		new("ImageLabel",{BackgroundTransparency=1,Image=outil.icon or "",ScaleType=Enum.ScaleType.Fit,AnchorPoint=Vector2.new(.5,.5),
			Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.92,.92),Rotation=-15,ZIndex=5},d)
	end
	lbl(t,outil.name,UDim2.fromScale(.42,.14),UDim2.fromScale(.54,.4),{z=4,color=WHITE,stroke=2.5})
	local sub=lbl(t,"",UDim2.fromScale(.42,.58),UDim2.fromScale(.54,.26),{z=4,color=WHITE,transp=.15})
	tabs[i]={btn=t,stroke=st,grad=grad,scale=sc,sub=sub,outil=outil}
	t.Activated:Connect(function() playClick() selectOutil(i) end)
	t.MouseEnter:Connect(function() if current~=i then TS:Create(sc,TweenInfo.new(.12),{Scale=1.04}):Play() end end)
	t.MouseLeave:Connect(function() if current~=i then TS:Create(sc,TweenInfo.new(.12),{Scale=1}):Play() end end)
	-- page des améliorations de cet outil
	local page=new("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Visible=false},pagesFrame)
	new("UIListLayout",{Padding=UDim.new(.05,0),SortOrder=Enum.SortOrder.LayoutOrder},page)
	tabs[i].page=page
	for j,item in ipairs(outil.items) do makeRow(page,outil,item,j) end
end

-- ================= MISE À JOUR =================
local function affordable()
	for _,r in rows do
		local it=r.item
		if not it.locked and owned(r.outil) and level(it)<maxLevel(it) and money()>=price(it) then return true end
	end
	return false
end

local open=false
local function refresh()
	moneyLbl.Text=string.format("$%.2f",money())
	for _,r in rows do
		local it=r.item
		if it.locked then
			buyStyle(r,"gray") r.buyText.Text="BIENTÔT"
			r.buy:SetAttribute("Achetable",false)
		else
			local l,mx=level(it),maxLevel(it)
			r.buy:SetAttribute("Achetable",l<mx and money()>=price(it)) -- utilisé par le tutoriel
			for p,pip in r.pips do pip.frame.BackgroundColor3=p<=l and r.outil.color or EMPTY_PIP end
			r.lv.Text=l>=mx and "MAX" or ("NIV "..l.."/"..mx)
			r.desc.Text=owned(r.outil) and (it.desc or "") or ("Achète d'abord la "..r.outil.name:lower().." à l'établi !")
			if not owned(r.outil) then
				-- outil pas encore acheté : améliorations bloquées
				buyStyle(r,"gray") r.buyText.Text="BLOQUÉ"
				r.buy:SetAttribute("Achetable",false)
			elseif l>=mx then buyStyle(r,"gold") r.buyText.Text="MAX"
			else
				buyStyle(r,money()>=price(it) and "green" or "gray")
				r.buyText.Text=fmt(price(it))
			end
			-- achat réussi : la ligne et la barre font un petit "pop"
			if l>r.lastLevel then
				r.scale.Scale=1.06
				TS:Create(r.scale,TweenInfo.new(.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
				local pip=r.pips[l]
				if pip then
					pip.scale.Scale=1.8
					TS:Create(pip.scale,TweenInfo.new(.4,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
				end
			end
			r.lastLevel=l
		end
	end
	for _,t in tabs do
		if t.outil.locked then t.sub.Text="Bientôt"
		elseif not owned(t.outil) then t.sub.Text="À acheter"
		else
			local total,maxi=0,0
			for _,it in t.outil.items do if not it.locked then total+=level(it) maxi+=maxLevel(it) end end
			t.sub.Text="Niveau "..total.."/"..maxi
		end
	end
	badge.Visible=not open and affordable()
end

selectOutil=function(i)
	current=i
	for k,t in tabs do
		local on=k==i
		t.page.Visible=on
		if on then
			t.grad.Color=seq({Color3.fromRGB(255,222,110),Color3.fromRGB(236,152,36)})
			t.stroke.Thickness=4
			TS:Create(t.scale,TweenInfo.new(.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1.06}):Play()
		else
			t.grad.Color=t.outil.locked and seq({Color3.fromRGB(110,122,112),Color3.fromRGB(74,84,76)}) or seq({Color3.fromRGB(96,158,100),Color3.fromRGB(52,104,62)})
			t.stroke.Thickness=3
			TS:Create(t.scale,TweenInfo.new(.15),{Scale=1}):Play()
		end
	end
	pageTitle.Text="Améliorations : "..OUTILS[i].name
	-- les lignes arrivent une par une
	for j,r in rows do
		if r.outil==OUTILS[i] then
			r.scale.Scale=.7
			task.delay(.03*j,function()
				TS:Create(r.scale,TweenInfo.new(.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
			end)
		end
	end
end

player.AttributeChanged:Connect(function(a) if a:sub(1,4)=="Upg_" or a=="Faucille" then refresh() end end)
task.spawn(function()
	buyRemote=buyRemote or RS:WaitForChild("BuyUpgrade",20)
	if buyRemote then buyRemote.AttributeChanged:Connect(refresh) refresh() end
end)
task.spawn(function()
	local ls=player:WaitForChild("leaderstats",15) if not ls then return end
	for _=1,40 do
		if MONEY_STAT~="" then moneyValue=ls:FindFirstChild(MONEY_STAT)
		else for _,n in {"Money","Cash","Argent","Coins","Dollars","$"} do moneyValue=ls:FindFirstChild(n) if moneyValue then break end end end
		if moneyValue then break end task.wait(.25)
	end
	if moneyValue then moneyValue.Changed:Connect(refresh) end
	refresh()
end)
selectOutil(1)
refresh()

-- ================= ADAPTATION À L'APPAREIL =================
local function adapter()
	local pad=usingGamepad()
	tabKey.Visible=not TOUCH and not pad
	padKey.Visible=pad
	aide.Text=pad and "A (Croix) : acheter   •   B (Rond) : fermer"
		or TOUCH and "Touche un prix pour acheter"
		or "Clique sur un prix pour acheter   •   TAB pour fermer"
	-- petit écran (téléphone) : panneau plus grand et sans descriptions
	local small=cam.ViewportSize.Y<520
	panel.Size=small and UDim2.fromScale(.98,.96) or UDim2.fromScale(.9,.86)
	panelRatio.AspectRatio=small and 1.9 or 1.7
	for _,d in descs do d.Visible=not small end
end
adapter()
UIS.LastInputTypeChanged:Connect(adapter)
cam:GetPropertyChangedSignal("ViewportSize"):Connect(adapter)

-- manette : sélectionne le premier bouton utile du menu
local function selectionManette()
	if not usingGamepad() then return end
	for _,r in rows do
		if r.outil==OUTILS[current] and not r.item.locked then GuiService.SelectedObject=r.buy return end
	end
	GuiService.SelectedObject=tabs[current].btn
end

-- ================= OUVERTURE / FERMETURE =================
local busy=false
local function setOpen(v)
	if busy or v==open then return end
	busy=true open=v
	-- 1re personne : libère la souris quand le panneau est ouvert (Modal)
	backdrop.Modal=v
	UIS.MouseIconEnabled=true
	player:SetAttribute("MenuOuvert",v) -- les ciseaux ne coupent pas pendant que le menu est ouvert
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,not v) end)
	if v then
		refresh()
		selectOutil(current)
		backdrop.Visible=true panel.Visible=true
		pScale.Scale=.6 panel.Position=UDim2.new(.5,0,.5,60) panel.GroupTransparency=1
		TS:Create(backdrop,TweenInfo.new(.25),{BackgroundTransparency=.4}):Play()
		TS:Create(blur,TweenInfo.new(.3),{Size=16}):Play()
		TS:Create(panel,TweenInfo.new(.2),{GroupTransparency=0}):Play()
		TS:Create(panel,TweenInfo.new(.45,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=UDim2.fromScale(.5,.5)}):Play()
		rIcon.Rotation=-45
		TS:Create(rIcon,TweenInfo.new(.6,Enum.EasingStyle.Elastic,Enum.EasingDirection.Out),{Rotation=-12}):Play()
		local t=TS:Create(pScale,TweenInfo.new(.42,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1})
		t:Play() t.Completed:Wait()
		selectionManette()
	else
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then GuiService.SelectedObject=nil end
		TS:Create(backdrop,TweenInfo.new(.2),{BackgroundTransparency=1}):Play()
		TS:Create(blur,TweenInfo.new(.2),{Size=0}):Play()
		TS:Create(panel,TweenInfo.new(.2),{GroupTransparency=1,Position=UDim2.new(.5,0,.5,40)}):Play()
		local t=TS:Create(pScale,TweenInfo.new(.22,Enum.EasingStyle.Back,Enum.EasingDirection.In),{Scale=.7})
		t:Play() t.Completed:Wait()
		backdrop.Visible=false panel.Visible=false
		refresh()
	end
	busy=false
end

button.Activated:Connect(function() playClick() setOpen(not open) end)
close.Activated:Connect(function() playClick() setOpen(false) end)
backdrop.MouseButton1Click:Connect(function() setOpen(false) end)
-- Tab est aussi utilisé par Roblox (liste des joueurs) : on ne tient pas compte de "gp",
-- on ignore seulement quand le joueur écrit dans le chat / une zone de texte.
-- Manette : Y / Triangle ouvre ou ferme, B / Rond ferme.
UIS.InputBegan:Connect(function(input)
	if UIS:GetFocusedTextBox() then return end
	if input.KeyCode==Enum.KeyCode.Tab or input.KeyCode==Enum.KeyCode.ButtonY then setOpen(not open)
	elseif input.KeyCode==Enum.KeyCode.ButtonB and open then setOpen(false) end
end)
