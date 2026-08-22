#!/bin/sh

# 主题：仅 Argon 会被目标配置选入固件。
# 采用面向 OpenWrt 23.05 的分支，兼容 ImmortalWrt 23.05.7。
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-23.05"

# 代理与组网源码。
UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
# 23.05 的 Kconfig 无法同时处理 mihomo 的两个互斥 PROVIDES 实现，保留默认的
# mihomo-meta，排除 mihomo-alpha，避免生成 PACKAGE_mihomo-alpha 与
# PACKAGE_mihomo-meta 的递归依赖。
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main" "" "mihomo-alpha"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "master" "luci-app-openclash"
OPENCLASH_INIT="$CUSTOM_PACKAGE_DIR/openclash/root/etc/init.d/openclash"
[ -f "$OPENCLASH_INIT" ] || fail "OpenClash 缺少启动脚本"
if grep -Eq '^[[:space:]]*procd_kill "openclash"[[:space:]]*$' "$OPENCLASH_INIT"; then
	sed -i '/^[[:space:]]*procd_kill "openclash"[[:space:]]*$/c\      procd_running "openclash" >/dev/null 2>&1 && procd_kill "openclash" >/dev/null 2>&1 || true' "$OPENCLASH_INIT"
fi
grep -Fq 'procd_running "openclash" >/dev/null 2>&1 && procd_kill "openclash" >/dev/null 2>&1 || true' "$OPENCLASH_INIT" || fail "无法修复 OpenClash procd 停止逻辑"
UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "luci-app-passwall"
UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "luci-app-passwall2"
UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"

# 其他保留源码；除清单明确选中的包外，不会默认编译进固件。
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main" "" "ddns-go"
# 固定的 23.05 packages feed 尚未提供阿里云 DDNS 扩展，单独补充该包。
UPDATE_PACKAGE "ddns-scripts-aliyun" "sbwml/openwrt-package" "main" "ddns-scripts-aliyun"
UPDATE_PACKAGE "diskmanager" "4IceG/luci-app-mini-diskmanager" "main"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
UPDATE_PACKAGE "luci-app-mosdns" "sbwml/luci-app-mosdns" "v5" "luci-app-mosdns"
UPDATE_PACKAGE "v2dat" "sbwml/luci-app-mosdns" "v5" "v2dat"
MOSDNS_BASIC_JS="$CUSTOM_PACKAGE_DIR/luci-app-mosdns/htdocs/luci-static/resources/view/mosdns/basic.js"
[ -f "$MOSDNS_BASIC_JS" ] || fail "luci-app-mosdns 缺少 LuCI 页面资源 basic.js"
UPDATE_PACKAGE "netwizard" "sirpdboy/luci-app-netwizard" "main"
UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main" "" "qfirehose"
UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"
UPDATE_PACKAGE "timecontrol" "sirpdboy/luci-app-timecontrol" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "axonhub gecoosac luci-app-axonhub luci-app-gecoosac sing-box luci-app-homeproxy luci-app-timewol luci-app-wolplus luci-app-wolultra"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"

# 当前 PassWall 的自定义配置菜单在 ImmortalWrt 23.05 上会与自身包符号形成
# PACKAGE_luci-app-passwall <-> PACKAGE_luci-app-passwall_INCLUDE_* 递归依赖。
PASSWALL_MAKEFILE="$CUSTOM_PACKAGE_DIR/passwall/Makefile"
if [ -f "$PASSWALL_MAKEFILE" ] && grep -Fq 'depends on PACKAGE_$(PKG_NAME)' "$PASSWALL_MAKEFILE"; then
	sed -i '\|^[[:space:]]*depends on PACKAGE_\$(PKG_NAME)[[:space:]]*$|d' "$PASSWALL_MAKEFILE"
	printf '已应用 PassWall 23.05 Kconfig 兼容修复。\n'
fi

# 按用户要求，不保留：qbittorrent、partexp、diskman、netspeedtest、
# athena-led、Aurora、Kucat、NoobWrt、Shadcn、Fluent 及其配置包。
