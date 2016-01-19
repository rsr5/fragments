# Represents one machine fragment and provides functionality to serialise
# and de-serialise
class Fragment
  attr_accessor :name, :run_list, :attributes, :memory_weight,
                :required_fragments, :every_node, :cardinality, :berkshelf,
                :host_aliases, :machine_files, :machine_commands, :tags,
                :avoid_tags, :group_with_tags, :flavor_id

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def self.from_resource(fragment_resource)
    fragment = Fragment.new
    fragment.name = fragment_resource.name
    fragment.run_list = fragment_resource.run_list
    fragment.attributes = fragment_resource.attributes
    fragment.memory_weight = fragment_resource.memory_weight
    fragment.required_fragments = fragment_resource.required_fragments
    fragment.every_node = fragment_resource.every_node
    fragment.cardinality = fragment_resource.cardinality
    fragment.berkshelf = fragment_resource.berkshelf
    fragment.host_aliases = fragment_resource.host_aliases
    fragment.machine_files = fragment_resource.machine_files
    fragment.machine_commands = fragment_resource.machine_commands
    fragment.tags = fragment_resource.tags
    fragment.avoid_tags = fragment_resource.avoid_tags
    fragment.group_with_tags = fragment_resource.group_with_tags
    fragment.flavor_id = fragment_resource.flavor_id
    fragment
  end

  def self.from_hash(hash)
    fragment = Fragment.new
    fragment.name = hash['name']
    fragment.run_list = hash['run_list']
    fragment.attributes = hash['attributes']
    fragment.memory_weight = hash['memory_weight']
    fragment.required_fragments = hash['required_fragments']
    fragment.every_node = hash['every_node']
    fragment.cardinality = hash['cardinality']
    fragment.berkshelf = hash['berkshelf']
    fragment.host_aliases = hash['host_aliases']
    fragment.machine_files = hash['machine_files']
    fragment.machine_commands = hash['machine_commands']
    fragment.tags = hash['tags']
    fragment.avoid_tags = hash['avoid_tags']
    fragment.group_with_tags = hash['group_with_tags']
    fragment.flavor_id = hash['flavor_id']
    fragment
  end

  def to_hash
    {
      name: @name,
      run_list: @run_list,
      attributes: @attributes,
      memory_weight: @memory_weight,
      required_fragments: @required_fragments,
      every_node: @every_node,
      cardinality: @cardinality,
      berkshelf: @berkshelf,
      host_aliases: @host_aliases,
      machine_files: @machine_files,
      machine_commands: @machine_commands,
      tags: @tags,
      avoid_tags: @avoid_tags,
      group_with_tags: @group_with_tags,
      flavor_id: @flavor_id
    }
  end

  # Returns the berkshelf hash with strings for the keys.
  def normalised_berkshelf
    Hash[berkshelf.map { |k, v| [k.to_s, v] }]
  end
end
