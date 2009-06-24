class AddTypeToDiscountCodes < ActiveRecord::Migration
  def self.up
    add_column :discount_codes, :type, :string
  end

  def self.down
    drop_column :discount_codes, :type
  end
end