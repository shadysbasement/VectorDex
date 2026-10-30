extends Control

# ==================================================================================
# Hoenn-Spec Pokedex Console Controller
#
# Elevated with modern Dribbble-tier aesthetics:
# - dynamic type-tinted hero card (mint green for grass, coral for fire, etc)
# - pokeball watermark backdrop behind the floting sprite
# - shiny pokemon mode with sparkle burst and instant shiny artwork swap
# - live type defenses matric (2x weaknesses & 0.5x resistances via the type chart)
# - keyboard navigation legend
# ==================================================================================

const TYPE_COLORS: Dictionary = {
    "grass": Color("#48d0b0"),   # mint teal
    "fire": Color("#fb6c6c"),    # coral salmon
    "water": Color("#76befe"),   # sky cyan
    "electric": Color("#ffd769"), # sunburst amber
    "poison": Color("#a890f0"),   # lavender poison
    "bug": Color("#8bd674"),      # lime leaf
    "normal": Color("#b5b9c4"),   # steel grey
    "ground": Color("#e0c068"),   # sand amber
    "fairy": Color("#fdb9e9"),    # pastel pink
    "fighting": Color("#eb4971"), # crimson rose
    "psychic": Color("#fa65b0"),  # vibrant magenta
    "rock": Color("#c5b679"),     # desert rock
    "ghost": Color("#7c538c"),    # phantom plum
    "ice": Color("#98d8d8"),      # glacial ice
    "dragon": Color("#7b62fe"),   # mystic royal purple
    "dark": Color("#705848"),     # umber brown
    "steel": Color("#b8b8d0")     # platinum silver
}

# node references
@onready var sound_manager: Node = $SoundManager
@onready var search_capsule: PanelContainer = %SearchCapsule
@onready var search_icon: TextureRect = %SearchIcon
@onready var search_input: LineEdit = %SearchInput
@onready var cards_container: VBoxContainer = %CardsContainer
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var entry_count_label: Label = %EntryCountLabel

# hero elements
@onready var hero_card_panel: PanelContainer = %HeroCardPanel
@onready var hero_artwork: TextureRect = %HeroArtwork
@onready var hero_spotlight: TextureRect = %HeroSpotlight
@onready var hero_number: Label = %HeroNumber
@onready var hero_name: Label = %HeroName
@onready var hero_genus: Label = %HeroGenus
@onready var hero_types: HBoxContainer = %HeroTypes
@onready var play_cry_btn: Button = %PlayCryBtn
@onready var shiny_btn: Button = %ShinyBtn
@onready var sparkle_particles: CPUParticles2D = %SparkleParticles

# modular HUD cards
@onready var height_val: Label = %HeightVal
@onready var weight_val: Label = %WeightVal
@onready var abilities_container: HBoxContainer = %AbilitiesContainer
@onready var flavor_text: Label = %FlavorText
@onready var total_stats_val: Label = %TotalStatsVal
@onready var flavor_terminal: PanelContainer = %FlavorTerminal
@onready var weaknesses_container: HFlowContainer = %WeaknessesContainer
@onready var resistances_container: HFlowContainer = %ResistancesContainer

# stat bars
@onready var stat_hp: HBoxContainer = %StatHP
@onready var stat_atk: HBoxContainer = %StatATK
@onready var stat_def: HBoxContainer = %StatDEF
@onready var stat_spa: HBoxContainer = %StatSPA
@onready var stat_spd: HBoxContainer = %StatSPD
@onready var stat_spe: HBoxContainer = %StatSPE

# hardware lights
@onready var orb_lens: TextureRect = %OrbLens
@onready var led_green1: ColorRect = %LEDGreen1
@onready var led_green2: ColorRect = %LEDGreen2

# state
var all_pokemon: Array = []
var filtered_pokemon: Array = []
var active_pokemon: Dictionary = {}
var active_index: int = 0
var is_shiny: bool = false
var idle_time: float = 0.0

var card_scene: PackedScene = preload("res://scenes/components/pokemon_card.tscn")
var card_nodes: Dictionary = {}

func _ready():
    if hero_card_panel:
        var st = hero_card_panel.get_theme_stylebox("panel")
        if st:
            hero_card_panel.add_theme_stylebox_override("panel", st.duplicate())
    if flavor_terminal:
        var ft = flavor_terminal.get_theme_stylebox("panel")
        if ft:
            flavor_terminal.add_theme_stylebox_override("panel", ft.duplicate())
    if search_capsule:
        var sc = search_capsule.get_theme_stylebox("panel")
        if sc:
            search_capsule.add_theme_stylebox_override("panel", sc.duplicate())

    _setup_spotlight_texture()
    _connect_ui_signals()
    _load_pokedex_data()

    if all_pokemon.size() > 0:
        select_pokemon(all_pokemon[0])

func _process(delta: float):
    idle_time += delta * 2.4
    if hero_artwork:
        hero_artwork.position.y = sin(idle_time) * 4.5
    if orb_lens:
        var p = (sin(idle_time * 1.5) * 0.5 + 0.5) * 0.25 + 0.85
        orb_lens.modulate.a = p

func _setup_spotlight_texture():
    if hero_spotlight:
        var grad = Gradient.new()
        grad.colors = PackedColorArray([Color(1, 1, 1, 0.4), Color(1, 1, 1, 0.0)])
        grad.offsets = PackedFloat32Array([0.0, 1.0])
        var tex = GradientTexture2D.new()
        tex.gradient = grad
        tex.fill = GradientTexture2D.FILL_RADIAL
        tex.fill_from = Vector2(0.5, 0.5)
        tex.fill_to = Vector2(0.5, 0.0)
        tex.width = 256
        tex.height = 256
        hero_spotlight.texture = tex

func _connect_ui_signals():
    search_input.text_changed.connect(_on_search_changed)
    search_input.focus_entered.connect(_on_search_focus_entered)
    search_input.focus_exited.connect(_on_search_focus_exited)
    play_cry_btn.pressed.connect(func(): _play_active_cry())
    shiny_btn.pressed.connect(_toggle_shiny)
    %RandomBtn.pressed.connect(_select_random)

func _load_pokedex_data():
    var path = "res://data/pokedex.json"
    if not FileAccess.file_exists(path):
        printerr("pokedex.json not found! Run 'ruby tools/fetch_pokedex.rb' first.")
        return

    var file = FileAccess.open(path, FileAccess.READ)
    var json = JSON.new()
    if json.parse(file.get_as_text()) == OK:
        all_pokemon = json.data
        filtered_pokemon = all_pokemon.duplicate()
        _populate_card_list()
        if entry_count_label:
            entry_count_label.text = "[ %d / %d ]" % [filtered_pokemon.size(), all_pokemon.size()]

func _populate_card_list():
    for c in cards_container.get_children():
        c.queue_free()
    card_nodes.clear()

    for poke in filtered_pokemon:
        var card = card_scene.instantiate()
        cards_container.add_child(card)
        card.set_pokemon(poke)
        card.card_selected.connect(select_pokemon)
        card_nodes[poke["id"]] = card

    if active_pokemon.has("id") and card_nodes.has(active_pokemon["id"]):
        card_nodes[active_pokemon["id"]].set_selected(true)

    if entry_count_label:
        entry_count_label.text = "[ %d / %d ]" % [filtered_pokemon.size(), all_pokemon.size()]

func select_pokemon(poke: Dictionary):
    if poke.is_empty():
        return

    sound_manager.play_click()
    active_pokemon = poke
    active_index = all_pokemon.find(poke)

    for id in card_nodes:
        card_nodes[id].set_selected(id == poke["id"])

    # 1. header & text
    hero_number.text = poke.get("number", "#000")
    hero_name.text = poke.get("name", "Unknown").capitalize()
    hero_genus.text = poke.get("genus", "Pokémon").to_upper()

    # 2. artwork (regular vs shiny)
    _update_artwork()

    # 3. type badges & dynamic colors
    for c in hero_types.get_children():
        hero_types.remove_child(c)
        c.queue_free()

    var types: Array = poke.get("types", ["normal"])
    for t in types:
        hero_types.add_child(_create_type_badge(t))

    var primary_type = types[0].to_lower()
    var theme_color = TYPE_COLORS.get(primary_type, Color("#48d0b0"))
    _animate_theme_color(theme_color)

    # 4. physical specs & bio
    height_val.text = "%s m" % str(poke.get("height", 0.0))
    weight_val.text = "%s kg" % str(poke.get("weight", 0.0))
    flavor_text.text = poke.get("flavor_text", "No bio data recorded.")

    # abilties matrix
    for c in abilities_container.get_children():
        abilities_container.remove_child(c)
        c.queue_free()
    for a in poke.get("abilities", []):
        var pill = _create_ability_pill(a.get("name", "unknown"), a.get("is_hidden", false), theme_color)
        abilities_container.add_child(pill)

    # 5. type defenses (weaknesses & resistances)
    _update_type_defenses(types)

    #6. base stats
    var stats: Dictionary = poke.get("stats", {})
    stat_hp.set_stat("HP", stats.get("hp", 50))
    stat_atk.set_stat("ATK", stats.get("attack", 50))
    stat_def.set_stat("DEF", stats.get("defense", 50))
    stat_spa.set_stat("SP.A", stats.get("special_attack", 50))
    stat_spd.set_stat("SP.D", stats.get("special_defense", 50))
    stat_spe.set_stat("SPD", stats.get("speed", 50))
    total_stats_val.text = "BASE TOTAL: %d" % stats.get("total", 300)

    # 7. play cry
    _play_active_cry()

func _update_artwork():
    var poke_id = active_pokemon.get("id", 1)
    var folder = "shiny" if is_shiny else "artwork"
    var art_path = "res://assets/images/%s/%d.png" % [folder, poke_id]

    if ResourceLoader.exists(art_path):
        hero_artwork.texture = load(art_path)
    elif FileAccess.file_exists(art_path):
        var img = Image.load_from_file(art_path)
        if img:
            hero_artwork.texture = ImageTexture.create_from_image(img)

func _update_type_defenses(defending_types: Array):
    for c in weaknesses_container.get_children():
        weaknesses_container.remove_child(c)
        c.queue_free()
    for c in resistances_container.get_children():
        resistances_container.remove_child(c)
        c.queue_free()

    var defenses = TypeChart.get_defenses(defending_types)

    # render 2x weaknesses
    for w in defenses["weaknesses"]:
        weaknesses_container.add_child(_create_defense_chip(w, "2x"))

    # redner 0.5x resistances
    for r in defenses["resistances"]:
        resistances_container.add_child(_create_defense_chip(r, "1/2"))

func _create_defense_chip(type_name: String, multiplier: String) -> PanelContainer:
    var chip = PanelContainer.new()
    var style = StyleBoxFlat.new()
    var col = TYPE_COLORS.get(type_name.to_lower(), Color.GRAY)
    style.bg_color = Color(col.r, col.g, col.b, 0.25)
    style.border_color = col
    style.border_width_left = 1
    style.border_width_right = 1
    style.border_width_top = 1
    style.border_width_bottom = 1
    style.set_corner_radius_all(3)
    chip.add_theme_stylebox_override("panel", style)

    var lbl = Label.new()
    lbl.text = " %s %s " % [type_name.to_upper(), multiplier]
    lbl.add_theme_font_size_override("font_size", 9)
    lbl.add_theme_color_override("font_color", col)
    chip.add_child(lbl)
    return chip

func _create_type_badge(type_name: String) -> PanelContainer:
    var badge = PanelContainer.new()
    var style = StyleBoxFlat.new()
    # white semi-translucent pill like the dribbvle reference!
    style.bg_color = Color(1.0, 1.0, 1.0, 0.25)
    style.set_corner_radius_all(12)
    badge.add_theme_stylebox_override("panel", style)

    var lbl = Label.new()
    lbl.text = "  " + type_name.capitalize() + "  "
    lbl.add_theme_font_size_override("font_size", 11)
    lbl.add_theme_color_override("font_color", Color.WHITE)
    badge.add_child(lbl)
    return badge

func _create_ability_pill(ab_name: String, is_hidden: bool, theme_col: Color) -> PanelContainer:
    var pill = PanelContainer.new()
    var style = StyleBoxFlat.new()

    if is_hidden:
        style.bg_color = Color(1.0, 0.75, 0.2, 0.15)
        style.border_color = Color(1.0, 0.75, 0.2, 0.8)
    else:
        style.bg_color = Color(0.12, 0.14, 0.20, 0.9)
        style.border_color = Color(0.24, 0.28, 0.38, 0.7)

    style.border_width_left = 1
    style.border_width_right = 1
    style.border_width_top = 1
    style.border_width_bottom = 1
    style.set_corner_radius_all(4)
    pill.add_theme_stylebox_override("panel", style)

    var lbl = Label.new()
    var text_suffix = " (HIDDEN)" if is_hidden else ""
    lbl.text = "  " + ab_name.to_upper() + text_suffix + "  "
    lbl.add_theme_font_size_override("font_size", 10)
    var col = Color(1.0, 0.82, 0.3) if is_hidden else Color(0.82, 0.86, 0.94)
    lbl.add_theme_color_override("font_color", col)
    pill.add_child(lbl)
    return pill

func _animate_theme_color(target_color: Color):
    var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

    # animate the hero card background color
    if hero_card_panel:
        var card_style: StyleBoxFlat = hero_card_panel.get_theme_stylebox("panel")
        if card_style:
            tween.tween_property(card_style, "bg_color", target_color, 0.45)
            tween.tween_property(card_style, "shadow_color", Color(target_color.r, target_color.g, target_color.b, 0.35), 0.45)

    if flavor_terminal:
        var ft_box: StyleBoxFlat = flavor_terminal.get_theme_stylebox("panel")
        if ft_box:
            tween.tween_property(ft_box, "border_color", target_color, 0.4)

func _play_active_cry():
    if active_pokemon.has("id"):
        sound_manager.play_cry(active_pokemon["id"])
        _flash_leds()

func _flash_leds():
    var tween = create_tween().set_parallel(true)
    if led_green1:
        tween.tween_property(led_green1, "modulate", Color(2.0, 2.5, 2.0, 1.0), 0.08)
        tween.chain().tween_property(led_green1, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)
    if led_green2:
        tween.tween_property(led_green2, "modulate", Color(2.0, 2.5, 2.0, 1.0), 0.08)
        tween.chain().tween_property(led_green2, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)
    if orb_lens:
        tween.tween_property(orb_lens, "modulate", Color(2.0, 2.5, 3.0, 1.0), 0.08)
        tween.chain().tween_property(orb_lens, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
func _toggle_shiny():
    is_shiny = not is_shiny
    shiny_btn.text = "SHINY ON" if is_shiny else "SHINY"
    sound_manager.play_click()
    _update_artwork()
    _apply_shiny_active_style(is_shiny)

    if is_shiny and sparkle_particles:
        sparkle_particles.restart()
        sparkle_particles.emitting = true

func _apply_shiny_active_style(active: bool):
    if not shiny_btn:
        return
    if active:
        var style = StyleBoxFlat.new()
        style.bg_color = Color(0.25, 0.20, 0.06, 1.0)
        style.border_width_left = 2
        style.border_width_top = 2
        style.border_width_right = 2
        style.border_width_bottom = 2
        style.border_color = Color(1.0, 0.88, 0.25, 1.0)
        style.set_corner_radius_all(16)
        style.shadow_color = Color(1.0, 0.88, 0.25, 0.5)
        style.shadow_size = 10
        shiny_btn.add_theme_stylebox_override("normal", style)
        shiny_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
    else:
        shiny_btn.remove_theme_stylebox_override("normal")
        shiny_btn.remove_theme_color_override("font_color")

func _on_search_focus_entered():
    sound_manager.play_click()
    if search_capsule:
        var style: StyleBoxFlat = search_capsule.get_theme_stylebox("panel")
        if style:
            var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
            tween.tween_property(style, "border_color", Color(0.3, 0.85, 0.95, 1.0), 0.2)
            tween.tween_property(style, "shadow_color", Color(0.3, 0.85, 0.95, 0.4), 0.2)
            tween.tween_property(style, "shadow_size", 8, 0.2)
    if search_icon:
        var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        tween.tween_property(search_icon, "modulate", Color(0.4, 0.9, 1.0), 0.2)

func _on_search_focus_exited():
    if search_capsule:
        var style: StyleBoxFlat = search_capsule.get_theme_stylebox("panel")
        if style:
            var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
            tween.tween_property(style, "border_color", Color(0.26, 0.11, 0.08, 0.9), 0.25)
            tween.tween_property(style, "shadow_color", Color(0, 0, 0, 0.4), 0.25)
            tween.tween_property(style, "shadow_size", 4, 0.25)
    if search_icon:
        var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        tween.tween_property(search_icon, "modulate", Color(0.65, 0.72, 0.85), 0.25)

func _navigate_relative(offset: int):
    if all_pokemon.is_empty():
        return
    var new_idx = wrapi(active_index + offset, 0, all_pokemon.size())
    select_pokemon(all_pokemon[new_idx])
    _scroll_to_active()

func _select_random():
    if all_pokemon.is_empty():
        return
    var rnd = randi() % all_pokemon.size()
    select_pokemon(all_pokemon[rnd])
    _scroll_to_active()

func _scroll_to_active():
    if active_pokemon.has("id") and card_nodes.has(active_pokemon["id"]):
        var card = card_nodes[active_pokemon["id"]]
        scroll_container.ensure_control_visible(card)

func _on_search_changed(query: String):
    var q = query.strip_edges().to_lower()
    if q.is_empty():
        filtered_pokemon = all_pokemon.duplicate()
    else:
        filtered_pokemon = all_pokemon.filter(func(p):
            var name_match = p.get("name", "").to_lower().contains(q)
            var num_match = p.get("number", "").to_lower().contains(q) or str(p.get("id", "")).contains(q)
            var type_match = false
            for t in p.get("types", []):
                if t.to_lower().contains(q):
                    type_match = true
                    break
            return name_match or num_match or type_match
        )
    _populate_card_list()

func _input(event: InputEvent):
    if event is InputEventKey and event.pressed and not event.echo:
        if search_input.has_focus():
            if event.keycode == KEY_ESCAPE:
                search_input.text = ""
                _on_search_changed("")
                search_input.release_focus()
                get_viewport().set_input_as_handled()
            return

        match event.keycode:
            KEY_SLASH:
                search_input.grab_focus()
                get_viewport().set_input_as_handled()
            KEY_J, KEY_DOWN:
                _navigate_relative(1)
                get_viewport().set_input_as_handled()
            KEY_K, KEY_UP:
                _navigate_relative(-1)
                get_viewport().set_input_as_handled()
            KEY_LEFT:
                _navigate_relative(-10)
                get_viewport().set_input_as_handled()
            KEY_RIGHT:
                _navigate_relative(10)
                get_viewport().set_input_as_handled()
            KEY_SPACE:
                _play_active_cry()
                get_viewport().set_input_as_handled()
            KEY_S:
                _toggle_shiny()
                get_viewport().set_input_as_handled()
            KEY_R:
                _select_random()
                get_viewport().set_input_as_handled()
