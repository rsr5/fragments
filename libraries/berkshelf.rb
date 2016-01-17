
require 'berkshelf'

module Berkshelf
  # Get access to the Berkshelf output system.
  class ProvisioningFormatter < HumanFormatter
    def self.provider(provider)
      @@provider = provider # rubocop:disable Style/ClassVars
    end

    def install(source, cookbook)
      message = "Installing #{cookbook.name} (#{cookbook.version})"

      unless source.default?
        message << " from #{source}"
        message << " ([#{cookbook.location_type}] #{cookbook.location_path})"
      end

      @@provider.converge_by(message) {}
    end

    def fetch(dependency)
      @@provider.converge_by(
        "Fetching '#{dependency.name}' from #{dependency.location}"
      ) {}
    end

    def uploaded(cookbook, conn)
      @@provider.converge_by(
        "Uploaded #{cookbook.cookbook_name} (#{cookbook.version}) "\
        "to: '#{conn.server_url}'"
      ) {}
    end

    def skipping(cookbook, _)
      @@provider.converge_by(
        "Skipping #{cookbook.cookbook_name} (#{cookbook.version}) (frozen)"
      ) {}
    end

    def use(dependency)
      message =  "Using #{dependency.name} (#{dependency.locked_version})"
      message << " from #{dependency.location}" if dependency.location
      @@provider.converge_by(message) {}
    end
  end
end

module Fragments
  module Packers
    # Encapsulates all of the functionality needed to extrapolate the Berksfile
    # needed for a set of machine_fragment resources.
    class Berkshelf
      require_relative 'dsl.rb'
      include ::Fragments::DSL

      def initialize(packer)
        @packer = packer
      end

      # Retrieves a role by name from the Chef server and returns any recipes
      # in it's run_list
      def recipe_from_role(name)
        role = Chef::Search::Query.new.search(:role, "name:#{name}")[0][0]
        run_list = role.env_run_list[chef_environment]
        run_list.select { |rli| rli.type == :recipe }.map(&:name)
      end

      # Returns all of the recipes needed by a packer including any mentioned
      # in roles in the run_list.
      def recipes
        @packer.recipes + @packer.roles.map { |r| recipe_from_role(r) }.flatten
      end

      # Returns the list of cookbooks needed by a packer
      def cookbooks
        cookbooks = recipes.map { |r| [r.split('::')[0], {}] }.uniq.sort
        # Merge the raw cookbook information with the extra berkshelf options
        # passed to the fragment resources.
        Hash[cookbooks].merge(
          @packer.fragments.map(&:normalised_berkshelf).reduce({}, :merge)
        )
      end
    end
  end
end
