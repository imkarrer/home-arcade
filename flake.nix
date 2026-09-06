{
  description = "Home arcade hub and station source. No ROMs or zips.";

  outputs = { self }: {
    nixosModules.arcade-hub = import ./modules/arcade-hub.nix;
    nixosModules.default = self.nixosModules.arcade-hub;
  };
}
