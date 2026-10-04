class_name Pin
extends RefCounted
## Feedback pins: a short code that holds where you are and what you carry, plus a note.
## P in the game copies a link with the code (#pin=...). Opening that link, pressing O and pasting it,
## or running with `-- --pin=CODE` puts you back in the same spot with the same items, size and facing.
## The code is URL-safe base64 of JSON, so anyone can read it back with a base64 decoder.

## Everything a pin restores, as a plain dictionary.
static func capture(p: Player, cam_yaw: float, note := "") -> Dictionary:
	var pos := p.global_position
	var f := p._flat_facing()
	return {
		"v": 1,
		"pos": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)],
		"face": [snappedf(f.x, 0.01), snappedf(f.z, 0.01)],
		"yaw": snappedf(cam_yaw, 0.01),
		"small": p.small,
		"push": p.magnet_push,
		"candle": p.candle_lit,
		"hp": p.hp,
		"items": p.inventory.counts.duplicate(),
		"slots": Array(p.inventory.slots),
		"note": note,
	}

static func encode(d: Dictionary) -> String:
	return Marshalls.utf8_to_base64(JSON.stringify(d)).replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")

## Reads a code, or anything containing "pin=CODE" (a whole link). Returns {} if it isn't a pin.
static func decode(text: String) -> Dictionary:
	var code := text.strip_edges()
	var at := code.find("pin=")
	if at >= 0:
		code = code.substr(at + 4)
	for stop in ["&", " ", "\n"]:
		var k := code.find(stop)
		if k >= 0:
			code = code.substr(0, k)
	if not code.begins_with("eyJ"): # every pin is base64 of '{"', so anything else isn't one
		return {}
	code = code.replace("-", "+").replace("_", "/")
	while code.length() % 4 != 0:
		code += "="
	var parsed = JSON.parse_string(Marshalls.base64_to_utf8(code))
	if parsed is Dictionary and parsed.has("pos"):
		return parsed
	return {}

## Puts the player back where the pin says. Returns false if the pin was empty.
static func apply(p: Player, d: Dictionary, rig: CameraRig = null) -> bool:
	if d.is_empty():
		return false
	var inv := p.inventory
	inv.counts.clear()
	var items: Dictionary = d.get("items", {})
	for id in items:
		if Inventory.ITEMS.has(id):
			inv.counts[id] = int(items[id])
	var slots: Array = d.get("slots", [])
	for i in Inventory.SLOTS:
		var id: String = str(slots[i]) if i < slots.size() else ""
		inv.slots[i] = id if id == "" or inv.counts.has(id) else ""
	if p.carrying != null:
		p.carrying.queue_free()
		p.carrying = null
	if p.umbra != null:
		p.umbra.fade()
	p.drop_holds()
	p.stow_spider()
	p.set_candle(bool(d.get("candle", false)) and inv.has("candle"))
	p.magnet_push = bool(d.get("push", false))
	p.set_small(bool(d.get("small", false)), true)
	p.hp = clampi(int(d.get("hp", p.max_hp)), 1, p.max_hp)
	var pos: Array = d["pos"]
	p.teleport(Vector3(float(pos[0]), float(pos[1]), float(pos[2])))
	p.target = null
	p.roll_t = 0.0
	var face: Array = d.get("face", [0.0, -1.0])
	var f := Vector3(float(face[0]), 0.0, float(face[1]))
	if f.length() > 0.1:
		p.facing = f.normalized()
		p.lock_dir = p.facing
	if rig != null:
		rig.yaw = float(d.get("yaw", rig.yaw))
		rig.snap()
	inv.changed.emit()
	return true
