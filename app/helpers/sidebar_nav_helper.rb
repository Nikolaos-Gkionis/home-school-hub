# frozen_string_literal: true

module SidebarNavHelper
  include ActionView::Helpers::TagHelper

  def sidebar_unit_status(completed_lesson_ids, lessons)
    ids = lessons.map(&:id)
    done = ids.count { |id| completed_lesson_ids.include?(id) }
    return :empty if done.zero?
    return :complete if done == ids.size

    :in_progress
  end

  def sidebar_subject_status(completed_lesson_ids, lessons_by_unit)
    stats = lessons_by_unit.values.map { |ls| sidebar_unit_status(completed_lesson_ids, ls) }
    return :complete if stats.any? && stats.all? { |s| s == :complete }
    return :in_progress if stats.any? { |s| s == :in_progress || s == :complete }

    :empty
  end

  def sidebar_subject_summary_classes(status, current: false)
    base = "flex cursor-pointer list-none items-start justify-between gap-2 rounded-md px-2 py-1.5 text-xs font-semibold marker:content-none sm:text-sm border-l-2 border-transparent"

    if current
      return "#{base} !border-l-4 !border-[var(--color-accent)] bg-[var(--color-accent)]/[0.2] text-[var(--color-text)] shadow-[inset_0_0_0_1px_rgba(255,255,255,0.08)]"
    end

    if status == :empty
      "#{base} text-[var(--color-text-muted)] hover:bg-white/5 hover:text-[var(--color-text)]"
    else
      "#{base} text-[var(--color-text)] hover:bg-white/5"
    end
  end

  def sidebar_unit_summary_classes(status, current: false)
    base = "flex cursor-pointer list-none items-start justify-between gap-2 rounded-md px-2 py-1.5 pl-3 text-[11px] marker:content-none sm:text-xs border-l-2 border-transparent"

    if current
      return "#{base} !border-l-[3px] !border-[var(--color-accent)] bg-[var(--color-accent)]/[0.14] text-[var(--color-text)]"
    end

    if status == :empty
      "#{base} text-[var(--color-text-muted)] hover:bg-white/5 hover:text-[var(--color-text)]"
    else
      "#{base} text-[var(--color-text)] hover:bg-white/5"
    end
  end

  def sidebar_status_dot(status)
    base = "fa-fw mt-0.5 shrink-0 self-start text-[10px] sm:text-xs"
    case status
    when :complete
      tag.i(class: "fa-solid fa-circle-check text-emerald-400 #{base}", "aria-hidden": "true")
    when :in_progress
      tag.i(class: "fa-solid fa-circle-half-stroke text-amber-400 #{base}", "aria-hidden": "true")
    else
      tag.i(class: "fa-regular fa-circle text-[var(--color-text-muted)] opacity-70 #{base}", "aria-hidden": "true")
    end
  end
end
