extends CanvasLayer

const FRAME := preload("res://textures/inventory.png")
const COIN := preload("res://textures/currency_coin.png")
# Области спрайтов без прозрачных полей.
const ICON_REGIONS := {
	"strength": Rect2(17, 4, 117, 354),
	"adrenaline": Rect2(9, 17, 135, 327),
}
const BATTLE_COMPONENT_SCENES := [
	"res://battle_cell.tscn",
	"res://battle_unit.tscn",
]

var open_button: Button
var wallet: PanelContainer
var balance: Label
var overlay: ColorRect
var frame: TextureRect
var close_button: Button
var details: ScrollContainer
var description: Label
var slots: Array[Button] = []
var displayed_counts: Dictionary[String, int] = {}
var quantity_font := SystemFont.new()
var paused_by_inventory := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(false)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.alignment = BoxContainer.ALIGNMENT_END
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	header.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	header.offset_left = -12
	header.offset_top = 12
	header.offset_right = -12
	header.offset_bottom = 56

	open_button = Button.new()
	open_button.text = "Инвентарь"
	open_button.custom_minimum_size.x = 180
	open_button.hide()
	header.add_child(open_button)
	open_button.pressed.connect(_open)

	wallet = PanelContainer.new()
	wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.09, 0.085, 0.105, 0.9)
	background.set_corner_radius_all(6)
	background.content_margin_left = 8
	background.content_margin_right = 10
	wallet.add_theme_stylebox_override("panel", background)
	header.add_child(wallet)

	var funds := HBoxContainer.new()
	funds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	funds.add_theme_constant_override("separation", 6)
	wallet.add_child(funds)

	var coin := TextureRect.new()
	coin.texture = COIN
	coin.custom_minimum_size = Vector2(32, 32)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	funds.add_child(coin)

	balance = Label.new()
	balance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	funds.add_child(balance)
	GameState.money_changed.connect(_update_balance)
	_update_balance(GameState.money)

	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.hide()
	root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var aspect := AspectRatioContainer.new()
	aspect.ratio = 1.25
	aspect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(aspect)
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aspect.offset_left = 12
	aspect.offset_top = 12
	aspect.offset_right = -12
	aspect.offset_bottom = -12

	frame = TextureRect.new()
	frame.texture = FRAME
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aspect.add_child(frame)

	close_button = Button.new()
	close_button.flat = true
	close_button.tooltip_text = "Закрыть инвентарь"
	frame.add_child(close_button)
	_place(close_button, Rect2(1166, 53, 91, 79))
	close_button.pressed.connect(_close)

	details = ScrollContainer.new()
	details.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(details)
	_place(details, Rect2(75, 828, 1130, 122))

	description = Label.new()
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_override("font", ThemeDB.fallback_font)
	description.add_theme_font_size_override("font_size", 15)
	details.add_child(description)

	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed()


func _input(event: InputEvent) -> void:
	if overlay.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _on_scene_changed() -> void:
	_close()
	var tree := get_tree()
	var scene := tree.current_scene
	wallet.visible = (
		scene != null
		and scene.scene_file_path != "res://main_menu.tscn"
		and not tree.has_group("battle_arena")
		and scene.scene_file_path not in BATTLE_COMPONENT_SCENES
	)
	open_button.visible = wallet.visible and scene.scene_file_path != "res://main_menu.tscn"


func _update_balance(amount: int) -> void:
	balance.text = str(amount)


func _open() -> void:
	if displayed_counts != GameState.item_counts:
		for slot in slots:
			slot.hide()
			slot.queue_free()
		slots.clear()
		displayed_counts.assign(GameState.item_counts)
		for item_id in GameState.BATTLE_ITEMS:
			var count: int = displayed_counts[item_id]
			if count > 0:
				_add_slot(item_id, count, slots.size())
	description.text = "Инвентарь пуст" if slots.is_empty() else "Выберите предмет"
	details.scroll_vertical = 0

	open_button.hide()
	overlay.show()
	set_process_input(true)
	paused_by_inventory = not get_tree().paused
	get_tree().paused = true
	close_button.grab_focus()


func _close() -> void:
	if not overlay.visible:
		return
	overlay.hide()
	set_process_input(false)
	if paused_by_inventory:
		get_tree().paused = false
		paused_by_inventory = false
	open_button.show()
	open_button.grab_focus()


func _add_slot(item_id: String, count: int, index: int) -> void:
	var item: Dictionary = GameState.BATTLE_ITEMS[item_id]
	var slot := Button.new()
	slot.flat = true
	slot.icon = item.icon
	if ICON_REGIONS.has(item_id):
		var cropped_icon := AtlasTexture.new()
		cropped_icon.atlas = item.icon
		cropped_icon.region = ICON_REGIONS[item_id]
		cropped_icon.filter_clip = true
		slot.icon = cropped_icon
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.expand_icon = true
	slot.tooltip_text = item.name
	frame.add_child(slot)
	var columns := [75, 243, 412, 580, 750, 920]
	var rows := [162, 322, 483, 643]
	var row := floori(float(index) / columns.size())
	_place(slot, Rect2(columns[index % columns.size()], rows[row], 156, 151))
	slot.pressed.connect(func() -> void:
		description.text = "%s ×%d\n%s" % [item.name, count, item.description]
		details.scroll_vertical = 0
	)
	slots.append(slot)

	var quantity := Label.new()
	quantity.text = "×%d" % count
	quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantity.add_theme_font_override("font", quantity_font)
	quantity.add_theme_font_size_override("font_size", 16)
	quantity.add_theme_color_override("font_outline_color", Color.BLACK)
	quantity.add_theme_constant_override("outline_size", 5)
	slot.add_child(quantity)
	quantity.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 5)


func _place(control: Control, bounds: Rect2) -> void:
	var texture_size := FRAME.get_size()
	control.anchor_left = bounds.position.x / texture_size.x
	control.anchor_top = bounds.position.y / texture_size.y
	control.anchor_right = bounds.end.x / texture_size.x
	control.anchor_bottom = bounds.end.y / texture_size.y
