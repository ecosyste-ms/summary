module ApplicationHelper
  include Pagy::Frontend

  def meta_title
    [@meta_title, 'Ecosyste.ms: Summary'].compact.join(' | ')
  end

  def meta_description
    @meta_description || 'An open API service for producing an overview of a list of open source projects.'
  end

  def obfusticate_email(email)
    return unless email
    email.split('@').map do |part|
      # part.gsub(/./, '*') 
      part.tap { |p| p[1...-1] = "****" }
    end.join('@')
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
