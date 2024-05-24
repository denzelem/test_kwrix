module Kwrix
  class Configuration
    include Singleton

    attr_reader :secrets

    def initialize
      @secrets = build_secrets
    end

    private

    def build_secrets
      YAML.safe_load(File.read(Kwrix.root.join('secrets.yml'))).each_with_object(ActiveSupport::OrderedOptions.new) do |(key, value), options|
        options.public_send("#{key}=", value)
      end
    end
  end
end
