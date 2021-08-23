# X-Plane Simulation

Via uses off-the-shelf software for its simulation environments. Someday we will build a headless simulator in Gazebo, but for now we're taking advantage of what's already out there. If you would like to fly a Cessna in X-Plane with Via in the loop, please follow these steps:

0.  Setup your transmitter according to [this document](transmitter.md).
1.  Clone the Via repository (https://github.com/copperpunk-elixir/via)
2.  [Install Nerves](https://hexdocs.pm/nerves/installation.html)
3.  [Install dependencies for Scenic](https://github.com/boydm/scenic/blob/master/guides/install_dependencies.md). NOTE: if you get errors with the packages, then the version numbers might be wrong in the documentation. But you should be able to figure it out.
4.  [Install X-Plane](https://www.x-plane.com/desktop/try-it/) (the demo version is fine, and it doesn't need to be on the same computer as Via).
5.  Modify X-Plane settings to output data via UDP. You can just copy the settings shown here, but change the IP address in the "NETWORK CONFIGURATION" section to that of the computer that will be running Via (or 127.0.0.1 if they're on the same computer): <p align="center"><img src="../resources/xplane_data_output.jpg" width="70%"></p>
    In case you don't like looking at pictures, the following messages must have the "Network via UDP" box checked:
    *   3: Speeds
    *   16: Angular Velocities
    *   17: Pitch, roll, & headings
    *   20: Latitude, longitude, & altitude
    *   21: Location, velocity, & distance traveled

    <br>In addition, the UDP Rate slider should be put up to its maximum value (99.9 packets/sec), not that our dev computers can ever seem to run it that fast.
6.  Start flying the Cessna Skyhawk in X-Plane (any airport will do). If you are not achieving at least 50 frames-per-second with your frame rate, you will need to turn down some of your graphics (maybe just turn them all the way down anyway).
7.  Start up the Via simulation. This is accomplished by providing some command-line arguments. The following runs Via for the Cessna Skyhawk.<br>
```vehicle_type=FixedWing model_type=Cessna node_type=Sim iex -S mix```