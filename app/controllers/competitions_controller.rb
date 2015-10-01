class CompetitionsController < ApplicationController
  authorize :index, :show, :create, :update, :destroy, :master
  authorize :members, :coordinator

  def index
    return HESResponder(@promotion.competitions)
  end

  def show
    competition = Competition.find(params[:id])
    return HESResponder(competition)
  end

  def create
    competition = nil
    Competition.transaction do
      competition = Competition.create(params[:competition])
    end
    return HESResponder("Error saving competition.", "ERROR") if !competition
    return HESResponder(competition.errors.full_messages, "ERROR") if !competition.valid?
    return HESResponder(competition)
  end

  def update
    competition = Competition.find(params[:id]) rescue nil
    return HESResponder("Competition", "NOT_FOUND") if !competition
    Competition.transaction do
      competition.update_attributes(params[:competition])
    end
    return HESResponder(competition.errors.full_messages, "ERROR") if !competition.valid?
    return HESResponder(competition)
  end

  def destroy
    competition = Competition.find(params[:id]) rescue nil
    return HESResponder("Competition", "NOT_FOUND") if !competition
    Competition.transaction do
      competition.destroy
    end
    return HESResponder(competition)
  end

  def members
    competition = @promotion.competitions.find(params[:id]) rescue nil
    return HESResponder("Competition", "NOT_FOUND") if !competition
    return HESResponder(competition.members)
  end

end
