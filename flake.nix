{
  description = "ftlio's dotfiles: macOS via nix-darwin and home-manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # Not packaged in nixpkgs, so pinned here and sourced from the store.
    oh-my-bash.url = "github:ohmybash/oh-my-bash";
    oh-my-bash.flake = false;
    # Loaded by ~/.emacs.d/init.el from ~/.config/crafted-emacs.
    crafted-emacs.url = "github:SystemCrafters/crafted-emacs";
    crafted-emacs.flake = false;
  };

  outputs = inputs@{ self, nix-darwin, home-manager, ... }:
  let
    # Machines are described outside this repo (hostnames, usernames and
    # addresses are not public); hosts/example.nix documents the fields.
    hostDefaults = h: {
      system = "aarch64-darwin";
      dotfilesDir = "/Users/${h.user}/.dotfiles";
      privateDir = "/Users/${h.user}/.dotfiles-private";
      emacsExtra = "";
      sshConfig = "";
      awsConfig = "";
      # Database connections for DBeaver; see home-databases.nix.
      databases = { };
      # nix-darwin modules from other flakes, for this host only (e.g. a
      # service a project provides). Appended after the shared modules.
      extraModules = [ ];
      # A Linux builder VM (nix.linux-builder), for a machine that builds
      # NixOS systems and their VM tests to deploy them.
      linuxBuilder = false;
    } // h // {
      git = { signingKey = null; identities = [ ]; } // h.git;
    };

    mkHost = hostname: h:
      # The attribute's name is the host's: `rebuild` selects it by that, not
      # by the machine's LocalHostName, which an MDM may rename.
      let host = hostDefaults h // { name = hostname; }; in
      nix-darwin.lib.darwinSystem {
        specialArgs = { inherit inputs self host; };
        modules = [
          ./darwin.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # Existing dotfiles (e.g. ~/.bash_profile) are renamed, not clobbered.
            home-manager.backupFileExtension = "before-home-manager";
            home-manager.extraSpecialArgs = { inherit inputs host; };
            home-manager.users.${host.user}.imports = [
              ./home.nix
              ./home-darwin.nix
              ./home-remote-sudo.nix
              ./home-databases.nix
            ];
          }
        ] ++ host.extraModules;
      };
  in
  {
    # hostname -> host description, to darwinConfigurations.
    lib.mkHosts = builtins.mapAttrs mkHost;

    darwinConfigurations = self.lib.mkHosts {
      example = import ./hosts/example.nix;
    };
  };
}
