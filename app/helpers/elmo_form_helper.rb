# makes a standard looking form
module ElmoFormHelper

  # renders a form using the ElmoFormBuilder
  def elmo_form_for(obj, *args, &block)
    defaults = {
      builder: ElmoFormBuilder,
      html: {
        class: "#{obj.class.model_name.singular}_form elmo_form"
      }
    }

    # deep merge the user-provided options with the defaults;
    args << merge_options(defaults, args.extract_options!)

    form_for(obj, *args, &block)
  end

  # renders a set of form fields using the ElmoFormBuilder
  def elmo_fields_for(field_name, obj, *args, &block)
    defaults = {
      builder: ElmoFormBuilder
    }

    # deep merge the user-provided options with the defaults;
    args << merge_options(defaults, args.extract_options!)

    fields_for(field_name, obj, *args, &block)
  end

  # gets the mode a form should be displayed in: one of new, edit, or show
  def form_mode
    {new: :new, create: :new, show: :show}[controller.action_name.to_sym] || :edit
  end

  # Tests if form_mode == :show. Note that some the ElmoFormBuilder overrides form_mode when rendering custom partials
  # using the :partial directive. This is also why a ? is not used as a suffix.
  def read_only
    form_mode == :show
  end

  # renders the standard 'required' symbol, which is an asterisk
  def reqd_sym
    content_tag(:div, "*", class: "reqd-sym")
  end

  private

  def merge_options(defaults, options)
    defaults.deep_merge(options) do |key,oldval,newval|
      # if the key is :class, merge the old and new values into a space-separated list
      key == :class ? "#{oldval} #{newval}" : newval
    end
  end
end
