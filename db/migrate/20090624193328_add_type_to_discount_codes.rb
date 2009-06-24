class AddTypeToDiscountCodes < ActiveRecord::Migration
  def self.up
    add_column :discount_codes, :discount_type, :string, :default => 'dollar amount'
  end

  def self.down
    drop_column :discount_codes, :type
  end
end