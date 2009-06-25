class AddProductToDiscountCodes < ActiveRecord::Migration
  def self.up
    add_column :discount_codes, :product_id, :int
  end

  def self.down
    drop_column :discount_codes, :product_id
  end
end