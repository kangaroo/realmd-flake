{
  inputs = {
    nixpkgs.url = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    oddjob = {
      type = "github";
      owner = "kangaroo";
      repo = "oddjob-flake";
      ref = "main";
    };
  };
  outputs = { self, flake-utils, oddjob, ... }@inputs:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = inputs.nixpkgs.legacyPackages."${system}";
        oddjob = inputs.oddjob;
      in
      {
        packages.default = pkgs.stdenv.mkDerivation rec {
          name = "realmd";
          version = "0.17.0";

          src = pkgs.fetchFromGitLab {
            domain = "gitlab.freedesktop.org";
            owner = name;
            repo = name;
            rev = version;
            sha256 = "1c6q2a86kk2f1akzc36nh52hfwsmmc0mbp6ayyjxj4zsyk9zx5bf";
          };

          preConfigure = with pkgs; ''
            substituteInPlace service/realmd-defaults.conf \
              --replace "/usr/sbin/winbindd" "${samba}/sbin/winbindd"
            substituteInPlace service/realmd-defaults.conf \
              --replace "/usr/bin/net" "${samba}/sbin/net"
            substituteInPlace service/realmd-defaults.conf \
              --replace "/usr/sbin/adcli" "${adcli}/bin/adcli"

            substituteInPlace service/realmd-defaults.conf \
              --replace "/bin/bash" "${bash}/bin/bash"

            cat >service/realmd-nixos.conf <<END
[paths]
smb.conf = /etc/samba/smb.conf
krb5.conf = /etc/krb5.conf

[samba-packages]
samba-common-tools = ${samba}/sbin/net

[winbind-packages]
samba-winbind = ${samba}/sbin/winbindd
samba-winbind-clients = ${samba}/bin/wbinfo
oddjob = ${oddjob}/sbin/oddjobd
oddjob-mkhomedir = ${oddjob}/libexec/oddjob/mkhomedir

[sssd-packages]
sssd = ${sssd}/sbin/sssd
oddjob = ${oddjob}/sbin/oddjobd
oddjob-mkhomedir = ${oddjob}/libexec/oddjob/mkhomedir

[adcli-packages]
adcli = ${adcli}/bin/adcli

[commands]
winbind-enable-logins =
winbind-disable-logins =
winbind-enable-service = ${systemd}/bin/systemctl enable winbind.service
winbind-disable-service = ${systemd}/bin/systemctl disable winbind.service
winbind-restart-service = ${systemd}/bin/systemctl restart winbind.service
winbind-stop-service = ${systemd}/bin/systemctlstop winbind.service

sssd-enable-logins =
sssd-disable-logins =
sssd-enable-service = ${systemd}/bin/systemctl enable sssd.service
sssd-disable-service = ${systemd}/bin/systemctl disable sssd.service
sssd-restart-service = ${systemd}/bin/systemctl restart sssd.service
sssd-stop-service = ${systemd}/bin/systemctl stop sssd.service
sssd-caches-flush = ${sssd}/sbin/sss_cache --users --groups --netgroups --services --autofs-maps
END
          '';

          nativeBuildInputs = with pkgs; [ autoreconfHook pkg-config ];
          buildInputs = with pkgs; [ openldap libkrb5 polkit libxslt intltool glib systemd ];

          configureFlags = [
            "--with-distro=nixos"
            "--disable-doc"
            "--sysconfdir=${placeholder "out"}/etc"
            "--with-systemd-unit-dir=${placeholder "out"}/share/systemd"
          ];
        };
      });
}
