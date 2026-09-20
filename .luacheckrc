std = "lua51"
max_line_length = 120
exclude_files = { ".release", "tests" }
ignore = { "212" } -- unused arguments (event handler signatures)

globals = {
  "TackleboxDB", "TackleboxCharDB",
  "Tacklebox_ToggleFishingMode", "Tacklebox_OnAddonCompartmentClick",
  "BINDING_HEADER_TACKLEBOX", "BINDING_NAME_TACKLEBOX_TOGGLE", "BINDING_NAME_TACKLEBOX_MENU",
  "Tacklebox_ToggleMenu",
  "SLASH_TACKLEBOX1", "SLASH_TACKLEBOX2", "SlashCmdList", "UISpecialFrames",
}

read_globals = {
  -- Lua additions
  "wipe", "date", "time",
  -- Frames and UI
  "CreateFrame", "UIParent", "RaidNotice_AddMessage", "RaidWarningFrame", "ChatTypeInfo",
  "PlaySound", "SOUNDKIT", "Settings", "CreateSettingsButtonInitializer",
  "MinimalSliderWithSteppersMixin",
  -- Bindings and input
  "SetOverrideBinding", "SetOverrideBindingClick", "ClearOverrideBindings",
  "GetBindingAction", "GetBindingName", "IsKeyDown", "IsMouseButtonDown",
  "IsAltKeyDown", "IsControlKeyDown", "IsShiftKeyDown",
  -- Player state
  "InCombatLockdown", "IsInInstance", "IsMounted", "IsSwimming", "UnitIsDeadOrGhost",
  "UnitChannelInfo", "GetTime", "GetZoneText", "GetSubZoneText",
  -- Spells, items, auras, gear
  "C_Spell", "GetSpellInfo", "C_Item", "GetItemInfo", "GetItemInfoInstant", "GetItemCount",
  "GetItemSpell", "EquipItemByName", "C_Container", "GetItemCooldown", "GetContainerNumSlots",
  "GetContainerItemID", "NUM_BAG_SLOTS", "PlayerHasToy", "C_UnitAuras", "AuraUtil",
  "GetWeaponEnchantInfo", "GetInventoryItemID", "GetInventoryItemLink", "INVSLOT_MAINHAND",
  "C_EquipmentSet",
  -- Loot
  "IsFishingLoot", "GetNumLootItems", "GetLootSlotType", "GetLootSlotLink", "GetLootSlotInfo",
  "Enum",
  -- Events clock and goals
  "GetGameTime", "C_DateAndTime", "WorldFrame", "GetCategoryInfo", "GetCategoryList",
  "GetCategoryNumAchievements", "GetAchievementInfo", "GetAchievementNumCriteria",
  "GetAchievementCriteriaInfo", "GetAchievementLink", "PROFESSIONS_FISHING",
  -- Midnight helpers
  "C_Reputation", "C_GossipInfo", "_G",
  -- Alerts, pools, log window, mounts
  "UnitGUID", "strsplit", "GetLocale", "TooltipDataProcessor", "GameTooltip", "C_MountJournal",
  -- Menu
  "GetCursorInfo", "ClearCursor", "GetItemIcon", "GetSpellTexture",
  -- Misc
  "C_Timer", "C_Map", "C_CVar", "GetCVar", "SetCVar", "C_CurrencyInfo", "GetCoinTextureString",
  "issecretvalue", "WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE", "WOW_PROJECT_CLASSIC",
  -- Optional pricing addons
  "Auctionator", "TSM_API",
}
