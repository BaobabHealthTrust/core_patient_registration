# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

	def get_global_property_value(global_property)
		property_value = Settings[global_property]
		if property_value.nil?
			property_value = GlobalProperty.find(:first, :conditions => {:property => "#{global_property}"}
      ).property_value rescue nil
		end
		return property_value
	end

  def show_intro_text
    get_global_property_value("show_intro_text").to_s == "true" rescue false
  end

  def show_middle_name
    get_global_property_value("show_middle_name").to_s == "true" rescue false
  end

  def  show_maiden_name
    get_global_property_value("show_maiden_name").to_s == "true" rescue false
  end

  def  show_birthyear
    get_global_property_value("show_birthyear").to_s == "true" rescue false
  end

  def  show_birthmonth
    get_global_property_value("show_birthmonth").to_s == "true" rescue false
  end

  def  show_birthdate
    get_global_property_value("show_birthdate").to_s == "true" rescue false
  end

  def  show_age
    get_global_property_value("show_age").to_s == "true" rescue false
  end

  def  show_region_of_origin
    get_global_property_value("show_region_of_origin").to_s == "true" rescue false
  end

  def  show_district_of_origin
    get_global_property_value("show_district_of_origin").to_s == "true" rescue false
  end

  def  show_t_a_of_origin
    get_global_property_value("show_t_a_of_origin").to_s == "true" rescue false
  end

  def  show_home_village
    get_global_property_value("show_home_village").to_s == "true" rescue false
  end

  def  show_current_region
    get_global_property_value("show_current_region").to_s == "true" rescue false
  end

  def  show_current_district
    get_global_property_value("show_current_district").to_s == "true" rescue false
  end

  def  show_current_t_a
    get_global_property_value("show_current_t_a").to_s == "true" rescue false
  end

  def  show_current_village
    get_global_property_value("show_current_village").to_s == "true" rescue false
  end

  def  show_current_landmark
    get_global_property_value("show_current_landmark").to_s == "true" rescue false
  end

  def  show_cell_phone_number
    get_global_property_value("show_cell_phone_number").to_s == "true" rescue false
  end

  def  show_office_phone_number
    get_global_property_value("show_office_phone_number").to_s == "true" rescue false
  end

  def  show_home_phone_number
    get_global_property_value("show_home_phone_number").to_s == "true" rescue false
  end

  def  show_occupation
    get_global_property_value("show_occupation").to_s == "true" rescue false
  end

  def month_name_options(selected_months = [])
    i=0
    options_array = [[]] +Date::ABBR_MONTHNAMES[1..-1].collect{|month|[month,i+=1]} + [["Unknown","Unknown"]]
    options_for_select(options_array, selected_months)
  end

    def ask_home_address

    return false if session[:request_params].blank?

    eval(["Home of Origin", "Home District",
        "Home Village"].collect{|k| (session[:request_params][k] || "false")}.join(" || "))
  end

  def ask_current_address

    return false if session[:request_params].blank?

    eval(["Current T/A", "Current District",
        "Current Village"].collect{|k|
        (session[:request_params][k] || "false")}.join(" || "))
  end

  def ask_cell_phone_number

    return false if session[:request_params].blank?

    eval(["Cell Phone Number"].collect{|k|
        (session[:request_params][k] || "false")}.join(" || "))
  end

  def ask_home_phone_number

    return false if session[:request_params].blank?

    eval(["Home Phone Number"].collect{|k|
        (session[:request_params][k] || "false")}.join(" || "))
  end

  def ask_office_phone_number

    return false if session[:request_params].blank?

    eval(["Office Phone Number"].collect{|k|
        (session[:request_params][k] || "false")}.join(" || "))
  end

  def ask_landmark

    return false if session[:request_params].blank?

    eval(["Landmark or Plot"].collect{|k|
        (session[:request_params][k] || "false")}.join(" || "))
  end

  def ask_middle_name

    return false if session[:request_params].blank?

    eval(["Middle Name"].collect{|k|
        (session[:request_params][k] || "false")}.join(" || "))
  end

  def ask_maiden_name

    return false if session[:request_params].blank?

    eval(["Maiden Name"].collect{|k|
        (session[:request_params][k] || "false")}.join(" || "))
  end

  def ask_occupation

    eval(["Occupation"].collect{|k|
        (session[:request_params][k] || "false")}.join(" || "))
  end
  
end
