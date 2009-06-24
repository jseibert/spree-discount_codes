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
    
    #######################
    # The Order gets by with a little help from friends
    Order.class_eval do
      belongs_to :discount_code
      attr_accessor :discount_code_code
      before_save :find_discount_code
      
      def find_discount_code
        if self.discount_code_code
          self.discount_code = DiscountCode.find_by_code(self.discount_code_code)
        end
      end  

      def total_with_discount
        self.total = total_without_discount + self.discount_total
      end
      alias_method_chain :total, :discount

      def discount_total
        discount = 0.0 
        if self.discount_code
          discount = self.item_total * self.discount_code.discount_rate
        end
        discount *= -1
      end

      def commission_total
        commission_total = 0.0 
        if self.discount_code
          commission_total = self.item_total * self.discount_code.commission_rate
        end
      end
      
    end#class_eval
    
  end #activate 
end# class extension
