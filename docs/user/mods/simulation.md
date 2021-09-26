# Modifying Simulation Environment

Sample file: [simulation.txt](../../resources/sample_config_files/simulation.txt)

## Format:
```
<simulator_name>,<vehicle_name>,<input_type>
```

Examples:<br>
#
The following will connect to **X-Plane** to fly the **Cessna Skyhawk** using either joystick or keyboard inputs:
```
xplane,skyhawk,any
```

#
The following will connect to **RealFlight** to fly the **E-Flight Carbon-Z Cessna 2.1m**. A joystick (or USB dongle) must be connected to the computer running RealFlight, so the `vehicle_type` is not required.
```
realflight,cessna2m
```
