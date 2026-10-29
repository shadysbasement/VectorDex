extends PanelContainer

# ==========================================================================================
# Pokemon Card Component
#
# Clickable card in the right console list with smooth sliding hover physics,
# type pills, and dynamic active glow.
# ==========================================================================================

signal card_selected(pokemon_data: Dictionary)

const TYPE_COLORS: Dictionary = {
    "normal": Color(0.66, 0.65, 0.48),
    "fire": Color(0.93, 0.51, 0.19),
    "water": Color(0.39, 0.56, 0.94),
    "electric": Color(0.97, 0.82, 0.17),
    "grass": Color(0.48, 0.78, 0.30),
    "ice": Color(0.59, 0.85, 0.84),
    "fighting": Color(0.76, 0.18, 0.16),
    "poison": Color(0.64, 0.24, 0.63),
    "ground": Color(0.89, 0.75, 0.40),
    "flying": Color(0.66, 0.56, 0.95),
    "psychic": Color(0.98, 0.33, 0.53),
    "bug": Color(0.65, 0.73, 0.10),
    "rock": Color(0.71, 0.63, 0.21),
    "ghost": Color(0.45, 0.34, 0.59),
    "dragon": Color(0.44, 0.21, 0.99),
    "steel": Color(0.72, 0.72, 0.81),
    "fairy": Color(0.84, 0.52, 0.68)
}

@onready var sprite_texture: TextureRect = $HBox/Sprite
@onready var number_label: Label = $HBox/VBox/Header/Number
@onready var name_label: Label = $HBox/VBox/Header/Name
@onready var types_container: HBoxContainer = $HBox/VBox/Types
@onready var button: Button = $SelectButton
@onready var active_bar: ColorRect = $ActiveBar

var pokemon_data: Dictionary = {}
var is_active: bool = false
var base_style: StyleBoxFlat

func _ready():
    button.pressed.connect(_on_pressed)
    button.mouse_entered.connect(_on_mouse_entered)
    button.mouse_exited.connect(_on_mouse_exited)

    base_style = StyleBoxFlat.new()
    base_style.bg_color = Color(0.09, 0.10, 0.14, 0.85)
    base_style.set_corner_radius_all(6)
    base_style.border_width_left = 2
    base_style.border_width_top = 1
    base_style.border_width_right = 1
    base_style.border_width_bottom = 1
    base_style.border_color = Color(0.18, 0.20, 0.28, 0.6)
    add_theme_stylebox_override("panel", base_style)

    active_bar.visible = false

func set_pokemon(data: Dictionary):
    pokemon_data = data
    if not is_node_ready():
        await ready
    
    number_label.text = data.get("number", "#000")
    name_label.text = data.get("name", "Unknown")

    # Load thumbnail artwork
    var path = "res://assets/images/artwork/%d.png" % data.get("id", 1)
    if ResourceLoader.exists(path):
        sprite_texture.texture = load(path)
    elif FileAccess.file_exists(path):
        var img = Image.load_from_file(path)
        if img:
            sprite_texture.texture = ImageTexture.create_from_image(img)
        
    # render type tags
    for c in types_container.get_children():
        c.queue_free()

    var types: Array = data.get("types", [])
    for t in types:
        var pill = _create_type_pill(t)
        types_container.add_child(pill)

func _create_type_pill(type_name: String) -> PanelContainer:
    var pill = PanelContainer.new()
    var pill_style = StyleBoxFlat.new()
    var col = TYPE_COLORS.get(type_name.to_lower(), Color(0.5, 0.5, 0.5))
    pill_style.bg_color = Color(col.r, col.g, col.b, 0.25)
    pill_style.border_color = Color(col.r, col.g, col.b, 0.8)
    pill_style.border_width_bottom = 1
    pill_style.border_width_left = 1
    pill_style.border_width_right = 1
    pill_style.border_width_top = 1
    pill_style.set_corner_radius_all(3)
    pill.add_theme_stylebox_override("panel", pill_style)

    var lbl = Label.new()
    lbl.text = " " + type_name.to_upper() + " "
    lbl.add_theme_font_size_override("font_size", 9)
    lbl.add_theme_color_override("font_color", col)
    pill.add_child(lbl)
    return pill

func set_selected(selected: bool):
    is_active = selected
    active_bar.visible = selected

    var primary_type = "normal"
    var types: Array = pokemon_data.get("types", [])
    if types.size() > 0:
        primary_type = types[0].to_lower()
    var theme_col = TYPE_COLORS.get(primary_type, Color.WHITE)

    if selected:
        base_style.bg_color = Color(0.13, 0.16, 0.24, 1.0)
        base_style.border_color = theme_col
        base_style.shadow_color = Color(theme_col.r, theme_col.g, theme_col.b, 0.2)
        base_style.shadow_size = 4
        active_bar.color = theme_col
    else:
        base_style.bg_color = Color(0.09, 0.10, 0.14, 0.85)
        base_style.border_color = Color(0.18, 0.20, 0.28, 0.6)
        base_style.shadow_size = 0

func _on_pressed():
    card_selected.emit(pokemon_data)

func _on_mouse_entered():
    if not is_active:
        base_style.bg_color = Color(0.12, 0.14, 0.20, 1.0)
        var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(self, "position:x", 4.0, 0.1)

func _on_mouse_exited():
    if not is_active:
        base_style.bg_color = Color(0.09, 0.10, 0.14, 0.85)
        var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(self, "position:x", 0.0, 0.1)
 