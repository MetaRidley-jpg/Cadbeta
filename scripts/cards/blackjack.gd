class_name Blackjack
extends RefCounted
## Blackjack rules only (no drawing). The card table page drives it.
## House rules: 4-deck shoe, reshuffle under 25%. Cadavire deals; she stands on
## all 17 (S17). Blackjack pays 3:2 (rounded up). Double on your first two cards.
## Split once (a pair of the same value; split aces get one card each; a split 21
## is not a blackjack). Double after split is allowed. No insurance.
## A card = {"r": 1..13, "s": 0..3}  (1 = ace, 11-13 = J Q K; s: 0 spades, 1 hearts, 2 clubs, 3 diamonds)

const DECKS := 4
const RESHUFFLE_AT := 0.25

var shoe: Array = []
var rng := RandomNumberGenerator.new()

func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	shuffle()

func shuffle() -> void:
	shoe.clear()
	for d in DECKS:
		for s in 4:
			for r in range(1, 14):
				shoe.append({"r": r, "s": s})
	for i in range(shoe.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = shoe[i]
		shoe[i] = shoe[j]
		shoe[j] = t

func needs_shuffle() -> bool:
	return shoe.size() < DECKS * 52 * RESHUFFLE_AT

func draw() -> Dictionary:
	if shoe.is_empty():
		shuffle()
	return shoe.pop_back()

func peek_next() -> Dictionary:
	if shoe.is_empty():
		shuffle()
	return shoe.back()

## Removes the top card (a manager "burns" it). Returns it.
func burn() -> Dictionary:
	return draw()

## Bottom deal: swaps the top card with one deeper in the shoe.
func bottom_swap() -> void:
	if shoe.size() < 10:
		return
	var j := rng.randi_range(0, shoe.size() - 6)
	var t = shoe[shoe.size() - 1]
	shoe[shoe.size() - 1] = shoe[j]
	shoe[j] = t

static func card_value(c: Dictionary) -> int:
	return mini(int(c.r), 10)

## Best total <= 21 if possible (aces count 11 when that does not bust).
static func total(hand: Array) -> int:
	var t := 0
	var aces := 0
	for c in hand:
		t += card_value(c)
		if int(c.r) == 1:
			aces += 1
	if aces > 0 and t + 10 <= 21:
		t += 10
	return t

static func is_soft(hand: Array) -> bool:
	var t := 0
	var aces := 0
	for c in hand:
		t += card_value(c)
		if int(c.r) == 1:
			aces += 1
	return aces > 0 and t + 10 <= 21

static func is_blackjack(hand: Array) -> bool:
	return hand.size() == 2 and total(hand) == 21

static func is_bust(hand: Array) -> bool:
	return total(hand) > 21

## S17: the dealer draws to 16 and stands on every 17.
static func dealer_should_hit(hand: Array) -> bool:
	return total(hand) < 17

## Simple seat AI for managers (not basic strategy: they are characters).
static func seat_should_hit(hand: Array, dealer_up: Dictionary, bold: bool) -> bool:
	var t := total(hand)
	var up := card_value(dealer_up) if int(dealer_up.r) != 1 else 11
	if t <= 11:
		return true
	if t >= 17:
		return false
	if bold:
		return t <= 16
	return up >= 7 and t < 16

## Result for one player hand vs the dealer. Returns {"result", "back"} where back is
## the Marrow returned (stake included): lose 0, push = bet, win = 2x, blackjack = bet + ceil(1.5 bet).
static func settle(hand: Array, dealer: Array, bet: int, from_split := false) -> Dictionary:
	var pbj := is_blackjack(hand) and not from_split
	var dbj := is_blackjack(dealer)
	if is_bust(hand):
		return {"result": "bust", "back": 0}
	if pbj and dbj:
		return {"result": "push", "back": bet}
	if pbj:
		return {"result": "blackjack", "back": bet + int(ceil(bet * 1.5))}
	if dbj:
		return {"result": "lose", "back": 0}
	if is_bust(dealer):
		return {"result": "dealer_bust", "back": bet * 2}
	var p := total(hand)
	var d := total(dealer)
	if p > d:
		return {"result": "win", "back": bet * 2}
	if p == d:
		return {"result": "push", "back": bet}
	return {"result": "lose", "back": 0}

## Two first cards of the same value can split (10, J, Q, K all count as 10).
static func can_split(hand: Array) -> bool:
	return hand.size() == 2 and card_value(hand[0]) == card_value(hand[1])

static func rank_text(c: Dictionary) -> String:
	match int(c.r):
		1: return "A"
		11: return "J"
		12: return "Q"
		13: return "K"
	return str(int(c.r))

static func is_red(c: Dictionary) -> bool:
	return int(c.s) == 1 or int(c.s) == 3
