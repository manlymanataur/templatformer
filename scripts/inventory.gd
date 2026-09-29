class_name Inventory
extends RefCounted
## Ocarina-style inventory. The spear is equipment (always on the attack button).
## Usable items go on three quick slots (keys 1-3, like the C buttons) from the pause screen.

signal changed

const ITEMS := {
	"spear": {"name": "Spear", "color": Color(0.85, 0.75, 0.45), "slot": false, "max": 1},
	"bombs": {"name": "Bombs", "color": Color(0.25, 0.25, 0.3), "slot": true, "max": 20},
	"potion": {"name": "Red Potion", "color": Color(0.9, 0.2, 0.2), "slot": true, "max": 3},
	# toggles: using one switches it on or off, nothing is used up
	"candle": {"name": "Candle Hat", "color": Color(1.0, 0.75, 0.35), "slot": true, "max": 1, "toggle": true},
	"umbra": {"name": "Umbra", "color": Color(0.45, 0.38, 1.0), "slot": true, "max": 1, "toggle": true},
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
	if id == "bombs" and player.carrying != null:
		player.release_bomb() # second press throws or sets down the bomb you're holding
		return false
	if id == "" or count(id) <= 0:
		return false
	match id:
		"candle":
			player.set_candle(not player.candle_lit)
			return true
		"umbra":
			player.toggle_umbra()
			return true
		"potion":
			if player.hp >= player.max_hp:
				return false
			player.hp = player.max_hp
		"bombs":
			player.pull_bomb()
	counts[id] = count(id) - 1
	changed.emit()
	return true
