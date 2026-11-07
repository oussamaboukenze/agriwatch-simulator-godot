extends Node
signal report(message: String)
var request: HTTPRequest
var busy := false
var enabled := false
var connected := false
var status := "Hors ligne — passerelle facultative"
const URL = "http://127.0.0.1:8765"

func _ready():
	request = HTTPRequest.new()
	request.timeout = 2.0
	add_child(request)
	request.request_completed.connect(_completed)

func send(path: String, data: Dictionary = {}):
	if busy: return
	busy = true
	var error := request.request(URL + path, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(data))
	if error != OK:
		busy = false
		status = "Passerelle inaccessible"
		connected = false

func _completed(result, code, _headers, body):
	busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		connected = false
		status = "Passerelle inaccessible / erreur HTTP %d" % code
		report.emit(status)
		return
	var response = JSON.parse_string(body.get_string_from_utf8())
	if response is Dictionary:
		connected = response.get("connected", false)
		status = response.get("status", "Inconnu")
		if response.has("accepted"):
			report.emit("Passerelle : %s acceptés ; %s envoyés au transport (QoS 0, sans accusé broker)" % [response.accepted, response.get("acked", 0)])
