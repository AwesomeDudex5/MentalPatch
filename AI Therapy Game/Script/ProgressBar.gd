extends TextureProgressBar


func _ready():
	connect("HappinessChanged", update_bar)

func update_bar(currentHappiness):
	print("Updating Health Bar")
	value = currentHappiness


func _on_control_happiness_changed(current_value):
	print("Updating Health Bar " + str(current_value))
	value = current_value
