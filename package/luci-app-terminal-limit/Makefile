include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-terminal-limit
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=Jasonsmod
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-terminal-limit
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI terminal bandwidth limit
  DEPENDS:=+luci-base +luci-compat +luci-app-sqm +sqm-scripts +jsonfilter +tc +nftables +kmod-nft-bridge +kmod-sched-cake +kmod-sched-flower
endef

define Package/luci-app-terminal-limit/description
 Provides per-IP and per-MAC terminal bandwidth limits with SQM qdisc support.
endef

define Package/luci-app-terminal-limit/conffiles
/etc/config/terminal_limit
endef

define Build/Compile
endef

define Package/luci-app-terminal-limit/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/terminal_limit $(1)/etc/config/terminal_limit
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/terminal_limit $(1)/etc/init.d/terminal_limit
	$(INSTALL_DIR) $(1)/usr/libexec
	$(INSTALL_BIN) ./files/usr/libexec/terminal-limit-manager $(1)/usr/libexec/terminal-limit-manager
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/controller/terminal_limit.lua $(1)/usr/lib/lua/luci/controller/terminal_limit.lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/terminal-limit
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/terminal-limit/list.htm $(1)/usr/lib/lua/luci/view/terminal-limit/list.htm
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/terminal-limit/edit.htm $(1)/usr/lib/lua/luci/view/terminal-limit/edit.htm
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./files/usr/share/rpcd/acl.d/luci-app-terminal-limit.json $(1)/usr/share/rpcd/acl.d/luci-app-terminal-limit.json
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/90-terminal-limit $(1)/etc/uci-defaults/90-terminal-limit
endef

define Package/luci-app-terminal-limit/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/terminal_limit enable >/dev/null 2>&1 || true
/etc/init.d/terminal_limit start >/dev/null 2>&1 || true
rm -f /tmp/luci-indexcache
/etc/init.d/rpcd restart >/dev/null 2>&1 || true
exit 0
endef

define Package/luci-app-terminal-limit/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/terminal_limit stop >/dev/null 2>&1 || true
/etc/init.d/terminal_limit disable >/dev/null 2>&1 || true
exit 0
endef

$(eval $(call BuildPackage,luci-app-terminal-limit))
