extends Control

signal HappinessChanged(current_value)

var returned_json
var current_emotion = "Neutral"
var sprite_avatar
var current_happiness = 50
var max_happiness = 100


#Emotion Sprites
@onready var neutral_expression = "res://Sprites/Jacob/Jacob-Neutral.png"
@onready var happy_expression = "res://Sprites/Jacob/Jacob-Happy.png"
@onready var scared_expression = "res://Sprites/Jacob/Jacob-Sad.png"
@onready var sad_expression = "res://Sprites/Jacob/Jacob-Sad.png"
@onready var angry_expression = "res://Sprites/Jacob/Jacob-Angry.png"
@onready var excited_expression = "res://Sprites/Jacob/Jacob-Happy.png"


#see https://ai.google.dev/tutorials/rest_quickstart

var api_key = ""
var http_request
var conversations = []
var last_user_prompt
@export var target_model = "v1beta/models/gemini-1.5-pro-latest"
func _ready():
	#Disable LevelComplete/Failed UI
	find_child("LevelCompleted").visible = false
	find_child("LevelFailed").visible = false
	find_child("MainUI").visible = true
	
	sprite_avatar = find_child("SpriteAvatar")
	emit_signal("HappinessChanged", current_happiness)
	
	var settings = JSON.parse_string(FileAccess.get_file_as_string("res://settings.json"))
	api_key = settings.api_key
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", _on_request_completed)

	var  option_keys = ["SexuallyExplicit","HateSpeech","Harassment","DangerousContent"]
	for key in option_keys:
		var option = find_child(key+"OptionButton")
		option.add_item("BLOCK_NONE")
		option.add_item("HARM_BLOCK_THRESHOLD_UNSPECIFIED")
		option.add_item("BLOCK_LOW_AND_ABOVE")
		option.add_item("BLOCK_MEDIUM_AND_ABOVE")
		option.add_item("BLOCK_ONLY_HIGH")
		
	var name = target_model.split("/")[-1]
	find_child("ModelName").text = name
	#conversations.append({"user":"I am aki","model":"Hello aki"})
	
	send_initial_prompt()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _get_option_selected_text(key):
	var option = find_child(key+"OptionButton")
	var text = option.get_item_text(option.get_selected_id())
	return  text


func _request_chat(prompt):
	
	var url = "https://generativelanguage.googleapis.com/%s:generateContent?key=%s"%[target_model,api_key]
	print(url)
	var contents_value = []
	for conversation in conversations:
		contents_value.append({
			"role":"user",
			"parts":[{"text":conversation["user"]}]
		})
		contents_value.append({
			"role":"model",
			"parts":[{"text":conversation["model"]}]
		})
		
	contents_value.append({
			"role":"user",
			"parts":[{"text":prompt}]
		})
	var body = JSON.new().stringify({
		"contents":contents_value
		,# basically useless,just they say 'I cant talk about that.'
		"safety_settings":[
			{
			"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
			"threshold": _get_option_selected_text("SexuallyExplicit"),
			},
			{
			"category": "HARM_CATEGORY_HATE_SPEECH",
			"threshold": _get_option_selected_text("HateSpeech"),
			},
			{
			"category": "HARM_CATEGORY_HARASSMENT",
			"threshold": _get_option_selected_text("Harassment"),
			},
			{
			"category": "HARM_CATEGORY_DANGEROUS_CONTENT",
			"threshold": _get_option_selected_text("DangerousContent"),
			},
			]
	})
	last_user_prompt = prompt
	#print("send-content"+str(body))
	print("Sending Body Contents")
	var error = http_request.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	
	if error != OK:
		push_error("requested but error happen code = %s"%error)

#For the Content Settings Labels
func _set_label_text(key,text):
	var label = find_child(key)
	if text == "HIGH":
		label.get_label_settings().set_font_color(Color(1,0,0,1))
	else:
		label.get_label_settings().set_font_color(Color(1,1,1,1))
	label.text = text	

#Once it gets signal from Gemini, Edits Chat Text Area
func _on_request_completed(result, responseCode, headers, body):
	find_child("SendButton").disabled = false
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var response = json.get_data()
	print("response")
	print(response)
	
	if response == null:
		print("response is null")
		find_child("FinishedLabel").text = "No Response"
		find_child("FinishedLabel").visible = true
		return
	
	
	if response.has("promptFeedback"):
		var ratings = response.promptFeedback.safetyRatings
		for rate in ratings:
			match rate.category:
				"HARM_CATEGORY_SEXUALLY_EXPLICIT":
					_set_label_text("SexuallyExplicitStatus",rate.probability)
					
				"HARM_CATEGORY_HATE_SPEECH":
					_set_label_text("HateSpeechStatus",rate.probability)
					
				"HARM_CATEGORY_HARASSMENT":
					_set_label_text("HarassmentStatus",rate.probability)
					
				"HARM_CATEGORY_DANGEROUS_CONTENT":
					_set_label_text("DangerousContentStatus",rate.probability)
					
	
	if response.has("error"):
		find_child("FinishedLabel").text = "ERROR"
		find_child("FinishedLabel").visible = true
		find_child("ResponseEdit").text = "[Error: Please try again, send another message or action]"
		#maybe blocked
		return
	
	#No Answer
	if !response.has("candidates"):
		find_child("FinishedLabel").text = "Blocked"
		find_child("FinishedLabel").visible = true
		find_child("ResponseEdit").text = ""
		#maybe blocked
		return
		
	#I can not talk about
	if response.candidates[0].finishReason != "STOP":
		find_child("FinishedLabel").text = "Safety"
		find_child("FinishedLabel").visible = true
		find_child("ResponseEdit").text = ""
	else:
		find_child("FinishedLabel").text = ""
		find_child("FinishedLabel").visible = false
		var newStr = response.candidates[0].content.parts[0].text
		
		# T H E  M A G I C  H A P P E N S  H E R E
		#process string to extract emotion and message
		var parsed_string = process_json_output_string(newStr)
		print(current_emotion)
		process_sprite(current_emotion)
		check_happiness()
		#can_enable_hold_hands()
		#can_enable_location_buttons()
		
		var input_field = find_child("InputEdit")
		input_field.text = ""
		
		find_child("ResponseEdit").text = parsed_string
		conversations.append({"user":"%s"%last_user_prompt,"model":"%s"%newStr})

#TODO Change prompt so AI knows its a game, its a patient and JSON should also include happiness
func send_initial_prompt():
	find_child("SendButton").disabled = true
	var starting_parameter = "You are a roleplaying bot, acting as a patient for the user.
	Of the three patients in the game, you have the medium difficulty.
	The user will be acting as the role of therapist.
	Please reply to my messages in JSON format like this for example: {'Emotion':'Your Emotion', 'Message':'Your message', 'EmotionAmount':'5'}. 
	For example, your starting message can go like this: {'Emotion':'Neutral', 'Message':'Hi Doc. Name is Jacob, heard you can help.', 'EmotionAmount':'7'}. 
	Replace the single quotes with quotation marks to make it more like proper JSON format. 
	Only respond in JSON format.
	The emotions available to you during this roleplay session are: Happy, Sad, Angry, Neutral.
	The emotion amount from your responses range from -10 to 10. -10 is extreme negative feeling and 10 is extreme positive feeling.
	You start off feeling neutral. The goal is the user to eventually resolve your problem and get your emotion
	to a satisfying amount. Respond properly when the user acts inappropiately.
	Your personality: Jacob is calm and mature man who works as an accountant. He has been married to his wife for 5 years and loves her dearly.
	Your problem: Marriage troubles. You seek out marriage counseling to help your relationship with your 
	wife because you have trouble communicating your emotions effectively. 
	Your likes: Your wife Laura, dogs, a hearty meal, math, numbers, tennis, basketball
	Your dislikes: Loud noises, passive aggressive tones, people who don't do their work properly."
	_request_chat(starting_parameter)

func process_json_output_string(output_string):
	# Parse the JSON string
	var json = JSON.new()
	var data = json.parse_string(output_string)
	print(data)
	#print("THIS IS SOMETHING YES"+str(data))
	#return "testing"
	
	var dict = data
	var current_message = "[Could not process, please try again]"
	
	if(dict != null):
		if(dict["Emotion"] != null):
			current_emotion = dict["Emotion"]
		if(dict["Message"]):
			current_message = dict["Message"]
		if(dict["EmotionAmount"]):
			print("Emotional Amount: " + str(dict["EmotionAmount"]))
			current_happiness += int(dict["EmotionAmount"])
			emit_signal("HappinessChanged", current_happiness)
	
	return current_message

func process_sprite(current_emote):
	var lowercase_emotion = current_emote.to_lower()
	match lowercase_emotion:
		"happy":
			
			sprite_avatar.texture = load(happy_expression)
			return
		"scared":
			
			sprite_avatar.texture = load(scared_expression)
			return
		"sad":
			
			sprite_avatar.texture = load(sad_expression)
			return
		"angry":
			
			sprite_avatar.texture = load(angry_expression)
			return
		"excited":
			
			sprite_avatar.texture = load(excited_expression)
			return
		"scared":
			
			sprite_avatar.texture = load(angry_expression)
			return
		_:
			sprite_avatar.texture = load(neutral_expression)
			return
func check_happiness():
	if(current_happiness >= 100):
		find_child("LevelCompleted").visible = true
	elif (current_happiness <= 0):
		find_child("LevelFailed").visible = true

func _on_reset_button_pressed():
	get_tree().reload_current_scene()

func _disable_send_button():
	find_child("SendButton").disabled = true
	find_child("HoldHandsButton").disabled = true
	

func _on_send_button_pressed():
	#_disable_location_buttons()
	find_child("SendButton").disabled = true
	var input_field = find_child("InputEdit")
	var input = input_field.text
	_request_chat(input)


func _on_back_button_pressed():
	var scene_path = "res://main.tscn"
	get_tree().change_scene_to_file(scene_path)
