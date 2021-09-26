# Modifying Configurations (Raspberry Pi)

By default, Via will load parameters specified by the source code. These can be modified at runtime by supplying a USB flash drive with a file relevant to the parameters you wish to change (support for this is currently under development).

The USB drive only needs to be used once each time you make a change. The new parameters will be saved to the onboard Micro SD card. As long your don't burn a new firmware image, your changes will remain intact. 

The list of parameters that can be changed are below (it's a short list for now):

### <u>Simulation Environment (simulator, vehicle, input_type)</u>
* [Simulation Environment](mods/simulation.md)
* [Network Credentials](mods/network.md)