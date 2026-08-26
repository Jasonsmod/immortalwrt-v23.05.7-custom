include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-openvpn-server-custom
PKG_VERSION:=1.1.0
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=Jasonsmod
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-openvpn-server-custom
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=Secure OpenVPN server and multi-client management for LuCI
  DEPENDS:=+luci-base +luci-compat +openvpn-openssl +openvpn-easy-rsa +kmod-tun
endef

define Package/luci-app-openvpn-server-custom/description
 Provides a LuCI interface for a secure OpenVPN server and multiple
 independently managed OpenVPN client profiles.
endef

define Package/luci-app-openvpn-server-custom/conffiles
/etc/config/openvpn_server
/etc/config/openvpn_client_custom
endef

define Build/Compile
endef

define Package/luci-app-openvpn-server-custom/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/openvpn_server $(1)/etc/config/openvpn_server
	$(INSTALL_CONF) ./files/etc/config/openvpn_client_custom $(1)/etc/config/openvpn_client_custom
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/90-openvpn-server-custom $(1)/etc/uci-defaults/90-openvpn-server-custom
	$(INSTALL_DIR) $(1)/usr/libexec
	$(INSTALL_BIN) ./files/usr/libexec/openvpn-server-manager $(1)/usr/libexec/openvpn-server-manager
	$(INSTALL_BIN) ./files/usr/libexec/openvpn-server-auth $(1)/usr/libexec/openvpn-server-auth
	$(INSTALL_BIN) ./files/usr/libexec/openvpn-server-client-check $(1)/usr/libexec/openvpn-server-client-check
	$(INSTALL_BIN) ./files/usr/libexec/openvpn-client-manager $(1)/usr/libexec/openvpn-client-manager
	chmod 0700 $(1)/usr/libexec/openvpn-server-manager
	chmod 0755 $(1)/usr/libexec/openvpn-server-auth
	chmod 0755 $(1)/usr/libexec/openvpn-server-client-check
	chmod 0700 $(1)/usr/libexec/openvpn-client-manager
	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	$(INSTALL_DATA) ./files/lib/upgrade/keep.d/openvpn-server-custom $(1)/lib/upgrade/keep.d/openvpn-server-custom
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/controller/openvpn_server_custom.lua $(1)/usr/lib/lua/luci/controller/openvpn_server_custom.lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/openvpn-server-custom
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/model/cbi/openvpn-server-custom/server.lua $(1)/usr/lib/lua/luci/model/cbi/openvpn-server-custom/server.lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/openvpn-server-custom
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/openvpn-server-custom/server-actions.htm $(1)/usr/lib/lua/luci/view/openvpn-server-custom/server-actions.htm
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/openvpn-server-custom/server-client-extra.htm $(1)/usr/lib/lua/luci/view/openvpn-server-custom/server-client-extra.htm
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/openvpn-server-custom/account-list.htm $(1)/usr/lib/lua/luci/view/openvpn-server-custom/account-list.htm
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/openvpn-server-custom/client-list.htm $(1)/usr/lib/lua/luci/view/openvpn-server-custom/client-list.htm
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/openvpn-server-custom/client-edit.htm $(1)/usr/lib/lua/luci/view/openvpn-server-custom/client-edit.htm
endef

$(eval $(call BuildPackage,luci-app-openvpn-server-custom))
