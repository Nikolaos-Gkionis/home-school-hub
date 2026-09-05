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

  # Soft tint for calendar cells so subjects stay readable.
  def subject_tint_style(subject)
    key = subject_token_key(subject)
    "background-color: color-mix(in srgb, var(--subject-#{key}) 16%, white); border-color: color-mix(in srgb, var(--subject-#{key}) 38%, white)"
  end

  # Stronger fill for calendar event blocks, with a coloured left bar.
  def subject_block_style(subject)
    key = subject_token_key(subject)
    "background-color: color-mix(in srgb, var(--subject-#{key}) 28%, white); border-left-color: var(--subject-#{key})"
  end

  def week_calendar_path_for(week_monday:, month:, child: nil)
    args = { month: month, week: week_monday.iso8601 }
    if child
      parent_child_week_path(child, args)
    else
      child_dashboard_path(args.merge(overview: "week"))
    end
  end

  # Child stays in the hub on that exact lesson. A parent opens the Oak page
  # for the same lesson, because the parent dashboard is not a lesson player.
  def week_lesson_href(lesson, child: nil)
    return nil unless lesson

    if child
      lesson.oak_pupil_lesson_url
    else
      child_dashboard_path(lesson_id: lesson.id)
    end
  end

  def google_fonts_href
    "https://fonts.googleapis.com/css2?family=Fredoka:wght@400;500;600;700&family=Lexend:wght@400;500;600;700&display=swap"
  end
end
