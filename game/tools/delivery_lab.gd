extends SceneTree
## Authoring aid: prints quality metrics for Delivery Logic levels.
##   godot --headless --path game -s res://tools/delivery_lab.gd -- FILE.json [id ...] [--solution]
## FILE has {"levels": [{"id", "map"}...]}. Metrics come from
## DeliveryAnalysis (rules from DeliveryRules); they flag weak levels and do
## not measure fun.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else "res://data/delivery/levels.json"
	var show_solution := "--solution" in args
	var explain := "--explain" in args
	var only: Array = []
	for a in args.slice(1):
		if not a.begins_with("--"):
			only.append(a)
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(d) != TYPE_DICTIONARY:
		print("cannot read ", path)
		quit(1)
		return
	for ld in d.levels:
		if not only.is_empty() and not (str(ld.id) in only):
			continue
		var l := DeliveryLevel.from_dict(ld)
		print("\n== ", l.id, "  ", l.w, "x", l.h, " crates=", l.crate_count())
		for r in l.map:
			print("   ", r)
		if not l.is_valid():
			print("   INVALID: ", l.errors)
			continue
		var t0 := Time.get_ticks_msec()
		var g := DeliveryAnalysis.graph(l)
		var pr := DeliveryAnalysis.path_report(l, g)
		var t1 := Time.get_ticks_msec()
		var rnd := DeliveryAnalysis.random_agent(l)
		var gr := DeliveryAnalysis.greedy_agent(l)
		var fo := DeliveryAnalysis.fixed_order_agent(l)
		print("   nodes=%d complete=%s min_pushes=%d dead_ratio=%.2f  (%d ms)" % [g.nodes, g.complete, g.min_pushes, g.dead_ratio, t1 - t0])
		print("   path: pushes=%d choice_states=%d trap_states=%d silent_states=%d traps=%d silent=%d tempting=%d displacement=%d" % [
			pr.pushes, pr.choice_states, pr.trap_states, pr.silent_states, pr.traps, pr.silent_traps, pr.tempting, pr.displacement])
		print("   agents: random %d/%d  greedy %d/%d  nearest-first=%s  orders %d/%d" % [
			rnd.wins, rnd.runs, gr.wins, gr.runs, fo.nearest_first, fo.orders_ok, fo.orders])
		for ex in pr.trap_examples:
			print("   tempting trap: ", ex)
		if explain:
			_explain(l, g)
		if show_solution:
			var sv := DeliverySolver.solve(l, DeliveryRules.start_state(l))
			var mv := sv.moves()
			var txt := ""
			for e in sv.push_list:
				txt += "%s@%d,%d " % [DeliveryRules.DIR_IDS[e.y][0], e.x % l.w, e.x / l.w]
			print("   solution pushes: ", txt, " valid=", DeliverySolver.validate(l, DeliveryRules.start_state(l), mv))
	quit(0)

const SYM := ["A", "B", "C", "D"]

static func _ascii(l: DeliveryLevel, s: DeliveryState) -> PackedStringArray:
	var out := PackedStringArray()
	for y in l.h:
		var r := ""
		for x in l.w:
			var c := y * l.w + x
			var ch := " "
			if l.kind[c] == DeliveryLevel.WALL:
				ch = "#"
			elif l.kind[c] == DeliveryLevel.FLOOR:
				ch = "."
				if l.goal[c] >= 0:
					ch = SYM[l.goal[c]].to_lower()
				if s.at[c] >= 0:
					var sy := l.crate_sym[s.at[c]]
					ch = str(sy + 1) if l.goal[c] == sy else SYM[sy]
				if s.player == c:
					ch = "@"
			r += ch
		out.append(r)
	return out

## Board after every push of one fewest-push solution, with the traps that
## were available just before it (X = proved unsolvable afterwards; * = the
## instant checks would not notice).
static func _explain(l: DeliveryLevel, g: Dictionary) -> void:
	var pr := DeliveryAnalysis.path_report(l, g)
	var s := DeliveryRules.start_state(l)
	var k := 0
	for step in pr.path:
		var node: int = step[0]
		var e: Array = step[1]
		var traps := ""
		for alt in g.edges[node]:
			var child := int(alt[0])
			if child < 0 or g.dist[child] == DeliveryAnalysis.UNSOLVABLE:
				var silent: bool = child >= 0 and DeliveryRules.deadlock(l, DeliveryRules.from_key(l, g.keys[child])).code == DeliveryRules.Dead.NONE
				traps += " X%s%s@%d,%d%s" % [SYM[l.crate_sym[int(alt[3])]], DeliveryRules.DIR_IDS[int(alt[2])][0], int(alt[1]) % l.w, int(alt[1]) / l.w, "*" if silent else ""]
		var cell := int(e[1])
		var d := int(e[2])
		var stand := l.nbr(cell, DeliveryRules.opposite(d))
		DeliveryRules.walk(l, s, stand)
		DeliveryRules.move(l, s, d)
		k += 1
		print("   %2d. push %s %s from %d,%d   traps before:%s" % [k, SYM[l.crate_sym[int(e[3])]], DeliveryRules.DIR_IDS[d], cell % l.w, cell / l.w, traps])
		for r in _ascii(l, s):
			print("        ", r)
