-- Réglages du système d'herbe (ModuleScript dans ReplicatedStorage)
return {
	BAG_CAPACITY = 25,            -- places dans le sac
	SPAWN_COUNT = 5000,            -- nombre de touffes sur la pelouse au début de la partie
	SPACING = 1,                  -- distance minimum entre 2 touffes (studs) : plus petit = plus serré
	RENDER_DIST = 100,            -- les touffes plus loin que ça ne sont pas affichées (anti-lag)
	CLICK_DIST = 14,              -- distance max pour couper au clic
	ZONES_FOLDER = "ZonesHerbe",  -- dossier des zones où l'herbe pousse
	COMPOST_NAME = "Composteur",
	MONEY_STAT = "",              -- nom de ta monnaie ("" = auto : Money, Cash, Argent, Coins...)
	MONEY_PER_PLACE = 0.01,       -- argent gagné par place de sac compostée
	PICK_SOUND = "",              -- optionnel : "rbxassetid://..."
	DEPOSIT_SOUND = "",
	SCISSORS_EXTRA = 4,           -- ciseaux : touffes voisines coupées en plus à chaque coup
	SCISSORS_RADIUS = 4,          -- ciseaux : rayon autour de la touffe visée (studs)
	-- raretés : chance (%) et place prise dans le sac
	RARITIES = {
		{name = "Normal",    chance = 95.8, size = 1},
		{name = "Or",        chance = 2.5, size = 2},
		{name = "Diamant",   chance = 1.5,  size = 5},
		{name = "ArcEnCiel", chance = 0.2,  size = 10},
	},
}
