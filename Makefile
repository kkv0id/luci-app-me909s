#
# Copyright (C) 2025
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-me909s
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

# LuCI 特定定义
LUCI_TITLE:=ME909s - web config for the ME909s modem
LUCI_DEPENDS:=+libpthread +libuci-lua +luci-compat +luci-base
LUCI_PKGARCH:=all

# 标准包定义
define Package/$(PKG_NAME)
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=$(LUCI_TITLE)
	DEPENDS:=$(LUCI_DEPENDS)
	PKGARCH:=$(LUCI_PKGARCH)
endef

define Package/$(PKG_NAME)/description
	Web interface configuration for ME909s LTE modem
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	cp -r ./src/* $(PKG_BUILD_DIR)/
	cp -r ./resources $(PKG_BUILD_DIR)/
	cp -r ./luasrc $(PKG_BUILD_DIR)/
	cp -r ./files $(PKG_BUILD_DIR)/
endef


# 安装到目标系统
define Package/$(PKG_NAME)/install	
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	cp -rp $(PKG_BUILD_DIR)/luasrc/* $(1)/usr/lib/lua/luci/

	$(INSTALL_DIR) $(1)/www/luci-static/resources/
	cp -rp $(PKG_BUILD_DIR)/resources/* $(1)/www/luci-static/resources/

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/files/me909s.config $(1)/etc/config/me909s

	$(INSTALL_DIR) $(1)/lib/netifd/proto
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/files/ecm.proto $(1)/lib/netifd/proto/ecm.sh

	$(INSTALL_DIR) $(1)/etc/hotplug.d/usb
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/files/ecm.usb $(1)/etc/hotplug.d/usb/00-ecm.sh

	$(INSTALL_DIR) $(1)/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/files/me909s.sh $(1)/lib/
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/sendat $(1)/usr/bin/

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/me909s.init $(1)/etc/init.d/me909s

	$(INSTALL_DIR) $(1)/lib/network/wwan
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/files/data/* $(1)/lib/network/wwan/
	shopt -s nullglob ; \
	for filevar in $(1)/lib/network/wwan/*-* ; \
	do \
		FILENAME=$$$$(basename $$$$filevar) ; \
		NEWNAME=$$$${FILENAME//-/:} ; \
		mv "$(1)/lib/network/wwan/$$$$FILENAME" "$(1)/lib/network/wwan/$$$$NEWNAME" ; \
	done
endef

$(eval $(call BuildPackage,$(PKG_NAME)))