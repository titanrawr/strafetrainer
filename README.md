# CS:S Strafetrainer ((AN ENTIRELY NEW ONE!!))
This plugin is supposed to be a replacement for the current strafetrainer typically seen in most bhop servers.

# How is it different?
1. All code is built from scratch (aside from me looking at how the other plugin calculates gain)
2. The strafetrainer submenu (image below) has more customisation 
<img width="257" height="228" alt="image" src="https://github.com/user-attachments/assets/295a7eb5-a396-4e5e-9d49-15935abd21ce" />
3. A much smaller & less jittery design
4. Fast toggle is enabled by default
5. Different colours of the trainer for better viewablity in all maps (+ rainbow!! :D)

# How do I put it on my server
1. Put the `.sp` file into the folder mentioned in step 2
1. `cd` into your scripting folder (often at `~/[CSS SERVER FOLDER NAME HERE]/cstrike/addons/sourcemod/scripting`)
2. Type `./spcomp strafetrainer.sp -o ../plugins/strafetrainer.smx`
3. Go into your server console and type `sm plugins load strafetrainer`
4. Done!

# How do I use this ingame?
Use /strafetrainer to change the trainer to your liking.

# IMPORTANT - PLEASE READ IF YOU USE BGS-JUMPSTATS
The strafetrainer included in this plugin will still be active (and also utilising the /strafetrainer command, making use of the one in this repo impossible) when you load the new plugin. To disable the strafetrainer built into Nimmy's plugin, use the command:
# js-enabled-trainer 0
to get rid of the outdated one.

## A video showcase is linked here:

https://upload.angelgirl.cloud/f/dvdtbx3s.mp4

I hope this helps to be more accurate with strafes!
