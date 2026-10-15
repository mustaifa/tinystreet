class_name Products
extends RefCounted
## Product catalogue for the first café. Products are referenced by integer id
## in the rules layer; string ids are used in level JSON and saves.

const COFFEE := 0
const TEA := 1
const CROISSANT := 2
const CUPCAKE := 3
const STRAWBERRY := 4
const CHOCOLATE := 5

const IDS: Array[String] = ["coffee", "tea", "croissant", "cupcake", "strawberry", "chocolate"]
const COUNT := 6

## Each product has a distinct shape so colour is never the only cue.
const COLORS: Array[Color] = [
	Color("8a5a3c"), # coffee: roasted brown
	Color("2f8f83"), # tea: teal tin
	Color("d9a441"), # croissant: golden
	Color("e58fa8"), # cupcake: rose frosting
	Color("d6453d"), # strawberry: red
	Color("5b3a2e"), # chocolate: dark cocoa
]

static func id_to_index(id: String) -> int:
	return IDS.find(id)

static func index_to_id(i: int) -> String:
	return IDS[i] if i >= 0 and i < COUNT else ""
