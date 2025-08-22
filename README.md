Reapercat is a custom anticheat forked from watchcat made to detect cheats and exploits on roblox. To install simply do:
Make a RemoteEvent named FlagEvent in ReplicatedStorage.Reapercat (Make that folder)
Make a LocalScript to handle OnClientEvent on said RemoteEvent (All this does is notify other players)
Make a ServerScript in ServerScriptService that has "require(script.Reapercat)"
Make a ModuleScript inside of the ServerScript you created and put the anticheat in it.
