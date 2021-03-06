class UsersController < ApplicationController
  authorize :create, :validate, :track, :get_user_from_auth_key, :password_reset, :verify_password_reset, :forgot, :authenticate, :public
  authorize :search, :show, :update, :leaderboard, :notification_count, :user
  authorize :index, :coordinator
  authorize :destroy, :impersonate, :master

  after_filter :update_conversation_user_last_seen

  def impersonate
    impersonate_user = User.find(params[:impersonate_id])

    json = impersonate_user.as_json
    json[:auth_key] = impersonate_user.auth_key
    render :json => json and return

    return HESResponder(impersonate_user)
  end

  def get_user_from_auth_key
    impersonated_user = User.where(:auth_key => params[:auth_key]).first

    json = impersonated_user.as_json
    json[:auth_basic_header] = impersonated_user.auth_basic_header

    render :json => json and return
  end

  def index
    sql = "SELECT users.id, first_name, last_name, email, COUNT(entries.id) AS 'days_logged', l2.id AS 'location_id', users.total_points, users.sso_identifier
          FROM users
          LEFT JOIN profiles ON profiles.user_id = users.id
          LEFT JOIN entries ON entries.user_id = users.id
          LEFT JOIN locations l1 ON l1.id = users.top_level_location_id
          LEFT JOIN locations l2 ON l2.id = users.location_id
          WHERE users.promotion_id = #{@promotion.id}
          GROUP BY users.id;"

    rows = ActiveRecord::Base.connection.select_all(sql)

    return HESResponder(rows)
  end

  def authenticate
    info = DomainConfig.parse(request.host)
    if @promotion
      user = @promotion.users.find_by_altid(params[:email]) rescue nil
      unless params[:email].nil? || params[:email].empty?
        user ||= @promotion.users.find_by_email(params[:email]) rescue nil
      end
      user = user && user.password == params[:password] ? user : nil
    elsif @promotion.nil? && info[:subdomain] == 'api' && !params[:email].nil? && !params[:email].empty?
      users = User.find(:all,
                :conditions =>
                  [
                    "altid = ? or email = ?",
                    params[:email], params[:email]
                  ],
                :order => "users.created_at DESC")
      user = users.detect{|u| u.password == params[:password]}
    end
    HESSecurityMiddleware.set_current_user(user)
    if user

      user.last_login = user.promotion.current_time
      user.save!

      json = user.as_json
      json[:auth_basic_header] = user.auth_basic_header
      render :json => json and return
    else
      return HESResponder("Email or password is incorrect.", 401)
    end
  end

  def show
    if @target_user.id == @current_user.id || @current_user.master?
      @target_user.attach('stats', @target_user.stats)
      #@target_user.attach('recent_activities', @target_user.recent_activities)
      @target_user.attach('team_id', !@target_user.current_team.nil? ? @target_user.current_team.id : nil)
      @target_user.attach('order_count', @target_user.orders.count)

      if @target_user.id == @current_user.id || @current_user.coordinator_or_above?
        @target_user.attach('completed_evaluation_definition_ids', @target_user.completed_evaluation_definition_ids)
        @target_user.attach('active_evaluation_definition_ids', @target_user.active_evaluation_definition_ids)
      end

      if @target_user.fitbit_user
        device_sql = "SELECT fud.remote_id, fud.type_of_device, fud.device_version, fud.last_sync_time FROM fitbit_user_devices fud
               INNER JOIN fitbit_users fbu ON fud.fitbit_user_id = fbu.id
               INNER JOIN users u ON fbu.user_id = u.id
               WHERE u.id = #{@target_user.id};"

        notification_sql = "SELECT fbn.id, fbn.status, fbn.date, fbn.updated_at FROM fitbit_notifications fbn
               INNER JOIN fitbit_users fbu ON fbn.fitbit_user_id = fbu.id
               INNER JOIN users u ON fbu.user_id = u.id
               WHERE u.id = #{@target_user.id};"

        fitbit_devices = User.connection.select_all(device_sql)
        fitbit_notifications = User.connection.select_all(notification_sql)

        @target_user.attach('fitbit_devices', fitbit_devices)
        @target_user.attach('fitbit_user', @target_user.fitbit_user)
        @target_user.attach('fitbit_user_notifications', fitbit_notifications)
        @target_user.attach('fitbit_weeks', @target_user.get_fitbit_weeks)
        @target_user.attach('subscriptions', @target_user.fitbit_user.retrieve_subscriptions) rescue nil
      end
    end

    if @current_user.master?
      if @target_user.fitbit_user
        device_sql = "SELECT fud.remote_id, fud.type_of_device, fud.device_version, fud.last_sync_time FROM fitbit_user_devices fud
               INNER JOIN fitbit_users fbu ON fud.fitbit_user_id = fbu.id
               INNER JOIN users u ON fbu.user_id = u.id
               WHERE u.id = #{@target_user.id};"

        notification_sql = "SELECT fbn.id, fbn.status, fbn.date, fbn.updated_at FROM fitbit_notifications fbn
               INNER JOIN fitbit_users fbu ON fbn.fitbit_user_id = fbu.id
               INNER JOIN users u ON fbu.user_id = u.id
               WHERE u.id = #{@target_user.id};"

        fitbit_devices = User.connection.select_all(device_sql)
        fitbit_notifications = User.connection.select_all(notification_sql)

        @target_user.attach('fitbit_devices', fitbit_devices)
        @target_user.attach('fitbit_user', @target_user.fitbit_user)
        @target_user.attach('fitbit_user_notifications', fitbit_notifications)
        @target_user.attach('fitbit_weeks', @target_user.get_fitbit_weeks)
        @target_user.attach('subscriptions', @target_user.fitbit_user.retrieve_subscriptions) rescue nil
      end

      if @target_user.jawbone_user
        notification_sql = "SELECT jbn.id, jbn.status, jbn.created_at, jbn.updated_at FROM jawbone_notifications jbn
               INNER JOIN jawbone_users jbu ON jbn.jawbone_user_id = jbu.id
               INNER JOIN users u ON jbu.user_id = u.id
               WHERE u.id = #{@target_user.id};"

        jawbone_notifications = User.connection.select_all(notification_sql)

        @target_user.attach('jawbone_user', @target_user.jawbone_user)
        @target_user.attach('jawbone_user_notifications', jawbone_notifications)
        @target_user.attach('jawbone_weeks', @target_user.get_fitbit_weeks)
      end
    end

    return HESResponder(@target_user)
  end

  def create
    return HESResponder("No user provided.", "ERROR") if params[:user].empty?
    return HESResponder("Maximum participants reached.", "ERROR") if !@promotion.max_participants.nil? && @promotion.max_participants <= @promotion.total_participants
    demographic = false
    if !params[:user][:profile].nil?
      if !params[:user][:profile][:age].nil? || !params[:user][:profile][:gender].nil? || !params[:user][:profile][:ethnicity].nil?
        demographic = Demographic.new()
        demographic.age = params[:user][:profile].delete(:age) if !params[:user][:profile][:age].nil?
        demographic.gender = params[:user][:profile].delete(:gender) if !params[:user][:profile][:gender].nil?
        demographic.ethnicity = params[:user][:profile].delete(:ethnicity) if !params[:user][:profile][:ethnicity].nil?
      end
      params[:user][:profile] = Profile.new(params[:user][:profile])
    end

    if params[:evaluation] && params[:evaluation][:evaluation_definition_id]
      ed = EvaluationDefinition.find(params[:evaluation][:evaluation_definition_id]) rescue nil
      if ed && ed.eval_definitionable_type == "Promotion" && ed.eval_definitionable_id == @promotion.id
        eval_params = params[:evaluation]
        params[:user].delete(:evaluation)
      else
        return HESResponder("Invalid evaluation definition.", "ERROR")
      end
    else
      eval_params = nil
    end

    if @promotion.organization.is_sso_enabled
      if cookies['sso_session_token'].nil? || cookies['sso_session_token'].strip.empty?
        return HESResponder("Must provide SSO session token for SSO enabled organizations.", "ERROR")
      else
        sso = Sso.find_by_session_token(cookies['sso_session_token']) rescue nil
        if !sso
          return HESResponder("SSO not found.", "ERROR")
        elsif !@promotion.users.where(:sso_identifier => sso.identifier).empty?
          return HESResponder("SSO identifier already in use.", "ERROR")
        else
          params[:user][:sso_identifier] = sso.identifier
        end
      end
    end

    user = @promotion.users.new(params[:user])
    User.transaction do
      if !user.valid?
        return HESResponder(user.errors.full_messages, "ERROR")
      else
        user.save!
        if eval_params
          eval_params[:user_id] = user.id
          eval = ed.evaluations.build(eval_params)
          if eval.valid?
            eval.save!
          end
        end
        if demographic
          demographic.user_id = user.id
          demographic.save!
        end
        if @promotion.flags[:is_eligibility_displayed]
          if params[:eligibility_identifier].nil? || params[:eligibility_identifier].empty?
            return HESResponder("Eligibility identifier required.", "ERROR")
          else
            eligibility = @promotion.eligibilities.find_by_identifier(params[:eligibility_identifier]) rescue nil
            return HESResponder("Eligibility not found.", "ERROR") if !eligibility
            if !eligibility.user_id.nil?
              return HESResponder("Eligibility identifier already in use.", "ERROR")
            else
              eligibility.user_id = user.id
              eligibility.save!
            end
          end
        end
      end
    end
    user.welcome_notification
    user.attach('auth_basic_header', user.auth_basic_header)
    return HESResponder(user)
  end

  def update
    if @target_user.id != @current_user.id && !@current_user.master?
      return HESResponder("You may not edit this user.", "DENIED")
    else
      User.transaction do
        profile_data = !params[:user][:profile].nil? ? params[:user].delete(:profile) : []

        if params[:flags]
          @target_user.flags.keys.each{|flag|
            @target_user.flags[flag] = params[:flags][flag] if !params[:flags][flag].nil?
          }
        end

        profile_data.delete :id
        profile_data.delete :url
        profile_data.delete :backlog_date

        @target_user.update_attributes(params[:user])
        @target_user.profile.update_attributes(profile_data) if !profile_data.empty?
      end
      if !@target_user.valid?
        errors = !@target_user.profile.errors.empty? ? @target_user.profile.errors : @target_user.errors # the order here is important. profile will have specific errors.
        return HESResponder(errors.full_messages, "ERROR")
      else
        return HESResponder(@target_user)
      end
    end
  end

  def destroy
    if @current_user.master? && @current_user.id != @target_user.id
      User.transaction do
        @target_user.destroy
      end
      return HESResponder()
    end
  end

  def search
    search_string = params[:search_string].nil? ? params[:query] : params[:search_string]
    if search_string.nil? || search_string.blank?
      return HESResponder([])
    else
      search_string = search_string.strip
    end
    limit = !params[:limit].nil? ? params[:limit].to_i : 50
    pid = @current_user.master? && params[:promotion_id] ? params[:promotion_id] : @current_user.promotion_id
    users = @current_user.search(search_string, !params[:unassociated].nil?, limit, pid)
    unless users.empty?
      team_ids = User::get_team_ids(users.collect{|user|user.id})
      users.each_with_index{ |user, idx|
        users[idx].attach('team_id', team_ids[user.id])
      }
    end
    return HESResponder(users, "OK", limit)
  end


  # this just checks for uniqueness at the moment
  def validate
    return HESResponder("Field and value required.", "ERROR") unless params[:field] && params[:value]
    fs = ['email','username', 'altid']
    f = params[:field]
    if !fs.include?(f)
      return HESResponder("Can't check this field.", "ERROR")
    end
    f = f.to_sym
    v = params[:value]
    if @promotion.users.where("LOWER(#{f}) = ?", v.downcase).count > 0
      return HESResponder(f.to_s.titleize + " is not unique within promotion.", "ERROR")
    else
      return HESResponder()
    end
  end

  def stats
    user = (@target_user.id != @current_user.id) ? @target_user : @current_user
    return HESResponder(user.stats())
  end

  def forgot
    user = @promotion.users.find(:first, :conditions => ["email = ?", params[:email]])
    unless user.nil?
      GoMailer.forgot_password(user, get_host).deliver
    end
    return HESResponder()
  end

  # Reset the user password to the new password
  # Check is done to make sure the password is allowed to be changed for the user
  def password_reset
    password_changed = false;

    if allow_password_reset()
      unless params[:password].to_s.strip.empty?
        @password_reset_user.password = params[:password]
        @password_reset_user.save!
        @password_reset_user.initialize_aes_iv_and_key
        @password_reset_user.save!
        GoMailer.password_reset(@password_reset_user, get_host).deliver
        password_changed=true
      end
    end

    return HESResponder({:password_changed => password_changed})
  end

  #Verify the password reset is allowed
  def verify_password_reset
    return HESResponder({:allow => allow_password_reset()})
  end

  def allow_password_reset()
    # link in email is a big string separated by ~ and it is encrypted *with the app's AES key* and base-64 encoded
    # example: 983~BmpnaBfzyLgfVltNMyPvVG4SFB2%0AcKuwHwkP8sKk%2BqDt2DYvWE33uT6tr
    # element 0 is the user's ID
    # element 1 is a big string separated by ~ and it is encrypted *with the user's AES key* and base-64 encoded
    # element 1,0 is random hex for padding
    # element 1,1 is the user's id
    # element 1,2 the date/time the link was created
    #
    # the link must be less than 60 minutes old (i.e. element 1,2 is a timestamp that must not be older than 60 minutes)
    allow_password_reset=false
    if params[:thing]
      key = params[:thing]
      decoded_key = PerModelEncryption.url_base64_decode(key)
      string = Encryption.decrypt(decoded_key) rescue nil
      if string
        user_id,encrypted_information = string.split('~')
        if user_id && encrypted_information
          @password_reset_user = User.find(user_id)
          if @password_reset_user
            decrypted_information = @password_reset_user.aes_decrypt(PerModelEncryption.url_base64_decode(encrypted_information))
            pieces = decrypted_information.split('~')
            if pieces.size==4 && @password_reset_user.id == pieces[1].to_i
              link_timestamp = Time.at(pieces[2].to_i).utc
              age = Time.now.utc - link_timestamp
              if age < 3600
                allow_password_reset = true
              end
            end
          end
        end
      end
    end

    return allow_password_reset
  end

  def track
    if !params[:uri].nil?
      if @current_user && @current_user.user_or_above?
        @current_user.requests.create(:uri => params[:uri], :ip => request.remote_ip, :info => params[:info])
      else
        r = Request.new(:uri => params[:uri], :ip => request.remote_ip, :info => params[:info])
        if r.valid?
          r.save!
        end
      end
    end
    return HESResponder()
  end

  def leaderboard
    conditions = {
      :location_ids => (params[:location].nil? ? nil : params[:location].split(',')),
      :sort         => params[:sort],
      :sort_dir     => params[:sort_dir]
      # :limit        => params[:page_size]
    }
    users = []
    users = @promotion.individual_leaderboard(conditions)
    count = @promotion.individual_leaderboard(conditions, true)
    return HESResponder(users, 'OK', nil, false, count)
  end

  def notification_count
    if @current_user.id != params[:user_id].to_i && !@current_user.master?
      return HESResponder("I can't let you do that, Dave.", "DENIED")
    end
    if params[:count] && (params[:count].is_a?(Integer) || params[:count].is_i?)
      User.transaction do
        @current_user.notification_count += params[:count].to_i
        @current_user.notification_count = 0 if @current_user.notification_count < 0
        @current_user.save!
      end
    end
    return HESDumpResponder({:notification_count => @current_user.notification_count})
  end

  def conversation_summary
    conversations = Conversation.unmuted_conversations(params[:user_id]).count
    return HESResponder("count: #{conversations}")
  end

  private

    def update_conversation_user_last_seen
      ConversationUser.update_last_seen(params[:user_id])
    end

end
