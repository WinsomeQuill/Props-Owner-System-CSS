# Props System Owner [CS:Source v90]

This plugin is suitable for a zombie server(Zombie Reloaded, Zombie Plague and etc...). 
The essence of the plugin is that Human cannot break Humans props (exception: Owner), and Zombie props are Zombies (exception: Owner).
If the prop owner is dead, then the prop goes to the server and any player can break it.

Requirements
----

    SourceMod 1.10+
    MetaMod 1.10+
    ZombieReloaded
    MultiColors
    SdkTools
    SdkHooks

Commands
----
    sm_getpropinfo - debug function, returns: Health, Owner, YourID, Model prop.
    sm_deleteprop - Deleted target prop. (Flag: ADMFLAG_SLAY)
    sm_sethpprop - Change target health prop. (Flag: ADMFLAG_RCON)
    sm_resetprop - Remove owner from target prop. (Flag: ADMFLAG_SLAY)
    sm_getprops - Get list owners props. (Flag: ADMFLAG_SLAY)
    sm_zprop_credits - Gives player credits for zprops. (Flag: ADMFLAG_CONVARS)

Info
----
I created special version for NIDE.GG
