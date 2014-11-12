class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.references  :promotion, :location, :top_level_location, :organization, :reseller, :map
      t.string      :role,                                            :limit => 50
      t.string      :password,                                        :limit => 50
      t.string      :auth_key,                                        :limit => 255
      t.string      :sso_identifier,                                  :limit => 100
      t.boolean     :allows_email,                                    :default => true
      t.datetime    :last_login
      
      t.timestamps
    end
  end
end
