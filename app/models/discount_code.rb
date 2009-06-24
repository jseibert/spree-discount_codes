class DiscountCode < ActiveRecord::Base
  belongs_to :user
  
  default_value_for :discount_type, "dollar amount"
  
  default_value_for :code do
    DiscountCode.generate_code
  end
  
  default_value_for :available_on do
    Time.now
  end
  
  named_scope :active, lambda { |*args| { :conditions => ["discount_codes.available_on <= ? and discount_codes.deleted_at is null", (args.first || Time.zone.now)] } }
  named_scope :not_deleted, lambda { |*args| { :conditions => ["discount_codes.deleted_at is null", (args.first || Time.zone.now)] } }
  
  named_scope :available, lambda { |*args| { :conditions => ["discount_codes.available_on <= ?", (args.first || Time.zone.now)] } }
  
  def self.generate_code(code_length=6)
    chars = ("a".."z").to_a + ("1".."9").to_a
    new_code = Array.new(code_length, '').collect{chars[rand(chars.size)]}.join
    Digest::MD5.hexdigest(new_code)[0..(code_length-1)].upcase
  end

  def self.generate_unique_code(code_length=6)
    begin
      new_code = generate_code(code_length)
    end until !active_code?( new_code )
    new_code
  end
  
  def self.type_options
    ['dollar amount', 'percent']
  end
  
  # Checks the database to ensure the specified code is not taken
  def active_code?( code )
    find :first, :conditions => { :code => code }
  end

  def expired?
    DateTime.now > expires_on
  end
  
  def to_s
    "#{code} (#{comments})"
  end
end
