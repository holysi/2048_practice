# scripts/GameManager.gd
extends Node

signal gold_changed(new_total: int)
signal bomb_aoe_requested(world_position: Vector2)

const GOLD_PER_MILESTONE: int = 20
const SCORE_MILESTONE: int = 200

var gold: int = 0
var _last_milestone_score: int = 0

## Called by Game.gd after every successful move.
func report_score(new_score: int) -> void:
	var milestones_passed := (new_score - _last_milestone_score) / SCORE_MILESTONE
	if milestones_passed > 0:
		gold += milestones_passed * GOLD_PER_MILESTONE
		_last_milestone_score += milestones_passed * SCORE_MILESTONE
		gold_changed.emit(gold)

## Called by TowerDefense.gd to purchase towers.
func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

## Called when enemies are killed or other gold rewards are granted.
func earn_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

## Called by HybridGame.gd when bomb AOE is triggered on the TD area.
func request_bomb_aoe(world_pos: Vector2) -> void:
	bomb_aoe_requested.emit(world_pos)

## Called on game restart.
func reset() -> void:
	gold = 0
	_last_milestone_score = 0
	gold_changed.emit(gold)
