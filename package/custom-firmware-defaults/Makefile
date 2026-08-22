include $(TOPDIR)/rules.mk

PKG_NAME:=custom-firmware-defaults
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=Jasonsmod

include $(INCLUDE_DIR)/package.mk

define Package/custom-firmware-defaults
  SECTION:=base
  CATEGORY:=Base system
  TITLE:=Custom defaults for the multi-target ImmortalWrt firmware
  DEPENDS:=+base-files +uci
endef

define Package/custom-firmware-defaults/description
 Applies the requested root password, Argon theme and package mirror.
endef

Build/Compile =

define Package/custom-firmware-defaults/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/99-custom-firmware $(1)/etc/uci-defaults/99-custom-firmware
	$(INSTALL_DIR) $(1)/etc/dnsmasq.d
	$(INSTALL_DATA) ./files/etc/dnsmasq.d/00-custom.conf $(1)/etc/dnsmasq.d/00-custom.conf
	$(INSTALL_DIR) $(1)/etc/sysctl.d
	$(INSTALL_DATA) ./files/etc/sysctl.d/13-custom-fq.conf $(1)/etc/sysctl.d/13-custom-fq.conf
endef

$(eval $(call BuildPackage,custom-firmware-defaults))
