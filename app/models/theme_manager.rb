# frozen_string_literal: true

# Maps a stored theme key to the CSS class on <body>.
# Older sci-fi keys still resolve so existing User rows keep working.
class ThemeManager
  CANONICAL = "academy"

  PRESETS = {
    CANONICAL => true
  }.freeze

  DISPLAY_NAMES = {
    CANONICAL => "Academy"
  }.freeze

  LEGACY_KEYS = %w[
    cosmic_voyager
    forest_ranger
    cyberpunk_scholar
    desert_explorer
  ].freeze

  def self.canonical_key(theme_key)
    key = theme_key.to_s
    return CANONICAL if PRESETS.key?(key)
    return CANONICAL if LEGACY_KEYS.include?(key)

    CANONICAL
  end

  def self.body_class_for(_theme_key = nil)
    "theme-academy"
  end
end
