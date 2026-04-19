# frozen_string_literal: true

require "test_helper"

class BrevoMailDeliveryTest < ActiveSupport::TestCase
  test "build_payload accepts string From and To (ActionMailer / Mail default shape)" do
    delivery = BrevoMailDelivery.new(api_key: "dummy-key-for-payload-only")
    mail = Mail.new
    mail[:from] = "Home School Hub <sender@example.com>"
    mail[:to] = "parent@example.com"
    mail.subject = "Invite"
    mail.body = "Plain text body"

    payload = delivery.send(:build_payload, mail)

    assert_equal "sender@example.com", payload.dig(:sender, :email)
    # Display name may be nil depending on how Mail parsed the header; Brevo only requires email.
    assert payload.dig(:sender, :name).in?([ nil, "Home School Hub" ])
    assert_equal "parent@example.com", payload.dig(:to, 0, :email)
  end
end
