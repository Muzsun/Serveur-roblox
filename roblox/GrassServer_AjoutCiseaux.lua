-- ===== CISEAUX : coupe les touffes proches (appelé par le script BoutiqueCiseaux) =====
-- À coller TOUT EN BAS du script GrassServer.
local CutGrass=game:GetService("ServerStorage"):FindFirstChild("CutGrassArea") or Instance.new("BindableFunction")
CutGrass.Name="CutGrassArea" CutGrass.Parent=game:GetService("ServerStorage")
CutGrass.OnInvoke=function(plr,center,radius,maxCount)
	if not ready then return 0 end
	local max=plr:GetAttribute("BagMax") or CFG.BAG_CAPACITY
	-- touffes dans le rayon, les plus proches d'abord
	local near={}
	for id,t in tufts do
		local dx,dz=t.p.X-center.X,t.p.Z-center.Z
		local d2=dx*dx+dz*dz
		if d2<=radius*radius and math.abs(t.p.Y-center.Y)<6 then table.insert(near,{id,t,d2}) end
	end
	table.sort(near,function(a,b) return a[3]<b[3] end)
	local got,blocked=0,nil
	for _,e in near do
		if got>=maxCount then break end
		local id,t=e[1],e[2]
		local bag=plr:GetAttribute("Bag") or 0
		if bag+t.size<=max then
			tufts[id]=nil
			remotes:SetAttribute("GrassLeft",math.max(0,(remotes:GetAttribute("GrassLeft") or 1)-1))
			if t.door then remotes:SetAttribute("DoorLeft",math.max(0,(remotes:GetAttribute("DoorLeft") or 1)-1)) end
			if t.group then local k="Left_"..t.group remotes:SetAttribute(k,math.max(0,(remotes:GetAttribute(k) or 1)-1)) end
			Picked:FireAllClients(id,plr,t.size,t.r)
			plr:SetAttribute("Bag",bag+t.size)
			got+=1
		elseif not blocked then blocked=e end
	end
	-- rien n'a pu rentrer dans le sac : même message que quand on arrache à la main
	if got==0 and blocked then
		local now=os.clock()
		if not lastFull[plr] or now-lastFull[plr]>.4 then
			lastFull[plr]=now
			BagFull:FireClient(plr,blocked[1],blocked[2].size,max-(plr:GetAttribute("Bag") or 0))
		end
	end
	return got
end
