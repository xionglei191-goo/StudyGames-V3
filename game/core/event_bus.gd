extends Node
## Global V4 decoupled event bus for cozy life actions, stealth learning evidence,
## diegetic speech bubbles, wardrobe updates, and AI companion responses.

signal stealth_evidence_observed(payload: Dictionary)
signal wardrobe_changed(wardrobe: Dictionary)
signal diegetic_prompt_requested(payload: Dictionary)
signal diegetic_choice_selected(choice_id: String, context: Dictionary)
signal ai_chat_requested(npc_id: String, player_text: String, context: Dictionary)
signal ai_chat_replied(npc_id: String, reply: Dictionary)
signal tts_speak_requested(text: String, lang: String, voice_hint: String)
signal active_book_unit_changed(book_id: String, unit_id: String)
signal cozy_quest_updated(quest_state: Dictionary)
signal popup_theater_opened(entry_id: String)
signal popup_theater_completed(entry_id: String, summary: Dictionary)
