# Like active record class for keeping track of likes that users have
class Like < ApplicationModel

  attr_privacy_path_to_user :user
  attr_privacy :id, :user_id, :likeable_type, :likeable_id, :user, :any_user

  belongs_to :likeable, :polymorphic => true
  belongs_to :user

  scope :typed, lambda{|likeable_type| where(:likeable_type => likeable_type)}

  after_create :trigger_after_like
  after_destroy :trigger_after_unlike

  validates_uniqueness_of :likeable_id, :scope => [:user_id, :likeable_type]

  # Destroys the like
  def unlike
    destroy
  end

  # Overrides likeable built by polymorphic association in case likeable is not an ActiveRecord
  def likeable
    unless HesLikeable::ActsAsLikeable.non_active_record_likeables.collect(&:to_s).include?(self.likeable_type)
      Rails.logger.info "\n\nNonActiveRecordLikeables: #{HesLikeable::ActsAsLikeable.non_active_record_likeables.collect(&:to_s).inspect}\n\n"
      super
    else
      HesLikeable::ActsAsLikeable.non_active_record_likeables.detect{|x| x.to_s == self.likeable_type}.find(self.likeable_id)
    end
  end

  # Triggers the 'after_like' method
  def trigger_after_like
    likeable.fire_after_like(self) if likeable.respond_to?(:fire_after_like)
    user.fire_after_like(self) if user.respond_to?(:fire_after_like)
  end

  # Triggers the 'after_like' method
  def trigger_after_unlike
    likeable.fire_after_unlike(self) if likeable.respond_to?(:fire_after_unlike)
    user.fire_after_unlike(self) if user.respond_to?(:fire_after_unlike)
  end

end
