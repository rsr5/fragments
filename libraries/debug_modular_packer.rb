
require 'chef/mixin/template'

include Chef::Mixin::Template
include Fragments::DSL

# Debug probes for the modular packer
module DebugModularPackerMixin
  # Debugging probe that is called when the packing process begins
  def packing_started
    @report = ''
    @fragment = ''
  end

  # Debugging probe that is called when the packing provess is finished
  def packing_finished
    return unless ::Chef.node['fragments']['enable-packer-debugging']
    ::File.open(chef_root('modular_packer_debug.html'), 'w+') do |fp|
      fp.write(render_template('report.html.erb', report: @report))
    end
  end

  # Debugging probe that may be used by packers.  Called when a filter
  # has been applied to a list of virtual machines.  It is required that
  # the list of machines returned by the filter is also returned here.
  def applied_filter(fragment, filter, machines)
    return machines unless ::Chef.node['fragments']['enable-packer-debugging']
    @fragment += render_template(
      'applied_filter.html.erb',
      filter: filter,
      machines: machines,
      fragment: fragment
    )
    machines
  end

  # Debugging probe that may be used by packers.  Called when a packer
  # calculates that a new virtual machine is required.  It is required that
  # the machine object is returned here.
  def created_machine(machine)
    return machine unless ::Chef.node['fragments']['enable-packer-debugging']
    @fragment += render_template(
      'placed_fragment.html.erb',
      message: 'Created',
      machine: machine
    )
    end_fragment
    machine
  end

  # Debugging probe that may be used by packers.  Called once a packer
  # has found a suitable machine to place the fragment in.
  def placed_fragment(machine)
    return unless ::Chef.node['fragments']['enable-packer-debugging']
    @fragment += render_template(
      'placed_fragment.html.erb',
      message: 'Placed in',
      machine: machine
    )
    end_fragment
  end

  # Debugging probe that may be used by packers.  Called just before
  # a fragment is going to be packed
  def beginning_to_pack_fragment(fragment, _index)
    return unless ::Chef.node['fragments']['enable-packer-debugging']
    require 'awesome_print'
    install_awesome_print
    @fragment += render_template(
      'fragment.html.erb',
      fragment: fragment
    )
  end

  private

  def install_awesome_print
    chef_gem = Chef::Resource::ChefGem.new('awesome_print',
                                           ::Chef.node.run_context)
    chef_gem.run_action(:install)
  end

  def end_fragment
    @report += render_template('end_fragment.html.erb', fragment: @fragment)
    @fragment = ''
  end

  def render_template(source, variables)
    context = TemplateContext.new(variables)
    context[:node] = ::Chef.node
    template_location = ::Chef::Provider::TemplateFinder.new(
      ::Chef.node.run_context, 'fragments', ::Chef.node
    ).find(source)

    context.render_template(template_location)
  end
end
