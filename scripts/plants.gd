class_name Plants
extends RefCounted
## One set of rules for every plant in the game (jovi, 2026-10-01), so no level has to remember them:
##   vine:  climbable, lash post, flammable (Burnable "vines")
##   wood:  climbable, lash post (a planted seed's trunk and roots)
##   grass: flammable (Burnable "grass")
## Anything that grows calls Plants.mark(node, kind) when it's made; that puts it in group "plants",
## "plant_<kind>" and every group its kind's rules need. A flammable plant must also be a Burnable (heat_box, heat).

const RULES := {
	"vine": ["climbable", "lash_posts", "flammable"],
	"wood": ["climbable", "lash_posts"],
	"grass": ["flammable"],
}

static func mark(n: Node, kind: String) -> void:
	n.add_to_group("plants")
	n.add_to_group("plant_" + kind)
	n.set_meta("plant", kind)
	for g in RULES[kind]:
		n.add_to_group(g)

## The groups n is missing for its kind (empty when it follows the rules).
static func missing(n: Node) -> Array[String]:
	var out: Array[String] = []
	var kind: String = n.get_meta("plant", "")
	if not RULES.has(kind):
		out.append("plant kind")
		return out
	for g in RULES[kind]:
		if not n.is_in_group(g):
			out.append(g)
	if n.is_in_group("flammable") and not n.has_method("heat"):
		out.append("heat()")
	return out
