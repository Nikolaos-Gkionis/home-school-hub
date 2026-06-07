# frozen_string_literal: true

module InsightsHelper
  def insights_day_label(date_string)
    Date.iso8601(date_string).strftime("%-d %b")
  rescue ArgumentError, TypeError
    date_string.to_s
  end

  def insights_daily_page_url(page)
    insights_path(request.query_parameters.merge(daily_page: page))
  end
end
