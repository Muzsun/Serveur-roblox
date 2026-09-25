-- GrassServer (Script dans ServerScriptService)
-- ANTI-LAG : le serveur ne crée AUCUNE pièce d'herbe. Il garde seulement la liste des touffes
-- (position, taille, rareté). Chaque joueur affiche lui-même les touffes proches de lui.
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
				tufts[nextId]={id=nextId,p=p,yaw=math.random()*math.pi*2,s=tuftScale(),r=rar,
					seed=math.random(1,1000000000),size=RAR[rar].size,door=isDoor,group=group}
				if isDoor then doorTotal+=1 end
				if group then groupTotal[group]=(groupTotal[group] or 0)+1 end
				addGrid(p)
				total+=1
			end
		end
		if i%40==0 then task.wait() end
	end
	ready=true
	-- compteur d'herbe (utilisé par la porte à cadenas)
	remotes:SetAttribute("GrassTotal",total)
	remotes:SetAttribute("GrassLeft",total)
	remotes:SetAttribute("DoorTotal",doorTotal)
	remotes:SetAttribute("DoorLeft",doorTotal)
	for g,n in groupTotal do remotes:SetAttribute("Total_"..g,n) remotes:SetAttribute("Left_"..g,n) end
	print("[Herbe] Zones trouvées :",#zones," | Touffes créées :",total)
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
	local hrp=hrpOf(plr)
	if not hrp or (hrp.Position-t.p).Magnitude>CFG.CLICK_DIST+8 then return end
	local now=os.clock()
	local bag,max=plr:GetAttribute("Bag") or 0,plr:GetAttribute("BagMax") or CFG.BAG_CAPACITY
	if bag+t.size>max then
		if not lastFull[plr] or now-lastFull[plr]>.4 then lastFull[plr]=now BagFull:FireClient(plr,id,t.size,max-bag) end
		return
	end
	-- Dextérité : chaque niveau réduit le délai de 15%
	local cd=math.max(.2,(CFG.PICK_COOLDOWN or .9)*(1-.15*(plr:GetAttribute("Upg_Dexterite") or 0)))
	if lastPick[plr] and now-lastPick[plr]<cd then return end
	lastPick[plr]=now
	local function take(tid,tt)
		tufts[tid]=nil -- ramassée pour de bon : elle ne repousse pas
		remotes:SetAttribute("GrassLeft",math.max(0,(remotes:GetAttribute("GrassLeft") or 1)-1))
		if tt.door then remotes:SetAttribute("DoorLeft",math.max(0,(remotes:GetAttribute("DoorLeft") or 1)-1)) end
		if tt.group then local k="Left_"..tt.group remotes:SetAttribute(k,math.max(0,(remotes:GetAttribute(k) or 1)-1)) end
		Picked:FireAllClients(tid,plr,tt.size,tt.r)
		plr:SetAttribute("Bag",(plr:GetAttribute("Bag") or 0)+tt.size)
	end
	take(id,t)
	-- Saisir : attrape aussi 1 herbe proche de plus par niveau
	local extra=plr:GetAttribute("Upg_Saisir") or 0
	if extra>0 then
		local got=0
		for id2,t2 in tufts do
			if got>=extra then break end
			if (t2.p-t.p).Magnitude<=8 and (plr:GetAttribute("Bag") or 0)+t2.size<=max then take(id2,t2) got+=1 end
		end
	end
end)

-- ===== AMÉLIORATIONS (menu TAB) =====
-- Garde les mêmes id / prix / max que dans InventoryUI.
local UPGRADES={
	Maintenir={price=1.00,max=1},  -- rester appuyé sur clic gauche = ramasse en continu
	Dexterite={price=0.50,max=5},  -- ramasse plus vite (-15% de délai par niveau)
	Saisir={price=0.75,max=5},     -- +1 herbe proche attrapée en même temps par niveau
}
local function applyUpgrades(plr)
	plr:SetAttribute("BagMax",CFG.BAG_CAPACITY)
end
Players.PlayerAdded:Connect(function(p) task.wait(1) applyUpgrades(p) end)
for _,p in Players:GetPlayers() do task.spawn(applyUpgrades,p) end
local BuyUpgrade=RS:FindFirstChild("BuyUpgrade") or Instance.new("RemoteEvent")
BuyUpgrade.Name="BuyUpgrade" BuyUpgrade.Parent=RS
local lastBuy={}
BuyUpgrade.OnServerEvent:Connect(function(plr,uid)
	local u=typeof(uid)=="string" and UPGRADES[uid] if not u then return end
	local now=os.clock() if lastBuy[plr] and now-lastBuy[plr]<.3 then return end lastBuy[plr]=now
	local lvl=plr:GetAttribute("Upg_"..uid) or 0
	if lvl>=u.max then return end
	local m=moneyStat(plr) if not m or (tonumber(m.Value) or 0)<u.price then return end
	m.Value=math.floor(((tonumber(m.Value) or 0)-u.price)*100+.5)/100
	plr:SetAttribute("Upg_"..uid,lvl+1)
	applyUpgrades(plr)
end)
