# TF2 Stamina Sprinting

[![IMAGE ALT TEXT HERE](http://img.youtube.com/vi/lySuGFnXiJU/0.jpg)](http://www.youtube.com/watch?v=lySuGFnXiJU)

## Description
Allows players to sprint using a stamina meter by double tapping w (forward button).

## Requirements
```
Plugin for Team Fortress 2
Requires Sourcemod 1.8+ and Metamod 1.10+
```

## Convar settings
```
sm_stamina_enabled - Enables/Disables stamina sprinting.
sm_stamina_speed - Speed increase value when sprinting.
sm_stamina_class - Bit-Wise operation to determine which class can sprint.
sm_stamina_drain - How fast to drain stamina, 0.1 is fastest.
sm_stamina_regen - How fast to regenerate stamina, 0.1 is fastest.
sm_stamina_hudx - X coordinate of HUD display.
sm_stamina_hudy - Y coordinate of HUD display.
sm_stamina_team - 0 - None, 1 - Both, 2 - Red, 3 - Blue.
```

## Installation
```
1. Place stamina.smx to addons/sourcemod/plugins/
2. Place stamina.cfg to cfg/sourcemod/ and edit your convars to fit your needs
```

## Class Type Bit-Wise
```
Scout =		1
Sniper =	2
Soldier =	4
Demoman =	8
Medic =		16
Heavy =		32
Pyro =		64
Spy =		128
Engineer =	256

To use sm_stamina_class, add the values of whatever class you want stamina sprinting to work for 
For example if i wanted only pyro and medic to have stamina sprinting, i would add 64 + 16 = 80
I would then set sm_stamina_class 80 
511 will enable all class to use stamina sprinting
```

## Overrides
```
This plugin is enabled for all clients who joins the server, if you want to limit this to an admin flag then set your admin overrides to 
sm_stamina_override

Plugin must be reloaded if you change the override.
```
