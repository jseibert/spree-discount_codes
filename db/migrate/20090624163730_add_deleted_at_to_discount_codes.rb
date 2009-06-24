class AddDeletedAtToDiscountCodes < ActiveRecord::Migration
  def self.up
    add_column :discount_codes, :available_on, :datetime
    add_column :discount_codes, :deleted_at, :datetime
  end

  def self.down
    drop_column :discount_codes, :available_on
    drop_column :discount_codes, :deleted_at
  end
end