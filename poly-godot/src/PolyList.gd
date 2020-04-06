extends Node
var polyAsset = load("poly-godot/src/PolyAsset.gd")

signal poly_list_loaded

# TODO support alternate auth methods
var apikey = null
var baseurl = "https://poly.googleapis.com/"
var apiver = "v1/"
var http = HTTPRequest.new()

enum CATEGORIES {
	ANIMALS,
	ARCHITECTURE,
	ART,
	FOOD,
	NATURE,
	OBJECTS,
	PEOPLE,
	SCENES,
	TECHNOLOGY,
	TRANSPORT
} 

enum ORDERBY {
	BEST,
	NEWEST,
	OLDEST
}
var headers = [""]

# Save a copy of the last used query strings
# This way, we can reuse a query while going to the next page
var query_keywords = null
var query_curated = null
var query_category = null
var query_max_complexity = null
var query_page_size = null
var query_order_by = null

var query_next_page_token = null
var next_page_list = null

var poly_asset_list = []

# Called when the node enters the scene tree for the first time.
func _ready():
	# Get API key
	var apifile = File.new()
	apifile.open("res://apikey.txt", apifile.READ)
	apikey = apifile.get_as_text()
	apifile.close()

	add_child(http)
	http.connect("request_completed", self, "_http_request_completed")
	connect("poly_list_loaded", self, "_poly_list_loaded")
	
# "keywords" One or more search terms to be matched against all text that Poly has indexed for assets, which includes displayName, description, and tags. Multiple keywords should be separated by a comma.
# "curated"  Return only assets that have been curated by the Poly team. 
# "category" Filter assets based on the specified category
# "max_complexity" Returns assets that are of the specified complexity or less.
# "page_size" The maximum number of assets to be returned.
# "order_by" Specifies an ordering for assets.
# "page_token" Specifies a continuation token from a previous search whose results were split into multiple pages. Alternatively, use `next_page`.
#
# See also https://developers.google.com/poly/reference/api/rest/v1/assets/list
func send_query(keywords, curated=null, category=null, max_complexity=null, page_size=null, order_by=null, page_token=null):
	query_keywords = keywords.replace(" ", ",")
	query_curated = curated
	query_category = category
	query_max_complexity = max_complexity
	query_page_size = page_size
	query_order_by = order_by
	# Page token must be determined after response

	#if(clear):
	#	_clear()
		
	# Send request. Any "null" fields will simply not be specified in the query string
	var queryString = ""
	queryString += "key=" + apikey
	# The list of formats that both Godot and Poly support are only OBJ and GLTF2. Unfortunately, we can only specify one per query.
	# For optimization, we'll be only using OBJ for now to avoid sending 2 queries per List getter.
	# There's enough overlap with duplicate formats on Poly that we won't be losing a significant amount of entries
	queryString += "&format=OBJ"
	#queryString += "&format=GLTF2"
	queryString += (("&keywords=" + query_keywords) if (query_keywords != null and query_keywords != "") else "")
	queryString += (("&curated=" + str(query_curated)) if (query_curated != null) else "")
	queryString += (("&category=" + query_category) if (query_category != null and query_category != "") else "")
	queryString += (("&maxComplexity=" + query_max_complexity) if (query_max_complexity != null and query_max_complexity != "") else "")
	queryString += (("&pageSize=" + str(query_page_size)) if (query_page_size != null and query_page_size >= 1 and query_page_size <= 100) else "")
	queryString += (("&orderBy=" + query_order_by) if (query_order_by != null and query_order_by != "") else "")
	queryString += (("&pageToken=" + page_token) if (page_token != null and page_token != "") else "")
	
	var complete_request = baseurl + apiver + "assets?" + queryString
	print("Sending query: " + complete_request)
	
	# TODO determine valid "FORMAT" query params for GODOT
	var err = http.request(complete_request, headers, true, 0, "")
	print(err)

# Gets the next page of results using the previous query as a new list.
# The list will be added as a child node of the current list
func next_page():
	if(next_page_list == null):
		if(query_next_page_token == null):
			print("Cannot get next page. Either no initial page has been loaded, or the end of the query has been reached")
			return null
		next_page_list = get_script().new()
		add_child(next_page_list)
		next_page_list.send_query(query_keywords, query_curated, query_category, query_max_complexity, query_page_size, query_order_by, query_next_page_token)
	return next_page_list

# Callback for a successful HTTP request
func _http_request_completed(result, response_code, headers, body):
	var json_resp = parse_json(body.get_string_from_utf8())
	_json_to_asset_list(json_resp)
	if json_resp != null and json_resp.has("nextPageToken"):
		query_next_page_token = json_resp["nextPageToken"]
	emit_signal("poly_list_loaded", poly_asset_list)
	
# Converts the JSON to a list of PolyAssets, and adds them to this PolyList
func _json_to_asset_list(body):
	if(body != null and body.has("assets")):
		for json in body["assets"]:
			var pa = polyAsset.new()
			pa.load_from_json(json)
			add_child(pa)
			poly_asset_list.append(pa)
	
func _poly_list_loaded(poly_list):
	print("Finished loading " + str(poly_list.size()) + " assets on this page")
