class DiscountCode < ActiveRecord::Base
  belongs_to :user
  belongs_to :product
  
  default_value_for :discount_type, "dollar amount"
  
  default_value_for :code do
    DiscountCode.generate_code
  end
  
  default_value_for :available_on do
    Time.zone.now
  end
  
  named_scope :active, lambda { |*args| { :conditions => ["(discount_codes.available_on is null or discount_codes.available_on <= ?) and (discount_codes.expires_on is null or discount_codes.expires_on >= ?)", (args.first || Time.zone.now), (args.first || Time.zone.now)] } }
  named_scope :not_deleted, lambda { |*args| { :conditions => ["discount_codes.deleted_at is null"] } }
  
  def self.generate_code(code_length=6)
    chars = ("a".."z").to_a + ("1".."9").to_a
    new_code = Array.new(code_length, '').collect{chars[rand(chars.size)]}.join
    Digest::MD5.hexdigest(new_code)[0..(code_length-1)].upcase
  end

  def self.generate_unique_code(code_length=6)
    begin
      new_code = generate_code(code_length)
    end until !find_by_code?( new_code )
    new_code
  end
  
  def self.type_options
    ['dollar amount', 'dollar amount per item', 'percent']
  end
  
  def self.find_by_code(code)
    self.active.not_deleted.find(:first, :conditions => {:code => code.upcase})
  end

  def expired?
    (available_on.nil? || DateTime.now < available_on) || (expires_on.nil? || DateTime.now > expires_on)
  end
  
  def to_s
    "#{code} (#{comments})"
  end
  
  def applies_to?(product_or_variant)
    if self.product
      if product_or_variant.is_a?(Product)
        (self.product.id == product_or_variant.id)
      elsif product_or_variant.is_a?(Variant)
        valid_variants = self.product.variants.collect {|v| v.id}
        valid_variants.include?(product_or_variant.id)
      end
    else
      true
    end
  end
  
  def value_for_product_amount(amount)
    case self.discount_type
    when "dollar amount":
      0.0
    when 'dollar amount per item':
      self.discount_rate.to_f
    when "percent":
      amount.to_f * self.discount_rate.to_f / 100.00
    end
  end
end
