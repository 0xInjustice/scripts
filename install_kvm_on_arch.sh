#!/usr/bin/env bash
# arch-kvm-setup.sh – Minimal interactive installer for KVM/QEMU + virt-manager on Arch Linux.
# Run: ok to pass --user="<username>" arg as non-root. Must be run as root (or via sudo).
# Will install qemu-full, virt-manager, dnsmasq, bridge-utils, iptables-nft, libguestfs, vde2, openbsd-netcat, tuned.
# Enables nested virtualization, libvirtd networking, Tuned tuning, and libvirt/iptables service.
# Works safely even if rerun.

set -euo pipefail

script_name="${0##*/}"
userdata=
target_user=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --user=*)
      target_user="${1#*=}"
      shift ;;
    --user)
      shift
      target_user="${1:-}"
      shift ;;  
    *)
      echo "Usage: $script_name [--user=<username>]" >&2
      exit 1 ;;
  esac
done

if ! [[ $EUID -eq 0 ]]; then
  echo "ERROR: must run as root (or via sudo):" >&2
  exit 1
fi

: "${target_user:=$(logname 2>/dev/null || echo "")}"
if [[ -z $target_user || ! $(getent passwd "$target_user") ]]; then
  echo "WARNING: non-root username not found; KVM filesystem socket access step will be skipped." >&2
fi

PACKAGES=(qemu-full virt-manager dnsmasq bridge-utils iptables-nft libguestfs vde2 openbsd-netcat tuned)
echo "➤ Installing packages: ${PACKAGES[*]}"
pacman -Sy --noconfirm --needed "${PACKAGES[@]}"

echo "➤ Enabling and starting libvirtd.service"
systemctl enable --now libvirtd.service

LIBVIRTD_CONF=/etc/libvirt/libvirtd.conf
echo "➤ Ensuring libvirtd.conf has correct socket group and permissions (libvirt, 0770)…"
grep -Eq '^unix_sock_group\s*=\s*"libvirt"' "$LIBVIRTD_CONF" || sed -i'.bk' \
  -E 's|^\s*#?\s*unix_sock_group\s*=.*|unix_sock_group = "libvirt"|' "$LIBVIRTD_CONF"
grep -Eq '^unix_sock_rw_perms\s*=\s*"0770"' "$LIBVIRTD_CONF" || sed -i \
  -E 's|^\s*#?\s*unix_sock_rw_perms\s*=.*|unix_sock_rw_perms = "0770"|' "$LIBVIRTD_CONF"
echo "✱ libvirtd.conf backed up to ${LIBVIRTD_CONF}.bk"

if [[ -n $target_user ]]; then
  echo "➤ Adding $target_user to libvirt group"
  usermod -aG libvirt "$target_user" || true
  echo "→ Please log out/in or run: newgrp libvirt"
fi

echo "➤ Restarting libvirtd.service"
systemctl restart libvirtd.service

LIBVIRT_NET_CONF=/etc/libvirt/network.conf
echo "➤ Setting firewall_backend = \"iptables\" in $LIBVIRT_NET_CONF to fix NAT-broken VMs"
if grep -Eq '^\s*firewall_backend\s*=.*' "$LIBVIRT_NET_CONF"; then
  sed -i'.bk2' -E 's|^\s*firewall_backend\s*=.*|firewall_backend = "iptables"|' "$LIBVIRT_NET_CONF"
else
  echo 'firewall_backend = "iptables"' >> "$LIBVIRT_NET_CONF".new
  mv "$LIBVIRT_NET_CONF".new "$LIBVIRT_NET_CONF"
fi
echo "✱ $LIBVIRT_NET_CONF backed up to ${LIBVIRT_NET_CONF}.bk2"

echo "➤ Enabling and starting iptables.service (uses nft backend via iptables-nft)"
systemctl enable --now iptables.service

echo "➤ Restarting libvirtd.service after firewall backend change"
systemctl restart libvirtd.service

echo "➤ Starting and autostarting default network in libvirt"
virsh net-list --all | grep -q ' default ' \
  && virsh net-autostart default \
  || virsh net-define /usr/share/libvirt/networks/default.xml \
       && virsh net-autostart default
virsh net-start default || echo "(It may already be running.)"

echo "➤ Detecting processor type for nested virtualization..."
if grep -Eqi '^(vendor_id\s*:\s*(AuthenticAMD|GenuineIntel))' /proc/cpuinfo; then
  vendor=$(grep -m1 'vendor_id' /proc/cpuinfo | cut -d':' -f2 | tr -d '[:space:]')
  case $vendor in
    AuthenticAMD|AMD)
      modulename=kvm_amd
      confname=/etc/modprobe.d/kvm-amd.conf ;;
    GenuineIntel|Intel)
      modulename=kvm_intel
      confname=/etc/modprobe.d/kvm-intel.conf ;;
  esac

  echo " • Processor: $vendor — enabling nested virtualization via $modulename"
  if modprobe -r "$modulename"; then
    modprobe "$modulename" nested=1
    echo "modprobe:$modulename nested=1" > "$modulename"‑nested‑yes
  else
    echo "WARNING: unable to remove $modulename module; maybe in use."; fi

  echo "options $modulename nested=1" > "$confname"
  echo "(Wrote persistent nested=1 option to $confname)"

  echo "• Verifying nested status:"
  cat "/sys/module/${modulename}/parameters/nested" || true
  echo
else
  echo "• CPU vendor not recognized; skipping nested virtualization."
fi

echo "➤ Enabling and starting tuned.service"
systemctl enable --now tuned.service
tuned-adm profile virtual-host

echo "✓ Done. Reboot recommended for newgroup, nested config, and everything to take full effect."

