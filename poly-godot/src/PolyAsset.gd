extends Node

var ObjParse = load("gd-obj/ObjParse.gd")

var json = JSON

signal model_loaded

# The thumbnail as a Godot image, lazy evaluated
var thumbnail = null
var thumbnailHttpReq = null
# The asset ID
var assetName = null
# The human-readable asset name
var displayname = null
# The asset author
var author = null
# The human-readable asset description
var description = null
# The time of original asset upload, in "YYYY-MM-DDThh:mm:ss.sZ" format
# eg "2017-07-27T15:56:33.413499Z"
var createTime = null
var updateTime = null
var license = null
var visibility = null
var isCurated = null
# TODO presentationParams
# TODO remixInfo


var model = null

var assetDirectory = null
var objFile = null
var mtlFile = null
# The count of all files required, to include the .obj, .mtl, and any image resources
var total_resource_count = 0
# The count of all files downloaded. Once total==loaded, the model is loaded into Godot
var loaded_resource_count = 0

enum LICENSETYPE {
	UNKNOWN,
	CREATIVE_COMMONS_BY,
	ALL_RIGHTS_RESERVED
}

enum VISIBILTYTYPE {
	VISIBILITY_UNSPECIFIED,
	PRIVATE,
	UNLISTED,
	PUBLIC
}

enum FORMATCOMPLEXITY {
	COMPLEXITY_UNSPECIFIED,
	COMPLEX,
	MEDIUM,
	SIMPLE
}

# Loads in all text based fields
# Images and models are not loaded in yet
func load_from_json(json_obj):
	json = json_obj
	
	assetName = json.get("name").replace("assets/", "")

	# Create cache directory
	assetDirectory = "user://" + assetName
	var d = Directory.new()
	if( !d.dir_exists(assetDirectory) ):
		d.open("user://")
		var err = d.make_dir_recursive(assetDirectory)
		print(err)
	objFile = assetDirectory + "/" + assetName + ".obj"
		
	displayname = json.get("displayName")
	author = json.get("authorName")
	description = json.get("description")
	createTime = json.get("createTime")
	updateTime = json.get("updateTime")
	license = json.get("license")
	isCurated = bool(json.get("isCurated"))
		
	# TODO - is there a better way to handle enums?
	if(license == "CREATIVE_COMMONS_BY"):
		license = LICENSETYPE.CREATIVE_COMMONS_BY
	elif(license == "ALL_RIGHTS_RESERVED"):
		license = LICENSETYPE.ALL_RIGHTS_RESERVED
	else:
		license = LICENSETYPE.UNKNOWN
		
	visibility = json.get("visibility")
	if(visibility == "PRIVATE"):
		visibility = VISIBILTYTYPE.PRIVATE
	elif(visibility == "UNLISTED"):
		visibility = VISIBILTYTYPE.UNLISTED
	elif(visibility == "PUBLIC"):
		visibility = VISIBILTYTYPE.PUBLIC
	else:
		visibility = VISIBILTYTYPE.VISIBILITY_UNSPECIFIED
		
# Loads the model as a Godot model
func get_model():
	if(model == null):
		model = MeshInstance.new()
		
		# Loop though all formats until the OBJ is found
		for format in json.get("formats"):
			if format["formatType"] == "OBJ":
				
				# Download OBJ model file
				print("Downloading model file: " + format["root"]["url"])
				var headers = [""]
				var modelHttpReq = HTTPRequest.new()
				add_child(modelHttpReq)
				modelHttpReq.connect("request_completed", self, "_attempt_load_full_model")
				modelHttpReq.set_download_file(objFile)
				modelHttpReq.request(format["root"]["url"], headers, true, 0, "")
				
				# Download other resources (.mtl, image files)
				total_resource_count = format.get("resources").size() + 1
				print("Getting materials, " + str(total_resource_count - 1) + " total texture files and one mtl")
				for mat in format.get("resources"):
					print("Loading mat file " + mat["relativePath"])
					
					# Save off MTL file for future reference
					if(mat["relativePath"].ends_with(".mtl")):
						mtlFile = assetDirectory + "/" + mat["relativePath"]
					
					var matHttpReq = HTTPRequest.new()
					add_child(matHttpReq)
					matHttpReq.connect("request_completed", self, "_attempt_load_full_model")
					matHttpReq.set_download_file(assetDirectory + "/" + mat["relativePath"])
					matHttpReq.request(mat["url"], headers, true, 0, "")
					
				return model
	return model
		
# After all resources (mtl and textures), attempt to load  model into Godot
func _attempt_load_full_model(result, response_code, headers, body):
	loaded_resource_count = loaded_resource_count + 1
	print("Downloaded " + str(loaded_resource_count) + "/" + str(total_resource_count) + " Model Resource files for " + assetName) 
	if(loaded_resource_count == total_resource_count):
		var importer = ObjParse.new()
		model.mesh = importer.parse_obj(objFile, mtlFile)
	
		emit_signal("model_loaded", model)
	
# Loads the thumbnail as a Godot Image
func get_thumbnail():
	# TODO cache thumbnails
	if(thumbnail == null):
		thumbnail = ImageTexture.new()
		thumbnailHttpReq = HTTPRequest.new()
		add_child(thumbnailHttpReq)
		thumbnailHttpReq.connect("request_completed", self, "_load_thumbnail_content")
		var headers = [""]
		thumbnailHttpReq.request(json.get("thumbnail").get("url"), headers, true, 0, "")
	return thumbnail
	
func _load_thumbnail_content(result, response_code, headers, body):
		print("Loading thumbnail content!")
		var type = json.get("thumbnail").get("contentType")
		var img = Image.new()
		if(type == "image/png"):
			img.load_png_from_buffer(body)
		elif(type == "image/jpg"):
			img.load_jpg_from_buffer(body)
		elif(type == "image/webp"):
			img.load_webp_from_buffer(body)
		thumbnail.create_from_image(img)
	
func print_all():
	for prop in get_property_list():
		if(prop.name != "json"):
			print(prop.name + " : ", get(prop.name))
