class Admin::DiscountCodesController < Admin::BaseController
  layout "admin"
  resource_controller
  
  new_action.response do |wants|
    wants.html {render :action => :new, :layout => false}
  end
  
  create.response do |wants| 
    wants.html {redirect_to collection_url }
  end
  
  update.response do |wants| 
    wants.html {redirect_to collection_url }
  end
  
  def collection 
    #use the active named scope only if the 'show deleted' checkbox is unchecked
    if params[:search].nil? || params[:search][:conditions].nil? || params[:search][:conditions][:deleted_at_is_not_null].blank?
      @search = end_of_association_chain.not_deleted.new_search(params[:search])
    else
      @search = end_of_association_chain.new_search(params[:search])
    end

    #set order by to default or form result
    @search.order_by ||= :code
    @search.order_as ||= "ASC"
    #set results per page to default or form result
    @search.per_page = Spree::Config[:admin_products_per_page]
    @search.include = :user
    @collection = @search.all
  end
end
