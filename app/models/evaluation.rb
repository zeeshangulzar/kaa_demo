# Models evaluations that a user completes with a set of default questions and the ability to add dynamic questions (custom prompts)
class Evaluation < ApplicationModel

  # Make all question answer fields accessible
  EvaluationQuestion.all.each do |question|
  	self.send(:attr_accessible, question.name)
  end

  attr_accessible :evaluation_definition_id

  belongs_to :user
  belongs_to :definition, :foreign_key => :evaluation_definition_id, :class_name => EvaluationDefinition

  after_create :set_next_eval

  # Makes sure evaluation questions are answered correclty
  # validates_with EvaluationValidator
  
  # Name of the evaluation definition
  # @return [String] name of the definition
  def name
  	definition.name
  end

  # Overrides serializable_hash so that only questions that are turned on are returned
  def serializable_hash(options = {})
    options = (options || {}).merge(:except => definition.flags.select{ |k, v| !v }.collect{ |x| x.first.to_s.gsub("is_", "").gsub("_displayed", "") })
  	super
  end

  def set_next_eval
    self.user.set_next_evaluation_date()
  end

  def read_attribute_for_serialization(n)
    attributes[n]
  end
end
