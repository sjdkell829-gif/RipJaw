# ============================================================
#   RipJaw — match_config.gd
#   Pantalla de configuración de partida
# ============================================================
extends Control

var _stocks: int = 3
var _vs_bot: bool = false

var stocks_value: Label
var minus_btn: Button
var plus_btn: Button
var bot_check: CheckBox


func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stocks  = GameData.stocks
	_vs_bot  = GameData.vs_bot
	_build_ui()


func _build_ui():
	# Fondo
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Panel central
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 380)
	panel.position = Vector2(-210, -190)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	# Padding superior
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 20)
	vbox.add_child(margin)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 24)
	margin.add_child(inner)

	# Título
	var title = Label.new()
	title.text = "⚔ Configuración de Partida"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	inner.add_child(title)

	var sep = HSeparator.new()
	inner.add_child(sep)

	# ── Fila de vidas ──────────────────────────────────────
	var stocks_label = Label.new()
	stocks_label.text = "Número de vidas (1-9):"
	stocks_label.add_theme_font_size_override("font_size", 16)
	inner.add_child(stocks_label)

	var stocks_row = HBoxContainer.new()
	stocks_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stocks_row.add_theme_constant_override("separation", 20)
	inner.add_child(stocks_row)

	minus_btn = Button.new()
	minus_btn.text = "  —  "
	minus_btn.custom_minimum_size = Vector2(60, 50)
	minus_btn.add_theme_font_size_override("font_size", 22)
	minus_btn.pressed.connect(_on_minus)
	stocks_row.add_child(minus_btn)

	stocks_value = Label.new()
	stocks_value.text = str(_stocks)
	stocks_value.custom_minimum_size = Vector2(60, 50)
	stocks_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stocks_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stocks_value.add_theme_font_size_override("font_size", 32)
	stocks_row.add_child(stocks_value)

	plus_btn = Button.new()
	plus_btn.text = "  +  "
	plus_btn.custom_minimum_size = Vector2(60, 50)
	plus_btn.add_theme_font_size_override("font_size", 22)
	plus_btn.pressed.connect(_on_plus)
	stocks_row.add_child(plus_btn)

	var sep2 = HSeparator.new()
	inner.add_child(sep2)

	# ── Fila de bot ────────────────────────────────────────
	var bot_row = HBoxContainer.new()
	bot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_row.add_theme_constant_override("separation", 16)
	inner.add_child(bot_row)

	var bot_label = Label.new()
	bot_label.text = "Jugar vs Bot:"
	bot_label.add_theme_font_size_override("font_size", 16)
	bot_row.add_child(bot_label)

	bot_check = CheckBox.new()
	bot_check.button_pressed = _vs_bot
	bot_check.toggled.connect(_on_bot_toggled)
	bot_row.add_child(bot_check)

	var sep3 = HSeparator.new()
	inner.add_child(sep3)

	# ── Botones de acción ──────────────────────────────────
	var start_btn = Button.new()
	start_btn.text = "¡A pelear! ⚔"
	start_btn.custom_minimum_size = Vector2(340, 55)
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.pressed.connect(_on_start)
	inner.add_child(start_btn)

	var back_btn = Button.new()
	back_btn.text = "← Volver"
	back_btn.custom_minimum_size = Vector2(340, 40)
	back_btn.add_theme_font_size_override("font_size", 15)
	back_btn.pressed.connect(_on_back)
	inner.add_child(back_btn)

	_update_display()


func _update_display():
	stocks_value.text  = str(_stocks)
	minus_btn.disabled = (_stocks <= 1)
	plus_btn.disabled  = (_stocks >= 9)


func _on_minus():
	_stocks = max(1, _stocks - 1)
	_update_display()


func _on_plus():
	_stocks = min(9, _stocks + 1)
	_update_display()


func _on_bot_toggled(pressed: bool):
	_vs_bot = pressed
	GameData.vs_bot = pressed


func _on_start():
	GameData.stocks = _stocks
	GameData.vs_bot = _vs_bot
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")


func _on_back():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
