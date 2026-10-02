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
    } // h // {
      git = { signingKey = null; identities = [ ]; } // h.git;
    };

    mkHost = _hostname: h:
      let host = hostDefaults h; in
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
            ];
          }
        ];
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
