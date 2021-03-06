class TeamMember < ApplicationModel
  attr_accessible :team_id, :user_id, :competition_id, :is_leader, :total_points, :total_exercise_points, :total_promotion_behavior_points, :total_competition_behavior_points, :created_at, :updated_at
  attr_privacy_path_to_user :user
  attr_privacy :id, :team_id, :user_id, :user, :any_user
  attr_privacy :total_points, :total_exercise_points, :total_promotion_behavior_points, :total_competition_behavior_points, :connections
  
  # Associations
  belongs_to :user
  belongs_to :team
  has_many :team_member_behaviors, :dependent => :destroy
  

  after_create :delete_team_invites
  after_create :delete_old_team_members
  after_create :update_points

  after_create :update_team
  after_save :update_team
  after_destroy :update_team

  # NOTE: this is not cognizant of whether the team is official, the competition is active, freezes_on_date, etc.
  # presently doing those types of checks on user.current_team()
  def update_points
    sql = "
      UPDATE team_members
      JOIN (
        SELECT
          team_members.user_id,
          SUM(COALESCE(entries.behavior_points, 0) + COALESCE(entries.exercise_points, 0) + COALESCE(team_member_behaviors.points), 0) AS total_points,
          SUM(entries.exercise_points) AS total_exercise_points,
          SUM(entries.behavior_points) AS total_promotion_behavior_points,
          SUM(team_member_behaviors.points) AS total_competition_behavior_points
        FROM team_members
        LEFT JOIN entries ON entries.user_id = team_members.user_id
        LEFT JOIN team_member_behaviors ON team_member_behaviors.team_member_id = team_members.id
        WHERE
          team_members.id = #{self.id}
          AND entries.recorded_on BETWEEN '#{self.team.competition.competition_starts_on}' AND '#{self.team.competition.competition_ends_on}'
          AND team_member_behaviors.recorded_on BETWEEN '#{self.team.competition.competition_starts_on}' AND '#{self.team.competition.competition_ends_on}'
        ) stats on stats.user_id = team_members.user_id
      SET
        team_members.total_points = COALESCE(stats.total_points, 0),
        team_members.total_exercise_points = COALESCE(stats.total_exercise_points, 0),
        team_members.total_promotion_behavior_points = COALESCE(stats.total_promotion_behavior_points, 0),
        team_members.total_competition_behavior_points = COALESCE(stats.total_competition_behavior_points, 0)
    "
    self.connection.execute(sql)
  end

  def update_team
    self.team.handle_status()
  end

  def delete_team_invites
    self.user.team_invites.each{|invite|
      invite.destroy
    }
  end

  def delete_old_team_members
    team_members = TeamMember.where("user_id = ? AND team_id <> ? AND competition_id = ?", self.user.id, self.team.id, self.team.competition.id)
    team_members.each{|team_member|
      team_member.destroy
    }
  end

end
