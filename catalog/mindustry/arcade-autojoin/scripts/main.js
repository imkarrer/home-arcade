// Home Arcade: the "Family game" button starts Mindustry with
// -Darcade.join=host:port (and -Darcade.name=<profile name>). The desktop
// client has no connect-on-launch flag, so this joins from inside the game.
// Without the property (the solo "Play" button) it does nothing.
Events.on(ClientLoadEvent, e => {
    const target = java.lang.System.getProperty("arcade.join");
    if(!target) return;

    const name = java.lang.System.getProperty("arcade.name");
    if(name && !Core.settings.getString("name", "").trim()){
        Core.settings.put("name", name);
        Vars.player.name = name;
    }

    const cut = String(target).lastIndexOf(":");
    const host = cut < 0 ? String(target) : String(target).substring(0, cut);
    const port = cut < 0 ? 6567 : parseInt(String(target).substring(cut + 1));
    Log.info("arcade-autojoin: joining @:@ as @", host, String(port), Vars.player.name);
    Vars.ui.join.connect(host, port);
});
