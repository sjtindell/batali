require 'batali'
require 'digest/sha2'
require 'securerandom'
require 'http'
require 'fileutils'

module Batali
  class Origin
    # Fetch unit information from remote site
    class RemoteSite < Origin

      # Site suffix for API endpoint
      COOKBOOK_API_SUFFIX = 'api/v1/cookbooks'

      include Bogo::Memoization

      attribute :name, String
      attribute :identifier, String
      attribute :endpoint, String, :required => true
      attribute :force_update, [TrueClass, FalseClass], :required => true, :default => false
      attribute :update_interval, Integer, :required => true, :default => 10000 # NOTE: reset this default to 60/120 when ready
      attribute :cache, String, :default => File.expand_path('~/.batali/cache/remote_site'), :required => true

      def initialize(*_)
        super
        endpoint = URI.join(self.endpoint, COOKBOOK_API_SUFFIX).to_s
        self.identifier = Digest::SHA256.hexdigest(endpoint)
        unless(name?)
          self.name = self.identifier
f        end
      end

      # @return [String] cache directory path
      def cache_directory
        memoize(:cache_directory) do
          path = File.join(cache, identifier)
          FileUtils.mkdir_p(path)
          path
        end
      end

      # @return [Array<Unit>] all units
      def units
        memoize(:units) do
          items.map do |u_name, versions|
            versions.map do |version, info|
              Unit.new(
                :name => u_name,
                :version => version,
                :dependencies => info[:dependencies].to_a,
                :source => Smash.new(
                  :type => :site,
                  :url => info[:download_url],
                  :version => version,
                  :dependencies => info[:dependencies]
                )
              )
            end
          end.flatten
        end
      end

      protected

      # @return [Smash] all info
      def items
        memoize(:items) do
          MultiJson.load(File.read(fetch)).to_smash
        end
      end

      # Fetch the universe
      #
      # @return [String] path to universe file
      def fetch
        do_fetch = true
        if(File.exists?(universe_path))
          age = Time.now - File.mtime(universe_path)
          if(age < update_interval)
            do_fetch = false
          end
        end
        if(do_fetch)
          t_uni = "#{universe_path}.#{SecureRandom.urlsafe_base64}"
          File.open(t_uni, 'w') do |file|
            file.write HTTP.get(URI.join(endpoint, 'universe')).body.to_s
          end
          FileUtils.mv(t_uni, universe_path)
        end
        universe_path
      end

      # @return [String] path to universe file
      def universe_path
        File.join(cache_directory, 'universe.json')
      end

    end
  end
end
