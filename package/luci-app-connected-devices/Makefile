include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-connected-devices
PKG_VERSION:=1.0.0
PKG_RELEASE:=2

PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=Jasonsmod
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-connected-devices
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI connected devices status panel
  DEPENDS:=+luci-base +luci-mod-status +rpcd-mod-iwinfo
endef

define Package/luci-app-connected-devices/description
 Adds a connected devices panel to the LuCI status overview page.
 It combines static assignments, DHCP leases, LAN neighbors and WiFi associations.
endef

define Build/Compile
endef

define Package/luci-app-connected-devices/install
	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) ./files/usr/libexec/rpcd/luci.connected-devices $(1)/usr/libexec/rpcd/luci.connected-devices
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./files/usr/share/rpcd/acl.d/luci-app-connected-devices.json $(1)/usr/share/rpcd/acl.d/luci-app-connected-devices.json
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/status/include
	$(INSTALL_DATA) ./files/www/luci-static/resources/view/status/include/45_connected_devices.js $(1)/www/luci-static/resources/view/status/include/45_connected_devices.js
endef

define Package/luci-app-connected-devices/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
rm -f /tmp/luci-indexcache
/etc/init.d/rpcd restart >/dev/null 2>&1 || true
exit 0
endef

$(eval $(call BuildPackage,luci-app-connected-devices))
