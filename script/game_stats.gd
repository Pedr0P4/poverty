class_name GameStats
extends RefCounted

const SAVE_PATH: String = "user://game_records.json"


static func load_stats() -> Dictionary:
	var default_stats: Dictionary = {
		"best_survival_time": 0.0,
		"best_kills": 0,
		"total_games_played": 0,
		"total_kills": 0,
		"total_time_survived": 0.0
	}

	if not FileAccess.file_exists(SAVE_PATH):
		return default_stats

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return default_stats

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(content)
	if error != OK:
		return default_stats

	var data = json.get_data()
	if not (data is Dictionary):
		return default_stats

	var dict := data as Dictionary
	for k: String in default_stats.keys():
		if not dict.has(k):
			dict[k] = default_stats[k]

	return dict


static func save_stats(stats: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	var json_str := JSON.stringify(stats, "\t")
	file.store_string(json_str)
	file.close()


static func get_best_time() -> float:
	var stats := load_stats()
	return float(stats.get("best_survival_time", 0.0))


static func get_best_kills() -> int:
	var stats := load_stats()
	return int(stats.get("best_kills", 0))


static func format_time(seconds: float) -> String:
	var total_sec: int = maxi(0, int(floor(seconds)))
	var mins: int = total_sec / 60
	var secs: int = total_sec % 60
	return "%02d:%02d" % [mins, secs]


static func register_run(survival_time: float, kills: int) -> Dictionary:
	var stats := load_stats()

	var old_best_time: float = float(stats.get("best_survival_time", 0.0))
	var old_best_kills: int = int(stats.get("best_kills", 0))

	var is_new_best_time: bool = survival_time > old_best_time
	var is_new_best_kills: bool = kills > old_best_kills

	if is_new_best_time:
		stats["best_survival_time"] = survival_time
	if is_new_best_kills:
		stats["best_kills"] = kills

	stats["total_games_played"] = int(stats.get("total_games_played", 0)) + 1
	stats["total_kills"] = int(stats.get("total_kills", 0)) + kills
	stats["total_time_survived"] = float(stats.get("total_time_survived", 0.0)) + survival_time

	save_stats(stats)

	return {
		"survival_time": survival_time,
		"kills": kills,
		"is_new_best_time": is_new_best_time,
		"is_new_best_kills": is_new_best_kills,
		"best_time": float(stats["best_survival_time"]),
		"best_kills": int(stats["best_kills"]),
		"total_games": int(stats["total_games_played"]),
		"total_kills": int(stats["total_kills"])
	}
