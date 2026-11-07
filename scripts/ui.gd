extends CanvasLayer
var controller
var metrics: Label
var connection: Label
var clock_label: Label
var diagnosis_title: Label
var diagnosis_text: Label
var station_reading: Label
var logs: TextEdit
var irrigation: CheckButton
var sensors: Array = []
var parcel_choice: OptionButton
var crop_choice: OptionButton
var station_choice: OptionButton
var interval: SpinBox
var fields: Dictionary = {}
var tls: CheckButton
var rain: CheckButton
var overview: Label
var crops: Array = [""]

func label_at(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 310
	label.add_theme_font_size_override("font_size", 15)
	parent.add_child(label)
	return label

func button(parent: Node, text: String, action: Callable):
	var b := Button.new()
	b.text = text
	parent.add_child(b)
	b.pressed.connect(action)

func tab(parent: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 9)
	scroll.add_child(v)
	return v

func _ready():
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(370, 850)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142a2e")
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.corner_radius_top_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)
	label_at(outer, "AGRIWATCH · SIMULATION").add_theme_font_size_override("font_size", 22)
	clock_label = label_at(outer, "")
	connection = label_at(outer, "Hors ligne")
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(340, 720)
	outer.add_child(tabs)
	var v := tab(tabs, "Terrains")
	overview = label_at(v, "6 terrains · 18 stations · 54 capteurs")
	parcel_choice = OptionButton.new()
	for i in range(controller.sim.parcels.size()): parcel_choice.add_item("Terrain %02d" % (i + 1))
	v.add_child(parcel_choice)
	parcel_choice.item_selected.connect(func(i): controller.selected_index = i; sync_controls())
	metrics = label_at(v, "")
	diagnosis_title = label_at(v, "")
	diagnosis_title.add_theme_font_size_override("font_size", 17)
	diagnosis_text = label_at(v, "")
	label_at(v, "Comparaison des profils démo à l'instant présent. Température + humidité seules ne prouvent pas l'aptitude réelle d'une terre.").add_theme_color_override("font_color", Color("b0c3bb"))
	label_at(v, "Occupation de cette terre (semis simulé)")
	crop_choice = OptionButton.new()
	crop_choice.add_item("Terre nue · aucun semis")
	for crop in controller.sim.profiles:
		crops.append(crop)
		crop_choice.add_item(crop)
	v.add_child(crop_choice)
	crop_choice.item_selected.connect(func(i): controller.sim.set_crop(controller.selected_index, crops[i]); sync_controls())
	irrigation = CheckButton.new()
	irrigation.text = "Irrigation de cette terre"
	v.add_child(irrigation)
	irrigation.toggled.connect(func(on): controller.sim.parcels[controller.selected_index].irrigation = on)
	station_choice = OptionButton.new()
	for title in ["Station A · côté ouest", "Station B · centre", "Station C · côté est"]: station_choice.add_item(title)
	v.add_child(station_choice)
	station_choice.item_selected.connect(func(_i): sync_controls())
	station_reading = label_at(v, "")
	for m in range(3):
		var toggle := CheckButton.new()
		v.add_child(toggle)
		toggle.toggled.connect(func(on): controller.sim.parcels[controller.selected_index].stations[station_choice.selected].online[m] = on)
		sensors.append(toggle)
	var climate := tab(tabs, "Climat")
	label_at(climate, "Les changements agissent sur toutes les terres, avec leurs différences locales de sol et de température.")
	button(climate, "Démarrer / Pause", func(): controller.sim.running = not controller.sim.running)
	button(climate, "Réinitialiser les terrains", func(): controller.sim.reset(); sync_controls())
	var speed := OptionButton.new()
	for title in ["Temps ×1", "Temps ×60", "Temps ×600", "Temps ×3600"]: speed.add_item(title)
	speed.select(1)
	climate.add_child(speed)
	speed.item_selected.connect(func(i): controller.sim.speed = [1.0, 60.0, 600.0, 3600.0][i])
	var scenario := OptionButton.new()
	for title in ["Normal · terrains contrastés", "Sécheresse progressive", "Chaleur persistante", "Pluie puis retour normal", "Panne humidité 01-A : 1 à 10 min"]: scenario.add_item(title)
	climate.add_child(scenario)
	scenario.item_selected.connect(func(i): controller.sim.set_scenario(i); sync_controls())
	rain = CheckButton.new()
	rain.text = "Pluie manuelle · cible 8 mm/h"
	climate.add_child(rain)
	rain.toggled.connect(func(on): controller.sim.rain = on)
	label_at(climate, "État initial :\n01 Blé · conditions compatibles\n02 Maïs · sol trop sec\n03 Soja · sol trop humide\n04 Terre nue · sèche\n05 Terre nue · équilibrée\n06 Terre nue · très humide\n\nLe diagnostic évolue avec les vraies lectures des capteurs simulés. Les capteurs déconnectés sont exclus ; si les mesures manquent, aucune conclusion n'est donnée.")
	var net := tab(tabs, "MQTT")
	label_at(net, "Transport vers Mosquitto / autre broker. Un message par capteur connecté. Aucune application front-end ou back-end nécessaire.")
	for key in ["host", "port", "client_id", "username", "password"]:
		var field := LineEdit.new()
		field.placeholder_text = {"host": "Hôte", "port": "Port", "client_id": "Identifiant client", "username": "Utilisateur (facultatif)", "password": "Mot de passe (mémoire uniquement)"}[key]
		field.text = {"host": "127.0.0.1", "port": "1883", "client_id": "agriwatch-" + Crypto.new().generate_random_bytes(4).hex_encode(), "username": "", "password": ""}[key]
		field.secret = key == "password"
		fields[key] = field
		net.add_child(field)
	tls = CheckButton.new()
	tls.text = "TLS · certificats vérifiés (port 8883)"
	net.add_child(tls)
	interval = SpinBox.new()
	interval.min_value = 1
	interval.max_value = 3600
	interval.value = 5
	interval.suffix = "s réelles / publication"
	net.add_child(interval)
	button(net, "Connecter / Reconfigurer", connect_broker)
	button(net, "Déconnecter MQTT", func(): controller.network.enabled = false; controller.network.send("/disconnect"))
	logs = TextEdit.new()
	logs.editable = false
	logs.custom_minimum_size = Vector2(310, 220)
	net.add_child(logs)
	var hint := Label.new()
	hint.text = "CLIC : analyser une terre   •   CLIC DROIT : orbite   •   MOLETTE : zoom   •   ZQSD / WASD : déplacer"
	hint.position = Vector2(445, 24)
	hint.add_theme_color_override("font_color", Color("16363b"))
	add_child(hint)
	sync_controls()

func connect_broker():
	if controller.network.busy:
		log_message("Requête en cours : réessayez dans 2 secondes.")
		return
	var config := {}
	for key in fields: config[key] = fields[key].text
	config.port = int(config.port)
	config.tls = tls.button_pressed
	controller.network.enabled = true
	controller.network.send("/configure", config)
	fields.password.text = ""

func sync_controls():
	if not is_instance_valid(irrigation): return
	var p: Dictionary = controller.sim.parcels[controller.selected_index]
	parcel_choice.select(controller.selected_index)
	crop_choice.select(crops.find(p.crop))
	irrigation.set_pressed_no_signal(p.irrigation)
	rain.set_pressed_no_signal(controller.sim.rain)
	for m in range(3): sensors[m].set_pressed_no_signal(p.stations[station_choice.selected].online[m])

func format_value(value, unit: String) -> String:
	return "—" if value == null else "%.1f %s" % [value, unit]

func refresh():
	var sim = controller.sim
	var index: int = controller.selected_index
	var p: Dictionary = sim.parcels[index]
	clock_label.text = "Jour %d · %02d:%02d · %s" % [int(sim.elapsed / 86400) + 1, int(12 + sim.elapsed / 3600) % 24, int(sim.elapsed / 60) % 60, "EN COURS" if sim.running else "PAUSE"]
	var measured: Dictionary = sim.readings(index)
	metrics.text = "%s · %s\nCulture : %s\nMoyennes des stations actives :\n%s · %s · %s\nCapteurs actifs T / sol / pluie : %d/3 · %d/3 · %d/3" % [p.id, p.soil_type, "AUCUNE (terre nue)" if p.crop == "" else p.crop, format_value(measured.values[0], "°C"), format_value(measured.values[1], "%"), format_value(measured.values[2], "mm/h"), measured.counts[0], measured.counts[1], measured.counts[2]]
	var diagnosis: Dictionary = sim.diagnosis(index)
	diagnosis_title.text = diagnosis.status
	diagnosis_text.text = diagnosis.text
	diagnosis_title.add_theme_color_override("font_color", {"good": Color("79d797"), "alert": Color("ef8968"), "empty": Color("e7c97d"), "unknown": Color("a8b5c1")}[diagnosis.kind])
	connection.text = controller.network.status
	var station: Dictionary = p.stations[station_choice.selected]
	station_reading.text = station.id + " · valeurs reçues :"
	for m in range(3):
		var on: bool = station.online[m]
		sensors[m].set_pressed_no_signal(on)
		sensors[m].text = "%s · %s" % [sim.sensor_id(index, station_choice.selected, m), format_value(station.observed[m], sim.UNITS[m]) if on else "HORS LIGNE"]
	for i in range(sim.parcels.size()):
		var parcel: Dictionary = sim.parcels[i]
		parcel_choice.set_item_text(i, "%02d · %s" % [i + 1, "Terre nue" if parcel.crop == "" else parcel.crop])

func log_message(message: String):
	logs.text = (Time.get_time_string_from_system() + " " + message + "\n" + logs.text).left(6500)
