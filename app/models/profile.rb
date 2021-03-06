class Profile < ApplicationModel
  # attrs
  attr_privacy_path_to_user :user
  
  attr_accessible :user_id, :gender, :first_name, :last_name, :phone, :mobile_phone, :line1, :line2, :city, :state_province, :country, :postal_code, :time_zone, :started_on, :registered_on, :created_at, :updated_at, :image, :goal_steps, :goal_minutes, :default_logging_type, :goal, :goal_points

  attr_privacy :first_name,:last_name,:image,:public_comment

  attr_privacy :first_name,:last_name,:phone,:mobile_phone,:user_id,:updated_at,:created_at, :started_on, :goal_steps, :goal_minutes, :goal_points, :backlog_date, :default_logging_type, :line1, :line2, :city, :state_province, :postal_code, :backlog_date, :goal, :me

  # validation
  validates_presence_of :first_name, :last_name

  # relationships
  belongs_to :user

  mount_uploader :image, ProfilePhotoUploader


  # flags
  flags :has_changed_password_at_least_once, :default => false

  # hooks
  before_create :set_default_values

  # constants
  GoalMin = 150
  GoalMax = 360
  Gender = [['-- Choose --', ''], ['Female','F'], ['Male','M'] ]
  DaysActivePerWeek = [['-- Choose --', ''], [0,0],[1,1],[2,2],[3,3],[4,4],[5,5],[6,6],[7,7] ]
  MinutesPerDay = [['-- Choose --', ''], ['0 - 15', '0 - 15'], ['16 - 30', '16 - 30'], ['31 - 45','31 - 45'], ['46 - 60','46 - 60'], ['More than 60', 'More than 60'] ]

  # methods

  # Full name (if both first and last name are present)
  def full_name
    first_name.to_s + " " + last_name.to_s
  end

  # Email with full name returned or nil
  def email_with_name
    "#{full_name} <#{email.to_s}>"
  end
  
  def email_with_name_escaped
    email_with_name.gsub("<", "&lt;").gsub(">", "&gt;")
  end

  def self.get_next_start_date(promotion,today=Date.today)
    return today if promotion.nil?
    if promotion.starts_on && promotion.registration_starts_on && promotion.registration_ends_on && promotion.registration_starts_on <= today && today <= promotion.registration_ends_on
      return promotion.starts_on
    elsif promotion.starts_on && today <= promotion.starts_on
      return promotion.starts_on
    else
      return today
    end
  end

  def set_default_values
    promotion = self.user.promotion
    self.registered_on = promotion.current_date
    self.started_on = self.class.get_next_start_date(promotion)
  end

  def backlog_date
    # Team stuff removed from calculation because it was KP specific from GO KP
    sans_team = (self.user.promotion.backlog_days && self.user.promotion.backlog_days > 0) ? [self.user.promotion.current_date - self.user.promotion.backlog_days, self.started_on].max : self.started_on
    return sans_team
  end

end
