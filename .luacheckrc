std = "lua51"
max_line_length = 120
exclude_files = { ".release", "tests", "dist" }
ignore = { "212" } -- unused arguments (event handler signatures)

globals = {
  "AnglersTackleBoxDB", "AnglersTackleBoxCharDB",
  "AnglersTackleBox_ToggleFishingMode", "AnglersTackleBox_OnAddonCompartmentClick",
  "BINDING_HEADER_ANGLERSTACKLEBOX", "BINDING_NAME_ANGLERSTACKLEBOX_TOGGLE", "BINDING_NAME_ANGLERSTACKLEBOX_MENU",
  "AnglersTackleBox_ToggleMenu",
  "SLASH_ANGLERSTACKLEBOX1", "SLASH_ANGLERSTACKLEBOX2", "SlashCmdList", "UISpecialFrames",
}

read_globals = {
  -- Lua additions
  "wipe", "date", "time",
  -- Frames and UI
  "CreateFrame", "UIParent", "RaidNotice_AddMessage", "RaidWarningFrame", "ChatTypeInfo",
  "PlaySound", "PlaySoundFile", "LibStub", "SOUNDKIT", "Settings", "CreateSettingsButtonInitializer",
  "MinimalSliderWithSteppersMixin",
  -- Bindings and input
  "SetOverrideBinding", "SetOverrideBindingClick", "ClearOverrideBindings",
  "GetBindingAction", "GetBindingName", "IsKeyDown", "IsMouseButtonDown",
  "IsAltKeyDown", "IsControlKeyDown", "IsShiftKeyDown",
  -- Player state
  "InCombatLockdown", "IsInInstance", "IsMounted", "IsSwimming", "UnitIsDeadOrGhost",
  "UnitChannelInfo", "GetTime", "GetZoneText", "GetSubZoneText", "UnitName", "GetRealmName",
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
  "GetCursorInfo", "ClearCursor", "GetItemIcon", "GetSpellTexture", "SetItemRef",
  -- Spots, gold, comforts, broker, records, goals
  "WorldMapFrame", "hooksecurefunc", "GetCameraZoom", "CameraZoomIn", "CameraZoomOut", "UnitIsAFK",
  "LibStub", "Minimap", "GetCursorPosition", "IsInGroup", "IsInGuild", "SendChatMessage", "C_ChatInfo",
  "GetProfessions", "GetProfessionInfo", "GetNumSkillLines", "GetSkillLineInfo", "C_QuestLog",
  -- Trade skill / cooking reagents
  "C_TradeSkillUI", "GetTradeSkillLine", "GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillNumReagents",
  "GetTradeSkillReagentInfo", "GetTradeSkillReagentItemLink", "GetTradeSkillItemLink", "PROFESSIONS_COOKING",
  -- Auction house
  "AuctionHouseFrame", "AuctionFrame",
  -- Misc
  "C_Timer", "C_Map", "C_CVar", "GetCVar", "SetCVar", "C_CurrencyInfo", "GetCoinTextureString",
  "issecretvalue", "WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE", "WOW_PROJECT_CLASSIC",
  -- Optional pricing addons
  "Auctionator", "TSM_API",
}
