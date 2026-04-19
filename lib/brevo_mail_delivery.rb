# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

# Sends mail via Brevo REST API (HTTPS :443), avoiding DigitalOcean blocks on SMTP ports 25/465/587.
# https://developers.brevo.com/reference/sendtransacemail
class BrevoMailDelivery
  attr_accessor :settings

  DEFAULTS = {
    api_key: nil,
    timeout: 30
  }.freeze

  API_URI = URI("https://api.brevo.com/v3/smtp/email").freeze

  def initialize(values = {})
    @settings = DEFAULTS.merge(values.symbolize_keys)
  end

  def deliver!(mail)
    api_key = settings[:api_key].to_s.strip
    raise ArgumentError, "Brevo api_key is blank" if api_key.blank?

    payload = build_payload(mail)
    response = post_json(payload)
    unless response.is_a?(Net::HTTPSuccess)
      body = response.body.to_s.byteslice(0, 500)
      raise "Brevo send failed (#{response.code}): #{body}"
    end

    log_brevo_success(response, payload)
    mail
  end

  private

  def build_payload(mail)
    sender = sender_hash(mail)
    html, text = extract_parts(mail)

    raise ArgumentError, "Mail has no html or text body for Brevo" if html.blank? && text.blank?

    to_list = recipients(mail, :to)
    raise ArgumentError, "Mail has no to recipients" if to_list.empty?

    payload = {
      sender: sender,
      to: to_list,
      subject: mail.subject.to_s
    }
    payload[:htmlContent] = html if html.present?
    payload[:textContent] = text if text.present?

    cc = recipients(mail, :cc)
    payload[:cc] = cc if cc.any?

    bcc = recipients(mail, :bcc)
    payload[:bcc] = bcc if bcc.any?

    reply = Array(mail.reply_to).compact.map(&:to_s).find { |s| s[/\S+@\S+/] }
    payload[:replyTo] = { email: reply[/\S+@\S+/] } if reply.present?

    payload
  end

  def sender_hash(mail)
    addr = mail.from_addrs&.first
    if addr.present?
      return { email: addr.address, name: (addr.display_name.presence || nil) }.compact
    end

    parsed = parse_mailer_from_string(ENV["MAILER_FROM"].to_s)
    raise ArgumentError, "Set MAILER_FROM or mail.from for Brevo sender" if parsed[:email].blank?

    { email: parsed[:email], name: parsed[:name] }.compact
  end

  def parse_mailer_from_string(str)
    return { email: nil, name: nil } if str.blank?

    m = Mail::Address.new(str)
    { email: m.address, name: m.display_name.presence }
  rescue Mail::Field::ParseError
    email = str[/\S+@\S+/]
    { email: email, name: nil }
  end

  def recipients(mail, field)
    addrs = case field
    when :to then mail.to_addrs
    when :cc then mail.cc_addrs
    when :bcc then mail.bcc_addrs
    else []
    end
    Array(addrs).filter_map do |a|
      next if a.blank?

      { email: a.address, name: (a.display_name.presence || nil) }.compact
    end
  end

  def extract_parts(mail)
    if mail.multipart?
      html = mail.html_part&.decoded
      text = mail.text_part&.decoded
      [ html, text ]
    else
      body = mail.body&.decoded
      ct = mail.content_type.to_s.downcase
      if ct.include?("text/html")
        [ body, nil ]
      else
        [ nil, body ]
      end
    end
  end

  def log_brevo_success(response, payload)
    data = JSON.parse(response.body)
    to_emails = Array(payload[:to]).map { |h| h[:email] }.join(", ")
    if data.is_a?(Hash) && data["messageId"].present?
      Rails.logger.info("Brevo transactional email accepted (HTTP #{response.code}) messageId=#{data['messageId']} to=#{to_emails}")
    else
      # Rare: 2xx without messageId — log body so we can debug "success in app but nothing in Brevo".
      Rails.logger.warn("Brevo HTTP #{response.code} but unexpected JSON (check API key & Brevo account): #{response.body.to_s.byteslice(0, 400)}")
    end
  rescue JSON::ParserError
    Rails.logger.warn("Brevo HTTP #{response.code} non-JSON body: #{response.body.to_s.byteslice(0, 400)}")
  end

  def post_json(payload)
    http = Net::HTTP.new(API_URI.host, API_URI.port)
    http.use_ssl = true
    t = settings[:timeout].to_i
    t = 30 if t <= 0
    http.open_timeout = t
    http.read_timeout = t

    req = Net::HTTP::Post.new(API_URI.request_uri)
    req["api-key"] = settings[:api_key].to_s
    req["Accept"] = "application/json"
    req["Content-Type"] = "application/json; charset=utf-8"
    req.body = JSON.generate(payload)

    http.request(req)
  end
end
