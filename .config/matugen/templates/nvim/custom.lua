return {
	<* if {{ is_dark_mode }} *>
	type = "dark",
	<* else *>
	type = "light",
	<* endif *>

	foreground = "{{ colors.on_surface.default.hex }}",
	background = "{{ colors.background.default.hex }}",
	red = "{{ colors.error.default.hex }}",
	green = "{{ colors.primary.default.hex }}",
	blue = "{{ colors.tertiary.default.hex }}",

	base00 = "{{ colors.background.default.hex }}",
	base01 = "{{ colors.surface_container_lowest.default.hex }}",
	base02 = "{{ colors.surface_container_low.default.hex }}",
	base03 = "{{ colors.outline_variant.default.hex }}",
	base04 = "{{ colors.on_surface_variant.default.hex }}",
	base05 = "{{ colors.on_surface.default.hex }}",
	base06 = "{{ colors.inverse_on_surface.default.hex }}",
	base07 = "{{ colors.surface_bright.default.hex }}",
	base08 = "{{ colors.error.default.hex }}",
	base09 = "{{ colors.tertiary.default.hex }}",
	base0A = "{{ colors.secondary.default.hex }}",
	base0B = "{{ colors.primary.default.hex }}",
	base0C = "{{ colors.tertiary_container.default.hex }}",
	base0D = "{{ colors.primary_container.default.hex }}",
	base0E = "{{ colors.secondary_container.default.hex }}",
	base0F = "{{ colors.error_container.default.hex }}",
}
