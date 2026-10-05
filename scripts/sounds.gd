extends Node

@onready var button_press_audio: AudioStreamPlayer = $ButtonPressAudio
@onready var button_hover_audio: AudioStreamPlayer = $ButtonHoverAudio
@onready var switch_press_audio: AudioStreamPlayer = $SwitchPressAudio
@onready var switch_hover_audio: AudioStreamPlayer = $SwitchHoverAudio


func play_button_press():
	button_press_audio.play()


func play_button_hover():
	button_hover_audio.play()


func play_switch_press():
	switch_press_audio.play()


func play_switch_hover():
	switch_hover_audio.play()
