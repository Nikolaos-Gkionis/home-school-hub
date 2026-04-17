class AddChildNameToInvitations < ActiveRecord::Migration[8.1]
  def change
    add_column :invitations, :child_name, :string

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE invitations
          SET child_name = 'Child'
          WHERE child_name IS NULL OR TRIM(child_name) = ''
        SQL
      end
    end
  end
end
