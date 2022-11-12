let

    pkgs = import <nixpkgs> {};

    nixos-iso = pkgs.fetchurl {
        url = "https://hydra.nixos.org/build/182736132/download/1/nixos-minimal-new-kernel-22.11pre389487.18b14a254dc-aarch64-linux.iso";
        sha256 = "837e00c4786f358c9ad82e54968756ae0ee7fb36b72e76f5ffb02417584ebc4f";
    };

    nixos-vm = pkgs.writeShellScriptBin "nixos-vm" ''
        ${pkgs.qemu}/bin/qemu-img create -f raw swap.raw 20G
        test -e data.raw || ${pkgs.qemu}/bin/qemu-img create data.raw 50G
        ${pkgs.qemu}/bin/qemu-system-aarch64 \
                 -nographic \
                 -accel hvf \
                 -accel tcg \
                 -machine virt,highmem=off \
                 -cpu cortex-a57 \
                 -smp 4 \
                 -m 3G \
                 -device qemu-xhci \
                 -device usb-kbd \
                 -device virtio-mouse-pci \
                 -drive file=${pkgs.qemu}/share/qemu/edk2-aarch64-code.fd,if=pflash,format=raw,readonly=on \
                 -drive file=swap.raw,format=raw,id=swap \
                 -drive file=data.raw,format=raw,id=data \
                 -nic user,hostfwd=tcp::2222-:22 \
                 -cdrom ${nixos-iso}
    '';

    setup = pkgs.writeText "setup.sh" ''
        ssh-copy-id -p 2222 root@localhost
        ssh -p 2222 root@localhost "mount -o remount,nr_blocks=0,nr_inodes=0 /
            mount -o remount,nr_blocks=0,nr_inodes=0 /nix/.rw-store
            mkswap /dev/vda
            swapon /dev/vda
            mkdir -p /mnt/data
            blkid /dev/vdb | grep -q ext4 || mkfs.ext4 /dev/vdb
            mount /dev/vdb /mnt/data
            "
    '';

in

    pkgs.linkFarmFromDrvs "qemu-macos-m1-nix" [
        nixos-vm
        setup
    ]
