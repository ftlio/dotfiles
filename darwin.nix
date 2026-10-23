{ pkgs, lib, self, host, ... }:
{
  # List packages installed in system profile. To search by name, run:
  # $ nix search nixpkgs wget
  environment.systemPackages =
    [ pkgs.vim
    ];

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # A Linux VM that builds aarch64-linux derivations here (a NixOS host's
  # closure, pushed with `nixos-rebuild --target-host`; its VM tests, which run
  # without KVM inside the builder and so slowly), for hosts that ask for it.
  # The first switch fetches the builder's image; the VM then runs under
  # launchd, idle until a build asks for linux.
  nix.linux-builder = lib.mkIf host.linuxBuilder {
    enable = true;
    ephemeral = true;
    maxJobs = 4;
    supportedFeatures = [ "kvm" "benchmark" "big-parallel" "nixos-test" ];
    config = {
      virtualisation.cores = 6;
      virtualisation.darwin-builder = {
        diskSize = 40 * 1024;
        memorySize = 8 * 1024;
      };
    };
  };

  # claude-code is unfree.
  nixpkgs.config.allowUnfree = true;

  system.primaryUser = host.user;
  users.users.${host.user}.home = "/Users/${host.user}";

  # Touch ID for sudo. This was enabled by hand in /etc/pam.d/sudo_local,
  # which nix-darwin refuses to overwrite; it is declared here instead.
  security.pam.services.sudo_local.touchIdAuth = true;

  # git rewrites GitHub https URLs to ssh, so clones from programs with no
  # terminal (Emacs fetching packages and grammars) need the host key to be
  # trusted up front. Keys from https://api.github.com/meta.
  programs.ssh.knownHosts = {
    "github.com-ed25519" = {
      hostNames = [ "github.com" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };
    "github.com-ecdsa" = {
      hostNames = [ "github.com" ];
      publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=";
    };
  };

  # Homebrew itself is installed outside of nix; this only declares what it
  # should have installed. Nothing undeclared is removed (cleanup = "none").
  homebrew = {
    enable = true;
    onActivation.cleanup = "none";
    # Login shell (/opt/homebrew/bin/bash, registered by hand in /etc/shells).
    brews = [ "bash" ];
    casks = [
      "emacs-app"
      # Database client. Its settings and connections are app data in
      # ~/Library/DBeaverData, not managed here.
      "dbeaver-community"
      # Firefox and Firefox Developer Edition were installed outside of brew.
      # To hand them over to brew, run once:
      #   brew install --cask --adopt firefox firefox@developer-edition
      # and then uncomment:
      # "firefox"
      # "firefox@developer-edition"
    ];
  };

  # Set Git commit hash for darwin-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = host.system;
}
