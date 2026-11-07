extends RefCounted

const METRICS = ["temperature", "soil_moisture", "rainfall"]
const UNITS = ["°C", "%", "mm/h"]
const STATION_OFFSETS = [Vector2(-5.5, -2), Vector2(0, 2), Vector2(5.5, -1)]
var parcels: Array = []
var elapsed: float = 0.0
var running := true
var speed := 60.0
var rain := false
var scenario := 0
var rng := RandomNumberGenerator.new()
var profiles: Dictionary = {}

func _init():
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://config/crop_profiles.json"))
	profiles = data.crops
	reset()

func reset():
	rng.seed = 42001
	elapsed = 0.0
	rain = false
	parcels.clear()
	for i in range(6):
		var crops := ["Blé", "Maïs", "Soja", "", "", ""]
		var moisture := [58.0, 25.0, 88.0, 28.0, 57.0, 82.0]
		var offsets := [-1.5, 2.5, -0.5, 3.0, 0.0, -2.0]
		var soils := ["Limon équilibré", "Sol sableux sec", "Sol argileux humide", "Sol sableux sec", "Limon équilibré", "Sol argileux humide"]
		var p := {"id": "parcel-%03d" % (i + 1), "name": "Terrain %02d" % (i + 1), "crop": crops[i], "soil_type": soils[i], "temperature_offset": offsets[i], "evaporation_factor": [1.0, 1.5, 0.65, 1.5, 1.0, 0.65][i], "values": [22.0 + offsets[i], moisture[i], 0.0], "irrigation": false, "stations": []}
		for s in range(3):
			var values := [p.values[0] + (s - 1) * 0.35, p.values[1] + (s - 1) * 3.0, 0.0]
			p.stations.append({"id": "station-%03d-%s" % [i + 1, ["a", "b", "c"][s]], "values": values, "observed": values.duplicate(), "online": [true, true, true], "last_seen": [0.0, 0.0, 0.0]})
		parcels.append(p)

func set_scenario(index: int):
	scenario = index
	reset()

func set_crop(index: int, crop: String):
	if crop == "" or profiles.has(crop): parcels[index].crop = crop

func step(real_delta: float):
	if not running: return
	var target := elapsed + real_delta * speed
	while floor(elapsed) < floor(target):
		elapsed = floor(elapsed) + 1.0
		_tick()
	elapsed = target

func _tick():
	var hour := fmod(12.0 + elapsed / 3600.0, 24.0)
	var ambient := 21.0 + 7.0 * sin((hour - 8.0) / 24.0 * TAU)
	if scenario == 1: ambient += minf(elapsed / 7200.0, 8.0)
	if scenario == 2: ambient = 39.0
	var raining := rain or (scenario == 3 and elapsed < 7200.0)
	if scenario == 4:
		parcels[0].stations[0].online[1] = not (elapsed >= 60.0 and elapsed < 600.0)
	for p in parcels:
		var mean := [0.0, 0.0, 0.0]
		for s in range(3):
			var station: Dictionary = p.stations[s]
			var v: Array = station.values
			v[0] = clampf(move_toward(v[0], ambient + p.temperature_offset + (s - 1) * 0.35, 0.005) + rng.randf_range(-0.003, 0.003), -20.0, 55.0)
			v[2] = move_toward(v[2], 8.0 if raining else 0.0, 0.02)
			var evaporation: float = (0.7 + maxf(v[0] - 15.0, 0.0) * 0.08) * p.evaporation_factor / 3600.0
			if scenario == 1: evaporation *= 2.0
			v[1] = clampf(v[1] - evaporation + v[2] * 0.7 / 3600.0 + (5.0 / 3600.0 if p.irrigation else 0.0) + rng.randf_range(-0.0002, 0.0002), 0.0, 100.0)
			for m in range(3):
				mean[m] += v[m] / 3.0
				if station.online[m]:
					station.observed[m] = v[m]
					station.last_seen[m] = elapsed
		p.values = mean

func readings(index: int) -> Dictionary:
	var values := []
	var counts := []
	var spans := []
	for m in range(3):
		var samples: Array = []
		for station in parcels[index].stations:
			if station.online[m] and elapsed - station.last_seen[m] <= 120:
				samples.append(station.observed[m])
		counts.append(samples.size())
		if samples.is_empty():
			values.append(null)
			spans.append(null)
		else:
			var total := 0.0
			for value in samples: total += value
			values.append(total / samples.size())
			spans.append([samples.min(), samples.max()])
	return {"values": values, "counts": counts, "spans": spans}

func evaluate(crop: String, temperature: float, moisture: float) -> Dictionary:
	var profile: Dictionary = profiles[crop]
	var reasons: Array = []
	var penalty := 0.0
	for item in [[temperature, profile.temperature, "Température", "°C"], [moisture, profile.soil_moisture, "Humidité", "%"]]:
		if item[0] < item[1][0]:
			reasons.append("%s trop basse (%.1f < %.0f %s)" % [item[2], item[0], item[1][0], item[3]])
			penalty += (item[1][0] - item[0]) / (item[1][1] - item[1][0])
		elif item[0] > item[1][1]:
			reasons.append("%s trop élevée (%.1f > %.0f %s)" % [item[2], item[0], item[1][1], item[3]])
			penalty += (item[0] - item[1][1]) / (item[1][1] - item[1][0])
	return {"crop": crop, "compatible": reasons.is_empty(), "penalty": penalty, "reasons": reasons}

func diagnosis(index: int) -> Dictionary:
	var p: Dictionary = parcels[index]
	var measured := readings(index)
	var result := {"status": "DONNÉES INSUFFISANTES", "kind": "unknown", "text": "Reconnecter au moins un capteur de température et d'humidité. Aucune conclusion possible.", "candidates": [], "partial": measured.counts[0] < 3 or measured.counts[1] < 3}
	if measured.values[0] == null or measured.values[1] == null: return result
	var ranked: Array = []
	for crop in profiles: ranked.append(evaluate(crop, measured.values[0], measured.values[1]))
	ranked.sort_custom(func(a, b): return a.penalty < b.penalty)
	result.candidates = ranked
	var matches: Array = []
	for item in ranked:
		if item.compatible: matches.append(item.crop)
	if p.crop == "":
		result.kind = "empty"
		result.status = "TERRE NUE · À ÉVALUER"
		result.text = "Profils compatibles maintenant : " + (", ".join(matches) if not matches.is_empty() else "aucun des profils démo")
		if matches.is_empty(): result.text += ". Ne pas proposer de semis automatiquement."
	else:
		var assessment := evaluate(p.crop, measured.values[0], measured.values[1])
		result.kind = "good" if assessment.compatible else "alert"
		result.status = "CONDITIONS COMPATIBLES" if assessment.compatible else "ALERTE · CONDITIONS INADAPTÉES"
		result.text = p.crop + " : " + ("dans les plages du profil démo." if assessment.compatible else "; ".join(assessment.reasons) + ".")
		if not assessment.compatible:
			result.text += " Autres profils compatibles : " + (", ".join(matches) if not matches.is_empty() else "aucun") + "."
	var spread: Array = measured.spans[1]
	result.text += "\nHumidité locale : %.1f–%.1f %% (variation entre stations)." % [spread[0], spread[1]]
	if result.partial: result.text += "\nDonnées partielles : diagnostic moins représentatif."
	return result

func sensor_id(parcel_index: int, station_index: int, metric_index: int) -> String:
	return "%s-%03d%s" % [["temp", "soil", "rain"][metric_index], parcel_index + 1, "" if station_index == 0 else ["", "-b", "-c"][station_index]]

func messages() -> Array:
	var result: Array = []
	for i in range(parcels.size()):
		var p: Dictionary = parcels[i]
		for s in range(3):
			var station: Dictionary = p.stations[s]
			for m in range(3):
				if not station.online[m]: continue
				var sensor := sensor_id(i, s, m)
				var payload := {"message_id": Crypto.new().generate_random_bytes(16).hex_encode(), "farm_id": "farm-001", "parcel_id": p.id, "sensor_id": sensor, "station_id": station.id, "metric": METRICS[m], "value": snappedf(station.observed[m], 0.01), "unit": UNITS[m], "timestamp": Time.get_datetime_string_from_system(true) + "Z", "simulated": true, "simulated_elapsed_seconds": snappedf(elapsed, 0.01), "crop": p.crop, "land_use": "bare" if p.crop == "" else "planted", "position_local_m": {"x": STATION_OFFSETS[s].x, "z": STATION_OFFSETS[s].y}}
				result.append({"topic": "agriwatch/farm-001/%s/sensors/%s/telemetry" % [p.id, sensor], "payload": payload})
	return result
