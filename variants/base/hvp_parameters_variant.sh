# Set default parameters

variant_type="Base"
variant_version="2024120801"

# Packages and kernel arguments to be removed/replaced/added

# Units to be masked/disabled/enabled

# Custom parameters
# Note: since these are evaluated after the usual embedded values, we take care of setting them only if undefined above

# Define pre and post hook functions

function pre_install_hook_custom_actions() {
	echo "pre_install_hook_custom_actions function for variant ${variant_type} version ${variant_version} starting"

	# Note: network-related parameters demanded to post_install_hook_custom_actions to let the built-in network autoconfiguration happen first
	echo "pre_install_hook_custom_actions function for variant ${variant_type} version ${variant_version} exiting"
}

function post_install_hook_custom_actions() {
	echo "post_install_hook_custom_actions function for variant ${variant_type} version ${variant_version} starting"
	# Extract kernel commandline parameters

	# Define settings

	# Generate dynamic configuration files

	echo "post_install_hook_custom_actions function for variant ${variant_type} version ${variant_version} exiting"
}

