require "hes-authorization"
require 'carrierwave'

require File.dirname(__FILE__) + "/post_validator"
require File.dirname(__FILE__) + "/has_wall"
require File.dirname(__FILE__) + "/is_postable"
require File.dirname(__FILE__) + "/post_action_notifier"
require File.dirname(__FILE__) + "/user_post_methods"


module HesPosts
  # Engine to start up HES posts
  class Engine < ::Rails::Engine
  	#initializer "hes-posts" do |app|
  		ActiveRecord::Base.send(:extend, HesPosts::HasWall)
  		ActiveRecord::Base.send(:extend, HesPosts::IsPostable)
      ActiveRecord::Base.send(:extend, HesPosts::UserPostMethods)
  #	end

  end
end
