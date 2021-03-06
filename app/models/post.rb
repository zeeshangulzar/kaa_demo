# Model that is posted to walls. Can be nested or replies to other posts and also contain postable object related to post.
class Post < ApplicationModel

  attr_privacy :content, :depth, :photo, :parent_post_id, :root_post_id, :is_flagged, :postable_type, :postable_id, :wallable_id, :wallable_type, :created_at, :updated_at, :flagged_by, :user, :title, :posts, :likes, :views, :any_user
  
  # The page size allowed for getting posts
  PAGESIZE = 20

  belongs_to :user

  belongs_to :parent_post, :class_name => Post, :foreign_key => :parent_post_id

  belongs_to :root_post, :class_name => Post, :foreign_key => :root_post_id

  has_many :posts, :class_name => Post, :foreign_key => :parent_post_id, :order => "created_at DESC"

  has_many :child_posts, :class_name => Post, :foreign_key => :root_post_id

  belongs_to :wallable, :polymorphic => true

  belongs_to :postable, :polymorphic => true

  mount_uploader :photo, PostPhotoUploader

  # Validates post making sure attributes are present
  validates_presence_of :content, :depth, :user_id, :wallable_id, :wallable_type

  # Validates post using custom validator locatated at lib/post_validater.rb
  validates_with HesPosts::PostValidator

  attr_accessible :parent_post_id, :root_post_id, :user_id, :depth, :content, :postable_id, :postable_type, :wallable_id, :wallable_type, :is_flagged, :is_deleted, :photo, :created_at, :updated_at, :flagged_by, :title, :views, :source_id

  # Set the root post id before validation
  before_validation :set_root_post_id

  # Set the wallable object before validation
  before_validation :set_wallable

  # Fired after post is replied to
  event_accessor :after_reply
  after_create lambda { |post| post.parent_post.fire_after_reply(post) }, :if => lambda { |post| post.reply? }

  # Fired after a reply is destroyed
  event_accessor :after_reply_destroyed
  after_destroy lambda { |post| post.parent_post.fire_after_reply_destroyed(post) }, :if => lambda { |post| post.reply? && post.parent_post }

  after_create :clone_wall_expert_post
  after_update :update_wall_expert_post
  after_destroy :destroy_wall_expert_post

  acts_as_likeable

  is_postable

  acts_as_notifier

  #after_update :notify_if_flagged

  scope :top, lambda { where(:depth => 0).includes([:user, {:likes => :user}, {:posts => [:user, {:likes => :user}]}] ).order("posts.created_at DESC") }

  scope :locationed, lambda { |location_id|
    locations = Location.find(location_id).children.collect{|l|l.id}.push(location_id)
    where(:depth => 0, :users => {:location_id => locations}).includes([:user, {:likes => :user}, {:posts => [:user, {:likes => :user}]}] ).order("posts.created_at DESC")
  }
  
  scope :reply, lambda { where("depth > 0").includes([:user, {:likes => :user}, {:posts => [:user, {:likes => :user}]}] ).order("posts.created_at DESC") }

  scope :before, lambda { |post_id| where("`posts`.id < :post_id", {:post_id => post_id || 10000000}) }

  scope :after, lambda { |post_id| where("`posts`.id > :post_id", {:post_id => post_id || -1}) }

  scope :from_users, lambda { |user_ids| where("`posts`.user_id in (:uids)", {:uids => user_ids}) }

  POPULARITY_SCORE = {
    :likes       => 3,
    :replies     => 3,
    :reply_likes => 1
  }
  # Gets the key to be applied to the formula for popular weight based on created_at
  def days_old_weight
    difference = Date.today - self.created_at.to_date
    HesPosts.days_old_weight.keys.sort{|x,y| y <=> x}.each do |day|  
      return HesPosts.days_old_weight[day] if difference >= day
    end
    return 1
  end

  # The root id should be set before a post is created. It should be either the parent id or the parent's root_post_id.
  # @return [Boolean] true
  def set_root_post_id
    unless depth.zero? || self.root_post_id
      self.root_post_id = self.parent_post.depth.zero? ? self.parent_post_id : self.parent_post.root_post_id unless self.parent_post.nil?
    end

    true
  end

  # The wallable id and type should be set before the post is created. It should be the same as the parent wallable id and type.
  # @return [Boolean] true
  def set_wallable
    unless depth.zero? || (self.wallable_type && self.wallable_id)
      self.wallable_id = self.parent_post.wallable_id
      self.wallable_type = self.parent_post.wallable_type
    end

    true
  end

  # Returns whether or not post is a reply
  # @return [Boolean] true if is a reply (depth greater than 0), false if root post (depth is 0)
  def reply?
    return !depth.zero?
  end

  # Creates this post on the wallable passed in. Used for chaining.
  # @param [Wallable] wallable that this post is being added to
  # @return [Post] post that has been added to wallable
  # @example
  #  @user.post("I'm doing my laundry").to(@promotion)
  #  @user.post("I'm eating this recipe", @recipe).to(@promotion)
  def to(wallable)
    self.wallable = wallable
    save
    self
  end

  # Override postable so that ActiveResource polymorphic association works
  # @todo Need to write a test to make sure ActiveResource models work
  def postable(*args)
    if self.postable_type.nil? || self.postable_type.constantize < ActiveRecord::Base
      super
    elsif self.postable_type.constantize < ActiveResource::Base
      self.postable_type.constantize.send(:find, self.postable_id)
    end
  rescue
    super
  end




    # Like actions
  after_like :create_post_owner_notification_of_like
  after_unlike :destroy_post_owner_notification_of_like
  # Reply actions
  after_reply :create_post_owner_notification_of_reply
  after_reply_destroyed :destroy_post_owner_notification_of_reply

  # Creates a notification after a post is liked
  # @param [Like] like that was generated from liking this post
  # @return [Notification] notification that was generated after liking post
  # @note Notification title and message can be edited in hes-posts_config file in config/initializers folder.
  def create_post_owner_notification_of_like(like)
    return if like.user.id == self.user.id # don't notify user of his own likes..
    case like.likeable.wallable.class.name
    when 'Recipe'
      url = "recipes/#{self.wallable_id}"
    when 'Tip'
      url = "tips/#{self.wallable_id}"
    else
      base_url = self.user.poster? ? "wall_expert" : "wall"
      url = !self.parent_post_id.nil? ? "#{base_url}/#{self.parent_post_id}?reply=#{self.id}" : "#{base_url}/#{self.id}"
    end
    notify(self.user, "Your post was liked!", "#{like.user.profile.full_name} liked your post!", :from => like.user, :key => post_like_notification_key(like), :link => url)
  end

  # Creates a notification after a post is liked
  # @param [Like] like that was generated from liking this post
  # @return [Boolean] true if notification was destroyed, false if it was not
  def destroy_post_owner_notification_of_like(like)
    self.notifications.find_by_key(post_like_notification_key(like)).destroy rescue true
  end

  # The key that is generated to find likes tied to a notification
  # @param [Like] like used for notification key
  # @return [String] key that will be used to create notification
  def post_like_notification_key(like)
    "post_like_#{like.id}"
  end


  # Creates a notification after a post is replied to
  # @param [Post] reply post
  # @return [Notification] notification that was generated after replying to post
  # @note Notification title and message can be edited in hes-posts_config file in config/initializers folder.
  def create_post_owner_notification_of_reply(reply)
    return if reply.user.id == self.user.id # don't notify user of his own replies..
    if self.user.role == "Poster"
      url = "wall_expert/#{self.id}"
    else
      url = "wall/#{self.id}"
    end
    notify(self.user, "Your post was commented on!", "#{reply.user.profile.full_name} commented on your post!", :from => reply.user, :key => post_reply_notification_key(reply), :link => '#{url}?reply=#{reply.id}')
  end

  # Destroys the notification after a post reply is destroyed
  # @return [Boolean] true if notification was destroyed, false if it was not
  def destroy_post_owner_notification_of_reply(reply)
    self.notifications.find_by_key(post_reply_notification_key(reply)).destroy rescue true
  end

  # The key that is generated to find replies tied to a notification
  # @param [Post] reply used for notification key
  # @return [String] key that will be used to create notification
  def post_reply_notification_key(reply)
    "post_reply_#{reply.id}"
  end

  def root_user
    return !self.root_post.nil? ? self.root_post.user : self.user
  end

  def notify_if_flagged
    if !self.is_flagged_was && self.is_flagged
      notify(self.user, "Your post has been flagged.", "Your post was flagged.", :from => self.user, :key => "post_" + self.id.to_s, :link => 'wall/#{self.id}')
    end
  end


  # big ass method to get everything on the wall without active record junk
  # it's ugly, but it's fast...
  def self.wall(wall, conditions = {}, count = false, reply_count = false)
    conditions = {
      :offset        => 0,
      :limit         => 50,
      :user_ids      => [],
      :location_ids  => [],
      :has_photo     => nil,
      :flagged_only  => false,
      :query         => nil,
      :by_popularity => false
    }.merge(conditions)

    if count
      # handle count of top posts separately as we don't want to use ActiveRecord's yucky count method
      posts_sql = "
        SELECT
        SUM(IF(id > 0, 1, 0)) AS count
        FROM (
          SELECT #{reply_count ? "replies.id" : "posts.id"} AS id
          FROM
          posts
      "
      if !conditions[:location_ids].empty? || !conditions[:user_ids].empty?
        posts_sql = posts_sql + " JOIN users ON users.id = posts.user_id "
        posts_sql = posts_sql + " AND ( users.location_id IN (#{conditions[:location_ids].join(',')}) OR users.top_level_location_id IN (#{conditions[:location_ids].join(',')}) )" if !conditions[:location_ids].empty?
        posts_sql = posts_sql + " AND users.id IN (#{conditions[:user_ids].join(',')}) " if !conditions[:user_ids].empty?
      end
      if conditions[:flagged_only] || reply_count
        posts_sql = posts_sql + " LEFT JOIN posts replies ON replies.parent_post_id = posts.id"
      end
      posts_sql = posts_sql + "
          WHERE
          posts.parent_post_id IS NULL AND posts.wallable_id = #{wall.id} AND posts.wallable_type = '#{wall.class.to_s}'
          #{ 'AND posts.photo IS NOT NULL' if conditions[:has_photo] }
          #{ 'AND (posts.is_flagged = 1 OR replies.is_flagged = 1)' if conditions[:flagged_only] }
          #{ "AND posts.content LIKE '%#{self.sanitize(conditions[:query],{:no_wrap=>true})}%'" if !conditions[:query].nil? }
          GROUP BY posts.id
          ORDER BY posts.created_at DESC
        ) X
      "
      result = self.connection.exec_query(posts_sql)
      return result.first['count'].to_s
    end

    # get top posts, all of the various conditions are applied here
    posts_sql = "
      SELECT
      posts.id, posts.content, posts.photo, posts.is_flagged, posts.flagged_by, posts.created_at, posts.user_id, posts.wallable_id#{ ', popularity.score' if conditions[:by_popularity]}
      FROM
      posts
    "
    if !conditions[:location_ids].empty? || !conditions[:user_ids].empty?
      posts_sql = posts_sql + " JOIN users ON users.id = posts.user_id "
      posts_sql = posts_sql + " AND ( users.location_id IN (#{conditions[:location_ids].join(',')}) OR users.top_level_location_id IN (#{conditions[:location_ids].join(',')}) )" if !conditions[:location_ids].empty?
      posts_sql = posts_sql + " AND users.id IN (#{conditions[:user_ids].join(',')}) " if !conditions[:user_ids].empty?
    end
    if conditions[:flagged_only]
      posts_sql = posts_sql + " LEFT JOIN posts replies ON replies.parent_post_id = posts.id"
    end
    if conditions[:by_popularity]
      posts_sql = posts_sql + "
        JOIN (
          SELECT
          posts.id, ( (#{Post::POPULARITY_SCORE[:replies]} * COUNT(DISTINCT(replies.id))) + (#{Post::POPULARITY_SCORE[:likes]} * COUNT(DISTINCT(likes.id))) + (#{Post::POPULARITY_SCORE[:reply_likes]} * COUNT(DISTINCT(reply_likes.id)))) score
          FROM posts
          LEFT JOIN posts replies ON replies.parent_post_id = posts.id
          LEFT JOIN likes ON likes.likeable_type = 'Post' AND likes.likeable_id = posts.id
          LEFT JOIN likes reply_likes ON reply_likes.likeable_type = 'Post' AND reply_likes.likeable_id = replies.id
          WHERE
          posts.parent_post_id IS NULL AND posts.wallable_id = #{wall.id} AND posts.wallable_type = '#{wall.class.to_s}'
          GROUP BY posts.id
        ) popularity ON popularity.id = posts.id
      "
    end
    posts_sql = posts_sql + "
      WHERE
      posts.parent_post_id IS NULL AND posts.wallable_id = #{wall.id} AND posts.wallable_type = '#{wall.class.to_s}'
      #{ 'AND posts.photo IS NOT NULL' if conditions[:has_photo] }
      #{ 'AND (posts.is_flagged = 1 OR replies.is_flagged = 1)' if conditions[:flagged_only] }
      #{ "AND posts.content LIKE '%#{self.sanitize(conditions[:query],{:no_wrap=>true})}%'" if !conditions[:query].nil? }
      GROUP BY posts.id
      ORDER BY #{conditions[:by_popularity] ? 'popularity.score DESC' : 'posts.created_at DESC'}
      LIMIT #{conditions[:offset]}, #{conditions[:limit]}
    "

    # grab replies..
    result = self.connection.exec_query(posts_sql)
    posts = []
    result.each{|row|
      post = {}
      post['photo']        = {}
      post['id']           = row['id']
      post['content']      = row['content']
      post['photo']['url'] = row['photo'].nil? ? PostPhotoUploader::default_url : PostPhotoUploader::asset_host_url + row['photo'].to_s
      post['is_flagged']   = row['is_flagged']
      post['flagged_by']   = row['flagged_by']
      post['created_at']   = row['created_at']
      post['user_id']      = row['user_id']
      post['wallable_id']  = row['wallable_id']
      post['score']        = row['score'] if conditions[:by_popularity]
      posts << post
    }

    return [] if posts.empty? # this is a rather important line

    replies_sql = "
      SELECT
      posts.id, posts.content, posts.photo, posts.is_flagged, posts.flagged_by, posts.created_at, posts.user_id, posts.parent_post_id
      FROM
      posts
      WHERE
      parent_post_id IN (#{posts.collect{|p|p['id']}.join(',')})
      ORDER BY created_at ASC
    "
    result = self.connection.exec_query(replies_sql)
    replies = []
    result.each{|row|
      reply = {}
      reply['photo']          = {}
      reply['id']             = row['id']
      reply['content']        = row['content']
      reply['photo']['url']   = row['photo'].nil? ? PostPhotoUploader::default_url : PostPhotoUploader::asset_host_url + row['photo'].to_s
      reply['is_flagged']     = row['is_flagged']
      reply['flagged_by']     = row['flagged_by']
      reply['created_at']     = row['created_at']
      reply['user_id']        = row['user_id']
      reply['parent_post_id'] = row['parent_post_id']
      replies << reply
    }

    # grab likes of posts and replies..
    likes_sql = "
      SELECT
      likes.id, likes.user_id, likes.likeable_id
      FROM likes
      WHERE
      likeable_type = 'Post' AND likeable_id IN (#{(posts.collect{|p|p['id']} + replies.collect{|r|r['id']}).join(',')})
    "
    result = self.connection.exec_query(likes_sql)
    likes = []
    result.each{|row|
      like = {}
      like['id']          = row['id']
      like['user_id']     = row['user_id']
      like['likeable_id'] = row['likeable_id']
      likes << like
    }

    # grab users of posts, replies and likes..
    users_sql = "
      SELECT
      users.id AS user_id, profiles.id AS profile_id, profiles.first_name, profiles.last_name, profiles.image,
      locations.id AS location_id, locations.name AS location_name
      FROM users
      JOIN profiles ON profiles.user_id = users.id
      LEFT JOIN locations ON locations.id = users.location_id
      WHERE users.id IN (#{( posts.collect{|p|p['user_id']} + replies.collect{|r|r['user_id']} + likes.collect{|l|l['user_id']} ).join(',')})
    "
    result = self.connection.exec_query(users_sql)
    users = []
    users_idx = {}
    result.each{|row|
      user = {}
      user['id']                      = row['user_id']
      user['profile']                 = {}
      user['profile']['image']        = {}
      user['location']                = {}
      user['profile']['id']           = row['profile_id']
      user['profile']['first_name']   = row['first_name']
      user['profile']['last_name']    = row['last_name']
      user['profile']['image']['url'] = row['image'].nil? ? ProfilePhotoUploader::default_url : ProfilePhotoUploader::asset_host_url + row['image'].to_s
      user['location_id']             = row['location_id']
      user['location']['id']          = row['location_id']
      user['location']['name']        = row['location_name']

      users_idx[row['user_id']] = user

      users << user
    }

    # attaching users to likes..
    likes.each_with_index{|like, index|
      likes[index]['user'] = users_idx[like['user_id']]
    }

    # attaching likes and users to replies..
    replies.each_with_index{|reply, index|
      replies[index]['user'] = users_idx[reply['user_id']]
      replies[index]['likes'] = likes.select{|like|like['likeable_id'] == reply['id']}
    }

    # attaching likes, users and replies to posts..
    posts.each_with_index{|post, index|
      posts[index]['user'] = users_idx[post['user_id']]
      posts[index]['likes'] = likes.select{|like|like['likeable_id'] == post['id']}
      posts[index]['posts'] = replies.select{|reply|reply['parent_post_id'] == post['id']}
    }

    # all done!
    return posts
  end

  def is_wall_expert_dashboard_post?
    return self.wallable && self.wallable.class == Promotion && self.wallable.is_dashboard? && self.user.poster? && self.parent_post_id.nil? && self.root_post_id.nil?
  end

  def clone_wall_expert_post
    return unless self.is_wall_expert_dashboard_post?
    Promotion.active.each{ |p|
      next if p.is_dashboard? # Promotion.active SHOULD exclude dashboard but just in case, we don't need any infinite loops
      post = self.dup
      post.wallable_id = p.id
      post.source_id = self.id
      post.save!
    }
  end

  def update_wall_expert_post
    return unless self.is_wall_expert_dashboard_post?
    posts = Post.where(:source_id => self.id)
    posts.each{ |p|
      p.is_flagged = self.is_flagged
      p.is_deleted = self.is_deleted
      p.content = self.content
      p.title = self.title
      p.save!
    }
  end

  def destroy_wall_expert_post
    return unless self.is_wall_expert_dashboard_post?
    posts = Post.where(:source_id => self.id)
    posts.each{ |p|
      p.destroy
    }
  end

  def score
    likes_score = Post::POPULARITY_SCORE[:likes] * self.likes.count
    reply_score = Post::POPULARITY_SCORE[:replies] * self.posts.count
    reply_likes_score = Post::POPULARITY_SCORE[:reply_likes] * self.posts.collect{|r|r.likes.count}.sum + self.likes.count
    return (likes_score + reply_score + reply_likes_score)
  end

end
