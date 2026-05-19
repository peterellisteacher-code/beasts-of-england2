class_name WindmillCaseData
extends RefCounted
## Act 4 — "THE WINDMILL" case file (Animal Farm, Chapter 6).
##
## All player-facing content for the case-file / slot-fill activity lives here.
## Authoring a different case = rewriting this one file; the engine never changes.
##
## Markup in body text:
##   [kw_xxx]   — a clickable keyword-clue (resolved against CASE.keywords)
##   [slot:xxx] — a fill slot in a casebook page (resolved against that page's slots)

# Category colours — the constructivist palette, re-told for the case.
const CATEGORY_COLOR: Dictionary = {
	"person": Color("c4a24a"),  # wheat-gold
	"thing": Color("b5793f"),   # worn ochre — legible on dark
	"place": Color("7d8a52"),   # faded animalism-green
}

const CATEGORY_LABEL: Dictionary = {
	"person": "ANIMALS & PEOPLE",
	"thing": "THINGS & EVIDENCE",
	"place": "PLACES",
}

const CASE: Dictionary = {
	# --- Act intro (fed into the shared ActIntro overlay) ---------------------
	"act_label": "ACT 4 — CHAPTER 6",
	"title": "THE WINDMILL",
	"protagonist": "You are one of the animals of Animal Farm — awake before the others, at the wreck of the windmill.",
	"story": "In the night a great storm broke over the farm, and this morning the windmill — a year of the animals' labour — lies in ruins. Napoleon is already among the stones, and soon he will tell every animal who to blame. Before he does, walk the wreck yourself. Gather what you can see with your own eyes, and work out what truly brought the windmill down.",
	"goal": "Investigate both rooms, collect the evidence, and complete the two pages of your Casebook.",
	"controls": [
		"Click a glowing mark to investigate it",
		"Click an underlined word to add it to your evidence",
		"Open the Casebook, then click a word and a slot to place it",
		"Click a filled slot to clear it",
		"Press H to hide or show the controls",
	],
	"goal_banner": "GOAL: Work out what truly brought the windmill down.",

	# --- The two rooms --------------------------------------------------------
	"rooms": [
		{"id": 1, "label": "The Windmill Knoll", "background": "res://assets/sprites/act4/windmill_exterior.png"},
		{"id": 2, "label": "Within the Ruins", "background": "res://assets/sprites/act4/windmill_interior.png"},
	],

	# --- Keywords -------------------------------------------------------------
	# id -> { text (chip label), category, source (quote shown on hover) }
	"keywords": {
		"kw_napoleon": {"text": "Napoleon", "category": "person",
			"source": "Napoleon walked slowly round the wreck, his snout to the ground."},
		"kw_snowball": {"text": "Snowball", "category": "person",
			"source": "The windmill, Napoleon said, was thrown down by Snowball."},
		"kw_squealer": {"text": "Squealer", "category": "person",
			"source": "The proclamation is painted in Squealer's careful hand."},
		"kw_boxer": {"text": "Boxer", "category": "person",
			"source": "Boxer stood among the stones: 'I will work harder.'"},
		"kw_animals": {"text": "the animals", "category": "person",
			"source": "The animals looked from the ruin to Napoleon, and waited."},
		"kw_benjamin": {"text": "Benjamin", "category": "person",
			"source": "Benjamin watched, and said nothing, as Benjamin always did."},
		"kw_windmill": {"text": "the windmill", "category": "thing",
			"source": "A year of the animals' labour — the windmill — lay scattered."},
		"kw_walls": {"text": "eighteen inches thick", "category": "thing",
			"source": "The walls had been built only eighteen inches thick."},
		"kw_storm": {"text": "the storm", "category": "thing",
			"source": "It was the storm in the night that tore the elm from the earth."},
		"kw_tiles": {"text": "torn tiles", "category": "thing",
			"source": "The storm had stripped tiles from the barn roof."},
		"kw_elm": {"text": "the elm", "category": "thing",
			"source": "An elm at the foot of the orchard lay torn out of the ground."},
		"kw_tracks": {"text": "pig-tracks", "category": "thing",
			"source": "Napoleon pointed to tracks leading toward a gap in the hedge."},
		"kw_foxwood": {"text": "Foxwood", "category": "place",
			"source": "The tracks, Napoleon said, led toward Foxwood."},
		"kw_quarry": {"text": "the quarry", "category": "place",
			"source": "The stone had been broken and hauled up from the quarry."},
		"kw_barn": {"text": "the barn", "category": "place",
			"source": "The storm had stripped tiles from the roof of the barn."},
	},

	# --- Hotspots -------------------------------------------------------------
	# room: 1 = the knoll (exterior); 2 = within the ruins (interior).
	# body carries [kw_xxx] markers for the clickable keyword-clues.
	"hotspots": [
		{
			"id": "hs_windmill", "room": 1, "title": "The fallen windmill",
			"pos": Vector2(556, 230),
			"body": "A year of the animals' labour lies scattered across the field. They had hauled and lifted and slept short to raise [kw_windmill], and in one night it has come down — its pale stones flung wide, its sails broken. The animals stand and look at it, and do not yet know what they are to think.",
		},
		{
			"id": "hs_napoleon", "room": 1, "title": "Napoleon among the stones",
			"pos": Vector2(680, 370),
			"body": "[kw_napoleon] walks slowly round the wreck. He stops; he lowers his snout to the broken stones and sniffs, long and certain. His tail has gone stiff. Then he speaks. The windmill did not fall, he says — it was thrown down in the night, in spite, by an enemy of the farm. He gives that enemy a name: [kw_snowball].",
		},
		{
			"id": "hs_tracks", "room": 1, "title": "The tracks in the grass",
			"pos": Vector2(400, 600),
			"body": "Napoleon lowers his snout to the grass and follows something only he can see. Here, he says: [kw_tracks], the prints of a pig, leading to a gap in the hedge on the side that faces [kw_foxwood]. He cannot say whose they are. He says he is certain they are Snowball's. You look where he points — the marks could belong to any pig on the farm, or to none.",
		},
		{
			"id": "hs_barn", "room": 1, "title": "The barn roof",
			"pos": Vector2(150, 360),
			"body": "Look to [kw_barn]. In the night the storm stripped [kw_tiles] from its roof and flung them into the mud, where they lie smashed. Whatever crossed the farm in the dark was strong enough to tear a roof open.",
		},
		{
			"id": "hs_orchard", "room": 1, "title": "The orchard",
			"pos": Vector2(290, 250),
			"body": "At the foot of the orchard an [kw_elm] lies torn clean out of the earth, its roots in the air. No animal's hoof did that. It was [kw_storm] in the night — the same wind, the same black hour — that wrenched the tree from the ground, and then passed on across the open field to the windmill.",
		},
		{
			"id": "hs_animals", "room": 1, "title": "Boxer and the animals",
			"pos": Vector2(560, 510),
			"body": "[kw_boxer] stands among the broken stones, and does not speak for a long while. A year of his strength lies scattered there in the mud. At last he says only, 'I will work harder.' Around him [kw_animals] look from the ruin to Napoleon and back. [kw_benjamin] the donkey watches everything and, as ever, says nothing at all.",
		},
		{
			"id": "hs_proclamation", "room": 1, "title": "The proclamation board",
			"pos": Vector2(1120, 440),
			"body": "A board has been raised already, painted while the stones were still warm. WINDMILL DESTROYED BY THE TRAITOR SNOWBALL, it reads, in white letters on red. The lettering is neat and practised — the careful hand of [kw_squealer], who can paint a thing into truth faster than the animals can think.",
		},
		{
			"id": "hs_wall", "room": 2, "title": "The broken wall",
			"pos": Vector2(235, 320),
			"body": "Down in the rubble you can see the wall in its broken edge — how it was made. It was built only [kw_walls]. The pigs had wanted it thinner and quicker; it should have stood three feet through. Eighteen inches of stone was all that was set between a year of work and a hard wind.",
		},
		{
			"id": "hs_stones", "room": 2, "title": "The scattered stone",
			"pos": Vector2(530, 545),
			"body": "The great stones lie everywhere, the same stones the animals broke and dragged up the long slope from [kw_quarry], month upon month. They have fallen outward, spread wide from the base — the way a wall falls when a wind pushes it over, not the way a thing flies apart when it is struck.",
		},
		{
			"id": "hs_gear", "room": 2, "title": "The mill machinery",
			"pos": Vector2(965, 335),
			"body": "The wooden gear of the mill lies smashed under a fallen beam. It was never finished; the windmill was a bare stone shell with the work not half done. There is no scorch, no blast, no mark of any tool of harm — only stone that has fallen, and rain coming down through the open roof that is no longer there.",
		},
	],

	# --- Casebook pages -------------------------------------------------------
	"scrolls": [
		{
			"id": "who", "title": "Page One — Who's Who at the Windmill",
			"mode": "three_tier",
			"intro": "Set down plainly who is who. Place a word in every slot, then read how it stands.",
			"body": "The windmill the animals built lies in ruins. [slot:s1_accuser] walks the wreck and names the one to blame. The blame falls on [slot:s1_accused], the pig who was driven off the farm long ago. The board is painted by [slot:s1_voice], whose work is to make the farm believe it. The loss is heaviest for [slot:s1_worker], who lifted the stones himself. And the [slot:s1_witnesses] look on, and must decide what to believe.",
			"slots": {
				"s1_accuser": {"category": "person", "accepts": ["kw_napoleon"]},
				"s1_accused": {"category": "person", "accepts": ["kw_snowball"]},
				"s1_voice": {"category": "person", "accepts": ["kw_squealer"]},
				"s1_worker": {"category": "person", "accepts": ["kw_boxer"]},
				"s1_witnesses": {"category": "person", "accepts": ["kw_animals"]},
			},
		},
		{
			"id": "account", "title": "Page Two — What Brought the Windmill Down",
			"mode": "dual_light",
			"intro": "Set down what the evidence shows. VALID lights when every slot holds the right kind of word; SOUND lights only when every slot holds the true one.",
			"body": "1.  In the night a violent [slot:s2_cause] struck the farm — the same wind tore the [slot:s2_ev1] from the barn roof and dragged the [slot:s2_ev2] up out of the orchard by its roots.\n2.  The windmill's walls had been built only [slot:s2_walls], when work of that height needed walls far thicker.\n3.  Walls that thin could not stand against a storm strong enough to uproot a tree.\n4.  [slot:s2_accused] was driven off the farm long ago, and no animal saw him here on the night of the storm.\n5.  The one sign offered against him is a set of [slot:s2_sign] — said to lead toward [slot:s2_place], and found, and read, by Napoleon alone.\n6.  Therefore the evidence does not point to an enemy. The windmill fell to its own thin walls and to [slot:s2_verdict].",
			"slots": {
				"s2_cause": {"category": "thing", "accepts": ["kw_storm"]},
				"s2_ev1": {"category": "thing", "accepts": ["kw_tiles"]},
				"s2_ev2": {"category": "thing", "accepts": ["kw_elm"]},
				"s2_walls": {"category": "thing", "accepts": ["kw_walls"]},
				"s2_accused": {"category": "person", "accepts": ["kw_snowball"]},
				"s2_sign": {"category": "thing", "accepts": ["kw_tracks"]},
				"s2_place": {"category": "place", "accepts": ["kw_foxwood"]},
				"s2_verdict": {"category": "thing", "accepts": ["kw_storm"]},
			},
		},
	],

	# --- Endings --------------------------------------------------------------
	"truth": {
		"title": "What the evidence shows",
		"body": "The evidence points to the storm. The walls were eighteen inches thick when they needed to be three feet; the same gale that stripped the barn and tore the elm from the orchard was strong enough to do the rest. No animal saw Snowball here — the tracks prove only what Napoleon says they prove. The windmill fell because it was built thin, and the night was wild. You have set the case down, and it is sound.",
	},
	"squealer": {
		"title": "And what the farm is told",
		"speaker": "SQUEALER",
		"body": "But the farm is not told this. Squealer comes down from the farmhouse, brisk and full of sorrow for them all. 'Comrades! A terrible thing — but do not let yourselves be deceived. Surely none of you imagines this was an accident? The windmill was destroyed by Snowball. Out of pure spite, to undo a year of our work, that traitor crept here in the dark. Comrade Napoleon himself has found the proof. You would not wish to see Jones come back? No. Then there is no more to be said.' The animals, who had thought it was the storm, say nothing at all.",
	},
	# Shown as the proclamation is stamped over the finished casebook.
	"proclamation": {
		"stamp_text": "WINDMILL DESTROYED BY THE TRAITOR SNOWBALL",
		"closing": "The case you proved is written down in no place on this farm. It is yours, and only yours.",
	},
}
