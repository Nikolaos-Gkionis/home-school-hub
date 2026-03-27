# frozen_string_literal: true

module Invitations
  class AcceptInvite
    def self.call(user, token)
      new(user, token).call
    end

    def initialize(user, token)
      @user = user
      @token = token.to_s.presence
    end

    def call
      return if @token.blank?

      inv = Invitation.find_by(token: @token)
      return if inv.blank? || inv.expired? || !inv.pending?
      return unless inv.email.downcase == @user.email.downcase

      ActiveRecord::Base.transaction do
        inv.update!(accepted_at: Time.current)
        @user.update!(
          role: ::User::ROLE_LEARNER,
          parent_id: inv.parent_id,
          setup_completed_at: Time.current
        )
        @user.learners.destroy_all
        lr = @user.learners.create!(
          year_group_key: inv.year_group_key,
          display_label: @user.email.split("@").first.tr(".", " ").titleize
        )
        @user.update!(active_learner: lr)
      end
    end
  end
end
