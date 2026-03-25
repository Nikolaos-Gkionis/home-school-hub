# frozen_string_literal: true

class ThemeManager
  PRESETS = {
    "cosmic_voyager" => true,
    "forest_ranger" => true,
    "cyberpunk_scholar" => true,
    "desert_explorer" => true
  }.freeze

  DISPLAY_NAMES = {
    "cosmic_voyager" => "Cosmic Voyager",
    "forest_ranger" => "Forest Ranger",
    "cyberpunk_scholar" => "Cyberpunk Scholar",
    "desert_explorer" => "Desert Explorer"
  }.freeze

  def self.body_class_for(theme_key)
    "theme-#{theme_key.to_s.tr('_', '-')}"
  end
end
