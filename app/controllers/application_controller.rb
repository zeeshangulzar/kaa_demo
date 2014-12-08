class ApplicationController < ActionController::Base
  protect_from_forgery

  respond_to :json

  before_filter :set_user_and_promotion
  before_filter :set_default_format_json

  HTTP_CODES = {
    'OK'        => 200,
    'DENIED'    => 403,
    'NOT_FOUND' => 404,
    'ERROR'     => 422
  }
  
  MeEquivalents = ['-', 'me']

  def get_user_from_params_user_id
    if MeEquivalents.include?(params[:id])
      user = @user
    else
      user = @promotion.users.find(params[:id]) rescue nil
    end
  end

  # Sets the default format to json unless a different format is request.
  def set_default_format_json
    if params[:format] && params[:format] != 'json'
      head :bad_request
    else
      request.format = 'json' unless params[:format]
    end
  end

  def set_user_and_promotion
    # first set it to me and my promotion
    @user = HESSecurityMiddleware.current_user
    if @user
      @promotion = @user.promotion

      if params[:promotion_id]
        can_change_promotion = false
        other_promotion = Promotion.find(params[:promotion_id])
        if @user.master? || @user.poster?
          can_change_promotion = true
        elsif @user.reseller? && other_promotion.organization.reseller_id == @user.promotion.organization.reseller_id
          can_change_promotion = true
        elsif @user.coordinator? && other_promotion.organization_id == @user.promotion.organization_id
          can_change_promotion = true
        end
        if can_change_promotion
          @promotion = other_promotion 
        end
      end
    else
      # what if promotion does not exist or is not active????
      info = DomainConfig.parse(request.host)
      if info[:subdomain]
        promotion = Promotion.find_by_subdomain(info[:subdomain])
        if promotion && promotion.is_active
          @promotion = promotion
        end
      end
    end
  end

  def HESResponder(body = 'AOK', status = 'OK')
    response_body = nil
    if status != 'OK'
      # we have an error of some sort..
      body = body.strip + " doesn't exist" if status == 'NOT_FOUND'
      response = {:errors => [body]}
    elsif body.is_a?(String)
      # status is OK and body is a string..
      response = {:message => body}
    else
      if body.is_a?(Array)
        # ActiveRecord collection
      else
        # Single ActiveRecord
      end
      response = body
    end
    code = HTTP_CODES.has_key?(status) ? HTTP_CODES[status] : (status.is_a? Integer) ? status : HTTP_CODES['ERROR']
    render :json => response, :status => code and return
  end

  # Takes incoming param (expected to be a hash) and removes anything that cannot be
  # written in accordance with the incoming model Object. Then returns the scrubbed hash
  def scrub(param, model)
    allowed_attrs = model.accessible_attributes.to_a
    posted_attrs = param.stringify_keys.keys
    attrs_to_update = allowed_attrs & posted_attrs
    param.delete_if{|k,v|!attrs_to_update.include?(k)}
  end

end
