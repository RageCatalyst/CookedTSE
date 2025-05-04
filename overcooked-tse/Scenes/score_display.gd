extends CanvasLayer

@onready var score_label = $Control/VBoxContainer/Score/ScoreValue
@onready var combo_label = $Control/VBoxContainer/Combo/ComboValue
@onready var multiplier_label = $Control/VBoxContainer/Multiplier/MultiplierValue

@onready var score_tracker = get_node("/root/ScoreTracker")

func _ready():
	print("---ScoreDisplay init ---")
	print("ScoreTracker: ", score_tracker != null)
	print("Score Label: ", score_label != null)
	
	if !score_tracker:
		printerr("ERROR: scoretracker not found! check name and node path")
		return
		
	if score_tracker.has_signal("score_updated"):
		score_tracker.score_updated.connect(_on_score_updated)
		print("scoretracker connected succesfully")
	else:
		printerr("ERROR: score_updated signal missing")
	
	
func _on_score_updated(total_score: int, current_combo: int):
	print("[Scoredisplay] Recieved update! Score: %d, Combo: %d" % [total_score, current_combo])
	
	var multiplier = min(floor((current_combo + 1) / 2), score_tracker.max_combo - 1) + 1
	update_display(total_score, current_combo, multiplier)





func update_display(score: int, combo: int, multiplier: int):
	print("[ScoreDisplay] Updating UI with", score, combo, multiplier)
	score_label.text = str(score)
	combo_label.text = str(combo)
	multiplier_label.text = "x" + str(multiplier)
	
	score_label.set_deferred("text", str(score))
	if multiplier >= 3:
		multiplier_label.add_theme_color_override("font_colour", Color.GOLD)
	else:
		multiplier_label.remove_theme_color_override("font_color")
