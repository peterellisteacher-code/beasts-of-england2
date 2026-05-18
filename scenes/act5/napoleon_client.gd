## napoleon_interrogation.gd
##
## Starting-point integration stub for the Napoleon interrogation in Godot 4.
## This is NOT a finished UI — it handles the HTTP layer, state machine, and
## portrait selection. Wire the signals below into your scene's UI nodes.
##
## How to use:
##   1. Add this as a script on an autoload or a scene node.
##   2. Connect the signals to your dialogue box, HUD, and portrait TextureRect.
##   3. Call start_game() on scene entry; call send_message(text) on player input.
##   4. Call restart_game() when the player chooses to face Napoleon again.
##
## The worker URL must point to your deployed Cloudflare Worker.
## Change WORKER_URL before exporting.

extends Node

# ── CONFIGURATION ────────────────────────────────────────────────────────────

const WORKER_URL: String = "https://napoleon-bot-proxy.peterellisteacher-code.workers.dev/napoleon"

## Path to portrait-manifest.json inside your Godot project's res:// tree.
## Copy portrait-manifest.json and all assets/portraits/*.png into your project.
const MANIFEST_PATH: String = "res://assets/napoleon/portrait-manifest.json"

# ── SIGNALS ──────────────────────────────────────────────────────────────────

## Emitted with Napoleon's reply text (may contain *narrator* markup).
signal napoleon_spoke(text: String)

## Emitted each turn with the updated game state.
signal game_state_updated(band: String, menace: int, score: int)

## Emitted when the portrait should change. Pass the Texture2D to your node.
signal portrait_changed(texture: Texture2D, portrait_id: String)

## Emitted when the game ends (game.dogs == true). text is the death narration.
signal player_died(text: String, final_score: int)

## Emitted on any network or parse error.
signal error_occurred(message: String)

# ── CLIENT-SIDE STATE (mirrors index.html) ───────────────────────────────────

## The menace integer received from game.menace last turn. Always send this
## back with the next request. The worker clamps it to 0–6.
var menace: int = 0

## +1 each turn game.falter is true. Display as "Lies exposed".
var score: int = 0

## Full conversation history — alternating napoleon/student turns.
## Each element is a Dictionary: {"role": "napoleon"|"student", "content": String}
var history: Array = []

## Whether the game has ended (dogs loose). Ignore further send_message calls.
var dead: bool = false

# ── INTERNAL ─────────────────────────────────────────────────────────────────

var _http: HTTPRequest
var _portraits: Dictionary = {}          # id -> Texture2D
var _manifest: Dictionary = {}           # parsed manifest JSON
var _pending_message: String = ""        # the message whose reply we await

# ── LIFECYCLE ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_load_manifest()

## Call this when the scene first becomes active. Seeds Napoleon's opening line
## into history WITHOUT a network call (the first message is baked in the client).
## Pass the opening text from your localised string or a constant.
func start_game(opening_text: String) -> void:
	menace = 0
	score  = 0
	history.clear()
	dead = false
	history.append({"role": "napoleon", "content": opening_text})
	napoleon_spoke.emit(opening_text)
	game_state_updated.emit("composed", 0, 0)
	_swap_portrait(_manifest.get("basePortrait", "cold_authority"))

## Resets all state identically to start_game(). Call on player restart.
func restart_game(opening_text: String) -> void:
	start_game(opening_text)

# ── SENDING A MESSAGE ────────────────────────────────────────────────────────

## Call with the player's typed message. Returns false if the game is over or
## a request is already in flight.
func send_message(message: String) -> bool:
	if dead:
		return false
	message = message.strip_edges()
	if message.is_empty():
		return false
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return false  # previous request still in flight

	# Append the student's turn before sending (mirrors index.html).
	history.append({"role": "student", "content": message})
	_pending_message = message

	# Build the request body — send everything except the last entry (the one
	# we just appended) as history, matching the web client exactly.
	var body: Dictionary = {
		"message": message,
		"history": history.slice(0, history.size() - 1),
		"menace":  menace,
	}

	var json_body: String = JSON.stringify(body)
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var err: int = _http.request(WORKER_URL, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		history.pop_back()  # undo the optimistic push
		error_occurred.emit("HTTPRequest error: %d" % err)
		return false

	return true

# ── RESPONSE HANDLING ────────────────────────────────────────────────────────

func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:

	if result != HTTPRequest.RESULT_SUCCESS:
		history.pop_back()  # undo the optimistic student push
		error_occurred.emit("Network error (result=%d)" % result)
		return

	var text_body: String = body.get_string_from_utf8()
	var json: Variant = JSON.parse_string(text_body)

	if json == null or not json is Dictionary:
		history.pop_back()
		error_occurred.emit("Could not parse worker response")
		return

	if response_code != 200:
		history.pop_back()
		error_occurred.emit(json.get("error", "HTTP %d" % response_code))
		return

	_handle_success(json)

func _handle_success(data: Dictionary) -> void:
	var reply_text: String   = data.get("text", "")
	var game: Dictionary     = data.get("game", {})
	var portrait_d: Dictionary = data.get("portrait", {})

	# Update client-side state (mirrors index.html exactly).
	menace = int(game.get("menace", menace))
	if game.get("falter", false):
		score += 1

	var band: String = game.get("band", "composed")

	# Append Napoleon's reply to history.
	history.append({"role": "napoleon", "content": reply_text})

	# Emit game state so the HUD can update.
	game_state_updated.emit(band, menace, score)

	# Swap portrait using the id from the response.
	var portrait_id: String = portrait_d.get("id", "")
	if portrait_id != "":
		_swap_portrait(portrait_id)

	# Emit Napoleon's text for the dialogue box.
	napoleon_spoke.emit(reply_text)

	# Death check — game.dogs is the sole authority (mirrors worker.js).
	if game.get("dogs", false):
		dead = true
		player_died.emit(reply_text, score)

# ── PORTRAIT LOADING & SELECTION ────────────────────────────────────────────

## Load manifest and pre-load all portrait textures.
func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("napoleon_interrogation.gd: manifest not found at " + MANIFEST_PATH)
		return

	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	var json: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if json == null or not json is Dictionary:
		push_error("napoleon_interrogation.gd: failed to parse manifest")
		return

	_manifest = json

	# Pre-load each portrait as a Texture2D.
	var portraits_array: Array = _manifest.get("portraits", [])
	for entry in portraits_array:
		if entry is Dictionary and entry.has("id") and entry.has("file"):
			var res_path: String = "res://" + entry["file"]
			if ResourceLoader.exists(res_path):
				_portraits[entry["id"]] = load(res_path) as Texture2D
			else:
				push_warning("napoleon_interrogation.gd: portrait not found: " + res_path)

func _swap_portrait(portrait_id: String) -> void:
	if _portraits.has(portrait_id):
		portrait_changed.emit(_portraits[portrait_id], portrait_id)
	else:
		push_warning("napoleon_interrogation.gd: no texture for portrait id '%s'" % portrait_id)

# ── SELECT PORTRAIT (local nearest-neighbour port of menace.js) ─────────────
##
## The server already returns the correct portrait.id in game.portrait —
## this function is provided as an offline fallback or for local use.
##
## Faithful port of selectPortrait() from menace.js:
##   Weighted Euclidean distance over 4 emotion axes.
##   Portraits without an "emotion" key (i.e. the death image) are skipped.
##
## emotion_vec: Dictionary with keys composure, threat, suspicion, contempt (0.0–1.0)
## Returns: portrait id String, or "" if no valid portraits found.
func select_portrait_local(emotion_vec: Dictionary) -> String:
	const WEIGHTS: Dictionary = {
		"composure": 1.0,
		"threat":    1.5,
		"suspicion": 1.2,
		"contempt":  0.8,
	}
	const AXES: Array = ["composure", "threat", "suspicion", "contempt"]
	const DEFAULTS: Dictionary = {
		"composure": 0.8, "threat": 0.15, "suspicion": 0.2, "contempt": 0.4
	}

	# Clamp the input vector to 0..1, fill missing axes from defaults.
	var e: Dictionary = {}
	for ax in AXES:
		var v: float = float(emotion_vec.get(ax, DEFAULTS[ax]))
		e[ax] = clampf(v, 0.0, 1.0)

	var best_id: String = ""
	var best_dist: float = INF
	var portraits_array: Array = _manifest.get("portraits", [])

	for p in portraits_array:
		if not p is Dictionary:
			continue
		if not p.has("emotion"):
			# Skip portraits with no emotion vector (e.g. the death image).
			continue

		var pe: Dictionary = p["emotion"]
		var dist: float = 0.0
		for ax in AXES:
			var pval: float = clampf(float(pe.get(ax, DEFAULTS[ax])), 0.0, 1.0)
			var diff: float = e[ax] - pval
			dist += WEIGHTS[ax] * diff * diff

		if dist < best_dist:
			best_dist = dist
			best_id = p["id"]

	return best_id
