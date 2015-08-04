class PromotionsController < ApplicationController
  authorize :index, :create, :update, :destroy, :master

  authorize :show, :current, :top_location_stats, :verify_users_for_achievements, :public
  authorize :index, :poster
  authorize :create, :update, :destroy, :master

  def index
    promotions = params[:organization_id] ? Organization.find(params[:organization_id]).promotions : params[:reseller_id] ? Reseller.find(params[:reseller_id]).promotions : Promotion.all
    return HESResponder(promotions)
  end


  def show
    promotion = (params[:id] == 'current') ? @promotion : Promotion.find(params[:id]) rescue nil
    if !promotion
      return HESResponder("Promotion", "NOT_FOUND")
    end
    return HESResponder(promotion)
  end

  def current
    if @current_user && @current_user.user?
      return HESCachedResponder(@promotion.cache_key, @promotion)
    end
    return HESResponder(@promotion)
  end

  def create
    promotion = Promotion.create(params[:promotion])
    if !promotion.valid?
      return HESResponder(promotion.errors.full_messages, "ERROR")
    end
    return HESResponder(promotion)
  end
  
  def update
    promotion = Promotion.find(params[:id])
    if !promotion
      return HESResponder("Promotion", "NOT_FOUND")
    else
      Promotion.transaction do
        promotion.update_attributes(params[:promotion])
      end
      if !promotion.valid?
        return HESResponder(promotion.errors.full_messages, "ERROR")
      else
        return HESResponder(promotion)
      end
    end
  end
  
  def destroy
    promotion = Promotion.find(params[:id]) rescue nil
    if !promotion
      return HESResponder("Promotion", "NOT_FOUND")
    elsif promotion.destroy
      return HESResponder(promotion)
    else
      return HESResponder("Error deleting.", "ERROR")
    end
  end

  def top_location_stats
    users = ActiveRecord::Base.connection.select_all("SELECT COUNT(*) AS 'user_count', locations.name FROM users INNER JOIN locations ON users.top_level_location_id = locations.id WHERE users.promotion_id = #{@promotion.id} GROUP BY locations.name;")
    render :json => {:data => users} and return
  end

  def verify_users_for_achievements
    Profile.do_nuid_verification
    render :text=>'OK',:layout=>nil
  end

end
