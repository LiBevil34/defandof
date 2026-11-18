extends Node
## 오펜스(턴제) 및 디펜스(실시간) 공용 상태이상 · 버프/디버프 · 유효 스탯 계산기 (Autoload: StatusEffectManager)

const BUFF_TYPES: PackedStringArray = [
	"BUFF_ATK",
	"BUFF_DEF",
	"BUFF_SPEED",
	"BUFF_SPEED_FLAT",
	"BUFF_DMG_BONUS",
	"BUFF_CRIT_RATE",
	"BUFF_CRIT_DMG",
	"BUFF_ARMOR_PEN",
	"BUFF_FINAL_DMG",
	"DMG_REDUCE",
	"VANGUARD_INIT_SPD",
	"KILL_SPD_BOOST",
	"SHIELD",
	"REFLECT",
	"EXPLODE_ON_DEATH",
	"VISION_UP",
	"DANGER_SENSE",
]

const DEBUFF_TYPES: PackedStringArray = [
	"BURN",
	"POISON",
	"STUN",
	"SLOW",
	"DEF_DOWN",
]

const EFFECT_LABELS: Dictionary = {
	"DAMAGE": "피해",
	"HEAL": "회복",
	"SHIELD": "보호막",
	"BUFF_ATK": "공격력 증가",
	"BUFF_DEF": "방어력 증가",
	"BUFF_SPEED": "속도 증가",
	"BUFF_DMG_BONUS": "피해량 증가",
	"BUFF_CRIT_RATE": "치명타 확률 증가",
	"BUFF_CRIT_DMG": "치명타 피해 증가",
	"BUFF_ARMOR_PEN": "방어관통 증가",
	"BUFF_FINAL_DMG": "최종 피해량 증가",
	"BURN": "화상(DoT)",
	"POISON": "독(DoT)",
	"STUN": "기절(CC)",
	"SLOW": "감속(CC)",
	"DEF_DOWN": "방어력 감소",
	"REFLECT": "피격 반사",
	"EXPLODE_ON_DEATH": "사망 자폭",
	"PUSH_BACK": "강제 후퇴(밀어내기)",
	"PULL_FRONT": "강제 견인(끌어당김)",
	"SWAP_POS": "진형 교체(스왑)",
	"SHUFFLE_POS": "진형 교란(무작위 섞기)",
	"BUFF_SPEED_FLAT": "기습/매복 속도 보너스(+SPD)",
	"VANGUARD_INIT_SPD": "선봉 기동(+SPD)",
	"KILL_SPD_BOOST": "근위 처치 가속(+SPD)",
	"DMG_REDUCE": "보호 가호(피해 감소)",
	"VISION_UP": "탐색 시야 반경 증가(+칸)",
	"DANGER_SENSE": "매복/위험 사전 감지",
}


func is_displacement_effect(effect_id: String) -> bool:
	return effect_id in ["PUSH_BACK", "PULL_FRONT", "SWAP_POS", "SHUFFLE_POS"]


func get_effect_label(effect_id: String) -> String:
	return EFFECT_LABELS.get(effect_id, effect_id)


func is_buff(effect_id: String) -> bool:
	return BUFF_TYPES.has(effect_id)


func is_debuff(effect_id: String) -> bool:
	return DEBUFF_TYPES.has(effect_id)


## 유닛의 기본 스탯 + 패시브 + 현재 활성 버프/디버프를 합산한 유효 스탯을 반환합니다.
func get_effective_stat(unit: Dictionary, stat_name: String) -> float:
	var effects: Array = unit.get("status_effects", [])
	var passives: Dictionary = unit.get("passive_bonuses", {})
	var ranks: Dictionary = unit.get("rank_bonuses", {})

	match stat_name:
		"max_hp":
			return maxf(1.0, float(unit.get("max_hp", 50)) + float(passives.get("max_hp", 0.0)) + float(ranks.get("max_hp", 0.0)))
		"atk":
			var base_atk: float = float(unit.get("atk", 15)) + float(passives.get("atk", 0.0)) + float(ranks.get("atk", 0.0))
			var atk_pct: float = 0.0
			for eff in effects:
				if str(eff.get("id", "")) == "BUFF_ATK":
					atk_pct += float(eff.get("value", 0.0))
			var tired_atk_mult: float = 0.85 if bool(unit.get("is_tired", false)) else 1.0
			return maxf(1.0, base_atk * maxf(0.1, 1.0 + atk_pct) * tired_atk_mult)
		"def":
			var base_def: float = float(unit.get("def", 0)) + float(passives.get("def", 0.0)) + float(ranks.get("def", 0.0))
			var def_pct: float = 0.0
			for eff in effects:
				var eid: String = str(eff.get("id", ""))
				if eid == "BUFF_DEF":
					def_pct += float(eff.get("value", 0.0))
				elif eid == "DEF_DOWN":
					def_pct -= float(eff.get("value", 0.0))
			return maxf(0.0, base_def * maxf(0.0, 1.0 + def_pct))
		"speed":
			var base_spd: float = float(unit.get("speed", 10)) + float(passives.get("speed", 0.0)) + float(ranks.get("speed", 0.0))
			var spd_flat: float = 0.0
			var spd_pct: float = 0.0
			for eff in effects:
				var eid: String = str(eff.get("id", ""))
				if eid == "BUFF_SPEED_FLAT" or eid == "VANGUARD_INIT_SPD" or eid == "KILL_SPD_BOOST":
					spd_flat += float(eff.get("value", 0.0))
				elif eid == "BUFF_SPEED":
					spd_pct += float(eff.get("value", 0.0))
				elif eid == "SLOW":
					spd_pct -= float(eff.get("value", 0.0))
			var tired_spd_mult: float = 0.85 if bool(unit.get("is_tired", false)) else 1.0
			return maxf(1.0, (base_spd + spd_flat) * maxf(0.15, 1.0 + spd_pct) * tired_spd_mult)
		"dmg_bonus":
			var total_bonus: float = float(unit.get("dmg_bonus", 0.0)) + float(passives.get("dmg_bonus", 0.0)) + float(ranks.get("dmg_bonus", 0.0))
			for eff in effects:
				if str(eff.get("id", "")) == "BUFF_DMG_BONUS":
					total_bonus += float(eff.get("value", 0.0))
			return total_bonus
		"crit_rate":
			var total_crit: float = float(unit.get("crit_rate", 0.05)) + float(passives.get("crit_rate", 0.0)) + float(ranks.get("crit_rate", 0.0))
			for eff in effects:
				if str(eff.get("id", "")) == "BUFF_CRIT_RATE":
					total_crit += float(eff.get("value", 0.0))
			return clampf(total_crit, 0.0, 1.0)
		"crit_dmg":
			var total_cdmg: float = float(unit.get("crit_dmg", 1.5)) + float(passives.get("crit_dmg", 0.0)) + float(ranks.get("crit_dmg", 0.0))
			for eff in effects:
				if str(eff.get("id", "")) == "BUFF_CRIT_DMG":
					total_cdmg += float(eff.get("value", 0.0))
			return maxf(1.0, total_cdmg)
		"armor_pen":
			var total_pen: float = float(unit.get("armor_pen", 0.0)) + float(passives.get("armor_pen", 0.0))
			if str(unit.get("class_group", "")) == "근위":
				total_pen += 0.10
			for eff in effects:
				if str(eff.get("id", "")) == "BUFF_ARMOR_PEN":
					total_pen += float(eff.get("value", 0.0))
			return clampf(total_pen, 0.0, 1.0)
		"final_dmg_mult":
			var total_mult: float = float(unit.get("final_dmg_mult", 1.0)) * float(passives.get("final_dmg_mult", 1.0))
			for eff in effects:
				if str(eff.get("id", "")) == "BUFF_FINAL_DMG":
					total_mult *= maxf(0.1, 1.0 + float(eff.get("value", 0.0)))
			return maxf(0.1, total_mult)
		_:
			return float(unit.get(stat_name, 0.0))


## 피격 시 받는 피해 배율(중장 전열 -10%, 의료 보호 가호 -10%, 방패기사 등) 계산
func get_damage_taken_multiplier(unit: Dictionary) -> float:
	if unit.is_empty():
		return 1.0
	var reduce_sum: float = 0.0
	for eff in unit.get("status_effects", []):
		if str(eff.get("id", "")) == "DMG_REDUCE" and float(eff.get("duration", 0.0)) > 0.0:
			reduce_sum += float(eff.get("value", 0.0))
	var cg: String = str(unit.get("class_group", ""))
	var is_front_or_outside: bool = (unit.has("rank") and int(unit.get("rank", -1)) == 0) or (unit.has("zone") and int(unit.get("zone", -1)) == 1)
	if cg == "중장" and is_front_or_outside:
		reduce_sum += 0.10
	if str(unit.get("sub_trait", "")) == "WALL_GUARD" and is_front_or_outside:
		reduce_sum += 0.08
	if str(unit.get("archetype", "")) == "PHALANX":
		reduce_sum += 0.12
	return maxf(0.25, 1.0 - reduce_sum)


func is_stunned(unit: Dictionary) -> bool:
	var effects: Array = unit.get("status_effects", [])
	for eff in effects:
		if str(eff.get("id", "")) == "STUN" and float(eff.get("duration", 0.0)) > 0.0:
			return true
	return false


func get_speed_factor(unit: Dictionary) -> float:
	var base_spd: float = maxf(1.0, float(unit.get("speed", 10)))
	return get_effective_stat(unit, "speed") / base_spd


func get_total_shield(unit: Dictionary) -> int:
	return maxi(0, int(unit.get("shield", 0)))


func has_effect(unit: Dictionary, effect_id: String) -> bool:
	for eff in unit.get("status_effects", []):
		if str(eff.get("id", "")) == effect_id and float(eff.get("duration", 0.0)) > 0.0:
			return true
	return false


func get_effect_value(unit: Dictionary, effect_id: String) -> float:
	var best: float = 0.0
	for eff in unit.get("status_effects", []):
		if str(eff.get("id", "")) == effect_id and float(eff.get("duration", 0.0)) > 0.0:
			best = maxf(best, float(eff.get("value", 0.0)))
	return best


## 대상 유닛에 상태이상(버프/디버프/보호막)을 부여합니다.
func apply_effect(
	target: Dictionary,
	effect_id: String,
	value: float,
	duration: float,
	caster: Dictionary = {}
) -> Dictionary:
	if target.is_empty():
		return {}
	if not target.has("status_effects"):
		target["status_effects"] = []
	var effects: Array = target["status_effects"]

	var dur: float = maxf(1.0, duration)
	if duration > 0.0 and duration < 50.0 and not caster.is_empty():
		if str(caster.get("class_group", "")) == "보조" and (is_buff(effect_id) or is_debuff(effect_id)):
			dur += maxf(1.0, float(caster.get("_duration_ext", 1.0)))
	var tick_dmg: int = 0
	var shield_gain: int = 0

	if effect_id == "BURN":
		var caster_atk: float = get_effective_stat(caster, "atk") if not caster.is_empty() else 15.0
		tick_dmg = maxi(1, roundi(caster_atk * maxf(0.1, value)))
	elif effect_id == "POISON":
		var target_max_hp: float = get_effective_stat(target, "max_hp")
		tick_dmg = maxi(1, roundi(target_max_hp * maxf(0.01, value)))
	elif effect_id == "SHIELD":
		var caster_atk: float = get_effective_stat(caster, "atk") if not caster.is_empty() else 20.0
		shield_gain = maxi(1, roundi(caster_atk * maxf(0.1, value)))
		target["shield"] = get_total_shield(target) + shield_gain

	# 동일 ID 효과가 이미 있으면 최신 수치/지속시간으로 갱신
	for eff in effects:
		if str(eff.get("id", "")) == effect_id:
			eff["value"] = value
			eff["duration"] = maxf(float(eff.get("duration", 0.0)), dur)
			if tick_dmg > 0:
				eff["tick_damage"] = maxi(int(eff.get("tick_damage", 0)), tick_dmg)
			if shield_gain > 0:
				eff["value"] = float(get_total_shield(target))
			return eff

	var new_eff: Dictionary = {
		"id": effect_id,
		"value": float(shield_gain) if effect_id == "SHIELD" else value,
		"duration": dur,
		"tick_damage": tick_dmg,
		"dot_timer": 0.0,
		"source_name": str(caster.get("name", "")) if not caster.is_empty() else "",
	}
	effects.append(new_eff)
	return new_eff


## 피격 시 보호막(SHIELD)을 먼저 소모하고 남은 피해를 HP에 적용합니다.
func apply_damage_with_shield(target: Dictionary, raw_damage: int) -> Dictionary:
	var dmg: int = maxi(0, raw_damage)
	var cur_shield: int = get_total_shield(target)
	var absorbed: int = mini(cur_shield, dmg)
	var remaining_dmg: int = dmg - absorbed

	if absorbed > 0:
		var new_shield: int = cur_shield - absorbed
		target["shield"] = new_shield
		if new_shield <= 0:
			_remove_effect_by_id(target, "SHIELD")

	var prev_hp: int = int(target.get("hp", 0))
	var new_hp: int = maxi(0, prev_hp - remaining_dmg)
	target["hp"] = new_hp

	return {
		"shield_absorbed": absorbed,
		"hp_damage": prev_hp - new_hp,
		"remaining_shield": get_total_shield(target),
	}


func _remove_effect_by_id(unit: Dictionary, effect_id: String) -> void:
	if not unit.has("status_effects"):
		return
	var effects: Array = unit["status_effects"]
	for i in range(effects.size() - 1, -1, -1):
		if str(effects[i].get("id", "")) == effect_id:
			effects.remove_at(i)


func clear_debuffs(unit: Dictionary) -> int:
	if unit.is_empty() or not unit.has("status_effects"):
		return 0
	var removed: int = 0
	var effects: Array = unit["status_effects"]
	for i in range(effects.size() - 1, -1, -1):
		if is_debuff(str(effects[i].get("id", ""))):
			effects.remove_at(i)
			removed += 1
	return removed


func add_flat_shield(target: Dictionary, shield_amount: int, duration: float = 3.0, source_name: String = "아이템") -> void:
	if target.is_empty() or shield_amount <= 0:
		return
	if not target.has("status_effects"):
		target["status_effects"] = []
	target["shield"] = get_total_shield(target) + shield_amount
	var effects: Array = target["status_effects"]
	for eff in effects:
		if str(eff.get("id", "")) == "SHIELD":
			eff["value"] = float(get_total_shield(target))
			eff["duration"] = maxf(float(eff.get("duration", 0.0)), duration)
			return
	effects.append({
		"id": "SHIELD",
		"value": float(get_total_shield(target)),
		"duration": maxf(1.0, duration),
		"tick_damage": 0,
		"dot_timer": 0.0,
		"source_name": source_name,
	})


## [오펜스 턴제용] 턴 시작 시 DoT 피해를 적용하고 지속 턴을 1 감소시킵니다.
func tick_turn_effects(unit: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if unit.is_empty() or int(unit.get("hp", 0)) <= 0:
		return events
	if not unit.has("status_effects"):
		return events

	var effects: Array = unit["status_effects"]
	for i in range(effects.size() - 1, -1, -1):
		var eff: Dictionary = effects[i]
		var eid: String = str(eff.get("id", ""))

		if eid == "BURN" or eid == "POISON":
			var dot_dmg: int = int(eff.get("tick_damage", 1))
			var dmg_res: Dictionary = apply_damage_with_shield(unit, dot_dmg)
			events.append({
				"type": "dot",
				"effect_id": eid,
				"damage": dot_dmg,
				"hp_damage": dmg_res["hp_damage"],
				"shield_absorbed": dmg_res["shield_absorbed"],
			})
			if int(unit.get("hp", 0)) <= 0:
				return events

		eff["duration"] = float(eff.get("duration", 0.0)) - 1.0
		if float(eff["duration"]) <= 0.0:
			if eid == "SHIELD":
				unit["shield"] = 0
			effects.remove_at(i)
			events.append({"type": "expired", "effect_id": eid})

	return events


## [디펜스 실시간용] dt초만큼 지속시간을 줄이고 1초마다 DoT 피해를 발생시킵니다.
func tick_realtime_effects(unit: Dictionary, dt: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if unit.is_empty() or int(unit.get("hp", 0)) <= 0:
		return events
	if not unit.has("status_effects"):
		return events

	var effects: Array = unit["status_effects"]
	for i in range(effects.size() - 1, -1, -1):
		var eff: Dictionary = effects[i]
		var eid: String = str(eff.get("id", ""))

		if eid == "BURN" or eid == "POISON":
			var timer: float = float(eff.get("dot_timer", 0.0)) + dt
			while timer >= 1.0:
				timer -= 1.0
				var dot_dmg: int = int(eff.get("tick_damage", 1))
				var dmg_res: Dictionary = apply_damage_with_shield(unit, dot_dmg)
				events.append({
					"type": "dot",
					"effect_id": eid,
					"damage": dot_dmg,
					"hp_damage": dmg_res["hp_damage"],
					"shield_absorbed": dmg_res["shield_absorbed"],
				})
				if int(unit.get("hp", 0)) <= 0:
					return events
			eff["dot_timer"] = timer

		eff["duration"] = float(eff.get("duration", 0.0)) - dt
		if float(eff["duration"]) <= 0.0:
			if eid == "SHIELD":
				unit["shield"] = 0
			effects.remove_at(i)
			events.append({"type": "expired", "effect_id": eid})

	return events


func get_active_effect_badges(unit: Dictionary) -> String:
	var effects: Array = unit.get("status_effects", [])
	var tags: PackedStringArray = []
	if bool(unit.get("is_tired", false)):
		tags.append("지침(-15%)")
	for eff in effects:
		var eid: String = str(eff.get("id", ""))
		var label: String = get_effect_label(eid)
		var dur: int = ceili(float(eff.get("duration", 0.0)))
		if eid == "SHIELD":
			tags.append("보호막%d" % get_total_shield(unit))
		else:
			tags.append("%s(%d)" % [label, dur])
	return " ".join(tags)
