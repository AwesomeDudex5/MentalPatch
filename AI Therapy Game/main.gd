extends Control

var settings_path = "res://settings.json"
# Called when the node enters the scene tree for the first time.
func _ready():
	var PatientSelectMenu = find_child("PatientSelectionMenu")
	var StartMenu = find_child("StartMenu")
	PatientSelectMenu.visible = false
	StartMenu.visible = true
	update_UI()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func update_UI():
	if FileAccess.file_exists(settings_path):
		find_child("MainMenu").visible = true
		find_child("SetAPIKeyMenu").visible = false
	else:
		find_child("MainMenu").visible = false
		find_child("SetAPIKeyMenu").visible = true

##TODO adjust ui so user can set their own API key
#func _on_set_api_button_pressed():
	#var key = find_child("KeyEdit").text
	#if key.is_empty():
		#return
	#var json_text = JSON.stringify({"api_key":key})
	#var file = FileAccess.open(settings_path,FileAccess.WRITE)
	#file.store_string(json_text)
	#file.close()


func _on_patient_1_pressed():
	var scene_path = "res://Scene/Patient1.tscn"
	get_tree().change_scene_to_file(scene_path)


func _on_patient_2_pressed():
	var scene_path = "res://Scene/Patient2.tscn"
	get_tree().change_scene_to_file(scene_path)


func _on_patient_3_pressed():
	var scene_path = "res://Scene/Patient3.tscn"
	get_tree().change_scene_to_file(scene_path)


func _on_send_ap_ibutton_pressed():
	var key = find_child("KeyEdit").text
	if key.is_empty():
		return
	var json_text = JSON.stringify({"api_key":key})
	var file = FileAccess.open(settings_path,FileAccess.WRITE)
	file.store_string(json_text)
	file.close()
	update_UI()


func _on_start_button_pressed():
	var PatientSelectMenu = find_child("PatientSelectionMenu")
	var StartMenu = find_child("StartMenu")
	PatientSelectMenu.visible = true
	StartMenu.visible = false


func _on_back_button_pressed():
	var PatientSelectMenu = find_child("PatientSelectionMenu")
	var StartMenu = find_child("StartMenu")
	PatientSelectMenu.visible = false
	StartMenu.visible = true
