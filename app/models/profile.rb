class Profile < ApplicationModel
  attr_accessible *column_names
  attr_privacy :first_name,:last_name,:phone,:mobile_phone,:user_id,:updated_at,:created_at,:me
  attr_privacy :first_name,:last_name,:connections
  attr_privacy :first_name,:last_name,:public_comment

  belongs_to :user

  include TrackChangedFields
  udfable
  
  flags :has_changed_password_at_least_once, :default => false
  
  before_create :set_default_values

  GoalMin = 150
  GoalMax = 360
  Gender = [['-- Choose --', ''], ['Female','F'], ['Male','M'] ]
  DaysActivePerWeek = [['-- Choose --', ''], [0,0],[1,1],[2,2],[3,3],[4,4],[5,5],[6,6],[7,7] ]
  MinutesPerDay = [['-- Choose --', ''], ['0 - 15', '0 - 15'], ['16 - 30', '16 - 30'], ['31 - 45','31 - 45'], ['46 - 60','46 - 60'], ['More than 60', 'More than 60'] ]

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
      self.goal = promotion.default_goal
  end
  
end