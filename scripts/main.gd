extends Node3D
const Simulation = preload("res://scripts/simulation.gd")
const Farm = preload("res://scripts/farm.gd")
const Network = preload("res://scripts/network.gd")
const Dashboard = preload("res://scripts/ui.gd")
var sim = Simulation.new()
var farm = Farm.new()
var network = Network.new()
var dashboard = Dashboard.new()
var selected_index := 0
var publication_clock := 0.0
var status_clock := 0.0

func _ready():
	farm.sim = sim
	add_child(farm)
	add_child(network)
	dashboard.controller = self
	add_child(dashboard)
	farm.selected.connect(func(i): selected_index = i; dashboard.sync_controls())
	network.report.connect(dashboard.log_message)
	if OS.get_cmdline_user_args().has("--mqtt-demo"):
		dashboard.fields.host.text = "broker.hivemq.com"
		dashboard.connect_broker()
	elif OS.get_cmdline_user_args().has("--mqtt-local"):
		dashboard.fields.host.text = "127.0.0.1"
		dashboard.connect_broker()

func _process(delta):
	sim.step(delta)
	farm.refresh(sim.parcels, selected_index)
	dashboard.refresh()
	status_clock += delta
	publication_clock += delta
	if network.enabled and not network.busy:
		if publication_clock >= dashboard.interval.value and sim.running:
			publication_clock = 0
			if network.connected:
				var messages: Array = sim.messages()
				network.send("/publish", {"messages": messages})
				if not messages.is_empty(): dashboard.log_message("Émission : " + JSON.stringify(messages[0]))
			else: network.send("/status")
		elif status_clock >= 2:
			status_clock = 0
			network.send("/status")
