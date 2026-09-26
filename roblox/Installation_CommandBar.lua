local f
for _, s in {workspace, game.ServerScriptService, game.ServerStorage, game.ReplicatedStorage} do f = f or s:FindFirstChild("InstallationCiseaux", true) end
if not f then warn("Insère d'abord InstallationCiseaux.rbxmx (clic droit sur Workspace > Insérer depuis un fichier)") return end
local bak = game.ServerStorage:FindFirstChild("AnciensScripts") or Instance.new("Folder")
bak.Name = "AnciensScripts" bak.Parent = game.ServerStorage
local noms = {GrassServer = true, GrassClient = true, CiseauxServer = true, BoutiqueCiseaux = true}
local marques = {"GrassServer (Script", "GrassClient (LocalScript", "BoutiqueCiseaux", "CiseauxServer (Script", "CISEAUX : coupe les touffes"}
local n = 0
for _, service in {workspace, game.ServerScriptService, game.ReplicatedStorage, game.ReplicatedFirst, game.StarterPlayer, game.StarterGui, game.StarterPack} do
	for _, s in service:GetDescendants() do
		if s:IsA("Script") and not s:IsDescendantOf(f) then
			local ok, src = pcall(function() return s.Source end)
			local ancien = noms[s.Name]
			if ok and not ancien then for _, m in marques do if src:find(m, 1, true) then ancien = true break end end end
			if ancien then s.Enabled = false s.Name ..= "_ANCIEN" s.Parent = bak n += 1 end
		end
	end
end
f.CiseauxServer.Parent = game.ServerScriptService
f.GrassServer.Parent = game.ServerScriptService
f.GrassClient.Parent = game.StarterPlayer.StarterPlayerScripts
f:Destroy()
for _, m in {"GrassConfig", "GrassKit"} do
	local mod = game.ReplicatedStorage:FindFirstChild(m)
	local ok = mod and mod:IsA("ModuleScript") and pcall(require, mod)
	print(m, if ok then "OK" else "PROBLÈME : vérifie ce ModuleScript dans ReplicatedStorage")
end
print(("Installation terminée ! %d ancien(s) script(s) rangé(s) dans ServerStorage > AnciensScripts"):format(n))
