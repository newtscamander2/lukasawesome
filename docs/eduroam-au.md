# Eduroam @ Aarhus University (laptop)

How to get the laptop onto AU's `eduroam` wifi. The desktop is wired and
doesn't need any of this.

Everything below assumes the dotfiles are installed (`make install`), which
pulls in NetworkManager, `nm-applet` (tray GUI, autostarted by awesome),
`nm-connection-editor`, and `python-dbus`.

## AU account facts

| Setting            | Value                                            |
|--------------------|--------------------------------------------------|
| SSID               | `eduroam`                                        |
| Security           | WPA2/WPA3 Enterprise (802.1X)                    |
| EAP method         | PEAP                                             |
| Phase 2 auth       | MSCHAPv2                                         |
| Username           | `au<AUID>@uni.au.dk` (e.g. `au123456@uni.au.dk`) |
| Password           | same as mit.au.dk / mitstudie.au.dk              |

The same credentials work at every eduroam-participating university worldwide.

## Recommended: eduroam CAT installer

The CAT installer pins AU's CA certificate and RADIUS server name, so the
laptop won't hand credentials to a rogue "eduroam" access point. Prefer this
over clicking through the applet.

1. Download the AU Linux profile (a Python script) from
   <https://cat.eduroam.org/?idp=531&profile=855>
   (or cat.eduroam.org → "Click here to download your eduroam installer" →
   Aarhus University).
2. Run it as your normal user — no sudo:

   ```bash
   python3 ~/Downloads/eduroam-linux-AU*.py
   ```

3. Enter username (`au<AUID>@uni.au.dk`) and your AU password when prompted.
   The script installs the CA certificate under `~/.config/cat_installer/`
   and creates the NetworkManager connection.
4. Connect: click the nm-applet tray icon → `eduroam`, or

   ```bash
   nmcli connection up eduroam
   ```

## Fallback: manual setup

Via GUI: nm-applet tray icon → pick `eduroam` → in the dialog choose
*PEAP* / *MSCHAPv2*, username/password as above. (Skipping CA-certificate
validation is what the dialog will offer — accept only if the CAT route is
unavailable; it's the less safe path.)

Via CLI:

```bash
nmcli connection add type wifi con-name eduroam ssid eduroam \
    wifi-sec.key-mgmt wpa-eap \
    802-1x.eap peap \
    802-1x.phase2-auth mschapv2 \
    802-1x.identity "au123456@uni.au.dk" \
    802-1x.password-flags 1     # prompt for password, don't store plaintext
nmcli --ask connection up eduroam
```

## Troubleshooting

```bash
nmcli device wifi list                   # is eduroam visible?
nmcli connection show eduroam            # inspect stored 802.1X settings
journalctl -u NetworkManager -f          # watch the auth handshake live
nmcli connection delete eduroam          # nuke and redo via CAT installer
```

- Auth failures are almost always the username format — it's the **auID**
  with `@uni.au.dk`, not the student mail address.
- After an AU password change, NetworkManager keeps retrying the old one and
  the account can get temporarily locked — update the password in
  `nm-connection-editor` right away.
- AU help: <https://eduroam.au.dk/en/>
