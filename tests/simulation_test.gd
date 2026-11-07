extends SceneTree

func _initialize():
	var Simulation = load("res://scripts/simulation.gd")
	var a = Simulation.new()
	var b = Simulation.new()
	a.speed = 1
	b.speed = 1
	for n in range(3600): a.step(1.0)
	b.step(3600.0)
	assert(a.parcels == b.parcels, "Simulation déterministe")
	assert(a.parcels[0].values[1] < 58.0, "Évaporation")
	a.set_scenario(3)
	a.step(3600)
	assert(a.parcels[0].values[1] > 58.0, "Pluie humidifie")
	a.set_scenario(2)
	a.step(3600)
	assert(a.parcels[0].values[0] > 35.0, "Chaleur persistante")
	a.set_scenario(1)
	a.step(86400)
	for p in a.parcels: assert(p.values[1] >= 0 and p.values[1] <= 100)
	a.set_scenario(4)
	a.step(61)
	assert(a.messages().size() == 53, "Capteur en panne exclu")
	a.step(540)
	assert(a.messages().size() == 54, "Capteur reconnecté")
	a.reset()
	a.parcels[0].irrigation = true
	var moisture_before: float = a.parcels[0].values[1]
	a.step(3600)
	assert(a.parcels[0].values[1] > moisture_before, "Irrigation")
	a.running = false
	var before: float = a.elapsed
	a.step(100)
	assert(a.elapsed == before, "Pause")
	var ids := {}
	for message in a.messages():
		assert(not ids.has(message.payload.message_id))
		ids[message.payload.message_id] = true
	a.reset()
	assert(a.parcels.size() == 6 and a.messages().size() == 54)
	assert(a.diagnosis(0).kind == "good", "Blé compatible")
	assert(a.diagnosis(1).kind == "alert", "Maïs sec : alerte")
	assert(a.diagnosis(2).kind == "alert", "Soja humide : alerte")
	for i in range(3, 6): assert(a.diagnosis(i).kind == "empty")
	assert(a.diagnosis(3).candidates[0].crop == "Orge", "Terre sèche : profil orge")
	assert(a.diagnosis(4).candidates[0].compatible, "Terre équilibrée")
	assert(not a.diagnosis(5).candidates[0].compatible, "Terre trop humide : aucun profil compatible")
	a.set_crop(3, "Orge")
	assert(a.diagnosis(3).kind == "good", "Semis adapté")
	a.set_crop(3, "Maïs")
	assert(a.diagnosis(3).kind == "alert", "Semis inadapté")
	a.set_crop(3, "")
	assert(a.diagnosis(3).kind == "empty", "Retrait du semis")
	a.parcels[0].stations[0].online[1] = false
	assert(a.diagnosis(0).partial and a.readings(0).counts[1] == 2)
	for station in a.parcels[0].stations: station.online[1] = false
	assert(a.diagnosis(0).kind == "unknown", "Aucun diagnostic sans mesure sol")
	assert(a.messages().size() == 51)
	a.reset()
	a.elapsed = 121
	assert(a.diagnosis(0).kind == "unknown", "Mesures périmées exclues")
	a.reset()
	var sensor_ids := {}
	for msg in a.messages():
		assert(not sensor_ids.has(msg.payload.sensor_id))
		sensor_ids[msg.payload.sensor_id] = true
		assert(msg.payload.has("station_id") and msg.payload.has("position_local_m"))
	assert(a.parcels[0].stations[0].values[1] != a.parcels[0].stations[2].values[1], "Variations spatiales")
	assert(a.evaluate("Blé", 12, 35).compatible, "Bornes inclusives")
	assert(not a.evaluate("Blé", 11, 35).compatible)
	print("PASS : déterminisme, évaporation, pluie, chaleur, limites, panne/reconnexion, irrigation, pause, identifiants")
	print("PASS : 6 terrains, 54 capteurs, diagnostics, semis, données partielles/manquantes/périmées, localisation, seuils")
	quit()
