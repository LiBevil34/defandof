extends Node
## 난수(RNG) 없는 확정형 데미지 계산기 (Autoload: CombatCalculator)
## 공식:
##   유효방어력 = max(0, 대상방어력 * (1.0 - 방어관통률))
##   최종데미지 = max(1, int(공격력 * 스킬계수 * (1.0 + 데미지증가합) * 치명타배율 * (100.0 / (100.0 + 유효방어력)) * 속성상성배율 * 최종데미지배율)) + 고정데미지

## 확정 데미지(정수)만 반환합니다.
func calculate_damage(
	atk: float,
	target_defense: float = 0.0,
	attacker_element: String = "",
	defender_element: String = "",
	skill_multiplier: float = 1.0,
	dmg_bonus_sum: float = 0.0,
	crit_multiplier: float = 1.0,
	armor_penetration: float = 0.0,
	final_dmg_multiplier: float = 1.0,
	flat_damage: int = 0
) -> int:
	var result: Dictionary = calculate_damage_detailed(
		atk,
		target_defense,
		attacker_element,
		defender_element,
		skill_multiplier,
		dmg_bonus_sum,
		crit_multiplier,
		armor_penetration,
		final_dmg_multiplier,
		flat_damage
	)
	return int(result["damage"])


## 확정 데미지와 세부 계산 항목(유효방어력, 속성 배율 등)을 함께 반환합니다.
func calculate_damage_detailed(
	atk: float,
	target_defense: float = 0.0,
	attacker_element: String = "",
	defender_element: String = "",
	skill_multiplier: float = 1.0,
	dmg_bonus_sum: float = 0.0,
	crit_multiplier: float = 1.0,
	armor_penetration: float = 0.0,
	final_dmg_multiplier: float = 1.0,
	flat_damage: int = 0
) -> Dictionary:
	var pen_clamped: float = clampf(armor_penetration, 0.0, 1.0)
	var effective_def: float = maxf(0.0, target_defense * (1.0 - pen_clamped))
	var defense_factor: float = 100.0 / (100.0 + effective_def)
	var element_mult: float = DataManager.get_element_multiplier(attacker_element, defender_element)

	var raw_damage: float = (
		atk
		* skill_multiplier
		* (1.0 + dmg_bonus_sum)
		* crit_multiplier
		* defense_factor
		* element_mult
		* final_dmg_multiplier
	)

	var base_int: int = maxi(1, int(raw_damage))
	var total_damage: int = base_int + flat_damage

	return {
		"damage": total_damage,
		"base_damage": base_int,
		"effective_defense": effective_def,
		"defense_factor": defense_factor,
		"element_multiplier": element_mult,
		"flat_damage": flat_damage,
	}


## 시전자·피격자의 현재 유효 스탯을 반영해 상태를 변경하지 않고 예상 확정 데미지를 산출합니다 (AI/타겟팅용).
func predict_damage_detailed(
	attacker: Dictionary,
	defender: Dictionary,
	skill_effect: Dictionary = {},
	flat_damage: int = 0
) -> Dictionary:
	return _compute_skill_damage_internal(attacker, defender, skill_effect, flat_damage, false)


## 시전자·피격자의 현재 유효 스탯(패시브 + 버프/디버프 합산)과 스킬 옵션을 모두 반영해 확정 데미지를 산출합니다.
func calculate_skill_damage(
	attacker: Dictionary,
	defender: Dictionary,
	skill_effect: Dictionary = {},
	flat_damage: int = 0
) -> Dictionary:
	return _compute_skill_damage_internal(attacker, defender, skill_effect, flat_damage, true)


## 스마트 타겟팅 점수 계산:
## - 예상 확정 데미지로 즉사(현재 HP + 보호막 이하) 가능 시 +100점
## - 속성 상성 1.5x 시 +50점 / 0.75x 시 -30점
func score_smart_target(
	attacker: Dictionary,
	defender: Dictionary,
	skill_effect: Dictionary = {}
) -> Dictionary:
	var pred: Dictionary = predict_damage_detailed(attacker, defender, skill_effect)
	var dmg: int = int(pred["damage"])
	var elem_mult: float = float(pred["element_multiplier"])
	var effective_hp: int = int(defender.get("hp", 0)) + StatusEffectManager.get_total_shield(defender)
	var score: float = 0.0
	if effective_hp > 0 and dmg >= effective_hp:
		score += 100.0
	if elem_mult >= 1.45:
		score += 50.0
	elif elem_mult <= 0.80:
		score -= 30.0
	# 동점 시 피해량 및 마무리 근접도 반영
	score += minf(20.0, float(dmg) * 0.05)
	return {
		"score": score,
		"damage": dmg,
		"element_multiplier": elem_mult,
		"is_lethal": effective_hp > 0 and dmg >= effective_hp,
	}


func _compute_skill_damage_internal(
	attacker: Dictionary,
	defender: Dictionary,
	skill_effect: Dictionary,
	flat_damage: int,
	mutate_crit_gauge: bool
) -> Dictionary:
	var eff_atk: float = StatusEffectManager.get_effective_stat(attacker, "atk")
	var eff_dmg_bonus: float = StatusEffectManager.get_effective_stat(attacker, "dmg_bonus")
	var eff_crit_rate: float = StatusEffectManager.get_effective_stat(attacker, "crit_rate")
	var eff_crit_dmg: float = StatusEffectManager.get_effective_stat(attacker, "crit_dmg")
	if str(attacker.get("class_group", "")) == "특수" and bool(attacker.get("ambush_active", false)):
		eff_crit_dmg += 0.20
	var eff_armor_pen: float = StatusEffectManager.get_effective_stat(attacker, "armor_pen")
	var eff_final_mult: float = StatusEffectManager.get_effective_stat(attacker, "final_dmg_mult")
	var elem_adv: float = DataManager.get_element_multiplier(str(attacker.get("element", "")), str(defender.get("element", "")))
	if elem_adv >= 1.45 and str(attacker.get("class_group", "")) == "술사":
		eff_final_mult *= 1.15
	if elem_adv >= 1.45 and str(attacker.get("sub_trait", "")) == "ELEMENT_MASTERY":
		eff_final_mult *= 1.15
	var target_def: float = StatusEffectManager.get_effective_stat(defender, "def")

	var skill_mult: float = float(skill_effect.get("multiplier", 1.0))
	var bonus_crit_rate: float = float(skill_effect.get("skill_bonus_crit_rate", 0.0))
	var bonus_armor_pen: float = float(skill_effect.get("skill_bonus_armor_pen", 0.0))

	var total_crit_rate: float = clampf(eff_crit_rate + bonus_crit_rate, 0.0, 1.0)
	var total_armor_pen: float = clampf(eff_armor_pen + bonus_armor_pen, 0.0, 1.0)

	# 난수 없는 확정 치명타 판정 (100% 이상 즉시 치명타, 미만 시 누적 치명타 게이지로 결정론적 발동)
	var is_crit: bool = false
	if total_crit_rate >= 1.0:
		is_crit = true
	elif total_crit_rate > 0.0 and attacker.has("crit_gauge"):
		var gauge: float = float(attacker["crit_gauge"]) + total_crit_rate
		if gauge >= 1.0:
			is_crit = true
			gauge -= 1.0
		if mutate_crit_gauge:
			attacker["crit_gauge"] = gauge

	var applied_crit_mult: float = eff_crit_dmg if is_crit else 1.0

	var res: Dictionary = calculate_damage_detailed(
		eff_atk,
		target_def,
		str(attacker.get("element", "")),
		str(defender.get("element", "")),
		skill_mult,
		eff_dmg_bonus,
		applied_crit_mult,
		total_armor_pen,
		eff_final_mult,
		flat_damage
	)
	var def_taken_mult: float = StatusEffectManager.get_damage_taken_multiplier(defender)
	if def_taken_mult < 0.999:
		res["damage"] = maxi(1, roundi(float(res["damage"]) * def_taken_mult))
	res["is_crit"] = is_crit
	res["crit_multiplier"] = applied_crit_mult
	res["total_crit_rate"] = total_crit_rate
	res["total_armor_pen"] = total_armor_pen
	return res
