class CryptosController < ApplicationController
  include AccountableResource

  permitted_accountable_attributes :symbol

end
