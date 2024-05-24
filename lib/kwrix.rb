require 'zeitwerk'
require 'pathname'
require 'pry'
require 'yaml'
require 'active_support/all'
require 'openai'
require 'open3'
require 'timeout'

loader = Zeitwerk::Loader.new
loader.push_dir(__dir__)
loader.setup

module Kwrix
  class Error < StandardError; end

  def self.root
    Pathname.new(File.expand_path('..', __dir__))
  end
end
