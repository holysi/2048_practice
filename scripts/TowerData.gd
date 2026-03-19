# scripts/TowerData.gd
# Tower stats table — keyed by [TowerType][level]
# cost = gold to place, upgrade_cost = gold to upgrade to next level (0 = max level)

const STATS: Dictionary = {
	0: {  # BASIC — fast single-target, ground only
		1: { "damage": 10, "range": 80.0, "fire_rate": 1.0, "cost": 50, "upgrade_cost": 75, "proj_speed": 280.0 },
		2: { "damage": 18, "range": 90.0, "fire_rate": 1.2, "cost": 50, "upgrade_cost": 120, "proj_speed": 280.0 },
		3: { "damage": 30, "range": 100.0, "fire_rate": 1.5, "cost": 50, "upgrade_cost": 0, "proj_speed": 280.0 },
	},
	1: {  # SNIPER — slow, long range, ground only
		1: { "damage": 35, "range": 160.0, "fire_rate": 0.4, "cost": 80, "upgrade_cost": 100, "proj_speed": 400.0 },
		2: { "damage": 60, "range": 180.0, "fire_rate": 0.5, "cost": 80, "upgrade_cost": 150, "proj_speed": 400.0 },
		3: { "damage": 100, "range": 200.0, "fire_rate": 0.6, "cost": 80, "upgrade_cost": 0, "proj_speed": 400.0 },
	},
	2: {  # SPLASH — AOE on impact, hits flying
		1: { "damage": 20, "range": 90.0, "fire_rate": 0.6, "cost": 100, "upgrade_cost": 130, "proj_speed": 220.0 },
		2: { "damage": 35, "range": 100.0, "fire_rate": 0.7, "cost": 100, "upgrade_cost": 180, "proj_speed": 220.0 },
		3: { "damage": 55, "range": 110.0, "fire_rate": 0.8, "cost": 100, "upgrade_cost": 0, "proj_speed": 220.0 },
	},
	3: {  # SLOW — slows enemies, hits flying
		1: { "damage": 5, "range": 80.0, "fire_rate": 0.8, "cost": 70, "upgrade_cost": 90, "proj_speed": 200.0 },
		2: { "damage": 8, "range": 90.0, "fire_rate": 1.0, "cost": 70, "upgrade_cost": 130, "proj_speed": 200.0 },
		3: { "damage": 12, "range": 100.0, "fire_rate": 1.2, "cost": 70, "upgrade_cost": 0, "proj_speed": 200.0 },
	},
	4: {  # LASER — continuous beam, hits flying
		1: { "damage": 15, "range": 100.0, "fire_rate": 2.0, "cost": 120, "upgrade_cost": 160, "proj_speed": 600.0 },
		2: { "damage": 25, "range": 110.0, "fire_rate": 2.5, "cost": 120, "upgrade_cost": 220, "proj_speed": 600.0 },
		3: { "damage": 40, "range": 120.0, "fire_rate": 3.0, "cost": 120, "upgrade_cost": 0, "proj_speed": 600.0 },
	},
}
