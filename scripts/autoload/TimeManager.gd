extends Node
## 시간, 계절, 날짜(5일 주기 디펜스 데이), 3년차 6단계 시기 및 일일 페이즈 순환 관리 (Autoload: TimeManager)
## GlobalData와 연동하여 평일(내정->마을->오펜스->정산)과 디펜스 데이(내정->마을->디펜스->정산)를 순환시킵니다.

const DAYS_PER_MONTH: int = 30
const DEFENSE_INTERVAL_DAYS: int = 5

const EVENT_STAGE_NAMES: Dictionary = {
	1: "1단계 · 개척기 (1년차 봄·여름)",
	2: "2단계 · 정착기 (1년차 가을·겨울)",
	3: "3단계 · 갈등기 (2년차 봄·여름)",
	4: "4단계 · 격변기 (2년차 가을·겨울)",
	5: "5단계 · 위기기 (3년차 봄·여름)",
	6: "6단계 · 결전기 (3년차 가을·겨울~)",
}

enum Season {
	SPRING,
	SUMMER,
	AUTUMN,
	WINTER,
}

const SEASON_NAMES: Dictionary = {
	Season.SPRING: "봄",
	Season.SUMMER: "여름",
	Season.AUTUMN: "가을",
	Season.WINTER: "겨울",
}

const PHASE_NAMES: Dictionary = {
	GlobalData.GamePhase.MANAGEMENT: "내정",
	GlobalData.GamePhase.TOWN: "마을 관리",
	GlobalData.GamePhase.DUNGEON: "오펜스",
	GlobalData.GamePhase.DEFENSE: "디펜스",
	GlobalData.GamePhase.SETTLEMENT: "정산",
}

# --- 시그널 ---
signal date_changed(year: int, season: Season, day_of_month: int)
signal season_changed(new_season: Season)
signal time_updated()

# --- 시간 상태 ---
var current_year: int = 1
var current_month: int = 1
var current_season: Season = Season.SPRING
var current_day_of_month: int = 1


func _ready() -> void:
	_apply_starting_phase_for_today()


## 5일 주기(5, 10, 15, 20, 25, 30일)이면 디펜스 데이로 판별합니다.
func is_defense_day(day: int = current_day_of_month) -> bool:
	return day > 0 and (day % DEFENSE_INTERVAL_DAYS) == 0


## 현재 진행 월(1년차 1월~3년차 12월+)을 총 6단계 시기(1~6)로 반환합니다.
func get_event_stage(month: int = current_month) -> int:
	return clampi(int((maxi(1, month) - 1) / 2) + 1, 1, 6)


func get_event_stage_label(stage: int = -1) -> String:
	var s: int = get_event_stage() if stage < 1 else clampi(stage, 1, 6)
	return str(EVENT_STAGE_NAMES.get(s, "%d단계" % s))


func get_event_scale_multiplier(stage: int = -1) -> float:
	var s: int = get_event_stage() if stage < 1 else clampi(stage, 1, 6)
	return 1.0 + float(s - 1) * 0.25


## 다음 디펜스 데이까지 남은 일수를 반환합니다. (오늘이 디펜스 데이면 0)
func get_days_until_defense(from_day: int = current_day_of_month) -> int:
	for offset in range(DAYS_PER_MONTH + 1):
		var d: int = ((from_day - 1 + offset) % DAYS_PER_MONTH) + 1
		if is_defense_day(d):
			return offset
	return 0


func get_season_name(season: Season = current_season) -> String:
	return SEASON_NAMES.get(season, "봄")


func get_season_key(season: Season = current_season) -> String:
	match season:
		Season.SUMMER:
			return "SUMMER"
		Season.AUTUMN:
			return "AUTUMN"
		Season.WINTER:
			return "WINTER"
		_:
			return "SPRING"


## 연차·계절별 적 스탯 스케일링 배율 및 환경 특성을 반환합니다.
func get_season_enemy_multipliers() -> Dictionary:
	var year_mult: float = 1.0 + float(maxi(0, current_year - 1)) * 0.35
	match current_season:
		Season.SUMMER:
			return {
				"hp": 1.15 * year_mult,
				"atk": 1.18 * year_mult,
				"def": 1.00 * year_mult,
				"speed": 1.15,
				"bonus_effect": "BURN",
				"trait_label": "여름 열파 (적 HP×1.15, ATK×1.18, 속도+15% / 화상 특성)",
			}
		Season.AUTUMN:
			return {
				"hp": 1.30 * year_mult,
				"atk": 1.25 * year_mult,
				"def": 1.15 * year_mult,
				"speed": 1.10,
				"bonus_effect": "DEF_DOWN",
				"trait_label": "가을 침공 (적 HP×1.30, ATK×1.25, DEF×1.15 / 파쇄 특성)",
			}
		Season.WINTER:
			return {
				"hp": 1.50 * year_mult,
				"atk": 1.30 * year_mult,
				"def": 1.35 * year_mult,
				"speed": 1.00,
				"bonus_effect": "SLOW",
				"trait_label": "겨울 혹한 (적 HP×1.50, ATK×1.30, DEF×1.35 / 빙결 감속)",
			}
		_:
			return {
				"hp": 1.00 * year_mult,
				"atk": 1.00 * year_mult,
				"def": 1.00 * year_mult,
				"speed": 1.00,
				"bonus_effect": "",
				"trait_label": "봄 평온 (표준 배율 ×%.2f)" % year_mult,
			}


func get_phase_name(phase: GlobalData.GamePhase = GlobalData.current_phase) -> String:
	return PHASE_NAMES.get(phase, "알 수 없음")


## 현재 날짜의 페이즈 흐름을 반환합니다. (UI 표시용)
func get_today_flow_text() -> String:
	if is_defense_day():
		return "내정 → 마을 관리 → 디펜스 → 정산"
	return "내정 → 마을 관리 → 오펜스 → 정산"


## 다음 페이즈로 순환합니다. 정산 이후에는 다음 날로 넘어갑니다.
func advance_phase() -> void:
	var phase: GlobalData.GamePhase = GlobalData.current_phase

	match phase:
		GlobalData.GamePhase.MANAGEMENT:
			GlobalData.set_phase(GlobalData.GamePhase.TOWN)
		GlobalData.GamePhase.TOWN:
			if is_defense_day():
				GlobalData.set_phase(GlobalData.GamePhase.DEFENSE)
			else:
				GlobalData.set_phase(GlobalData.GamePhase.DUNGEON)
		GlobalData.GamePhase.DUNGEON:
			GlobalData.set_phase(GlobalData.GamePhase.SETTLEMENT)
		GlobalData.GamePhase.DEFENSE:
			# 5일 주기 디펜스 페이즈 클리어 직후에만 대형 던전(FIELD_GRID) 맵 상태를 초기화하여 다음 주기에 새로 생성되게 함
			GlobalData.clear_field_dungeon_state()
			GlobalData.set_phase(GlobalData.GamePhase.SETTLEMENT)
		GlobalData.GamePhase.SETTLEMENT:
			_start_next_day()
		_:
			GlobalData.set_phase(GlobalData.GamePhase.MANAGEMENT)

	time_updated.emit()


func _start_next_day() -> void:
	current_day_of_month += 1
	if current_day_of_month > DAYS_PER_MONTH:
		current_day_of_month = 1
		current_month += 1
		var next_season_idx: int = (int(current_season) + 1) % Season.size()
		if next_season_idx == 0:
			current_year += 1
		current_season = next_season_idx as Season
		season_changed.emit(current_season)

	GlobalData.advance_day()
	_apply_starting_phase_for_today()
	date_changed.emit(current_year, current_season, current_day_of_month)


func _apply_starting_phase_for_today() -> void:
	GlobalData.set_phase(GlobalData.GamePhase.MANAGEMENT)


func reset_time() -> void:
	current_year = 1
	current_month = 1
	current_season = Season.SPRING
	current_day_of_month = 1
	GlobalData.reset_game()
	_apply_starting_phase_for_today()
	date_changed.emit(current_year, current_season, current_day_of_month)
	season_changed.emit(current_season)
	time_updated.emit()
