# Transmitter Setup

If you have not set up your transmitter before, please first visit the [FrSky](frsky.md) or [Spektrum](spektrum.md) pages to learn how to connect the transmitter to your computer.

# X-Plane Channel Ouput
Via uses 4 different "Pilot Control Levels" which affect the type of commands that are used, and 3 different "Autopilot Control Modes" that determine the source of the commands. They will not be discussed here, because there is another section of documentation that describes the command flow.<br>
> NOTE: The documentation doesn't actually exist yet.

Each of these states is controlled by a three-position switch, summarized by the following table:

## Autopilot Control Mode (ACM): 
| Switch position | Output (microseconds) | Value |       Mode        |                       Comments                       |
| :-------------: | :-------------------: | :---: | :---------------: | :--------------------------------------------------: |
|       min       |         1000          |   1   | Autopilot Control |          Remote pilot's inputs are ignored           |
|     neutral     |         1500          |   2   | Autopilot Assist  | Command type determined by the `Pilot Control Level` |
|       max       |         2000          |   3   |  Manual Control   |  Remote pilot is directly controlling the actuators  |

## Pilot Control Level (PCL):
Only if the `Autopilot Control Mode` is set at 2 (Autopilot Assist) does the `Pilot Control Level` come into play. In this case the switch positions yield the following:
| Switch position | Output (microseconds) | Value |   Command Type   |
| :-------------: | :-------------------: | :---: | :--------------: |
|       min       |         1000          |   1   |   Rate Control   |
|     neutral     |         1500          |   2   | Attitude Control |
|       max       |         2000          |   4   | Velocity Control |

You will notice that a `PCL` of 3 cannot be attained by the remote pilot. That is because Velocity Control values contain rate commands that are converted into fixed targets by the autopilot. For example, the pilot could request a climb rate of 2 m/s. Via would use the current altitude to calculate an altitude target based on that requested climb rate, and this be passed to the controller as a `PCL 3` command.

> NOTE: There are some commands that do not depend on the `Pilot Control Level`, such as `Flaps` and `Landing Gear`.

<br>

## Remote Pilot Commands
The channel output for each remote pilot configuration are shown below. Channels 1-10 are used, although channels 8 and 9 are reserved for hardware-related purposes. At the very least you will need a 7-channel transmitter. We will eventually have better support for configuring your radio.


| Channel number | ACM=3/PCL=Any | ACM=2/PCL=1  |  ACM=2/PCL=2  |  ACM=2/PCL=4  |
| :------------: | :-----------: | :----------: | :-----------: | :-----------: |
|       1        |    Aileron    |  Roll rate   |     Roll      |  Course rate  |
|       2        |   Elevator    |  Pitch rate  |     Pitch     | Altitude rate |
|       3        |   Throttle    |   Throttle   |   Throttle    |     Speed     |
|       4        |    Rudder     |   Yaw rate   | Change in yaw |   Sideslip    |
|       5        |     Flaps     |    Flaps     |     Flaps     |     Flaps     |
|       6        |      N/A      |     PCL      |      PCL      |      PCL      |
|       7        |      ACM      |     ACM      |      ACM      |      ACM      |
|       8        |      N/A      |     N/A      |      N/A      |      N/A      |
|       9        |      N/A      |     N/A      |      N/A      |      N/A      |
|       10       | Landing Gear  | Landing Gear | Landing Gear  | Landing Gear  |