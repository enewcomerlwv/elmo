# Evaluates a single condition in the responses view.
class ELMO.Views.ResponseConditionChecker extends ELMO.Views.ApplicationView

  initialize: (options) ->
    @manager = options.manager
    @condition = options.condition
    @inst = options.inst

    @rqRow = @manager.formRow(@condition.ref_qing_id, @inst)
    @rqType = @rqRow.data('qtype-name')
    @result = true

    # These handlers must be set dynamically based on rqRow.
    @rqRow.find('div.control').find('input, select, textarea').on('change', => @checkAndTell())
    @rqRow.find("div.control input[type='text']").on('keyup', => @checkAndTell())
    if @rqType == 'long_text' && !@manager.readOnly
      @ckeditorInstance().on('change', => @checkAndTell())

    @eval()

  checkAndTell: ->
    @eval()
    @manager.refresh()

  # Evaluates the condition and sets the result.
  eval: ->
    unless @rqRow.is(':visible')
      @result = false
      return

    actual = @actual()
    expected = @expected()

    # For select_one questions, the actual will be an array of selected option_node_ids.
    # We should return true if the expected option_node_id is anywhere in that list.
    # So `eq` just becomes `inc` and `neq` becomes `ninc`.
    # We could label it this way in the condition form but it seems that would be confusing.
    op = @condition.op
    if @rqType == 'select_one'
      op = 'inc' if op == 'eq'
      op = 'ninc' if op == 'neq'

    @result = switch op
      when 'eq' then @testEquality(actual, expected)
      when 'lt' then actual < expected
      when 'gt' then actual > expected
      when 'leq' then actual <= expected
      when 'geq' then actual >= expected
      when 'neq' then @testInequality(actual, expected)
      when 'inc' then actual.indexOf(expected) != -1
      when 'ninc' then actual.indexOf(expected) == -1
      else false

  # Uses a special array comparison method if appropriate.
  testEquality: (a, b) ->
    if $.isArray(a) && $.isArray(b)
      a.equalsArray(b)
    else
      a == b

  # For inequality conditions, ignore nulls for relevance test
  # unless null is the value being checked by the condition
  # improves UX for appearing/disappearing questions.
  testInequality: (refValue, expected) ->
    if $.isArray(refValue) && $.isArray(expected)
      if refValue.equalsArray([]) && !expected.equalsArray([])
        false
      else
        !refValue.equalsArray(expected)
    else
      # If you aren't checking for "not null"
      if refValue == null && expected != null
        false
      else
        refValue != expected

  # Gets the actual answer for the referred question.
  actual: ->
    # If readonly, use the data-val attrib
    if @manager.readOnly
      wrapper = @rqRow.find('div.control div.ro-val')
      if typeof(wrapper.data('val')) == 'undefined'
        wrapper.text()
      else
        wrapper.data('val')
    else
      switch @rqType
        when 'long_text'
          # Use ckeditor if available, else use textarea value (usually just on startup).
          ckeditor = @ckeditorInstance()
          content = if ckeditor then ckeditor.getData() else @rqRow.find('div.control textarea').val()

          # Strip wrapping <p> tag for comparison.
          content.trim().replace(/(^<p>|<\/p>$)/ig, '')

        when 'integer', 'decimal', 'counter'
          parseFloat(@rqRow.find("div.control input[type='text']").val())

        when 'select_one'
          # Return all selected option_node_ids.
          @rqRow.find('select').map(->
            id = $(this).val()
            if id then parseInt(id) else null
          ).get()

        when 'select_multiple'
          # Use prev sibling call to get to rails gen'd hidden field that holds the id
          @rqRow.find('div.control input:checked').map(->
            # Given a checkbox, get the value of the associated option_node_id hidden field made by rails
            # this field is the nearest prior sibling input with name attribute ending in [option_node_id].
            parseInt($(this).prevAll("input[name$='[option_node_id]']").first().val())
          ).get()

        when 'datetime', 'date', 'time'
          (new ELMO.TimeFormField(@rqRow.find('div.control'))).extract_str()

        else
          @rqRow.find("div.control input[type='text']").val()

  # Gets the expected answer from the condition definition.
  expected: ->
    switch @rqType
      when 'integer', 'decimal', 'counter' then parseFloat(@condition.value)
      when 'select_one', 'select_multiple' then @condition.option_node_id
      else @condition.value

  ckeditorInstance: ->
    return CKEDITOR.instances[@rqRow.find("div.control textarea").attr('id')]
