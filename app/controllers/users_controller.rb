class UsersController < ApplicationController
  authorize :create, :validate, :public
  authorize :search, :show, :user
  authorize :update, :me
  authorize :index, :coordinator
  authorize :destroy, :master

  def index
    return HESResponder(@promotion.users.find(:all,:include=>:profile))
  end

  # Get a user
  #
  # @url [GET] /users/1
  # @param [Integer] id The id of the user
  # @return [User] User that matches the id
  #
  # [URL] /users/:id [GET]
  #  [200 OK] Successfully retrieved User
  def show
    user = @promotion.users.find(params[:id]) rescue nil
    if !user
      return HESResponder("User doesn't exist.", 'NOT_FOUND')
    end
    return HESResponder(user)
  end



  # Create a user
  #
  # @url [POST] /users
  # @authorize Public
  # TODO: document me!
  def create
    return HESResponder('No user provided.', 'ERROR') if params[:user].nil?

    params[:user][:profile] = Profile.new(params[:user][:profile]) if !params[:user][:profile].nil?

    if params[:user][:evaluation] && params[:user][:evaluation][:evaluation_definition_id]
      ed = EvaluationDefinition.find(params[:user][:evaluation][:evaluation_definition_id])
      if ed && ed.eval_definitionable_type == 'Promotion' && ed.eval_definitionable_id == @promotion.id
        eval_params = params[:user][:evaluation]
        params[:user].delete(:evaluation)
      else
        return HESResponder("Invalid evaluation definition.", 'ERROR')
      end
    else
      eval_params = nil
    end

    user = @promotion.users.create(params[:user])

    if !user.valid?
      return HESResponder(user.errors.full_messages, 'ERROR')
    else
      if eval_params
        eval_params[:user_id] = user.id
        eval = ed.evaluations.create(eval_params)
      end
      return HESResponder(user)
    end
  end
  
  def update
    user = User.find(params[:id]) rescue nil
    if !user
      return HESResponder("User doesn't exist.", 'NOT_FOUND')
    else
      User.transaction do
        profile_data = !params[:user][:profile].nil? ? params[:user].delete(:profile) : []
        user.update_attributes(params[:user])
        user.profile.update_attributes(profile_data)
      end
      errors = user.profile.errors || user.errors # the order here is important. profile will have specific errors.
      if errors
        return HESResponder(errors.full_messages, 'ERROR')
      else
        return HESResponder(user)
      end
    end
  end
  
  def destroy
    user = User.find(params[:id]) rescue nil
    if !user
      return HESResponder("User doesn't exist.", 'NOT_FOUND')
    elsif @user.master? && user.destroy
      return HESResponder(user)
    else
      return HESResponder("You may not delete.", 'DENIED')
    end
  end

  # this might not be working yet..
  def search
    search_string = "%#{params[:search_string]}%"
    conditions = ["users.email like ? or profiles.first_name like ? or profiles.last_name like ?",search_string, search_string, search_string]
    p = (@user.master? && params[:promotion_id] && Promotion.exists?(params[:promotion_id])) ? Promotion.find(params[:promotion_id]) : @promotion
    users = p.users.find(:all,:include=>:profile,:conditions=>conditions)
    return HESResponder(users)
  end


  # this just checks for uniqueness at the moment
  def validate
    fs = ['email','username']
    f = params[:field]
    if !fs.include?(f)
      return HESResponder("Can't check this field.", 'ERROR')
    end
    f = f.to_sym
    v = params[:value]
    if @promotion.users.where(f=>v).count > 0
      return HESResponder(f.to_s.titleize + " is not unique within promotion.", 'ERROR')
    else
      return HESResponder()
    end
  end

end
