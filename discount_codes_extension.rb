class DiscountCodesExtension < Spree::Extension
  version "1.0"
  description "Extensions for New Leaf Paper"
  url "http://thinkfasttank.com"

  def self.require_gems(config)
    config.gem "thoughtbot-factory_girl",
               :lib    => "factory_girl",
               :source => "http://gems.github.com"
    
    ######## Also requires the default_value_for plugin!
    # ./script/plugin install git://github.com/FooBarWidget/default_value_for.git
  end  

  def activate

    Admin::UsersController.class_eval do
      before_filter :add_discount_code_fields
      after_filter :bulid_discount_code, :only => [:new,:edit]

      def add_discount_code_fields
        @extension_partials << 'discount_codes'
      end

      def bulid_discount_code
        @user.discount_codes.build
      end

    end
    
    Spree::BaseController.class_eval do
      def apply_discount_code
        if params[:promo]
          @order = find_order
          @order.discount_code = DiscountCode.find_by_code(params[:promo])
          @order.save
        end
      end
    end
    
    OrdersController.class_eval do
      before_filter :apply_discount_code
    end
    
    ProductsController.class_eval do
      before_filter :apply_discount_code
    end

    Admin::ConfigurationsController.class_eval do
      before_filter :add_discount_codes_links, :only => :index
      def add_discount_codes_links
        @extension_links << {
                              :link => admin_discount_codes_url, 
                              :link_text => 'Discount Codes', 
                              :description => "Manage affiliates and their discount codes." }
      end#def
    end#class_eval

    User.class_eval do
      has_many :discount_codes
      accepts_nested_attributes_for :discount_codes, 
        :allow_destroy => true, 
        :reject_if => proc { |attributes| attributes["comments"].blank? }
      attr_accessible :discount_codes_attributes
      include Affiliate
    end
    
    Spree::BaseHelper.class_eval do
      def order_price(order, options={})
        options.assert_valid_keys(:format_as_currency, :show_vat_text, :show_price_inc_vat)
        options.reverse_merge! :format_as_currency => true, :show_vat_text => true

        # overwrite show_vat_text if show_price_inc_vat is false
        options[:show_vat_text] = Spree::Tax::Config[:show_price_inc_vat]

        amount = order.item_total + order.discount_total 
        amount += Spree::VatCalculator.calculate_tax(order) if Spree::Tax::Config[:show_price_inc_vat]    

        options.delete(:format_as_currency) ? number_to_currency(amount) : amount
      end
      
      def order_discount(order, options={})
        options.assert_valid_keys(:format_as_currency, :show_vat_text, :show_price_inc_vat)
        options.reverse_merge! :format_as_currency => true, :show_vat_text => true

        # overwrite show_vat_text if show_price_inc_vat is false
        options[:show_vat_text] = Spree::Tax::Config[:show_price_inc_vat]

        amount = order.discount_total 
        amount += Spree::VatCalculator.calculate_tax(order) if Spree::Tax::Config[:show_price_inc_vat]    

        options.delete(:format_as_currency) ? number_to_currency(amount) : amount
      end
    end
    
    ProductsHelper.class_eval do
      def product_price(product_or_variant, options={})
        options.assert_valid_keys(:format_as_currency)
        options.reverse_merge! :format_as_currency => true

        amount = product_or_variant.is_a?(Product) ? product_or_variant.master_price : product_or_variant.price
        
        unless session[:order_id].blank?
          order = Order.find_or_create_by_id(session[:order_id])
          if order.discount_code && order.discount_code.applies_to?(product_or_variant)
            amount -= order.discount_code.value_for_product_amount(amount)
          end
        end
        
        options[:format_as_currency] ? number_to_currency(amount, options) : amount
      end
      
      # returns nil if there is no discount
      def product_price_without_discount(product_or_variant, options={})
        options.assert_valid_keys(:format_as_currency)
        options.reverse_merge! :format_as_currency => true

        amount = product_or_variant.is_a?(Product) ? product_or_variant.master_price : product_or_variant.price
        
        unless session[:order_id].blank?
          order = Order.find_or_create_by_id(session[:order_id])
          if order.discount_code && order.discount_code.applies_to?(product_or_variant)
            if order.discount_code.value_for_product_amount(amount) > 0.0
              return options[:format_as_currency] ? number_to_currency(amount, options) : amount
            end
          end
        end
        
        nil
      end
    end
    
    #######################
    # The Order gets by with a little help from friends
    Order.class_eval do
      belongs_to :discount_code
      attr_accessor :discount_code_code
      before_save :find_discount_code 

      def total_with_discount
        self.total = total_without_discount + self.discount_total
      end
      alias_method_chain :total, :discount
      
      def update_totals_with_discount
        update_totals_without_discount
        discount_total
        commission_total
      end
      alias_method_chain :update_totals, :discount

      def discount_total
        discount = 0.0 
        applicable_line_items = discount_scope
        unless applicable_line_items.empty?
          case self.discount_code.discount_type
          when "dollar amount":
            discount = self.discount_code.discount_rate
          when 'dollar amount per item':
            applicable_line_items.each do |li|
              discount += self.discount_code.discount_rate * li.quantity
            end
          when "percent":
            discount = self.item_total.to_f * self.discount_code.discount_rate.to_f / 100.00
          end
        end
        self[:discount_total] = discount * -1
      end

      def commission_total
        commission = 0.0
        applicable_line_items = discount_scope
        unless applicable_line_items.empty?
          case self.discount_code.discount_type
          when "dollar amount":
            commission = self.discount_code.commission_rate
          when 'dollar amount per item':
            applicable_line_items.each do |li|
              commission += self.discount_code.commission_rate * li.quantity
            end
          when "percent":
            commission = self.item_total.to_f * self.discount_code.commission_rate.to_f / 100.00
          end
        end
        
        self[:commission_total] = commission
      end
      
      private
      def find_discount_code
        if self.discount_code_code
          self.discount_code = DiscountCode.find_by_code(self.discount_code_code)
        end
      end
      
      def discount_scope
        return [] unless self.discount_code
        
        if self.discount_code.product
          valid_variants = self.discount_code.product.variants.collect {|v| v.id}
          self.line_items.find(:all, :conditions => {:variant_id => valid_variants})
        else
          self.line_items
        end
      end
      
    end#class_eval
    
  end #activate 
end# class extension
