class_name Inventory
extends RefCounted
## Ocarina-style inventory. The poleaxe and shield are equipment (the attack and guard buttons).
## Usable items go on three quick slots (keys 1-3, like the C buttons) from the pause screen.

signal changed

const ITEMS := {
	"poleaxe": {"name": "Poleaxe & Shield", "color": Color(0.85, 0.75, 0.45), "slot": false, "max": 1},
	"potion": {"name": "Red Potion", "color": Color(0.9, 0.2, 0.2), "slot": true, "max": 3},
	# toggles: using one switches it on or off, nothing is used up
	"candle": {"name": "Candle Hat", "color": Color(1.0, 0.75, 0.35), "slot": true, "max": 1, "toggle": true},
	"umbra": {"name": "Umbra", "color": Color(0.45, 0.38, 1.0), "slot": true, "max": 1, "toggle": true},
	# the magnet is always on: using it flips between pull (negative) and push (positive)
	"magnet": {"name": "Magnet", "color": Color(0.3, 0.55, 1.0), "slot": true, "max": 1, "toggle": true},
	# the clockwork spider: switches who you steer, you or it; hooked with the lash, a taut rope joins you
	"spider": {"name": "Clockwork Spider", "color": Color(0.6, 0.55, 0.5), "slot": true, "max": 1, "toggle": true},
	# Winch's leash and Propagule's lash in one rope
	"lash": {"name": "Lash", "color": Color(0.85, 0.7, 0.4), "slot": true, "max": 1, "toggle": true},
}
const SLOTS := 3

var counts := {}
var slots: Array[String] = ["", "", ""]

func count(id: String) -> int:
	return int(counts.get(id, 0))

func has(id: String) -> bool:
	return count(id) > 0

func owned() -> Array[String]:
	var r: Array[String] = []
	for id in ITEMS:
		if counts.has(id):
			r.append(id)
	return r

func add(id: String, n := 1) -> void:
	counts[id] = mini(count(id) + n, int(ITEMS[id]["max"]))
	if ITEMS[id]["slot"] and not slots.has(id):
		var free := slots.find("")
		if free >= 0:
			slots[free] = id
	changed.emit()

## Put an item on a quick slot. If it was already on another slot, the two swap.
func assign(slot: int, id: String) -> void:
	if not ITEMS[id]["slot"]:
		return
	var old := slots.find(id)
	if old >= 0:
		slots[old] = slots[slot]
	slots[slot] = id
	changed.emit()

## Use the item on a quick slot. Returns false when nothing happened (empty, none left, or no effect).
func use(slot: int, player: Player) -> bool:
	var id := slots[slot]
	if id == "" or count(id) <= 0:
		return false
	match id:
		"candle":
			player.set_candle(not player.candle_lit)
			return true
		"umbra":
			player.toggle_umbra()
			return true
		"magnet":
			player.magnet_push = not player.magnet_push
			changed.emit()
			return true
		"spider":
			player.use_spider()
			changed.emit()
			return true
		"lash":
			player.use_lash()
			changed.emit()
			return true
		"potion":
			if player.hp >= player.max_hp:
				return false
			player.hp = player.max_hp
	counts[id] = count(id) - 1
	changed.emit()
	return true
