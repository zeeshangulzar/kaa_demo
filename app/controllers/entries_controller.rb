class EntriesController < ApplicationController

  authorize :all, :user
  
  # Gets the list of entries for an team instance
  #
  # @return [Array] of all entries
  #
  # [URL] /entries [GET]
  #  [200 OK] Successfully retrieved Entry Array object
  #   # Example response
  #   [{
  #    "user_id": 1,
  #    "exercise_minutes": 45,
  #    "is_logged": true
  #    "recorded_on": "2012-11-21"
  #    "notes": "Eliptical machine while reading Fitness magazine"
  #   }]
  def index
    @entries = @user.entries.available.to_a
    return HESResponder(@entries)
  end

  # Gets a single entry for a team
  #
  # @example
  #  #GET /entries/1
  #
  # @param [Integer] id of the entry
  # @return [Entry] that matches the id
  #
  # [URL] /entries/1 [GET]
  #  [200 OK] Successfully retrieved Entry object
  #   # Example response
  #   {
  #    "user_id": 1,
  #    "exercise_minutes": 45,
  #    "is_logged": true
  #    "recorded_on": "2012-11-21"
  #    "notes": "Eliptical machine while reading Fitness magazine"
  #   }
  def show
    @entry = @user.entries.find(params[:id])
    return HESResponder(@entry)
  end

  # Creates a single entry
  #
  # @example
  #  #POST /entries/1
  #  {
  #    exercise_minutes: 45,
  #    notes: "Eliptical machine while reading Fitness magazine"
  #  }
  # @return [Entry] that was just created
  #
  # [URL] /entries [POST]
  #  [201 CREATED] Successfully created Entry object
  #   # Example response
  #   {
  #    "user_id": 1,
  #    "exercise_minutes": 45,
  #    "is_logged": true
  #    "recorded_on": "2012-11-21"
  #    "notes": "Eliptical machine while reading Fitness magazine"
  #   }
  def create
    Entry.transaction do
      ex_activities = params[:entry].delete(:entry_exercise_activities) || []
      activities = params[:entry].delete(:entry_activities) || []
      @entry = @user.entries.build(params[:entry])
      @entry.save!

      #create exercise activites
      ex_activities.each do |hash|
        @entry.entry_exercise_activities.create(scrub(hash, EntryExerciseActivity))
      end

      #TODO: Test entry activities
      activities.each do |hash|
        @entry.entry_activities.create(scrub(hash, EntryActvitity))
      end

      @entry.save!
    end
    return HESResponder(@entry)
  end

  # Updates a single entry
  #
  # @example
  #  #PUT /entries/1
  #  {
  #    exercise_minutes: 45,
  #    notes: "Eliptical machine while reading Fitness magazine"
  #  }
  #
  # @param [Integer] id of the entry
  # @return [Entry] that was just updated
  #
  # [URL] /entries [PUT]
  #  [202 ACCEPTED] Successfully updated Entry object
  #   # Example response
  #   {
  #    "user_id": 1,
  #    "exercise_minutes": 45,
  #    "is_recorded": true
  #    "recorded_on": "2012-11-21"
  #    "notes": "Eliptical machine while reading Fitness magazine"
  #    "entry_activities" : [{}]
  #    "entry_exercise_activities" : [{}]
  #   }
  def update
    @entry = @user.entries.find(params[:id])
    Entry.transaction do
      entry_ex_activities = params[:entry].delete(:entry_exercise_activities)
      if !entry_ex_activities.nil?
        
        ids = entry_ex_activities.nil? ? [] : entry_ex_activities.map{|x| x[:id]}
        remove_activities = @entry.entry_exercise_activities.reject{|x| ids.include? x.id}

        remove_activities.each do |act|
          # Remove from array and delete from db
           @entry.entry_exercise_activities.delete(act).first.destroy
        end

        entry_ex_activities.each do |entry_ex_act|
          if entry_ex_act[:id]
            eea = @entry.entry_exercise_activities.detect{|x|x.id==entry_ex_act[:id].to_i}
            eea.update_attributes(scrub(entry_ex_act, EntryExerciseActivity))
          else
            @entry.entry_exercise_activities.create(scrub(entry_ex_act, EntryExerciseActivity))
          end
        end
      end

      entry_activities = params[:entry].delete(:entry_activities)
      if !entry_activities.nil?
        ids = entry_activities.nil? ? [] : entry_activities.map{|x| x.id}
        remove_activities = @entry.entry_activities.reject{|x| ids.include? x.id}

        remove_activities.each do |act|
          @entry.entry_activities.delete(act).first.destroy
        end

         entry_activities.each do |entry_act|
          if entry_act[:id]
            ea = @entry.entry_activities.detect{|x|x.id==entry_act[:id].to_i}
            ea.update_attributes(scrub(entry_act, EntryActivity))
          else
            @entry.entry_activities.create(scrub(entry_act, EntryActivity))
          end
        end
      end 

      @entry.save!
      @entry.update_attributes(scrub(params[:entry], Entry))
    end 
    return HESResponder(@entry)
  end
end