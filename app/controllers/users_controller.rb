class UsersController < ApplicationController
  authorize :create, :validate, :public
  authorize :search, :update, :user
  authorize :index, :coordinator
  authorize :destroy, :master
  authorize :authenticate, :public

  def index
    respond_with @promotion.users.find(:all,:include=>:profile)
  end

  def authenticate
    user = @promotion.users.find_by_email(params[:email])

    if user && user.password == params[:password]
      json = user.as_json
      json[:auth_basic_header] = user.auth_basic_header
      render :json => json
    else
      render :json => {:errors => ["Can't authenticate user."]}, :status => 401 and return
    end
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
      render :json => {:errors => ["User doesn't exist."]}, :status => 404 and return
    end
    render :json => user and return
  end

  def create
    params[:user][:profile] = Profile.new(params[:user][:profile]) if !params[:user][:profile].nil?
    user = @promotion.users.create(params[:user])
    if !user.valid?
      render :json => {:errors => user.errors.full_messages}, :status =>  422 and return
    else
      render :json => user and return
    end
  end
  
  def update
    user = User.find(params[:id]) rescue nil
    params[:user][:profile] = Profile.new(params[:user][:profile]) if !params[:user][:profile].nil?
    if !user
      render :json => {:errors => ["User doesn't exist."]}, :status => 404 and return
    elsif user.update_attributes(params[:user])
      render :json => user
    elsif user.errors
      render :json => {:errors => user.errors.full_messages}, :status =>  422 and return
    else
      render :json => {:errors => "Something went wrong, Jake."}, :status =>  422 and return
    end
  end
  
  def destroy
    user = User.find(params[:id]) rescue nil
    if !user
      render :json => {:errors => ["User doesn't exist."]}, :status => 404 and return
    elsif @user.master? && user.destroy
      render :json => user
    else
      render :json => {:errors => "You may not delete."}, :status =>  403 and return
    end
  end

  # this might not be working yet..
  def search
    search_string = "%#{params[:search_string]}%"
    conditions = ["users.email like ? or profiles.first_name like ? or profiles.last_name like ?",search_string, search_string, search_string]
    p = (@user.master? && params[:promotion_id] && Promotion.exists?(params[:promotion_id])) ? Promotion.find(params[:promotion_id]) : @promotion
    users = p.users.find(:all,:include=>:profile,:conditions=>conditions)
    render :json => users and return
  end


  # this just checks for uniqueness at the moment
  def validate
    fs = ['email','username']
    f = params[:field]
    if !fs.include?(f)
      render :json => {:errors => "Can't check this field."}, :status =>  422 and return
    end
    f = f.to_sym
    v = params[:funky_chicken]
    if @promotion.users.where(f=>v).count > 0
      render :json => {:errors => f.to_s.titleize + " is not unique within promotion."}, :status =>  422 and return
    else
      render :json => {:message => 'AOK'} and return
    end
  end

end
