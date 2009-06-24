class AddColumnsToOrder < ActiveRecord::Migration
  def self.up
    add_column :orders, :discount_code_id, :integer
    add_column :orders, :discount_total, :float
    add_column :orders, :commission_total, :float
  end

  def self.down
    drop_column :orders, :discount_code_id
    drop_column :orders, :discount_total
    drop_column :orders, :commission_total
  end
end