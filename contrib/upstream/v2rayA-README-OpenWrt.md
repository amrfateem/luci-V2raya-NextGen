# v2rayA README: OpenWrt sections

Replace the existing `<details><summary><strong>OpenWrt</strong></summary>`
block in each file. Do this after the OpenWrt package is actually available.

## README.md (English)

```html
<details>
<summary><strong>OpenWrt</strong></summary>

The official OpenWrt packages feed carries v2rayA 2.5.13 and the matching
`v2raya_core` as the `v2raya` and `v2raya-core` packages. Install both, then
enable the service:

```sh
# OpenWrt 23.05 / 24.10
opkg update
opkg install v2raya v2raya-core

# OpenWrt 25.12
apk add v2raya v2raya-core

uci set v2raya.config.enabled='1'
uci commit v2raya
/etc/init.d/v2raya restart
```

Rule data is optional. Install `v2ray-geoip` and `v2ray-geosite` for offline
use, or let v2rayA download the files on first start. The LuCI app is
`luci-app-v2raya`.

The old 2.2.7.x package used a separate `xray-core`; it is obsolete for
2.5.x.

</details>
```

## README_zh.md

```html
<details>
<summary><strong>OpenWrt</strong></summary>

OpenWrt 官方 packages 源已提供 v2rayA 2.5.13 及配套的 `v2raya_core`，包名为
`v2raya` 和 `v2raya-core`。安装两者后启用服务：

```sh
# OpenWrt 23.05 / 24.10
opkg update
opkg install v2raya v2raya-core

# OpenWrt 25.12
apk add v2raya v2raya-core

uci set v2raya.config.enabled='1'
uci commit v2raya
/etc/init.d/v2raya restart
```

规则数据是可选的。离线使用可安装 `v2ray-geoip` 和 `v2ray-geosite`，否则
v2rayA 会在首次启动时下载。LuCI 应用为 `luci-app-v2raya`。

旧的 2.2.7.x 软件包使用独立的 `xray-core`，在 2.5.x 中已不再适用。

</details>
```

## README_ru.md

```html
<details>
<summary><strong>OpenWrt</strong></summary>

Официальный репозиторий пакетов OpenWrt содержит v2rayA 2.5.13 и
соответствующий `v2raya_core` в пакетах `v2raya` и `v2raya-core`. Установите
оба пакета и включите службу:

```sh
# OpenWrt 23.05 / 24.10
opkg update
opkg install v2raya v2raya-core

# OpenWrt 25.12
apk add v2raya v2raya-core

uci set v2raya.config.enabled='1'
uci commit v2raya
/etc/init.d/v2raya restart
```

Данные правил необязательны. Для работы без сети установите `v2ray-geoip` и
`v2ray-geosite`; иначе v2rayA загрузит их при первом запуске. Приложение
LuCI — `luci-app-v2raya`.

Старый пакет 2.2.7.x использовал отдельный `xray-core`; для 2.5.x он устарел.

</details>
```
