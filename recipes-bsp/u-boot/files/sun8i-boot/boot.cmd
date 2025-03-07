# DO NOT EDIT THIS FILE
#
# Please edit /boot/allwinnerEnv.txt to set supported parameters
#

# default values
setenv load_addr "0x45000000"
setenv overlay_error "false"
# default values
setenv verbosity "1"
setenv disp_mem_reserves "off"
setenv disp_mode "1920x1080p60"
setenv rootfstype "ext4"
setenv console "both"
setenv docker_optimizations "on"
setenv devnum "0"
setenv rootdev "/dev/mmcblk${devnum}p2"

# Print boot source
itest.b *0x28 == 0x00 && echo "U-boot loaded from SD"
itest.b *0x28 == 0x02 && echo "U-boot loaded from eMMC or secondary SD"
itest.b *0x28 == 0x03 && echo "U-boot loaded from SPI"

# get PARTUUID of first partition on SD/eMMC it was loaded from
# mmc 0 is always mapped to device u-boot (2016.09+) was loaded from
if test "${devtype}" = "mmc"; then
  part uuid mmc ${devnum}:1 partuuid;
  setenv devnum ${mmc_bootdev}
fi

echo "Boot script loaded from ${devtype}"

# Check if boot and OS partitions are the same
if test -e ${devtype} ${devnum}:1 /sbin/init; then
  echo "Combined boot and rootfs partition detected"
fi

if test -e ${devtype} ${devnum} ${prefix}allwinnerEnv.txt; then
	echo "Loading ${prefix}allwinnerEnv.txt..."
	load ${devtype} ${devnum} ${load_addr} ${prefix}allwinnerEnv.txt
	env import -t ${load_addr} ${filesize}
	echo "New verbosity: ${verbosity}"
fi

if test "${logo}" = "disabled"; then setenv logo "logo.nologo"; fi

if test "${console}" = "display" || test "${console}" = "both"; then setenv consoleargs "console=ttyS0,115200 console=tty1"; fi
if test "${console}" = "serial"; then setenv consoleargs "console=ttyS0,115200"; fi

# get PARTUUID of first partition on SD/eMMC it was loaded from
# mmc 0 is always mapped to device u-boot (2016.09+) was loaded from
if test "${devtype}" = "mmc"; then part uuid mmc 0:1 partuuid; fi

setenv bootargs "root=${rootdev} rootwait rootfstype=${rootfstype} ${consoleargs} hdmi.audio=EDID:0 disp.screen0_output_mode=${disp_mode} panic=10 consoleblank=0 loglevel=${verbosity} ubootpart=${partuuid} ubootsource=${devtype} usb-storage.quirks=${usbstoragequirks} ${extraargs} ${extraboardargs}"

if test "${disp_mem_reserves}" = "off"; then setenv bootargs "${bootargs} sunxi_ve_mem_reserve=0 sunxi_g2d_mem_reserve=0 sunxi_fb_mem_reserve=16"; fi
if test "${docker_optimizations}" = "on"; then setenv bootargs "${bootargs} cgroup_enable=memory swapaccount=1"; fi

load ${devtype} ${devnum} ${kernel_addr_r} ${prefix}zImage || load ${devtype} ${devnum} ${kernel_addr_r} ${prefix}uImage
load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}${fdtfile}

fdt addr ${fdt_addr_r}
fdt resize 65536
# Load overlays
for overlay_file in ${overlays}; do
	if load ${devtype} ${devnum} ${load_addr} ${prefix}overlay/${overlay_prefix}-${overlay_file}.dtbo; then
		echo "Applying kernel provided DT overlay ${overlay_prefix}-${overlay_file}.dtbo"
		fdt apply ${load_addr} || setenv overlay_error "true"
	fi
done

if test "${overlay_error}" = "true"; then
	echo "Error applying DT overlays, restoring original DT"
	load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}${fdtfile}
else
	if test -e ${devtype} ${devnum} ${prefix}fixup.scr; then
		load ${devtype} ${devnum} ${load_addr} ${prefix}fixup.scr
		echo "Applying user provided fixup script (fixup.scr)"
		source ${load_addr}
	fi
fi

bootz ${kernel_addr_r} - ${fdt_addr_r} || bootm ${kernel_addr_r} - ${fdt_addr_r}

# Recompile with:
# mkimage -C none -A arm -T script -d boot/boot.cmd boot/boot.scr
