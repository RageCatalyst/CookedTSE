extends Node

signal score_updated(total_score, current_combo)

var current_combo := 0
var total_score := 0
const max_combo := 4

func calculate_order_score(order: Node) -> int:
	if not order.has_method("get_tip"):
		return 0
	
	print("8.[ScoreTracker] Calculating score")
	var tip = order.get_tip()
	var processing_steps = 3 #chop 3 onions = 3 steps ? maybe change to 4 for cooking aswell ?

	current_combo += 1
	var combo_multiplier = min(floor((current_combo + 1) / 2), max_combo -1) + 1
	
	var score = (processing_steps * 20) + (tip * combo_multiplier)
	total_score += score
	print("10.new total score", total_score)
	print("11.[ScoreTracker] Emmiting score_updated with:",total_score, current_combo)
	
	
	score_updated.emit(total_score, current_combo)
	return score
	
func reset_combo():
	current_combo = 0
	score_updated.emit(total_score, current_combo)
