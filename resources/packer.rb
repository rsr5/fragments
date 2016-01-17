resource_name :datasift_machine_packer

action :pack do
  converge_by(
    "Packed #{::Chef.node.run_state['machine-fragments'].size} "\
    "fragments with '#{MachinePacker.get.class.name}'") do
    MachinePacker.get.pack
  end
end

action :verify do
  converge_by("Verified #{MachinePacker.get.fragments.size} fragments") do
    MachinePacker.get.verify_dependencies
  end
end
