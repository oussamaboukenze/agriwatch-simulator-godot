extends SceneTree
var frames := 0
func _initialize():
	root.add_child(load("res://scenes/main.tscn").instantiate())
func _process(_delta):
	frames += 1
	if frames == 30:
		root.get_texture().get_image().save_png("res://preview.png")
		quit()
	return false
