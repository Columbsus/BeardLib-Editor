Hooks:PostHook(MenuCallbackHandler, "_dialog_end_game_yes", "EditorDialogEndGame", function(self)
	Global.editor_mode = nil
	Global.current_mission_filter = nil
	Global.editor_loaded_instance = nil
end)