class Condition < ApplicationRecord
  include MissionBased, FormVersionable, Replication::Replicable

  acts_as_paranoid

  # question types that cannot be used in conditions
  NON_REFABLE_TYPES = %w(location image annotated_image signature sketch audio video)

  belongs_to :questioning, inverse_of: :condition
  belongs_to :ref_qing, class_name: "Questioning", foreign_key: "ref_qing_id",
    inverse_of: :referring_conditions
  belongs_to :option_node

  before_validation :clear_blanks
  before_validation :clean_times
  before_create :set_mission

  validate :all_fields_required
  validates :questioning, presence: true

  delegate :has_options?, :full_dotted_rank, to: :ref_qing, prefix: true
  delegate :form, :form_id, to: :questioning

  OPERATORS = [
    {name: 'eq', types: %w(decimal integer counter text long_text address select_one datetime date time),
      code: "="},
    {name: 'lt', types: %w(decimal integer counter datetime date time), code: "<"},
    {name: 'gt', types: %w(decimal integer counter datetime date time), code: ">"},
    {name: 'leq', types: %w(decimal integer counter datetime date time), code: "<="},
    {name: 'geq', types: %w(decimal integer counter datetime date time), code: ">="},
    {name: 'neq', types: %w(decimal integer counter text long_text address select_one datetime date time),
      code: "!="},
    {name: 'inc', types: %w(select_multiple), code: "="},
    {name: 'ninc', types: %w(select_multiple), code: "!="}
  ]

  replicable backward_assocs: [:questioning, :ref_qing, {name: :option_node, skip_obj_if_missing: true}],
    dont_copy: [:ref_qing_id, :questioning_id, :option_node_id]

  # We accept a list of OptionNode IDs as a way to set the option_node association.
  # This is useful for forms, etc. We just pluck the last non-blank ID off the end.
  # If all are blank, we set the association to nil.
  def option_node_ids=(ids)
    self.option_node_id = ids.reverse.find(&:present?)
  end

  def options
    option_nodes.map(&:option)
  end

  def option_nodes
    option_node.nil? ? nil : option_node.ancestors[1..-1] << option_node
  end

  def option_node_path
    OptionNodePath.new(option_set: ref_qing.option_set, target_node: option_node)
  end

  # all questionings that can be referred to by this condition
  def refable_qings
    questioning.previous.reject{|qing| NON_REFABLE_TYPES.include?(qing.qtype_name)}
  end

  # returns names of all operators that are applicable to this condition based on its referred question
  def applicable_operator_names
    ref_qing ? OPERATORS.select{|o| o[:types].include?(ref_qing.qtype_name)}.map{|o| o[:name]} : []
  end

  # Gets the definition of self's operator (self.op).
  def operator
    @operator ||= OPERATORS.detect{|o| o[:name] == op}
  end

  # Generates a human readable representation of condition.
  # prefs[:include_code] - Includes the question code in the string. May not always be desireable e.g. with printable forms.
  def to_s(prefs = {})
    if ref_qing_id.blank?
      '' # need to return something here to avoid nil errors
    else
      bits = []
      bits << Question.model_name.human
      bits << "##{ref_qing.full_dotted_rank}"
      bits << ref_qing.code if prefs[:include_code]

      if ref_qing_has_options?
        bits << option_node.level_name if ref_qing.multilevel?
        target = option_node.option_name
      else
        target = value
      end

      bits << I18n.t("condition.operators.#{op}")
      bits << (numeric_ref_question? ? target : "\"#{target}\"")
      bits.join(' ')
    end
  end

  def temporal_ref_question?
    ref_qing.try(:temporal?)
  end

  def numeric_ref_question?
    ref_qing.try(:numeric?)
  end

  # Gets the referenced Subqing.
  # If option_node is not set, returns the first subqing of ref_qing (just an alias).
  # If option_node is set, uses the depth to determine the subqing rank.
  def ref_subqing
    ref_qing.subqings[option_node.blank? ? 0 : option_node.depth - 1]
  end

  private

  def clear_blanks
    unless destroyed?
      self.value = nil if value.blank? || ref_qing && ref_qing.has_options?
    end
    return true
  end

  # Parses and reformats time strings given as conditions.
  def clean_times
    if !destroyed? && temporal_ref_question? && value.present?
      begin
        self.value = Time.zone.parse(value).to_s(:"std_#{ref_qing.qtype_name}")
      rescue ArgumentError
        self.value = nil
      end
    end
    return true
  end

  def all_fields_required
    errors.add(:base, :all_required) if any_fields_empty?
  end

  def any_fields_empty?
    ref_qing.blank? || op.blank? || (ref_qing.has_options? ? option_node_id.blank? : value.blank?)
  end

  # copy mission from questioning
  def set_mission
    self.mission = questioning.try(:mission)
  end
end
