module ApplicationHelper
  include Pagy::Frontend

  def meta_title
    [@meta_title, 'Ecosyste.ms: Summary'].compact.join(' | ')
  end

  def meta_description
    @meta_description || 
  end

  def app_name
    "Summary"
  end

  def app_description
    'An open API service for producing an overview of a list of open source projects.'
  end

  def obfusticate_email(email)
    return unless email
    email.split('@').map do |part|
      part.tap { |p| p[1...-1] = "****" }
    end.join('@')
  end

  def pretty_print_hash(hash)
    content_tag(:ul) do
      hash.map do |key, value|
        content_tag(:li) do
          humanized_key = key.to_s.underscore.humanize
          if value.is_a?(Hash)
            "#{humanized_key}: #{pretty_print_hash(value)}".html_safe
          elsif value.is_a?(Array)
            "#{humanized_key}: #{pretty_print_array(value)}".html_safe
          else
            "#{humanized_key}: #{value}".html_safe
          end
        end
      end.join.html_safe
    end
  end
  
  def pretty_print_array(array)
    content_tag(:ul) do
      array.map do |value|
        content_tag(:li) do
          if value.is_a?(Hash)
            pretty_print_hash(value).html_safe
          elsif value.is_a?(Array)
            pretty_print_array(value).html_safe
          else
            value.to_s.html_safe
          end
        end
      end.join.html_safe
    end
  end

  def distance_of_time_in_words_if_present(time)
    return 'N/A' unless time
    distance_of_time_in_words(time)
  end

  def rounded_number_with_delimiter(number)
    return 0 unless number
    number_with_delimiter(number.round(2))
  end
end
