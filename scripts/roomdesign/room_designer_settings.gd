class_name RoomDesignerSettings
extends Resource
## Tunables for the room designer (scenes/room_designer.tscn): the size of a place, the
## furniture on offer and how it is grouped, the colours of the room categories.

@export_group("A place")
## Metres across one bay, up one floor, and from the back wall to the open front.
@export var bay_width := 4.0
@export var floor_height := 3.2
@export var depth := 6.0
## How close to the back or front wall an item may stand.
@export var wall_margin := 0.25
## Past this far from the middle (metres) an item counts as at the back or at the front.
@export var depth_band := 0.8
## The Back, Mid and Front buttons put an item this deep.
@export var depth_presets: Array[float] = [-2.2, 0.0, 2.2]

@export_group("Furniture")
## The Kenney models are about half of true size (a desk 0.38 m high), and a place is
## 4 x 6 m: every piece is drawn this many times its model size, so a desk stands about
## 1.15 m, a doll's-house scale that reads in the room. An item's own scale is on top of
## it, so files keep metres of the room.
@export var furniture_scale := 3.0
## Placing and dragging snap across and deep to this many metres (Shift: free), and the
## floor shows grid lines this far apart.
@export var snap := 0.25
@export var grid_step := 0.5
@export var grid_color := Color(0, 0, 0, 0.18)
@export var model_folder := "res://assets/models/kenney_furniture/"
@export var models: Array[StringName] = [
		&"bathroomCabinet", &"bathroomCabinetDrawer", &"bathroomMirror", &"bathroomSink",
		&"bathroomSinkSquare", &"bathtub", &"bear", &"bedBunk", &"bedDouble", &"bedSingle",
		&"bench", &"benchCushion", &"benchCushionLow", &"bookcaseClosed", &"bookcaseClosedDoors",
		&"bookcaseClosedWide", &"bookcaseOpen", &"bookcaseOpenLow", &"books", &"cabinetBed",
		&"cabinetBedDrawer", &"cabinetBedDrawerTable", &"cabinetTelevision",
		&"cabinetTelevisionDoors", &"cardboardBoxClosed", &"cardboardBoxOpen", &"ceilingFan",
		&"chair", &"chairCushion", &"chairDesk", &"chairModernCushion",
		&"chairModernFrameCushion", &"chairRounded", &"coatRack", &"coatRackStanding",
		&"computerKeyboard", &"computerMouse", &"computerScreen", &"desk", &"deskCorner",
		&"dryer", &"hoodLarge", &"hoodModern", &"kitchenBar", &"kitchenBarEnd",
		&"kitchenBlender", &"kitchenCabinet", &"kitchenCabinetCornerInner",
		&"kitchenCabinetCornerRound", &"kitchenCabinetDrawer", &"kitchenCabinetUpper",
		&"kitchenCabinetUpperCorner", &"kitchenCabinetUpperDouble", &"kitchenCabinetUpperLow",
		&"kitchenCoffeeMachine", &"kitchenFridge", &"kitchenFridgeBuiltIn",
		&"kitchenFridgeLarge", &"kitchenFridgeSmall", &"kitchenMicrowave", &"kitchenSink",
		&"kitchenStove", &"kitchenStoveElectric", &"lampRoundFloor", &"lampRoundTable",
		&"lampSquareCeiling", &"lampSquareFloor", &"lampSquareTable", &"lampWall", &"laptop",
		&"loungeChair", &"loungeChairRelax", &"loungeDesignChair", &"loungeDesignSofa",
		&"loungeDesignSofaCorner", &"loungeSofa", &"loungeSofaCorner", &"loungeSofaLong",
		&"loungeSofaOttoman", &"pillow", &"pillowBlue", &"pillowBlueLong", &"pillowLong",
		&"plantSmall1", &"plantSmall2", &"plantSmall3", &"pottedPlant", &"radio", &"rugDoormat",
		&"rugRectangle", &"rugRound", &"rugRounded", &"rugSquare", &"shower", &"showerRound",
		&"sideTable", &"sideTableDrawers", &"speaker", &"speakerSmall", &"stairs",
		&"stairsCorner", &"stairsOpen", &"stairsOpenSingle", &"stoolBar", &"stoolBarSquare",
		&"table", &"tableCloth", &"tableCoffee", &"tableCoffeeGlass", &"tableCoffeeGlassSquare",
		&"tableCoffeeSquare", &"tableCross", &"tableCrossCloth", &"tableGlass", &"tableRound",
		&"televisionAntenna", &"televisionModern", &"televisionVintage", &"toaster", &"toilet",
		&"toiletSquare", &"trashcan", &"washer", &"washerDryerStacked"
]
## Each group is a regular expression on the model's name.
@export var groups := {
	"all": ".",
	"beds": "(?i)^bed|bunk",
	"seats": "(?i)chair|sofa|lounge|bench|stool|ottoman",
	"tables": "(?i)table|desk|bar|counter",
	"kitchen": "(?i)kitchen|toaster|hood|fridge|washer|dryer|trashcan",
	"bath": "(?i)bath|toilet|shower|sink",
	"storage": "(?i)cabinet|bookcase|shelf|drawer|coat",
	"decor": "(?i)lamp|plant|rug|pillow|bear|book|cardboard",
	"tech": "(?i)computer|laptop|radio|speaker|keyboard|mouse|television",
}
## Things with a top other things can stand on, unless the name also matches surface_not
## or the thing is taller than surface_max_height.
@export var surface := "(?i)table|desk|cabinet|kitchenBar|sideTable|bench|drawer"
@export var surface_not := "upper|Corner|Mirror"
@export var surface_max_height := 1.2
## Things that hang on the back wall at a height: name pattern -> metres above the floor.
@export var wall_heights := {
	"(?i)lampWall|Mirror": 1.7,
	"(?i)upper": 1.5,
	"(?i)ceiling": 2.4,
}
## Things stacked on a surface must leave this much room under the ceiling.
@export var ceiling_gap := 0.3

@export_group("Rooms")
## Each room kind's category (home, fear, shop, office, util): its colour, by level.
@export var categories := {
	&"family": "home", &"tenement": "home", &"duplex": "home", &"common": "home",
	&"guard": "fear", &"shop": "shop", &"corner": "shop", &"market": "shop", &"stock": "shop",
	&"desks": "office", &"archive": "office", &"vault": "office", &"training": "office",
	&"laundry": "util", &"family_tall": "home", &"laundry_tall": "util",
	&"shop_tall": "shop", &"desks_mirrored": "office", &"archive_wide": "office",
	&"training_down": "office",
}
@export var colors := {
	"home": [Color("bcd0f0"), Color("8fb0e8"), Color("5b8dd9")],
	"fear": [Color("f0b0ae"), Color("e27d79"), Color("d9534f")],
	"shop": [Color("f8e4a0"), Color("f5d462"), Color("f0c030")],
	"office": [Color("d6bdea"), Color("b98ad8"), Color("9a5cc8")],
	"util": [Color("b8e0dc"), Color("86cdc6"), Color("4fb3aa")],
}
@export var levels := 3
@export var undo_steps := 60

@export_group("Files")
## Where the designer keeps every room between visits (in the browser too).
@export var store_path := "user://room_designs.json"
## Room files that ship with the game, one per room and level.
@export var shipped_folder := "res://data/rooms/designs/"
@export var format := 1


## The colour of room kind `id` at `level` (1 to levels).
func color_of(id: StringName, level: int) -> Color:
	var shades: Array = colors.get(categories.get(id, "home"), [Color.WHITE])
	return shades[clampi(level - 1, 0, shades.size() - 1)]


func category_of(id: StringName) -> String:
	return categories.get(id, "home")


func preset(slot: int) -> float:
	return depth_presets[clampi(slot, 0, depth_presets.size() - 1)]
