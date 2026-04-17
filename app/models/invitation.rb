# frozen_string_literal: true

class Invitation < ApplicationRecord
  belongs_to :parent, class_name: "User"

  validates :child_name, presence: true, length: { maximum: 100 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :year_group_key, presence: true, inclusion: { in: Curriculum::YearGroups.all_year_keys }
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  before_validation :assign_defaults, on: :create

  scope :pending, -> { where(accepted_at: nil) }

  def expired?
    expires_at < Time.current
  end

  def pending?
    accepted_at.nil?
  end

  private

  def assign_defaults
    self.token ||= SecureRandom.urlsafe_base64(32)
    self.expires_at ||= 14.days.from_now
  end
end
