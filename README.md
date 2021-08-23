# Via

Welcome! You are looking at the open source version of an Elixir-based autopilot that is being developed by COPPERPUNK. The only difference between this and the previous version is that hopefully this one is better. In order to make that the case, we started over. This means the documentation is basically non-existent and the features are fewer (for now). If you would like to read about the older version (code name `Gristle`), you can check out our blog : https://www.copperpunk.com/blog/categories/gristle.

Via is not ready for developer collaboration just yet. Things are still changing quite a bit, so we wouldn't want anyone to waste their time writing code that will be obsolete in a week. However, we would love for people to start using the software. [This document](docs/why_via.md) outlines a few reasons why Via might be worth your time.

PLEASE NOTE: Via is currently only supported for Linux. In order to run on a Mac, additional hardware is required to interface with the transmitter/joystick, and the documentation is not available yet to describe the setup. Windows will require some additional work before USB peripherals can be supported, so that is also off the list at the moment. In the interest of getting the repository ready for community development as quickly as possible, we will be focusing on the Linux side of things. If you would like to help speed things up on the Mac and Windows fronts, please drop us a line.

## Simulation
Via integrates with X-Plane in order to create a software-in-the-loop (SIL) testing environment. Instructions on how to run Via in conjunction with X-Plane can be found [here](docs/user/xplane_sim.md).
Integration with RealFlight will follow soon.<br>

## Hardware
Via is currently testable with software only. The code exists for putting it on representative hardware, but we have not developed the tools for connecting the hardware back to the simulator (as was done with Gristle). This is high on the priority list.

## Questions/Comments
If you have any issues with running the simuation, please file an issue. If you have any general comments or questions, or simply would like to chat about the autopilot, please head over the www.copperpunk.com. There you can sign up for some open source office hours, or just leave a quick message. Thanks!


__- COPPERPUNK__
