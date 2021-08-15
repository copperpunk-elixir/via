# Transmitter Setup

If you have not set up your transmitter before, please first visit the [FrSky](frsky.md) or [Spektrum](spektrum.md) pages to learn how to connect the transmitter to your computer.

# X-Plane Channel Ouput
Via uses 4 different "Pilot Control Levels" which affect the type of commands that are used, and 3 different "Autopilot Control Modes" that determine the source of the commands. They will not be discussed here, because there is another section of documentation that describes the command flow.<br>
> NOTE: The documentation doesn't actually exist yet.

Each of these states is controlled by a three-position switch. Below are the switch positions, the equivalent PWM output, and the Via value assigned to each:

### Autopilot Control Mode (ACM): 

* min/1000us/1: Manual Control (the remote pilot is directly controlling the actuators)
* neutral/1500us/2: Autopilot Assist (the remote pilot is providing higher-level commands, as determined by the `Pilot Control Level`)
* max/2000us/3: Autopilot Control (the remote pilot's inputs are ignored, as the autopilot will be navigation a mission, if available)

Only if the `Autopilot Control Level` is at 2 (Autopilot Assist) does the `Pilot Control Level` come into play. In this case the switch positions are as follows:
* min/1000us/1: Rate Control
* neutral/1500us/2: Attitude Control
* max/2000us/4: Velocity Control

You will notice that a `PCL` of 3 cannot be attained by the remote pilot. That is because Velocity Control values contain rate commands that are converted into fixed targets by the autopilot. For example, the pilot could request a climb rate of 2 m/s. Via would use the current altitude to calculate an altitude target based on that requested climb rate, and this be passed to the controller as a `PCL 3` command.

NOTE: There are some commands that do not depend on the `Pilot Control Level`, such as `Flaps` and `Landing Gear`.

The channels for each remote pilot configuration are shown below. Channels 1-7 and 10 used. For a vehicle with fixed landing gear, only channels 1-7 are necessary. Channels 8 and 9 are reserved for hardware-related purposes.


## <u>Manual Control: ACM=1</u>
|Channel number |Output|
:---: | :---: |
|1|Aileron
|2|Elevator
|3|Throttle
|4|Rudder
|5|Flaps
|6|N/A
|7|Autopilot Control Mode
|8|N/A
|9|N/A
|10|Landing Gear
<br>

## <u>Rate Control: ACM=2/PCL=1</u>
|Channel number |Output|
:---: | :---: |
|1|Roll rate
|2|Pitch rate
|3|Throttle
|4|Yaw rate
|5|Flaps
|6|Pilot Control Level
|7|Autopilot Control Mode
|8|N/A
|9|N/A
|10|Landing Gear
<br>

## <u>Attitude Control: ACM=2/PCL=2</u>
|Channel number |Output|
:---: | :---: |
|1|Roll
|2|Pitch
|3|Throttle
|4|Delta Yaw
|5|Flaps
|6|Pilot Control Level
|7|Autopilot Control Mode
|8|N/A
|9|N/A
|10|Landing Gear

### <u>Velocity Control: ACM=2/PCL=4</u>
|Channel number |Output|
:---: | :---: |
|1|Course rate
|2|Altitude rate
|3|Speed
|4|Sideslip
|5|Flaps
|6|Pilot Control Level
|7|Autopilot Control Mode
|8|N/A
|9|N/A
|10|Landing Gear
