## Colorlight i9plus-v6.1 XDC Constraints
## Part: XC7A50T-FGG484

# ==============================================================================
# Clock: 25MHz on pin K4
# ==============================================================================
set_property PACKAGE_PIN K4 [get_ports clk_i]
set_property IOSTANDARD LVCMOS33 [get_ports clk_i]
create_clock -period 40.000 -name clk_25mhz [get_ports clk_i]

# ==============================================================================
# LED
# ==============================================================================
set_property PACKAGE_PIN A18 [get_ports led_o]
set_property IOSTANDARD LVCMOS33 [get_ports led_o]

# ==============================================================================
# Configuration settings
# ==============================================================================
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
