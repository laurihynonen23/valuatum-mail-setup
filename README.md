# Valuatumin sähköposti Codexiin ja Claude Codeen

Tämä paketti antaa tekoälylle pääsyn **omaan** sähköpostiisi: viestien lukeminen, haku ja luonnosten tallennus Thunderbirdiin. Se ei lähetä viestejä eikä poista niitä. Thunderbirdin ei tarvitse olla auki. Repo: [valuatum-mail-setup](https://github.com/laurihynonen23/valuatum-mail-setup).

**Suositus: aloita paikallisella asennuksella.** Railwayta, puhelinta tai selaimen hallintaa ei tarvita. Cloud-käyttö on erillinen, vapaaehtoinen vaihe.

## Kollegan aloitus

Anna alla oleva teksti Codexille tai Claude Codelle. Käytä tämän repon osoitetta. Jos GitHub pyytää kirjautumista, kirjaudu itse. Ylläpitäjän pitää ensin antaa sinulle pääsy yksityiseen repoon; vaihtoehtoisesti saat saman paketin ZIP-tiedostona.

> Asenna minulle Valuatum-sähköpostiyhteys Windowsiin reposta https://github.com/laurihynonen23/valuatum-mail-setup. Kloonaa repo tai käytä saamaani ZIP-pakettia. Lue ensin AGENTS.md ja README.md. Aloita paikallisesta käytöstä. Tarkista Python ja käyttämäni Codex/Claude Code, asenna puuttuvat edellytykset virallisista lähteistä ja suorita install.ps1. Avaa paikallinen kirjautumisikkuna, johon annan oman sähköpostini ja salasanani. Salasanaa ei saa pyytää chattiin. Testaa yhteys ilman viestien lähettämistä. Älä muuta olemassa olevia muita MCP-yhteyksiä tai tekoälyn yleisiä lupia. Jos jokin vaatii minulta klikkausta, anna täsmällinen ohje. Cloudia ei tarvitse asentaa vielä.

Tekoäly hoitaa tiedostot, Python-ympäristön, riippuvuudet, sähköpostiyhteyden ja skillin asennuksen. Sinä annat oman osoitteesi ja salasanasi sekä hyväksyt ohjelman tai työkalun pyytämät oikeudet. Tekoäly voi tarvita lupaa komentojen suorittamiseen ja omien käyttäjäasetustesi kirjoittamiseen. Full access ei ole edellytys, eikä asennus muuta sitä.

## Jos asennat itse

1. Asenna **Python 3.10 tai uudempi** [virallisesta lähteestä](https://www.python.org/downloads/windows/). Ota Python PATHiin ja avaa uusi PowerShell. Asenna tai ota käyttöön valitsemasi Codex CLI / Claude Code CLI. Pelkkä tavallinen Claude-chat ei riitä; Claude Code on erillinen tuote.
2. Lataa tai kloonaa tämä repo. Avaa PowerShell repon kansioon.
3. Suorita sopiva komento:

```powershell
# Codex
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\install.ps1 -Clients codex

# Claude Code
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\install.ps1 -Clients claude

# Molemmat
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\install.ps1 -Clients both
```

4. Anna **oma** Valuatum-sähköpostisi ja sähköpostisalasanasi avautuvaan ikkunaan. Paina **Verify and save**. Asennus testaa IMAP-kirjautumisen ja Luonnokset-kansion ennen tallennusta. Jos kirjautuminen epäonnistuu, korjaa tiedot samassa ikkunassa.
5. Käynnistä valitsemasi tekoälysovellus uudelleen. Hyväksy sähköpostityökalun käyttö, jos sovellus kysyy. Pyydä: **“Lue uusimman sähköpostini otsikko.”** Sen jälkeen voit pyytää: **“Tee luonnos itselleni aiheella Yhteystesti ja tekstillä Tämä on luonnos.”** Tarkista luonnos Thunderbirdissä. Mitään ei lähetetä.

Asennus tallentaa ohjelman ja asetukset kansioon `%LOCALAPPDATA%\ValuatumMail`, tekee oman Python-ympäristön ja rekisteröi `valuatum_mail`-yhteyden. Salasana on Windows DPAPI -salattu nykyiselle käyttäjälle ja koneelle; se ei siirry repoon eikä muille kollegoille. Tekoäly saa käyttöönsä myös sähköposti-skillin.

Jos samanniminen yhteys tai skilli on jo olemassa, asennus säilyttää sen. Tällöin tekoälyn pitää tarkistaa, osoittaako olemassa oleva yhteys tähän asennukseen; vanhaa yhteyttä ei korvata hiljaisesti.

## Tavalliset ongelmat

| Tilanne | Mitä tehdään |
|---|---|
| Repo ei aukea | Pyydä ylläpitäjältä GitHub-käyttöoikeus tai ZIP. |
| `Python ... required` | Asenna Python ja avaa uusi PowerShell. |
| `Codex CLI ... required` | Ota Codex CLI käyttöön; tekoäly voi tarkistaa myös desktopin mukana tulevan CLI:n polun. |
| `Claude Code CLI ... required` | Asenna Claude Code. Claude Desktopin oma MCP-asetus ei ole tämän asentimen automaattinen kohde. |
| Login failed | Tarkista sähköpostiosoite ja sähköpostisalasanasi. Osoite, salasana ja IMAP 993 pitää toimia tällä koneella. |
| Luonnoskansio puuttuu | Palvelin tai kansiopolku poikkeaa oletuksesta. Tekoäly tarkistaa Thunderbirdin tiliasetukset ja korjaa `drafts_folder`-asetuksen. Salasanaa ei lueta Thunderbirdistä. |
| Tekoäly ei löydä työkaluja | Käynnistä sovellus uudelleen ja tarkista `valuatum_mail` MCP-asetuksista. |
| Vaihdoit salasanaa | Suorita alla oleva configure-komento uudelleen. |

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\ValuatumMail\configure.ps1"

# Kirjautumistesti, ei luo eikä lähetä viestejä
& "$env:LOCALAPPDATA\ValuatumMail\venv\Scripts\python.exe" "$env:LOCALAPPDATA\ValuatumMail\runtime.py" --check
```

## Cloud on vapaaehtoinen

Jos haluat käyttää sähköpostia puhelimesta **läppärin ollessa kiinni**, lue [CLOUD.md](CLOUD.md). Jokaisella käyttäjällä on oma Railway-palvelu, oma sähköpostisalasanansa ja oma yhteystunnisteensa. Laurin palvelua tai tunnistetta ei käytetä kollegan asennuksessa.

Cloud vaatii hostingin käyttöoikeuden ja hyväksytyn laskutuksen sekä Codex Cloud -ympäristön ja sen henkilökohtaiset asetukset. Paikallinen asennus toimii ilman näitä. Tavallinen uusi ChatGPT-chat ei automaattisesti peri sähköpostiyhteyttä.

## Ylläpitäjälle

- Anna kollegoille pääsy tähän repoon tai toimita ZIP. Älä sisällytä ZIPiin käyttäjäkohtaisia asetuksia tai credential.xml-tiedostoja.
- Pilotoi asennus yhden kollegan Windows-koneella ennen yleistä jakelua. Tarkista kirjautuminen, työkalujen näkyminen uudessa chatissa ja luonnoksen ilmestyminen Thunderbirdiin.
- Paketti on testattu eristetyillä automatisoiduilla testeillä. Se ei tarkoita, että jokaisen kollegan Python-, Codex- tai Claude-asennus olisi jo testattu.
- Päivitys: lataa uusi versio ja aja install.ps1 uudelleen. Omat tiliasetukset, salasana ja muut MCP-yhteydet säilyvät. Olemassa oleva skilli päivitetään vasta käyttäjän hyväksymällä korvaamisella.
- Lopetus: poista `valuatum_mail` valitun tekoälyn MCP-asetuksista ja omat `%LOCALAPPDATA%\ValuatumMail`-tiedostot. Cloudissa poista lisäksi oma Railway-palvelu ja Cloudin henkilökohtaiset tunnisteet.
