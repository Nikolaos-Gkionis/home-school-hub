# frozen_string_literal: true

module ApplicationHelper
  # Maps an Oak subject name to a CSS custom property such as --subject-maths.
  SUBJECT_TOKEN_ALIASES = {
    "maths" => "maths",
    "mathematics" => "maths",
    "english" => "english",
    "science" => "science",
    "biology" => "biology",
    "chemistry" => "chemistry",
    "physics" => "physics",
    "history" => "history",
    "geography" => "geography",
    "art" => "art",
    "art-and-design" => "art",
    "computing" => "computing",
    "music" => "music",
    "drama" => "drama",
    "physical-education" => "pe",
    "pe" => "pe",
    "french" => "french",
    "german" => "german",
    "spanish" => "spanish",
    "religious-education" => "re",
    "re" => "re",
    "rshe-pshe" => "rshe",
    "rshe" => "rshe",
    "citizenship" => "citizenship",
    "design-technology" => "dt",
    "design-and-technology" => "dt"
  }.freeze

  def subject_token_key(subject)
    slug = subject.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
    SUBJECT_TOKEN_ALIASES[slug] || "default"
  end

  def subject_swatch_style(subject)
    key = subject_token_key(subject)
    "background-color: var(--subject-#{key})"
  end

  def google_fonts_href
    "https://fonts.googleapis.com/css2?family=Fredoka:wght@400;500;600;700&family=Lexend:wght@400;500;600;700&display=swap"
  end
end
