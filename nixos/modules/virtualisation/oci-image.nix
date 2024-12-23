{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.oci;
in
{
  imports = [
    ./oci-common.nix
    ../image/file-options.nix
  ];

  config = {
    # Use a priority just below mkOptionDefault (1500) instead of lib.mkDefault
    # to avoid breaking existing configs using that.
    virtualisation.diskSize = lib.mkOverride 1490 (8 * 1024);
    virtualisation.diskSizeAutoSupported = false;

    system.nixos.tags = [ "oci" ];
    image.extension = "qcow2";
    system.build.image = config.system.build.OCIImage;
    system.build.OCIImage = import ../../lib/make-disk-image.nix {
      inherit config lib pkgs;
      inherit (config.virtualisation) diskSize;
      name = "oci-image";
      baseName = config.image.baseName;
      configFile = ./oci-config-user.nix;
      format = "qcow2";
      partitionTableType = if cfg.efi then "efi" else "legacy";
    };

    systemd.services.fetch-ssh-keys = {
      description = "Fetch authorized_keys for root user";

      wantedBy = [ "sshd.service" ];
      before = [ "sshd.service" ];

      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      path = [
        pkgs.coreutils
        pkgs.curl
      ];
      script = ''
        mkdir -m 0700 -p /root/.ssh
        if [ -f /root/.ssh/authorized_keys ]; then
          echo "Authorized keys have already been downloaded"
        else
          echo "Downloading authorized keys from Instance Metadata Service v2"
          curl -s -S -L \
            -H "Authorization: Bearer Oracle" \
            -o /root/.ssh/authorized_keys \
            http://169.254.169.254/opc/v2/instance/metadata/ssh_authorized_keys
          chmod 600 /root/.ssh/authorized_keys
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StandardError = "journal+console";
        StandardOutput = "journal+console";
      };
    };
  };
}
