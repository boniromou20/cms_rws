class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :employee_id

      t.timestamps
    end
  end
end