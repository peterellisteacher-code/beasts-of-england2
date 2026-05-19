## Act 1 stealth level — comprehension question data (Chapters 1-7 recall).
## Data-only class: no logic, no nodes. The coordinator and rousable animals
## read from QUESTIONS. All values are constants — designers edit here only.
##
## Spec: active.md §6 "QUESTIONS".
class_name Act1Questions
extends RefCounted

# =============================================================================
# Question data — keyed by animal_id StringName
# =============================================================================

## MCQ question dictionary. Each entry:
##   q       : String   — the question text (≥16pt when rendered).
##   correct : String   — the single correct answer.
##   wrong   : Array    — exactly two wrong options.
##   hint    : String   — shown after first wrong attempt (one wrong removed after).
##   speaker : String   — attribution shown on the question panel header.
const QUESTIONS: Dictionary = {
	&"hen": {
		"q": "Old Major says one creature takes the animals' milk and eggs but does no work — the real enemy of every animal. Who?",
		"correct": "Man",
		"wrong": ["Foxes", "Other farms"],
		"hint": "He owns the farm and walks on two legs.",
		"speaker": "The hen",
	},
	&"sheep": {
		"q": "The sheep love a short, simple slogan. Which one do the pigs teach them?",
		"correct": "Four legs good, two legs bad",
		"wrong": ["All for one, one for all", "Slow and steady wins"],
		"hint": "It is about how many legs you walk on.",
		"speaker": "The sheep",
	},
	&"boxer": {
		"q": "Boxer the cart-horse meets every hardship with the same motto. What is it?",
		"correct": "I will work harder",
		"wrong": ["I will rest now", "Let the pigs do it"],
		"hint": "Boxer answers every problem with more effort.",
		"speaker": "Boxer",
	},
	&"clover": {
		"q": "Why must the animals creep to the barn so quietly tonight?",
		"correct": "So Mr Jones does not wake and stop the meeting",
		"wrong": ["So they do not frighten the hens", "So Moses can lead the way"],
		"hint": "The danger is the farmer waking up.",
		"speaker": "Clover",
	},
	&"scroll": {
		"q": "Old Major's torn scroll reads: 'Man is the only real ___ we have.' Missing word?",
		"correct": "enemy",
		"wrong": ["friend", "master"],
		"hint": "Old Major says Man is the cause of all their suffering.",
		"speaker": "The scroll",
	},
}
