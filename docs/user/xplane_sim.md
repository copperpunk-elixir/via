# X-Plane Simulation

Via uses off-the-shelf software for its simulation environments. Someday we will build a headless simulator in Gazebo, but for now we're utilizing X-Plane. If you would like to fly a Cessna in X-Plane with Via in the loop, please follow these steps:

1.  Clone the Via repository (https://github.com/copperpunk-elixir/via)
2.  [Install Nerves](https://hexdocs.pm/nerves/installation.html)
3.  [Install dependencies for Scenic](https://github.com/boydm/scenic/blob/master/guides/install_dependencies.md). NOTE: if you get errors with the packages, then the version numbers might be wrong in the documentation. But you should be able to figure it out.4
4.  [Install X-Plane](https://www.x-plane.com/desktop/try-it/) (the demo version is fine, and it doesn't need to be on the same computer as Via).
5.  Modify X-Plane settings to output data via UDP. You can just copy the settings shown here, but change the IP address to that of your computer that will be running Via (or 127.0.0.1 if they're on the same computer): <p align="center"><img src="../resources/xplane_data_output.jpg" width="70%"></p>
6.  Start flying the Cessna Skyhawk in X-Plane (any airport will do). If you are not achieving at least 50 frames-per-second with your framerate, you will need to turn down some of your graphics.
7.  Start up the Via simulation. This is accomplished by providing some command-line arguments. The following runs Via for the Cessna Skyhawk.<br>
```vehicle_type=FixedWing model_type=Cessna node_type=Sim iex -S mix```