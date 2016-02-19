
default['fragments']['resource_name'] = nil

default['fragments']['chef-zero-root'] = nil

# Configures a packer to output extra debugging information if it provides
# the facility
default['fragments']['enable-packer-debugging'] = false

# The default environment
default['fragments']['default_environment'] = '_default'

# A hash of extra user defined flavors.
default['fragments']['extra_flavors'] = {}

# A hash of extra machine options that should always be applied
default['fragments']['machine_options'] = {}
