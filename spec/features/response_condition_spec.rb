require "spec_helper"

feature "conditions in responses", js: true do
  let(:user) { create(:user) }
  let(:form) { create(:form) }
  let(:year) { Time.now.year - 2 }

  before do
    qings # Ensure qings get created first.
    login(user)
    visit(new_response_path(locale: "en", mode: "m", mission_name: get_mission.compact_name, form_id: form.id))
    expect(page).to have_content("New Response")
  end

  describe "different question types" do
    let!(:qings) do
      {}.tap do |qings|
        qings[:long_text] = create_questioning("long_text", form)

        qings[:text1] = create_questioning("text", form, display_if: "all_met",
          display_conditions_attributes: [
            {ref_qing_id: qings[:long_text].id, op: "eq", value: "foo"}
        ])

        qings[:integer] = create_questioning("integer", form, display_if: "all_met",
          display_conditions_attributes: [
            {ref_qing_id: qings[:text1].id, op: "neq", value: "bar"}
        ])

        qings[:counter] = create_questioning("counter", form, display_if: "all_met",
          display_conditions_attributes: [
            {ref_qing_id: qings[:integer].id, op: "gt", value: "10"}
        ])

        qings[:text2] = create_questioning("text", form)

        qings[:decimal] = create_questioning("decimal", form, display_if: "all_met",
          display_conditions_attributes: [
            {ref_qing_id: qings[:counter].id, op: "gt", value: "5"}
        ])

        qings[:select_one] = create_questioning("select_one", form, display_if: "all_met",
          display_conditions_attributes: [
            {ref_qing_id: qings[:decimal].id, op: "eq", value: "21.72"}
        ])

        oset = qings[:select_one].option_set
        qings[:mlev_sel_one] = create_questioning("multilevel_select_one", form, display_if: "all_met",
          display_conditions_attributes: [
            {ref_qing_id: qings[:select_one].id, op: "eq", option_node_id: oset.node("Dog").id}
        ])

        oset = qings[:mlev_sel_one].option_set
        qings[:geo_sel_one] = create_questioning("geo_multilevel_select_one", form, display_if: "all_met",
          display_conditions_attributes: [
            {ref_qing_id: qings[:mlev_sel_one].id, op: "eq", option_node_id: oset.node("Plant", "Tulip").id}
        ])

        oset = qings[:geo_sel_one].option_set
        qings[:select_multiple] = create_questioning("select_multiple", form, display_if: "all_met",
          display_conditions_attributes: [
            {ref_qing_id: qings[:geo_sel_one].id, op: "eq", option_node_id: oset.node("Canada").id}
        ])

        oset = qings[:select_multiple].option_set
        qings[:datetime] = create_questioning("datetime", form, display_if: "all_met",
          display_conditions_attributes: [
            {ref_qing_id: qings[:select_multiple].id, op: "inc", option_node_id: oset.node("Cat").id}
        ])

        qings[:date] = create_questioning("date", form, display_if: "all_met",
          display_conditions_attributes: [
            {ref_qing_id: qings[:datetime].id, op: "lt", value: "#{year}-01-01 5:00:21"}
        ])

        qings[:time] = create_questioning("time", form, display_if: "all_met",
          display_conditions_attributes: [
            {ref_qing_id: qings[:date].id, op: "eq", value: "#{year}-03-22"}
        ])

        qings[:text3] = create_questioning("text", form, display_if: "all_met",
          display_conditions_attributes: [
            {ref_qing_id: qings[:time].id, op: "geq", value: "3:00pm"}
        ])
      end
    end

    scenario "should work" do
      visible = [:long_text, :text2]
      fill_and_expect_visible(:long_text, "fo", visible)

      # integer also becomes available here because it depends on text1 not being bar,
      # which it isn't at first, because "" != "bar"
      fill_and_expect_visible(:long_text, "foo", visible << :text1 << :integer)

      fill_and_expect_visible(:text1, "bar", visible - [:integer])
      fill_and_expect_visible(:text1, "barz", visible << :integer)
      fill_and_expect_visible(:integer, "10", visible)
      fill_and_expect_visible(:integer, "11", visible << :counter)
      fill_and_expect_visible(:counter, "5", visible)
      fill_and_expect_visible(:counter, "6", visible << :decimal)
      fill_and_expect_visible(:decimal, "21.7", visible)
      fill_and_expect_visible(:decimal, "21.72", visible << :select_one)
      fill_and_expect_visible(:select_one, "Cat", visible)
      fill_and_expect_visible(:select_one, "Dog", visible << :mlev_sel_one)
      fill_and_expect_visible(:mlev_sel_one, ["Plant"], visible)
      fill_and_expect_visible(:mlev_sel_one, ["Plant", "Oak"], visible)
      fill_and_expect_visible(:mlev_sel_one, ["Plant", "Tulip"], visible << :geo_sel_one)
      fill_and_expect_visible(:geo_sel_one, ["Ghana"], visible)
      fill_and_expect_visible(:geo_sel_one, ["Canada"], visible << :select_multiple)
      fill_and_expect_visible(:geo_sel_one, ["Canada", "Ottawa"], visible)
      fill_and_expect_visible(:select_multiple, ["Dog"], visible)
      fill_and_expect_visible(:select_multiple, ["Dog", "Cat"], visible << :datetime)
      fill_and_expect_visible(:datetime, "#{year}-01-01 5:00:21", visible)
      fill_and_expect_visible(:datetime, "#{year}-01-01 5:00:20", visible << :date)
      fill_and_expect_visible(:date, "#{year}-03-21", visible)
      fill_and_expect_visible(:date, "#{year}-03-22", visible << :time)
      fill_and_expect_visible(:time, "6:00:00", visible)
      fill_and_expect_visible(:time, "15:00:00", visible << :text3)
    end
  end

  describe "display_if logic" do
    let!(:qings) do
      {}.tap do |qings|
        qings[:q1] = create_questioning("integer", form)
        qings[:q2] = create_questioning("integer", form)
        qings[:q3] = create_questioning("integer", form, display_if: display_if,
          display_conditions_attributes: [
            {ref_qing_id: qings[:q1].id, op: "gt", value: "10"},
            {ref_qing_id: qings[:q2].id, op: "gt", value: "20"}
            ])
      end
    end

    describe "all_met" do
      let(:display_if) { "all_met" }

      scenario "should work" do
        visible = [:q1, :q2]

        fill_and_expect_visible(:q1, "10", visible)
        fill_and_expect_visible(:q2, "20", visible)

        # This satisfies the first condition but not the second, so q3 should not show yet.
        fill_and_expect_visible(:q1, "11", visible)

        # This satisfies the second condition but not the first, so q3 should still not show.
        fill_and_expect_visible(:q1, "10", visible)
        fill_and_expect_visible(:q2, "21", visible)

        # NOW it should show!
        fill_and_expect_visible(:q1, "11", visible << :q3)
      end
    end

    describe "any_met" do
      let(:display_if) { "any_met" }

      scenario "should work" do
        visible = [:q1, :q2]

        fill_and_expect_visible(:q1, "10", visible)
        fill_and_expect_visible(:q2, "20", visible)

        # Satisfy one, expect visible
        fill_and_expect_visible(:q1, "11", visible + [:q3])

        # Satisfy both, expect visible
        fill_and_expect_visible(:q2, "21", visible + [:q3])

        # Unsatisfy first one, expect still visible
        fill_and_expect_visible(:q1, "10", visible + [:q3])

        # Unsatisfy second one, expect not visible
        fill_and_expect_visible(:q2, "20", visible)
      end
    end
  end

  def fill_and_expect_visible(q, value, visible)
    fill_answer(qing: qings[q], value: value)
    expect_visible(visible)
  end

  def fill_answer(qing: nil, value: nil)
    idx = "#{qing.id}_1"
    id = "response_answers_attributes_#{idx}_value"
    case qing.qtype_name
    when "long_text"
      fill_in_ckeditor(id, with: value)
    when "select_one"
      if value.is_a?(Array)
        value.each_with_index do |o,i|
          id = "response_answers_attributes_#{idx}_#{i}_option_node_id"
          find("#response_answers_attributes_#{idx}_#{i}_option_node_id option", text: o)
          select(o, from: id)
        end
      else
        select(value, from: "response_answers_attributes_#{idx}_option_node_id")
      end
    when "select_multiple"
      qing.options.each_with_index do |o,i|
        id = "response_answers_attributes_#{idx}_choices_attributes_#{i}_checked"
        value.include?(o.name) ? check(id) : uncheck(id)
      end
    when "datetime", "date", "time"
      t = Time.parse(value)
      prefix = "response_answers_attributes_#{idx}_#{qing.qtype_name}_value"
      unless qing.qtype_name == "time"
        select(t.strftime("%Y"), from: "#{prefix}_1i")
        select(t.strftime("%B"), from: "#{prefix}_2i")
        select(t.day.to_s, from: "#{prefix}_3i")
      end
      unless qing.qtype_name == "date"
        select(t.strftime("%H"), from: "#{prefix}_4i")
        select(t.strftime("%M"), from: "#{prefix}_5i")
        select(t.strftime("%S"), from: "#{prefix}_6i")
      end
    else
      fill_in(id, with: value)
    end
  end

  def expect_visible(visible_qing_names)
    visible_qing_ids = visible_qing_names.map { |qing_name| qings[qing_name].id }
    qings.each do |key, qing|
      visible = visible_qing_ids.include?(qing.id)
      expect(page).send(visible ? :to : :not_to,
        have_css("div.answer_field[data-qing-id=\"#{qing.id}\"]", visible: true),
        "Expected #{key} #{visible ? '' : 'not '}to be visible at this point")
    end
  end
end
