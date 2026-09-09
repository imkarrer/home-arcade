# Canonical arcade hub module. Game files stay on /srv/arcade, not in git.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.arcade-hub;
in
{
  options.services.arcade-hub = {
    enable = lib.mkEnableOption ''
      Home-arcade hub on ac-box. Paths, LAN firewall, and rsync export only
      unless individual game services are enabled. Does not touch Docker or
      the Assetto Corsa lobby stack.
    '';

    lanAddress = lib.mkOption {
      type = lib.types.str;
      description = ''
        Game/LAN address arcade services bind to. Not 0.0.0.0.

        No default on purpose: this is a host fact, not a tenant fact — on
        ac-box it is `config.homelab.host.networks.lan.address` in the
        platform layer. A hardcoded default here is exactly how it drifted
        (this module and agent-hub each carried their own copy of the same
        IP). The composing host config must set it explicitly, e.g.
        `services.arcade-hub.lanAddress =
        config.homelab.host.networks.lan.address;`. This module stays
        importable standalone; it just refuses to guess a LAN address for
        you.
      '';
    };

    gameInterface = lib.mkOption {
      type = lib.types.str;
      description = ''
        LAN NIC. Arcade ports open on this interface only.

        No default for the same reason as lanAddress: it is
        `config.homelab.host.networks.lan.interface` on the platform side,
        owned once there and passed in, not redeclared per tenant.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/srv/arcade";
      description = "Library: roms, metadata, shaders, saves. Never AC content.";
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/arcade";
      description = "Hub state: lobby DB, Minetest world, secrets. Not /var/lib/ac-host.";
    };

    rsync.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Optional rsyncd. Windows spokes use SMB; Nix stations can still rsync.";
    };

    smb.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "LAN SMB share of /srv/arcade. Windows spokes robocopy this; no WSL.";
    };

    lobby.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "arcade-lobby HTTP (not implemented in this skeleton).";
    };

    lobby.port = lib.mkOption {
      type = lib.types.port;
      default = 8090;
    };

    mitm.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "RetroArch netplay MITM (not started until battle-test netplay).";
    };

    mitm.port = lib.mkOption {
      type = lib.types.port;
      default = 55435;
    };

    minetest.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    minetest.port = lib.mkOption {
      type = lib.types.port;
      default = 30000;
    };

    mumble.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    mumble.port = lib.mkOption {
      type = lib.types.port;
      default = 64738;
    };

    freeciv.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Dedicated Freeciv server, LAN bind only. No metaserver.";
    };

    freeciv.port = lib.mkOption {
      type = lib.types.port;
      default = 5556;
      description = "TCP game port. freeciv-server binds this to lanAddress.";
    };

    freeciv.announcePort = lib.mkOption {
      type = lib.types.port;
      default = 4555;
      description = ''
        UDP LAN-announce port, which is what lets the Freeciv client's
        "LAN servers" list find this server without anyone typing an IP --
        the whole point on a kids' arcade LAN.

        A separate option because it is a genuinely separate port: the server
        binds TCP 5556 to lanAddress but its UDP announce socket listens on
        4555, and on 0.0.0.0 rather than the LAN address. `--bind` governs the
        game socket only. Opening it on gameInterface is therefore the only
        scoping available; default-deny covers every other NIC.
      '';
    };

    mindustry.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Dedicated Mindustry server, LAN firewall only.";
    };

    mindustry.port = lib.mkOption {
      type = lib.types.port;
      default = 6567;
      description = ''
        Port the server listens on. This is now actually passed to the server
        via its `config port` console command -- previously it only opened a
        firewall hole and the server was left on its own 6567 default, so
        changing this option silently did nothing to the service.
      '';
    };

    mindustry.multicastPort = lib.mkOption {
      type = lib.types.port;
      default = 20151;
      description = ''
        UDP multicast discovery port -- what puts this server in the Mindustry
        client's own LAN game list instead of making a kid type an IP address.
        Exactly the role freeciv.announcePort plays, and a separate option for
        exactly the same reason: it is a genuinely different port from the game
        port, and conflating the two is how the freeciv one stayed broken.

        Unlike mindustry.port, this is NOT configurable in Mindustry -- it is a
        compile-time constant, so this option exists to declare the number,
        never to change it. `javap -p -constants mindustry.Vars` on the shipped
        server jar:

            public static final int port = 6567;
            public static final int multicastPort = 20151;
            public static final String multicastGroup = "227.2.7.7";

        and mindustry.net.ArcNetProvider's constructor calls
        arc.net.Server.setMulticast(multicastGroup, multicastPort). No console
        command reaches it. Corroborated live on ac-box: /proc/net/igmp lists
        group 070702E3 -- 227.2.7.7 -- joined on the game interface, with the
        socket bound on *:20151.

        Kept as an option rather than inlined so a host on a different
        Mindustry build has somewhere to say so.
      '';
    };

    mindustry.map = lib.mkOption {
      type = lib.types.str;
      default = "Islands";
      description = ''
        Built-in map to host. The server's own help reads
        `host [mapname] [mode]`, so the first argument is a MAP, not a mode --
        which is why "host sandbox" failed with "No map with name 'sandbox'
        found" and the server sat loaded but never opened a port.

        Valid built-in names come from the server's `maps all` command and are
        underscore-separated: Ancient_Caldera, Archipelago, Debris_Field,
        Domain, Fork, Fortress, Glacier, Islands, Labyrinth, Maze, Molten_Lake,
        Mud_Flats, Passage, Shattered, Tendrils, Triad, Veins, Wasteland.
        Custom maps would live in ${"\${stateDir}"}/mindustry/config/maps, which is empty.
      '';
    };

    mindustry.mode = lib.mkOption {
      type = lib.types.enum [ "survival" "sandbox" "attack" "pvp" ];
      default = "sandbox";
      description = ''
        Gamemode. sandbox has no enemy waves, which is the point for the kids'
        arcade -- survival (the server's default when nothing is specified)
        attacks them.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.arcade = { };
    users.users.arcade = {
      isSystemUser = true;
      group = "arcade";
      home = cfg.stateDir;
      createHome = true;
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 arcade arcade -"
      "d ${cfg.dataDir}/roms 0755 arcade arcade -"
      "d ${cfg.dataDir}/roms/snes 0755 arcade arcade -"
      "d ${cfg.dataDir}/roms/n64 0755 arcade arcade -"
      "d ${cfg.dataDir}/roms/genesis 0755 arcade arcade -"
      "d ${cfg.dataDir}/roms/dos 0755 arcade arcade -"
      "d ${cfg.dataDir}/metadata 0755 arcade arcade -"
      "d ${cfg.dataDir}/metadata/crops 0755 arcade arcade -"
      "d ${cfg.dataDir}/shaders 0755 arcade arcade -"
      "d ${cfg.dataDir}/saves 0775 arcade arcade -"
      "d ${cfg.stateDir} 0750 arcade arcade -"
      "d ${cfg.stateDir}/secrets 0700 arcade arcade -"
      "d ${cfg.stateDir}/freeciv 0750 arcade arcade -"
      "d ${cfg.stateDir}/mindustry 0750 arcade arcade -"
      "d ${cfg.dataDir}/apps 0755 arcade arcade -"
      "d ${cfg.dataDir}/apps/windows 0755 arcade arcade -"
    ];

    # Interface-scoped only. Never global allowedTCPPorts — those hit every NIC
    # including a future management link. Do not UniFi-forward these.
    networking.firewall.interfaces.${cfg.gameInterface} = {
      allowedTCPPorts =
        (lib.optional cfg.rsync.enable 873)
        ++ (lib.optionals cfg.smb.enable [ 139 445 ])
        ++ (lib.optional cfg.lobby.enable cfg.lobby.port)
        ++ (lib.optional cfg.mitm.enable cfg.mitm.port)
        ++ (lib.optional cfg.minetest.enable cfg.minetest.port)
        ++ (lib.optional cfg.mumble.enable cfg.mumble.port)
        ++ (lib.optional cfg.freeciv.enable cfg.freeciv.port)
        ++ (lib.optional cfg.mindustry.enable cfg.mindustry.port);
      allowedUDPPorts =
        (lib.optional cfg.mitm.enable cfg.mitm.port)
        ++ (lib.optional cfg.minetest.enable cfg.minetest.port)
        ++ (lib.optional cfg.mumble.enable cfg.mumble.port)
        # announcePort, NOT freeciv.port. freeciv-server's UDP socket is the
        # LAN-announce/discovery port, not the game port -- verified live: TCP
        # 5556 bound to the LAN address, UDP 4555 bound to 0.0.0.0. Opening UDP
        # 5556 was protecting a port nothing listens on, while the port actually
        # in use went undeclared entirely.
        ++ (lib.optional cfg.freeciv.enable cfg.freeciv.announcePort)
        ++ (lib.optional cfg.mindustry.enable cfg.mindustry.port)
        # multicastPort as well as port, and for the same reason the freeciv
        # line above says announcePort as well: the game port carries play, a
        # second UDP port carries DISCOVERY, and opening only the first leaves
        # the server invisible in the client's LAN list.
        #
        # This one was live-broken on ac-box until 9 Sep 2026. `ss -ulnp`
        # showed the server bound on *:20151 while `iptables -S` had accept
        # rules for 6567/tcp and 6567/udp and nothing else -- so every
        # multicast discovery packet from a LAN client was dropped and the
        # only way onto the server was typing its address. Found by diffing
        # live sockets against the port registry in homelab's tenants.nix,
        # not by reading this file.
        ++ (lib.optional cfg.mindustry.enable cfg.mindustry.multicastPort);
    };

    services.samba = lib.mkIf cfg.smb.enable {
      enable = true;
      openFirewall = false;
      nmbd.enable = false;
      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "server string" = "arcade";
          "interfaces" = "${cfg.lanAddress}/24";
          "bind interfaces only" = "yes";
          "security" = "user";
          "map to guest" = "Bad User";
          "guest account" = "arcade";
          "hosts allow" = "192.168.1. 127.0.0.1";
          "hosts deny" = "0.0.0.0/0";
        };
        arcade = {
          path = cfg.dataDir;
          "browseable" = "yes";
          "read only" = "yes";
          "guest ok" = "yes";
          "force user" = "arcade";
          "force group" = "arcade";
        };
      };
    };

    # Win10/11 Pro refuse guest SMB. Keep a real samba user; password lives
    # only in /var/lib/arcade/secrets/smb-password (not in git).
    systemd.services.arcade-smb-password = lib.mkIf cfg.smb.enable {
      description = "Ensure Samba password for arcade user";
      after = [ "samba-smbd.service" ];
      wants = [ "samba-smbd.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.samba
        pkgs.openssl
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -euo pipefail
        secret=${cfg.stateDir}/secrets/smb-password
        umask 077
        mkdir -p ${cfg.stateDir}/secrets
        [ -s "$secret" ] || openssl rand -hex 8 > "$secret"
        chown arcade:arcade "$secret"
        chmod 600 "$secret"
        pass=$(tr -d '\n' < "$secret")
        printf '%s\n%s\n' "$pass" "$pass" | smbpasswd -a -s arcade
      '';
    };

    services.rsyncd = lib.mkIf cfg.rsync.enable {
      enable = true;
      socketActivated = false;
      settings = {
        globalSection = {
          address = cfg.lanAddress;
          "use chroot" = true;
          "max connections" = 8;
        };
        sections = {
          arcade-lib = {
            path = cfg.dataDir;
            comment = "Arcade library (read-only: roms, metadata, shaders)";
            "read only" = true;
            uid = "arcade";
            gid = "arcade";
          };
          arcade-saves = {
            path = "${cfg.dataDir}/saves";
            comment = "Arcade profile saves (read-write)";
            "read only" = false;
            uid = "arcade";
            gid = "arcade";
          };
        };
      };
    };

    systemd.services.arcade-freeciv = lib.mkIf cfg.freeciv.enable {
      description = "Arcade Freeciv dedicated server (LAN only)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "arcade";
        Group = "arcade";
        WorkingDirectory = "${cfg.stateDir}/freeciv";
        ExecStart = "${pkgs.freeciv}/bin/freeciv-server --bind ${cfg.lanAddress} --port ${toString cfg.freeciv.port} --saves ${cfg.stateDir}/freeciv --log ${cfg.stateDir}/freeciv/server.log";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    systemd.services.arcade-mindustry = lib.mkIf cfg.mindustry.enable {
      description = "Arcade Mindustry dedicated server (LAN only)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "arcade";
        Group = "arcade";
        WorkingDirectory = "${cfg.stateDir}/mindustry";
        ExecStart = "${pkgs.writeShellScript "arcade-mindustry" ''
          # Startup commands go in on stdin, one per line, exactly as if typed at
          # the console. Passing them as argv does not work: the server joins
          # them into a single command line, so "config name Arcade" and
          # "host ..." became one "config" call and the host never ran.
          #
          # `config port` is sent explicitly because the server otherwise
          # ignores mindustry.port entirely and sits on its built-in 6567.
          printf '%s\n' \
            "config name Arcade" \
            "config port ${toString cfg.mindustry.port}" \
            "host ${cfg.mindustry.map} ${cfg.mindustry.mode}" \
            | exec ${pkgs.jre_headless}/bin/java -Xms256M -Xmx1G -jar ${cfg.stateDir}/mindustry/server-release.jar
        ''}";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    assertions = [
      {
        assertion = cfg.lanAddress != "0.0.0.0";
        message = "services.arcade-hub.lanAddress must be the LAN IP, not 0.0.0.0.";
      }
    ];
  };
}
