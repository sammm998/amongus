class_name Inventory
extends RefCounted
## Five slots (primary, secondary, sidearm, utility, healing), finite ammo per
## type with carry limits, consumable healing items (GAME_SPEC §5.5).

const PRIMARY := 0
const SECONDARY := 1
const SIDEARM := 2
const UTILITY := 3
const HEALING := 4
const SLOT_NAMES := ["primary", "secondary", "sidearm", "utility", "healing"]

var weapons: Array = [null, null, null]  # WeaponInstance per weapon slot
var ammo: Dictionary = {}
var consumables: Dictionary = {}          # item id -> count
var active := SIDEARM
var carry_limits: Dictionary = {}
var consumable_defs: Dictionary = {}


func _init(combat: Dictionary = {}, items: Dictionary = {}) -> void:
	for t: String in combat.get("ammo_types", {}):
		carry_limits[t] = int(combat["ammo_types"][t]["carry_limit"])
		ammo[t] = 0
	consumable_defs = items.get("consumables", {})


static func slot_index(slot_name: String) -> int:
	return SLOT_NAMES.find(slot_name)


func active_weapon() -> WeaponInstance:
	return weapons[active] if active < weapons.size() else null


## Puts a weapon into its slot. Returns the weapon it replaced (to drop) or null.
func add_weapon(w: WeaponInstance) -> WeaponInstance:
	var idx := slot_index(w.def.get("slot", "primary"))
	if idx < 0 or idx > SIDEARM:
		idx = PRIMARY
	var old: WeaponInstance = weapons[idx]
	weapons[idx] = w
	if active_weapon() == null or old != null and active == idx:
		active = idx
	return old


## Adds ammo up to the carry limit; returns the amount that did not fit.
func add_ammo(ammo_type: String, amount: int) -> int:
	if not carry_limits.has(ammo_type):
		return amount
	var space: int = carry_limits[ammo_type] - int(ammo.get(ammo_type, 0))
	var taken := clampi(amount, 0, maxi(space, 0))
	ammo[ammo_type] = int(ammo.get(ammo_type, 0)) + taken
	return amount - taken


func take_ammo(ammo_type: String, amount: int) -> void:
	ammo[ammo_type] = maxi(0, int(ammo.get(ammo_type, 0)) - amount)


func reserve_for(w: WeaponInstance) -> int:
	return int(ammo.get(w.ammo_type(), 0)) if w != null else 0


func add_consumable(item: String, amount: int) -> int:
	if not consumable_defs.has(item):
		return amount
	var cap := int(consumable_defs[item].get("max_stack", 5))
	var have := int(consumables.get(item, 0))
	var taken := clampi(amount, 0, maxi(cap - have, 0))
	consumables[item] = have + taken
	return amount - taken


## Best healing item for the current need (health first, then shield).
func pick_consumable(health: float, max_health: float, shield: float, max_shield: float) -> String:
	var order := ["med_kit", "trauma_kit", "med_patch"] if health < max_health * 0.5 else ["med_patch", "trauma_kit", "med_kit"]
	if health < max_health:
		for item: String in order:
			if int(consumables.get(item, 0)) > 0 and float(consumable_defs[item]["heal"]) > 0.0:
				return item
	if shield < max_shield:
		for item: String in ["shield_cell", "trauma_kit"]:
			if int(consumables.get(item, 0)) > 0:
				return item
	return ""


func use_consumable(item: String) -> Dictionary:
	if int(consumables.get(item, 0)) <= 0:
		return {}
	consumables[item] = int(consumables[item]) - 1
	return consumable_defs[item]


func select(slot: int) -> bool:
	if slot == HEALING:
		active = HEALING
		return true
	if slot < 0 or slot > SIDEARM or weapons[slot] == null:
		return false
	if active < weapons.size() and weapons[active] != null:
		weapons[active].cancel_reload()
	active = slot
	return true


## Spawn / revive loadout: pistol + light ammo only.
func reset_loadout(pistol_def: Dictionary, light_ammo: int) -> void:
	weapons = [null, null, WeaponInstance.create(pistol_def)]
	for t: String in ammo:
		ammo[t] = 0
	consumables.clear()
	ammo["light"] = mini(light_ammo, int(carry_limits.get("light", light_ammo)))
	active = SIDEARM


func view() -> Dictionary:
	var ws: Array = []
	for w: WeaponInstance in weapons:
		ws.append([] if w == null else [w.id, w.rarity, w.mag])
	return {"weapons": ws, "ammo": ammo.duplicate(), "items": consumables.duplicate(), "active": active}
