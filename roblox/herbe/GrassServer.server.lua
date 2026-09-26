-- GrassServer (Script dans ServerScriptService)
-- ANTI-LAG : le serveur ne crée AUCUNE pièce d'herbe. Il garde seulement la liste des touffes
-- (position, taille, rareté). Chaque joueur affiche lui-même les touffes proches de lui.
if not game:GetService("RunService"):IsServer() then
	warn("[Herbe] GrassServer doit être un Script dans ServerScriptService (pas un LocalScript) !")
	return
end
print("[Herbe] GrassServer démarré")
local CS=game:GetService("CollectionService")
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local CFG=require(RS:WaitForChild("GrassConfig"))
local K=require(RS:WaitForChild("GrassKit"))

local remotes=RS:FindFirstChild("GrassRemotes") or Instance.new("Folder")
remotes.Name="GrassRemotes" remotes.Parent=RS
local function remote(n,cls)
	cls=cls or "RemoteEvent"
	local r=remotes:FindFirstChild(n)
	if r and r.ClassName~=cls then r:Destroy() r=nil end
	if not r then r=Instance.new(cls) r.Name=n r.Parent=remotes end
	return r
end
local Picked,BagFull,Deposited,PickRequest=remote("Picked"),remote("BagFull"),remote("Deposited"),remote("PickRequest")
local GetGrass=remote("GetGrass","RemoteFunction")
local NewGrass=remote("NewGrass") -- une nouvelle zone vient de pousser
local MONEY_PER_PLACE=CFG.MONEY_PER_PLACE or CFG.MONEY_PER_TUFT or 0
local SPACING=CFG.SPACING or 3

-- ===== raretés =====
local RAR,totalChance={},0
for _,r in CFG.RARITIES do RAR[r.name]=r totalChance+=r.chance end
local function rollRarity()
	local x=math.random()*totalChance
	for _,r in CFG.RARITIES do x-=r.chance if x<=0 then return r.name end end
	return CFG.RARITIES[1].name
end

-- ===== tailles très variées (par rapport à la taille de ton modèle Grass2) =====
local function tuftScale()
	local r=math.random()
	if r<.25 then return .7+math.random()*.15       -- 25% petites        (70-85%)
	elseif r<.6 then return 1.05+math.random()*.15 -- 35% moyennes       (105-120%)
	elseif r<.85 then return 1.35+math.random()*.15 -- 25% grosses       (135-150%)
	else return 1.75+math.random()*.15 end         -- 15% très grosses   (175-190%)
end

-- ===== joueurs =====
local MONEY_NAMES={"Money","Cash","Argent","Coins","Dollars","Pieces","Pièces","$"}
local function moneyStat(plr)
	local ls=plr:FindFirstChild("leaderstats") if not ls then return nil end
	if CFG.MONEY_STAT~="" then return ls:FindFirstChild(CFG.MONEY_STAT) end
	for _,n in MONEY_NAMES do
		local v=ls:FindFirstChild(n)
		if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then return v end
	end
end
local function initPlayer(p)
	p:SetAttribute("Bag",0)
	p:SetAttribute("BagMax",CFG.BAG_CAPACITY)
	local ls=p:FindFirstChild("leaderstats") or p:WaitForChild("leaderstats",5)
	if not ls then ls=Instance.new("Folder") ls.Name="leaderstats" ls.Parent=p end
	if not ls:FindFirstChild("Herbe") then local v=Instance.new("IntValue") v.Name="Herbe" v.Parent=ls end
	-- argent : créé s'il n'existe pas encore
	if not moneyStat(p) then local v=Instance.new("NumberValue") v.Name=CFG.MONEY_STAT~="" and CFG.MONEY_STAT or "Money" v.Parent=ls end
end
Players.PlayerAdded:Connect(initPlayer)
for _,p in Players:GetPlayers() do task.spawn(initPlayer,p) end
local lastPick,lastFull,lastDep={},{},{}
Players.PlayerRemoving:Connect(function(p) lastPick[p]=nil lastFull[p]=nil lastDep[p]=nil end)
local function hrpOf(plr) return plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") end

-- ===== outils de coupe : on ne peut couper l'herbe qu'avec un outil en main (ciseaux, faucille...) =====
local SCISSORS_EXTRA=CFG.SCISSORS_EXTRA or 0   -- touffes voisines coupées en plus à chaque coup (0 = une par une)
local SCISSORS_RADIUS=CFG.SCISSORS_RADIUS or 4 -- rayon autour de la touffe visée (studs)
-- un outil peut couper plus : attributs "CoupeEnPlus" (touffes en plus) et "RayonCoupe" (studs) sur l'outil
local function cutterTool(plr)
	local ch=plr.Character
	local tool=ch and ch:FindFirstChildOfClass("Tool")
	if tool and (CS:HasTag(tool,"OutilCiseaux") or CS:HasTag(tool,"OutilFaucille") or tool.Name=="Ciseaux" or tool:GetAttribute("CoupeEnPlus")~=nil) then return tool end
	return nil
end

-- ===== composteur =====
local composts={}
local function deposit(plr,c)
	local bag=plr:GetAttribute("Bag") or 0
	if bag<=0 then return end
	local now=os.clock()
	if lastDep[plr] and now-lastDep[plr]<1.5 then return end
	local hrp=hrpOf(plr)
	local cf,size=c:GetBoundingBox()
	if not hrp or (hrp.Position-cf.Position).Magnitude>math.max(size.X,size.Z)/2+14 then return end
	lastDep[plr]=now
	local ls=plr:FindFirstChild("leaderstats")
	local h=ls and ls:FindFirstChild("Herbe")
	if h then h.Value+=bag end
	local gain=0
	local m=moneyStat(plr)
	if m and MONEY_PER_PLACE>0 then
		gain=bag*MONEY_PER_PLACE
		if m:IsA("IntValue") then gain=math.max(1,math.floor(gain+.5)) m.Value+=gain
		else m.Value=math.floor((m.Value+gain)*100+.5)/100 end
	end
	Deposited:FireAllClients(plr,c,bag,gain)
	plr:SetAttribute("Bag",0)
	-- statistiques de fin de partie
	plr:SetAttribute("SacsVides",(plr:GetAttribute("SacsVides") or 0)+1)
	plr:SetAttribute("ArgentGagne",math.floor(((plr:GetAttribute("ArgentGagne") or 0)+gain)*100+.5)/100)
end
local function setupCompost(c)
	table.insert(composts,c)
	if c:FindFirstChild("GrassDepositHitbox") then return end
	local cf,size=c:GetBoundingBox()
	local hb=Instance.new("Part") hb.Name="GrassDepositHitbox"
	hb.Size=size+Vector3.new(1.2,0,1.2) hb.CFrame=cf hb.Transparency=1 hb.Anchored=true
	hb.CanCollide=false hb.CanTouch=true hb.CanQuery=true hb.CastShadow=false hb.Parent=c
	local cd=Instance.new("ClickDetector") cd.MaxActivationDistance=30 cd.Parent=hb
	cd.MouseClick:Connect(function(plr) deposit(plr,c) end)
	hb.Touched:Connect(function(part)
		local ch=part:FindFirstAncestorOfClass("Model")
		local plr=ch and Players:GetPlayerFromCharacter(ch)
		if plr then deposit(plr,c) end
	end)
	CS:AddTag(c,"GrassCompost")
end
for _,d in workspace:GetDescendants() do
	if d:IsA("Model") and d.Name==CFG.COMPOST_NAME then setupCompost(d) end
end
if #composts==0 then warn("[Herbe] Aucun modèle '"..CFG.COMPOST_NAME.."' trouvé dans Workspace") end

-- ===== zones de pelouse =====
local zones={}
local zf=workspace:FindFirstChild(CFG.ZONES_FOLDER)
local ZONE_COLOR=Color3.fromRGB(80,255,120)
for _,z in workspace:GetDescendants() do
	if z:IsA("BasePart") and ((zf and z:IsDescendantOf(zf)) or (z.Name:sub(1,4)=="Zone" and z.Color==ZONE_COLOR)) then
		z.Transparency=1 z.CanCollide=false z.CanQuery=false z.CanTouch=false
		table.insert(zones,z)
	end
end
if #zones==0 then warn("[Herbe] Aucune zone trouvée : pas d'herbe") end

-- ===== liste des touffes (pas de pièces !) =====
local tufts={}   -- [id] = {id, p=position, yaw, s=taille, r=rareté, seed, size=places}
local grid={}    -- grille pour vérifier l'espacement très vite
local function cellOf(x,z) return math.floor(x/SPACING),math.floor(z/SPACING) end
local function tooClose(p)
	local gx,gz=cellOf(p.X,p.Z)
	for dx=-1,1 do for dz=-1,1 do
		local cell=grid[(gx+dx)..":"..(gz+dz)]
		if cell then
			for _,q in cell do
				local a,b=q.X-p.X,q.Z-p.Z
				if a*a+b*b<SPACING*SPACING then return true end
			end
		end
	end end
	return false
end
local function addGrid(p)
	local gx,gz=cellOf(p.X,p.Z)
	local k=gx..":"..gz
	grid[k]=grid[k] or {}
	table.insert(grid[k],p)
end

local area=0 for _,z in zones do area+=z.Size.X*z.Size.Z end
local function randomSpot()
	for _=1,30 do
		local x,zone=math.random()*area,zones[#zones]
		for _,z in zones do x-=z.Size.X*z.Size.Z if x<=0 then zone=z break end end
		local lx,lz=(math.random()-.5)*zone.Size.X,(math.random()-.5)*zone.Size.Z
		local top=zone.CFrame:PointToWorldSpace(Vector3.new(lx,zone.Size.Y/2,lz))
		local bottom=zone.CFrame:PointToWorldSpace(Vector3.new(lx,-zone.Size.Y/2,lz))
		local hit=K.Cast(top+Vector3.new(0,20,0),Vector3.new(0,-(zone.Size.Y+40),0))
		if hit and hit.Position.Y<=top.Y+.5 and hit.Position.Y>=bottom.Y-.5 and not tooClose(hit.Position) then
			local ok=true
			for _,c in composts do
				local cf,sz=c:GetBoundingBox()
				local d=Vector3.new(cf.Position.X-hit.Position.X,0,cf.Position.Z-hit.Position.Z).Magnitude
				if d<math.max(sz.X,sz.Z)/2+1.5 then ok=false break end
			end
			if ok then return hit.Position end
		end
	end
end

local nextId,ready,total,doorTotal=0,false,0,0
-- ===== zones une par une =====
-- Au début, l'herbe ne pousse que dans la 1re zone. Quand elle est toute coupée, la zone suivante pousse, etc.
-- Ordre : ZonePorte -> ZoneParc -> ZoneLabyrinthe -> Zone -> ZoneStade (ou GrassConfig.ZONES_ORDER si tu le mets).
-- Une zone qui n'est pas dans la liste passe après, de la plus proche du spawn à la plus loin.
local PROGRESSIVE=CFG.ZONES_UNE_PAR_UNE~=false
local reserve={}          -- toutes les touffes créées (pas encore poussées)
local stages,stage={},0   -- ordre des zones, zone en cours
local stageLeft=0         -- touffes restantes dans la zone en cours
local nextStage -- (plus bas)
local groupTotal={}
local MIN2=(SPACING*.6)^2
task.spawn(function()
	-- remplissage en grille (avec un petit décalage aléatoire) : couvre toutes les zones sans trou
	local cands={}
	for _,zone in zones do
		local nx=math.max(1,math.floor(zone.Size.X/SPACING))
		local nz=math.max(1,math.floor(zone.Size.Z/SPACING))
		for ix=0,nx-1 do
			for iz=0,nz-1 do
				local lx=-zone.Size.X/2+(ix+.5+(math.random()-.5)*.7)*zone.Size.X/nx
				local lz=-zone.Size.Z/2+(iz+.5+(math.random()-.5)*.7)*zone.Size.Z/nz
				table.insert(cands,{zone,lx,lz})
			end
		end
	end
	for i=#cands,2,-1 do local j=math.random(1,i) cands[i],cands[j]=cands[j],cands[i] end
	for i,c in cands do
		if total>=CFG.SPAWN_COUNT then break end
		local zone,lx,lz=c[1],c[2],c[3]
		local top=zone.CFrame:PointToWorldSpace(Vector3.new(lx,zone.Size.Y/2,lz))
		local bottom=zone.CFrame:PointToWorldSpace(Vector3.new(lx,-zone.Size.Y/2,lz))
		local hit=K.Cast(top+Vector3.new(0,20,0),Vector3.new(0,-(zone.Size.Y+40),0))
		if hit and hit.Position.Y<=top.Y+.5 and hit.Position.Y>=bottom.Y-.5 then
			local p=hit.Position
			local ok=true
			-- pas collé à une autre touffe (utile si des zones se chevauchent)
			local gx,gz=cellOf(p.X,p.Z)
			for dx=-1,1 do for dz=-1,1 do
				local cell=grid[(gx+dx)..":"..(gz+dz)]
				if cell then for _,q in cell do local a,b=q.X-p.X,q.Z-p.Z if a*a+b*b<MIN2 then ok=false end end end
			end end
			if ok then
				for _,cp in composts do
					local cf,sz=cp:GetBoundingBox()
					if Vector3.new(cf.Position.X-p.X,0,cf.Position.Z-p.Z).Magnitude<math.max(sz.X,sz.Z)/2+1.5 then ok=false break end
				end
			end
			if ok then
				nextId+=1
				local rar=rollRarity()
				local isDoor=zone.Name=="ZonePorte"
				local group=zone.Name -- Zone, ZonePorte, ZoneLabyrinthe...
				reserve[#reserve+1]={id=nextId,p=p,yaw=math.random()*math.pi*2,s=tuftScale(),r=rar,
					seed=math.random(1,1000000000),size=RAR[rar].size,door=isDoor,group=group}
				if isDoor then doorTotal+=1 end
				if group then groupTotal[group]=(groupTotal[group] or 0)+1 end
				addGrid(p)
				total+=1
			end
		end
		if i%40==0 then task.wait() end
	end
	-- ordre des zones
	local byGroup,center={},{}
	for _,t in reserve do
		local g=t.group or "Zone"
		byGroup[g]=byGroup[g] or {}
		table.insert(byGroup[g],t)
		center[g]=(center[g] or Vector3.zero)+t.p
	end
	local spawnLoc=workspace:FindFirstChildWhichIsA("SpawnLocation",true)
	local origin=spawnLoc and spawnLoc.Position or Vector3.zero
	local rank={}
	-- ordre du jeu : Porte -> Parc -> Labyrinthe -> Zone -> Stade (modifiable avec GrassConfig.ZONES_ORDER)
	local order=typeof(CFG.ZONES_ORDER)=="table" and CFG.ZONES_ORDER or {"ZonePorte","ZoneParc","ZoneLabyrinthe","Zone","ZoneStade"}
	for i,n in order do rank[n]=i end
	for g,list in byGroup do table.insert(stages,{name=g,list=list,dist=(center[g]/#list-origin).Magnitude}) end
	table.sort(stages,function(a,b)
		local ra,rb=rank[a.name] or math.huge,rank[b.name] or math.huge
		if ra~=rb then return ra<rb end
		return a.dist<b.dist
	end)
	if not PROGRESSIVE then stages={{name="Tout",list=reserve}} end
	local noms={} for i,s in stages do noms[i]=s.name.." ("..#s.list..")" end
	print("[Herbe] Ordre des zones :",table.concat(noms," -> "))
	-- la 1re zone pousse tout de suite
	stage=1
	for _,t in stages[1] and stages[1].list or {} do tufts[t.id]=t end
	stageLeft=stages[1] and #stages[1].list or 0
	remotes:SetAttribute("ZoneEnCours",stages[1] and stages[1].name or "")
	remotes:SetAttribute("ZoneNumero",1)
	remotes:SetAttribute("ZonesTotal",#stages)
	ready=true
	-- compteur d'herbe (utilisé par la porte à cadenas)
	remotes:SetAttribute("GrassTotal",total)
	remotes:SetAttribute("GrassLeft",total)
	remotes:SetAttribute("DoorTotal",doorTotal)
	remotes:SetAttribute("DoorLeft",doorTotal)
	for g,n in groupTotal do remotes:SetAttribute("Total_"..g,n) remotes:SetAttribute("Left_"..g,n) end
	print("[Herbe] Zones trouvées :",#zones," | Touffes créées :",total)
end)

-- zone terminée : la suivante pousse (on saute les zones vides)
nextStage=function()
	if stageLeft>0 then return end
	while stage<#stages do
		stage+=1
		local s=stages[stage]
		if #s.list>0 then
			local out={}
			for _,t in s.list do
				tufts[t.id]=t
				table.insert(out,{t.id,t.p.X,t.p.Y,t.p.Z,t.yaw,t.s,t.r,t.seed,t.size})
			end
			stageLeft=#s.list
			remotes:SetAttribute("ZoneEnCours",s.name)
			remotes:SetAttribute("ZoneNumero",stage)
			NewGrass:FireAllClients(out,s.name)
			print("[Herbe] Zone terminée ! L'herbe pousse dans :",s.name,"("..#s.list.." touffes)")
			return
		end
	end
end

-- ===== TEST : finir la zone en cours d'un coup =====
-- En Play (barre de commande côté Server) : game.ServerStorage.TestFinirZone:Fire()
local testZone=game:GetService("ServerStorage"):FindFirstChild("TestFinirZone") or Instance.new("BindableEvent")
testZone.Name="TestFinirZone" testZone.Parent=game:GetService("ServerStorage")
-- plus simple : dans Studio, appuie sur la touche K en jouant (ne marche PAS dans le vrai jeu publié)
local testKey=remote("TestFinirZone")
testKey.OnServerEvent:Connect(function() if game:GetService("RunService"):IsStudio() then testZone:Fire() end end)
testZone.Event:Connect(function()
	local n=0
	for id,t in tufts do
		tufts[id]=nil n+=1
		remotes:SetAttribute("GrassLeft",math.max(0,(remotes:GetAttribute("GrassLeft") or 1)-1))
		if t.door then remotes:SetAttribute("DoorLeft",math.max(0,(remotes:GetAttribute("DoorLeft") or 1)-1)) end
		if t.group then local k="Left_"..t.group remotes:SetAttribute(k,math.max(0,(remotes:GetAttribute(k) or 1)-1)) end
		Picked:FireAllClients(id,nil,t.size,t.r)
	end
	stageLeft=0
	print("[Herbe] TEST : zone terminée ("..n.." touffes)")
	nextStage()
end)

-- chaque joueur récupère la liste au démarrage
GetGrass.OnServerInvoke=function()
	while not ready do task.wait(.1) end
	local out={}
	for _,t in tufts do
		table.insert(out,{t.id,t.p.X,t.p.Y,t.p.Z,t.yaw,t.s,t.r,t.seed,t.size})
	end
	return out
end

-- ===== arracher une touffe (le joueur envoie juste son numéro) =====
PickRequest.OnServerEvent:Connect(function(plr,id)
	if typeof(id)~="number" then return end
	local t=tufts[id] if not t then return end
	local tool=cutterTool(plr)
	if not tool then return end -- plus d'arrachage à la main
	local hrp=hrpOf(plr)
	if not hrp or (hrp.Position-t.p).Magnitude>CFG.CLICK_DIST+8 then return end
	local now=os.clock()
	local bag,max=plr:GetAttribute("Bag") or 0,plr:GetAttribute("BagMax") or CFG.BAG_CAPACITY
	if bag+t.size>max then
		if not lastFull[plr] or now-lastFull[plr]>.4 then lastFull[plr]=now BagFull:FireClient(plr,id,t.size,max-bag) end
		return
	end
	-- Dextérité : chaque niveau réduit le délai de DEX_PAR_NIVEAU (8 % par défaut)
	-- les améliorations (Dextérité, Saisir, Maintenir) ne marchent qu'avec les ciseaux
	-- chaque outil a ses améliorations : ciseaux (Dextérité, Saisir) / faucille (Rapidité, Coupe supplémentaire)
	local scissors=CS:HasTag(tool,"OutilCiseaux") or tool.Name=="Ciseaux"
	-- les autres outils ont un préfixe : F = faucille, D = débroussailleuse (Upg_<P>Rapidite, Upg_<P>Coupe)
	local pre=tool:GetAttribute("Prefixe") or ((CS:HasTag(tool,"OutilFaucille") or tool.Name=="Faucille") and "F") or nil
	local dex=scissors and (plr:GetAttribute("Upg_Dexterite") or 0) or pre and (plr:GetAttribute("Upg_"..pre.."Rapidite") or 0) or 0
	local cd=math.max(.2,(CFG.PICK_COOLDOWN or .9)*(1-(CFG.DEX_PAR_NIVEAU or .08)*dex))
	if lastPick[plr] and now-lastPick[plr]<cd then return end
	lastPick[plr]=now
	local function take(tid,tt)
		tufts[tid]=nil -- ramassée pour de bon : elle ne repousse pas
		stageLeft-=1
		if stageLeft<=0 then task.defer(nextStage) end
		remotes:SetAttribute("GrassLeft",math.max(0,(remotes:GetAttribute("GrassLeft") or 1)-1))
		if tt.door then remotes:SetAttribute("DoorLeft",math.max(0,(remotes:GetAttribute("DoorLeft") or 1)-1)) end
		if tt.group then local k="Left_"..tt.group remotes:SetAttribute(k,math.max(0,(remotes:GetAttribute(k) or 1)-1)) end
		Picked:FireAllClients(tid,plr,tt.size,tt.r)
		plr:SetAttribute("Bag",(plr:GetAttribute("Bag") or 0)+tt.size)
		-- statistiques de fin de partie
		plr:SetAttribute("TouffesCoupees",(plr:GetAttribute("TouffesCoupees") or 0)+1)
		if tt.r and tt.r~="Normal" then
			plr:SetAttribute("HerbesRares",(plr:GetAttribute("HerbesRares") or 0)+1)
			plr:SetAttribute("Rare_"..tt.r,(plr:GetAttribute("Rare_"..tt.r) or 0)+1)
		end
	end
	take(id,t)
	-- animation de coupe des ciseaux (script CiseauxServer)
	local anim=game:GetService("ServerStorage"):FindFirstChild("CiseauxCoupe")
	if anim then anim:Fire(plr) end
	-- outil + Saisir : coupe aussi les touffes voisines (les plus proches d'abord)
	local extra=SCISSORS_EXTRA+(scissors and (plr:GetAttribute("Upg_Saisir") or 0) or 0)+(pre and (plr:GetAttribute("Upg_"..pre.."Coupe") or 0)*(tonumber(tool:GetAttribute("CoupeParNiveau")) or 1) or 0)+(tonumber(tool:GetAttribute("CoupeEnPlus")) or 0)
	local radius=math.max(SCISSORS_RADIUS,tonumber(tool:GetAttribute("RayonCoupe")) or 0)
	if extra>0 then
		local near={}
		for id2,t2 in tufts do
			local d=(t2.p-t.p).Magnitude
			if d<=radius then table.insert(near,{id2,t2,d}) end
		end
		table.sort(near,function(a,b) return a[3]<b[3] end)
		local got=0
		for _,e in near do
			if got>=extra then break end
			if tufts[e[1]] and (plr:GetAttribute("Bag") or 0)+e[2].size<=max then take(e[1],e[2]) got+=1 end
		end
	end
end)

-- ===== AMÉLIORATIONS (menu TAB) =====
-- Les prix et niveaux max d'ici sont envoyés au menu InventoryUI (ce sont eux qui comptent).
local UPGRADES={
-- prices = prix de chaque niveau (niveau 1, niveau 2, ...)
	Maintenir={prices={1.10},max=1},                      -- rester appuyé = coupe en continu avec les ciseaux
	Dexterite={prices={0.60,0.90,1.35,2.00,3.00},max=5},  -- les ciseaux coupent plus vite
	Saisir={prices={0.85,1.90},max=2},                    -- +1 touffe voisine coupée en même temps par niveau
	-- FAUCILLE (il faut l'avoir achetée pour acheter ses améliorations)
	FMaintenir={prices={3.50},max=1,requires="Faucille"},                     -- rester appuyé = fauche en continu
	FRapidite={prices={2.00,3.00,4.50,6.50,9.00},max=5,requires="Faucille"},  -- la faucille frappe plus vite
	FCoupe={prices={3.00,5.00},max=2,requires="Faucille"},                    -- +1 touffe par niveau : 3 -> 4 -> 5 touffes par coup
	-- DÉBROUSSAILLEUSE (il faut l'avoir achetée)
	DMaintenir={prices={8.00},max=1,requires="Debroussailleuse"},                        -- rester appuyé = fauche en continu
	DRapidite={prices={5.00,7.50,11.00,16.00,22.00},max=5,requires="Debroussailleuse"}, -- elle fauche plus vite
	DCoupe={prices={8.00,14.00},max=2,requires="Debroussailleuse"},                      -- +2 touffes par niveau : 6 -> 8 -> 10
}
local GROWTH=1.5 -- seulement si un niveau n'a pas de prix dans la liste
local function cost(u,lvl)
	if u.prices[lvl+1] then return u.prices[lvl+1] end
	return math.floor(u.prices[#u.prices]*GROWTH^(lvl+1-#u.prices)*100+.5)/100
end
local function applyUpgrades(plr)
	plr:SetAttribute("BagMax",CFG.BAG_CAPACITY)
end
Players.PlayerAdded:Connect(function(p) task.wait(1) applyUpgrades(p) end)
for _,p in Players:GetPlayers() do task.spawn(applyUpgrades,p) end
local BuyUpgrade=RS:FindFirstChild("BuyUpgrade") or Instance.new("RemoteEvent")
BuyUpgrade.Name="BuyUpgrade" BuyUpgrade.Parent=RS
for uid,u in UPGRADES do
	BuyUpgrade:SetAttribute("Price_"..uid,cost(u,0)) BuyUpgrade:SetAttribute("Max_"..uid,u.max)
	for lvl=0,u.max-1 do BuyUpgrade:SetAttribute("Price_"..uid.."_"..(lvl+1),cost(u,lvl)) end -- prix de chaque niveau pour le menu
end
BuyUpgrade:SetAttribute("Growth",GROWTH)
local lastBuy={}
BuyUpgrade.OnServerEvent:Connect(function(plr,uid)
	local u=typeof(uid)=="string" and UPGRADES[uid] if not u then return end
	local now=os.clock() if lastBuy[plr] and now-lastBuy[plr]<.3 then return end lastBuy[plr]=now
	local lvl=plr:GetAttribute("Upg_"..uid) or 0
	if lvl>=u.max then return end
	if u.requires and not plr:GetAttribute(u.requires) then return end -- ex : acheter la faucille d'abord
	local c=cost(u,lvl)
	local m=moneyStat(plr) if not m or (tonumber(m.Value) or 0)<c then return end
	m.Value=math.floor(((tonumber(m.Value) or 0)-c)*100+.5)/100
	plr:SetAttribute("Upg_"..uid,lvl+1)
	applyUpgrades(plr)
end)
