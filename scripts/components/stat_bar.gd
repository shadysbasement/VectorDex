extends HBoxContainer

# =======================================================================
# StatBar Component
#
# High-tech cyber stat meter with rounded capsule bars, rating labels,
# and fluid tweened fill transactions
# =======================================================================

@onready var stat_name_label: Label = $NamePill/StatName
@onready var stat_value_label: Label = $StatValue
@onready var bar_background: PanelContainer = $BarContainer
@onready var bar_fill: ColorRect = $BarContainer/BarFill
@onready var rating_label: Label = $RatingLabel

var target_width: float = 0.0

func set_stat(name_text: String, value: int, max_val: int = 255):
    if stat_name_label:
        stat_name_label.text = name_text
    if stat_value_label:
        stat_value_label.text = "%3d" % value

    # Compute color and rank title
    var col: Color
    var rank: String
    if value >= 140:
        col = Color(0.74, 0.48, 1.0) # s-tier violet
        rank = "ELITE"
    elif value >= 110:
        col = Color(0.0, 0.9, 1.0) # a-tier cyan
        rank = "HIGH"
    elif value >= 80:
        col = Color(0.2, 0.9, 0.5) # b-tier emerald
        rank = "GOOD"
    elif value >= 50:
        col = Color(1.0, 0.72, 0.2) # c-tier amber
        rank = "NORM"
    else:
        col = Color(1.0, 0.35, 0.38) # d-tier red
        rank = "POOR"
    
    if rating_label:
        rating_label.text = rank
        rating_label.add_theme_color_override("font_color", col)

    if bar_fill:
        bar_fill.color = col
        if not is_node_ready():
            await ready

        await get_tree().process_frame
        var pct = clampf(float(value) / float(max_val), 0.0, 1.0)
        target_width = bar_background.size.x * pct

        var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        tween.tween_property(bar_fill, "custom_minimum_size:x", target_width, 0.4)
