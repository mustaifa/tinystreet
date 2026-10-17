extends SceneTree
## Authoring aid (never shipped as content by itself): tries random crate,
## destination and courier placements inside hand-drawn rooms and keeps the
## placements whose analysis shows real decisions. Every kept candidate is
## then reviewed, edited and documented by hand before it becomes a level.
##   godot --headless --path game -s res://tools/delivery_gen.gd -- ROOMS.json OUT.json [trials] [seed]
## ROOMS.json: {"rooms": [{"id", "map" (walls/floor only), "crates": [2,3], "symbols": 2}]}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var rooms = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var out_path: String = args[1]
	var trials := int(args[2]) if args.size() > 2 else 200
	var seed0 := int(args[3]) if args.size() > 3 else 1
	var found: Array = []
	for room in rooms.rooms:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed0 + hash(str(room.id))
		var best: Array = []
		var counts: Array = room.get("crates", [2, 3])
		for t in trials:
			var k: int = counts[rng.randi_range(0, counts.size() - 1)]
			var nsym := mini(int(room.get("symbols", k)), k)
			# retry until the start position is not already provably dead
			var rows: Array = []
			var l: DeliveryLevel = null
			for attempt in 40:
				rows = _place(room.map, k, nsym, rng, float(room.get("on_goal", 0.15)))
				if rows.is_empty():
					continue
				l = DeliveryLevel.from_rows(str(room.id), rows)
				if l.is_valid() and DeliveryRules.deadlock(l, DeliveryRules.start_state(l)).code == DeliveryRules.Dead.NONE:
					break
				l = null
			if l == null:
				continue
			var g := DeliveryAnalysis.graph(l, 60000)
			if not g.complete or g.min_pushes < 5 or g.min_pushes > 45:
				continue
			var pr := DeliveryAnalysis.path_report(l, g)
			var gr := DeliveryAnalysis.greedy_agent(l, 10)
			var fo := DeliveryAnalysis.fixed_order_agent(l)
			var sc: float = 3.0 * pr.trap_states + 2.0 * pr.silent_states + 4.0 * mini(pr.tempting, 4) + 2.0 * mini(pr.silent_traps, 5) \
				+ 2.5 * mini(pr.displacement, 3) + 6.0 * (1.0 - gr.rate) + (5.0 if not fo.nearest_first else 0.0) \
				+ (4.0 if fo.orders_ok < fo.orders else 0.0) - 0.2 * g.min_pushes - 1.5 * (k - 2)
			best.append({"score": sc, "id": "%s_%d" % [room.id, t], "map": rows, "min_pushes": g.min_pushes,
				"nodes": g.nodes, "decisions": pr.trap_states, "silent_states": pr.silent_states, "tempting": pr.tempting, "silent": pr.silent_traps,
				"displacement": pr.displacement, "greedy": gr.rate, "nearest_first": fo.nearest_first,
				"orders": "%d/%d" % [fo.orders_ok, fo.orders]})
		best.sort_custom(func(a, b): return a.score > b.score)
		for c in best.slice(0, int(room.get("keep", 4))):
			found.append(c)
			print("%s score=%.1f mp=%d trapst=%d silentst=%d tempt=%d silent=%d disp=%d greedy=%.2f nf=%s orders=%s" % [
				c.id, c.score, c.min_pushes, c.decisions, c.silent_states, c.tempting, c.silent, c.displacement, c.greedy, c.nearest_first, c.orders])
			for r in c.map:
				print("    ", r)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"levels": found}, " "))
	f.close()
	quit(0)

func _place(room: Array, k: int, nsym: int, rng: RandomNumberGenerator, on_goal: float) -> Array:
	var grid: Array = []
	var floors: Array = []
	for y in room.size():
		var r: Array = []
		for x in str(room[y]).length():
			var ch: String = room[y][x]
			r.append(ch)
			if ch == ".":
				floors.append(Vector2i(x, y))
		grid.append(r)
	if floors.size() < 2 * k + 1:
		return []
	# shuffle
	for i in range(floors.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = floors[i]; floors[i] = floors[j]; floors[j] = tmp
	var syms: Array = []
	for i in k:
		syms.append(i % nsym)
	var idx := 0
	for i in k:
		var gc: Vector2i = floors[idx]; idx += 1
		var s: int = syms[i]
		if rng.randf() < on_goal:
			grid[gc.y][gc.x] = str(s + 1)       # crate already on its destination
		else:
			grid[gc.y][gc.x] = char("a".unicode_at(0) + s)
			var cc: Vector2i = floors[idx]; idx += 1
			grid[cc.y][cc.x] = char("A".unicode_at(0) + s)
	var pc: Vector2i = floors[idx]
	grid[pc.y][pc.x] = "@"
	var rows: Array = []
	for r in grid:
		rows.append("".join(r))
	# reject if already solved
	var all_on := true
	for r in rows:
		for ch in ["A", "B", "C", "D"]:
			if str(r).contains(ch):
				all_on = false
	return [] if all_on else rows
