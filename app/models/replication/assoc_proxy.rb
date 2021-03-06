# Wraps a parent or child association in the replication.
class Replication::AssocProxy
  attr_accessor :name, :klass, :foreign_key, :target_class, :belongs_to, :type, :skip_obj_if_missing

  def self.get(klass, attribs)
    attribs = {name: attribs} if attribs.is_a?(Symbol)
    attribs[:klass] = klass
    attribs[:target_class] = attribs[:target_class_name].constantize if attribs[:target_class_name]

    @@assocs ||= {}
    if valid?(attribs)
      @@assocs[[attribs[:klass], attribs[:name]]] ||= new(attribs)
    else
      nil
    end
  end

  def self.valid?(attribs)
    attribs[:name] == :children ||
      attribs[:klass].reflect_on_association(attribs[:name]).present?
  end

  def initialize(attribs)
    attribs.each{|k,v| instance_variable_set("@#{k}", v)}

    if name == :children
      self.target_class = klass
      self.foreign_key = 'ancestry'
      self.belongs_to = false
    else
      reflection = klass.reflect_on_association(name)
      raise "Association #{name} on #{klass.name} doesn't exist." if reflection.nil?
      self.target_class = reflection.klass
      self.foreign_key = reflection.foreign_key
      self.belongs_to = reflection.belongs_to?
    end
  end

  def inspect
    "<AssocProxy name=#{name} klass=#{klass} foreign_key=#{foreign_key} target_class=#{target_class.name} type=#{type} skip=#{skip_obj_if_missing}>"
  end

  def belongs_to?
    belongs_to
  end

  def ancestry?
    foreign_key == 'ancestry'
  end
end
