extends Node
var PolyList = load("poly-godot/src/PolyList.gd")

var pl = null

var keywords = LineEdit.new()
var keywords_label = Label.new()
var category = OptionButton.new()
var category_label = Label.new()
var go_button = Button.new()

var polies_display = []

# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	print("Getting polies")
	_display_UI()
	
func _submit_query():
	for poly in polies_display:
		remove_child(poly)
	pl = PolyList.new()
	add_child(pl)
	pl.connect("poly_list_loaded", self, "_display_polies")
	pl.send_query(keywords.text, true, category.text)
	polies_display.append(pl)
	
func _display_UI():
	add_child(go_button)
	go_button.set_text("Submit")
	go_button.set_position(Vector2(20, 50))
	go_button.connect("pressed", self, "_submit_query")
		
	add_child(keywords)
	keywords.set_position(Vector2(100, 50))
	keywords.set_text("Apple")
	add_child(keywords_label)
	keywords_label.set_position(Vector2(100, 30))
	keywords_label.set_text("Keywords")
	
	add_child(category)
	category.set_position(Vector2(200, 50))
	var item = 1
	category.add_item("", 0)
	for e in PolyList.CATEGORIES.keys():
		category.add_item(e, item)
		item = item + 1
	add_child(category_label)
	category_label.set_position(Vector2(200, 30))
	category_label.set_text("Category")

func _display_polies(polies):
	var posy = 200
	for poly in polies:
		# Create sprite with thumbnail
		var sprite = Sprite.new()
		sprite.set_texture(poly.get_thumbnail())
		add_child(sprite)
		polies_display.append(sprite)
		sprite.set_position(Vector2(100, posy))
		sprite.set_scale(Vector2(0.25, 0.25))
		
		# Create text listing name, description, etc
		var assetHumanReadableName = Label.new()
		assetHumanReadableName.text = "Name: " + str(poly.displayname) + "\nDescription: " + str(poly.description) + "\nAuthor: " + str(poly.author)
		assetHumanReadableName.set_position(Vector2(250, posy - 40))
		add_child(assetHumanReadableName)
		polies_display.append(assetHumanReadableName)
		
		var loadPolyButton = Button.new()
		loadPolyButton.set_text("Load " + str(poly.displayname))
		loadPolyButton.set_position(Vector2(200, posy - 50))
		loadPolyButton.connect("pressed", self, "_begin_load_model", [poly])
		add_child(loadPolyButton)
		polies_display.append(loadPolyButton)
		
		posy += 150

func _begin_load_model(poly):
	poly.connect("model_loaded", self, "_display_model")
	polies_display.append(poly.get_model())
	
func _display_model(model):
	print("Displaying model: " + str(model) + " with " + str(model.get_surface_material_count()) + " surface materials")	
	add_child(model)
