require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::HetznerAgent do
  before(:each) do
    @valid_options = Agents::HetznerAgent.new.default_options
    @checker = Agents::HetznerAgent.new(:name => "HetznerAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
