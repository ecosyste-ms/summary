class ApplicationController < ActionController::Base
  skip_forgery_protection
  include Pagy::Backend
end
