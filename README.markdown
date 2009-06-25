# Affiliate System #

## extensions
This extension creates a DiscountCode resource. 
	discount_code belongs_to :user 
	order has_many :discount_codes

We also will add some columns to the Order model. 
	order.discount_code_id
	order.discount_total => once the discount is calculated it is stored on the order 
	order.commission_total => likewise 

The methods added:
	order.discount_total
	order.commission_total
	order.total_with_discount
	order.total_without_discount

## theory

A user can become an affiliate by adding a discount_code