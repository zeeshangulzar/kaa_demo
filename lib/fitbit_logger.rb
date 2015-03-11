class FitbitLogger
  
  def self.update_entry(entry, fbu, fds, write_to_log = false)
    if !entry.manually_recorded
      entry.update_attributes(:exercise_steps => fds.steps)
      entry.updated_at = Time.now.utc 

      if entry.save
        log "- updated Entry##{entry.id} on: #{entry.recorded_on}; steps is now #{fds.steps}", 2 if write_to_log
        $redis.publish('fitbitEntrySaved', entry.to_json)
      else
        log "- FALSE returned when updating Entry##{entry.id} on: #{entry.recorded_on}", 2 if write_to_log
      end

      self.send_notifications(fbu, fds, write_to_log)
    else
      log "- not updating Entry##{entry.id} on: #{entry.recorded_on}; marked as manually recorded", 2 if write_to_log
    end
  end

  def self.create_entry(fbu, fds, write_to_log = false)
    entry = fbu.user.entries.build(:recorded_on => fds.reported_on)
    entry.exercise_steps = fds.steps

    if entry.save
      log "- Created new entry (#{entry.id}) for User##{fbu.user.id}", 2 if write_to_log
      # not sure why passport required a double-save... assuming GoKP does not
      #self.update_entry(entry, act, fbu, fds, write_to_log)
    else
      log "- FALSE returned when creating new entry for User##{fbu.user.id}", 2 if write_to_log
    end
    entry
  end

  def self.send_notifications(fbu, fds, write_to_log)
    log "- sending notifications", 2 if write_to_log

    # Find the user's Fitbit notification.
    user_notification = fbu.user.notifications.find_by_key('FITBIT')
    
    # Date and time Fitbit data was synced.
    dt = fbu.user.promotion.current_date.strftime("%B %e")
    tm = fbu.user.promotion.current_time.strftime("%I:%M %P %Z").gsub(/^0/, '')

    # Send the user a notification saying that their Fitbit data has been synced.
    if user_notification
      log "- Updated Notification##{user_notification.id} for #{fbu.user.email}", 2 if write_to_log
      user_notification.update_attributes(:message => "Your Fitbit data was synchronized with GoKP on #{dt} at #{tm}")
    else
      log "- Created FITBIT notification for #{fbu.user.email}", 2 if write_to_log
      fbu.user.notifications.create(:key => 'FITBIT', :title => "Fitbit Data Synced", :message => "Your Fitbit data was synchronized with GoKP on #{dt} at #{tm}")
    end

    # # Send the user a notification about the activity's cap value.
    # if act.cap_value && act.cap_value > 0 && fds.steps > act.cap_value
    #   cap_notification = fbu.user.notifications.find_by_key('FITBIT-CAP')

    #   # No need to create another one.
    #   unless cap_notification
    #     fbu.user.notifications.create(:key => 'FITBIT-CAP', :title => "Activity Cap", :message => act.cap_message)
    #   end
    # end
  end

  def self.log(s, indent = 1)
    msg = "#{Time.now} #{'  ' * indent}#{s}"
    File.open("#{Rails.root}/log/fitbit_import_control.log", "a") {|f| f.puts msg}
  end
end