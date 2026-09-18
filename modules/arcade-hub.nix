# Canonical arcade hub module. Game files stay on /srv/arcade, not in git.
#
# THE MODULE IS THE SKELETON; THE ENVIRONMENT IS THE TENANT (homelab ADR
# 0009 step 2, on ac-box since 18 Sep 2026 12:34 CDT). What the two game
# servers RUN is .flox/env/manifest.toml, pushed by CI as a generation of
# imkarrer/arcade and pulled by homelab's pull unit; what they run AS is
# this file: the unit names (never renamed), User/Group, WorkingDirectory,
# After/Wants, Restart, the state directories, the firewall holes, and the
# SMB/rsync export of /srv/arcade. homelab's stubs
# (hosts/ac-box/configuration.nix, homelab.tenants.arcade.environment)
# mkForce ExecStart on both units to `flox activate -d /var/lib/arcade/env
# -g <N> -- <server>` and read the options below for the argv and stdin
# they pass. This file no longer builds an ExecStart of its own: the
# placeholder each unit carries exits 1 naming the stub, so a host that
# composes this module without one gets a failed unit, not a silent one.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.arcade-hub;

  # The placeholder ExecStart for a game unit: what runs if the composing
  # host has no stub for it. Exits 1 with the reason on stderr (the
  # journal), so Restart=on-failure retries it until systemd's start limit
  # trips and the unit sits failed -- loud, and on the box the stub's
  # mkForce means it is never the ExecStart at all. It does NOT try to run
  # a server: this file no longer knows which package the tenant runs.
  skeletonExecStart =
    unit:
    pkgs.writeShellScript "${unit}-skeleton" ''
      echo "${unit}.service: this unit is a skeleton from home-arcade's modules/arcade-hub.nix;" \
        "its ExecStart comes from homelab's stub (hosts/ac-box/configuration.nix," \
        "homelab.tenants.arcade.environment.units.\"${unit}.service\"), which is not composed here." >&2
      exit 1
    '';
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

        Read by homelab's arcade-freeciv stub as `--bind <lanAddress>`, and
        by the samba/rsync export below. The environment carries no LAN
        address (manifest header); this option is where the box's reaches
        the server.
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
      description = ''
        Hub state: lobby DB, Minetest world, secrets. Not /var/lib/ac-host.

        A host fact homelab's stubs read: arcade-freeciv's `--saves
        <stateDir>/freeciv --log <stateDir>/freeciv/server.log`, and both
        units' WorkingDirectory (set here; Mindustry writes config/ under
        its cwd, <stateDir>/mindustry). The flox environment itself lives
        under it too, at <stateDir>/env, which homelab's pull unit creates.
      '';
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
      description = ''
        The arcade-freeciv.service skeleton and its firewall holes. The
        server itself is the environment's freeciv, run by homelab's stub
        (see the file header); with no stub the unit exists and fails.
      '';
    };

    freeciv.port = lib.mkOption {
      type = lib.types.port;
      default = 5556;
      description = ''
        TCP game port. A host fact homelab's stub passes as `--port`; the
        firewall hole on gameInterface is opened here.
      '';
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
      description = ''
        The arcade-mindustry.service skeleton and its firewall holes. The
        server itself is the environment's mindustry-server, run by
        homelab's stub (see the file header); with no stub the unit exists
        and fails.
      '';
    };

    mindustry.port = lib.mkOption {
      type = lib.types.port;
      default = 6567;
      description = ''
        Port the server listens on. A host fact homelab's stub feeds the
        server as its `config port` console line (the unit's
        StandardInputText=); the firewall hole is opened here. It has to be
        sent: the server otherwise sits on its built-in 6567, so before the
        console line existed changing this option silently did nothing to
        the service.
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
        Built-in map to host. A host fact homelab's stub feeds the server as
        the `host <map> <mode>` console line. The server's own help reads
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
        Gamemode, the second word of the stub's `host <map> <mode>` line.
        sandbox has no enemy waves, which is the point for the kids' arcade
        -- survival (the server's default when nothing is specified) attacks
        them.
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

    # rsyncd binds cfg.lanAddress, so like every other LAN-bound unit in this
    # file it must wait for that address to EXIST -- and nixpkgs' rsyncd module
    # orders only after network.target, which is satisfied before DHCP has
    # handed out anything. The two hand-written units below (freeciv,
    # mindustry) already carry this pair; rsyncd was the one LAN-bound unit
    # without it, because it comes from a nixpkgs module rather than from here.
    #
    # Found on ac-box's first reboot in a week, 12 Sep 2026: rsyncd started at
    # 12:37:34 and died with "bind() failed: Cannot assign requested address",
    # while samba-smbd -- same address, but nixpkgs' samba module orders after
    # network-online.target -- started six seconds later and was fine. On the
    # previous boot (5 Sep) rsyncd's first start was an hour after boot, from a
    # nixos-rebuild switch, so this had never actually been tested at boot.
    #
    # The unit is `rsync.service`, not rsyncd -- nixpkgs names it that way and
    # carries rsyncd.service only as an alias.
    systemd.services.rsync = lib.mkIf cfg.rsync.enable {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      # Second layer, independent of the first. The ordering above fixes the
      # cause; this fixes the consequence if the cause ever recurs in a form
      # ordering does not catch. nixpkgs' rsyncd.nix sets `RestartSec = 1`
      # and NO `Restart=` -- a retry delay for a retry that never happens --
      # so a failed bind left the unit dead until a human noticed, which on
      # 12 Sep 2026 was the operator reading Grafana. Two arcade stations
      # (192.168.1.146, 192.168.1.21) pull the ROM library over this; the
      # export being down is a kid's machine failing to sync, not a log line.
      #
      # Only Restart= is set here. RestartSec is inherited from upstream's 1s
      # rather than overridden: with the ordering fix the address exists
      # before the first start, so this is belt-and-braces, and a plain
      # `RestartSec = 5` here is a conflicting definition against upstream's
      # value (hub-gates caught exactly that). Fighting nixpkgs over a number
      # that no longer matters is not worth a mkForce.
      serviceConfig.Restart = "on-failure";
    };

    # The two game units, as skeletons. Everything below is what homelab's
    # stubs rely on and leave alone (modules/tenant/environment.nix: "only
    # ExecStart and the variables"): the unit's existence under its pinned
    # name, the description, User/Group, WorkingDirectory -- Mindustry
    # writes config/ under its cwd, so it must be <stateDir>/mindustry --
    # After/Wants network-online (both bind lanAddress, which must exist
    # first; see the rsync comment above), Restart/RestartSec, and
    # wantedBy. The stub adds ExecStart (mkForce), Environment= and, for
    # mindustry, StandardInputText= with the three console lines the
    # wrapper this file used to carry piped into java: `config name
    # Arcade`, `config port <mindustry.port>`, `host <map> <mode>`.
    #
    # Until 18 Sep 2026 this file built the real ExecStart: freeciv-server
    # from the host's nixpkgs, and for mindustry a printf | java -jar
    # <stateDir>/mindustry/server-release.jar wrapper around a jar
    # scripts/fetch_mindustry.py downloaded by hand (v159.7). Both are
    # dead with the stubs on -- the environment's freeciv 3.2.2 and
    # mindustry-server 159.3 own argv -- and are gone rather than kept as
    # a fallback: a fallback that hosts a port is exactly what the module
    # and the environment must never both do (docs/ci.md). What is left is
    # a placeholder that fails loudly, so `enable = true` without the stub
    # is a failed unit in the journal naming what is missing, never a
    # silent no-op and never a server on a different jar.
    systemd.services.arcade-freeciv = lib.mkIf cfg.freeciv.enable {
      description = "Arcade Freeciv dedicated server (LAN only)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "arcade";
        Group = "arcade";
        WorkingDirectory = "${cfg.stateDir}/freeciv";
        ExecStart = skeletonExecStart "arcade-freeciv";
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
        ExecStart = skeletonExecStart "arcade-mindustry";
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
