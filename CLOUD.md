# Vapaaehtoinen Codex Cloud -asennus

Paikallinen asennus riittää, kun tekoälyä käytetään omalla Windows-koneella. Tämä vaihe tarvitaan puhelinkäyttöön läppärin ollessa kiinni. Suositus on yksi eristetty Railway-palvelu jokaista käyttäjää kohti, yhdessä yrityksen hosting-tilissä jos ylläpitäjä niin päättää.

## Mitä tarvitaan

- Käyttäjälle pääsy tähän yksityiseen GitHub-repoon ja Codex Cloudiin.
- Käyttäjä tai ylläpitäjä, jolla on Railway-projektien luontioikeus ja hyväksyntä hosting-kustannuksiin. Uusi palvelu kuluttaa Railway-resursseja; vanha noin 5 euron Hobby-tilaus ei tarkoita rajatonta palvelumäärää.
- Oma toimiva sähköpostiosoite ja salasana, oma satunnainen vähintään 32 tavun yhteystunniste.

Palvelu lukee sähköpostia ja tallentaa luonnoksia IMAPilla. SMTP-lähetystä ei ole tässä paketissa. Railway Hobbylla voi käyttää tätä luku/luonnospalvelua; SMTP edellyttäisi vähintään Pro-pakettia ja erillistä toteutusta. [Railwayn rajoitus](https://docs.railway.com/networking/outbound-networking).

## Railway: käyttäjän oma palvelu

1. Luo uusi projekti ja palvelu käyttäjälle, esimerkiksi `mail-bridge-oma-nimi`. Valitse tämän repon Dockerfile. Palvelu käyttää porttia 8080 tai Railwayn PORT-muuttujaa.
2. Lisää Railway Variables -asetuksiin:

| Muuttuja | Arvo |
|---|---|
| `VALUATUM_MAIL_ACCOUNT` | Käyttäjän oma sähköpostiosoite |
| `VALUATUM_MAIL_PASSWORD` | Käyttäjän sähköpostisalasanan salainen arvo |
| `VALUATUM_MAIL_HOST` | `mail.valuatum.com` |
| `VALUATUM_DRAFTS_FOLDER` | `INBOX.Drafts`, ellei tilin kansio ole muu |
| `MAIL_BRIDGE_TOKEN` | Uusi satunnainen pitkä tunniste vain tätä käyttäjää varten |
| `PORT` | `8080` |

Anna salasana Railwayn asetuspaneelissa tai paikallisessa salatussa syöttöikkunassa, josta ylläpitäjän hyväksymä asennus toimittaa sen Railwayhin. Salasana tai tunniste eivät kuulu chattiin, GitHubiin, Docker-imageen tai deploy-lokeihin. Älä käytä Laurin tunnistetta.

3. Julkaise palvelu. Luo Railway HTTPS domain kohdeporttiin 8080. Tallenna sen URL ilman loppupolkua.
4. Testaa `/health`, väärän tunnisteen hylkäys ja kirjautuminen `list_folders`-kutsulla. JSON-pyynnössä on `account`, `name` ja `arguments`; palvelu hylkää toisen sähköpostiosoitteen ja vastaa oman tilin identiteetillä. Health-vastaus yksin ei todista sähköpostiyhteyttä.

HTTPS `/tools/call` on oma JSON-rajapinta, ei suoraan MCP-osoite. Cloudin runtime.py toimii sen MCP-sovittimena.

## Codex Cloud: käyttäjän oma ympäristö

1. Luo ympäristö tästä reposta. Rajaa käyttö **Only me** tai määritä yrityksen käyttäjäkohtainen secret-malli. Yhteinen ympäristö ei saa sisältää jaettuja postilaatikkotunnuksia.
2. Lisää environment variables:
   - `VALUATUM_MAIL_ACCOUNT`: oma sähköpostiosoite.
   - `MAIL_BRIDGE_URL`: käyttäjän oman Railway-palvelun HTTPS-osoite.
   - `VALUATUM_DRAFTS_FOLDER`: oman tilin Luonnokset-kansio.
3. Lisää **network secret** `MAIL_BRIDGE_TOKEN` ja rajaa Allowed domains oman Railway-palvelun täsmälliseen hostnamen. Lisää hostname ympäristön verkkoasetuksiin. Cloud ei tarvitse sähköpostisalasanan kopiota.
4. Anna setup-chatille:

> Lue AGENTS.md ja CLOUD.md. Asenna requirements.txt omaan virtuaaliympäristöön. Käytä runtime.py:ta stdio MCP -palvelimena; rekisteröi valuatum_mail käyttäen virtuaaliympäristön Pythonin ja runtime.py:n absoluuttisia polkuja. Käytä valmiiksi annettuja ympäristömuuttujia ja network secretiä. Testaa runtime.py --check ja sähköpostin haku. Älä lähetä mitään. Tee vain erikseen pyytämäni testiluonnos ja varmista sen löytyminen. Julkaise ympäristö, kun testit onnistuvat.

5. Julkaise ympäristö ja avaa siitä uusi Cloud-chat puhelimella. Testaa yhden viestin lukeminen ja luonnos, kun läppäri on pois päältä. Pelkkä onnistunut Railway-testi ei vielä todista puhelimen Cloud-yhteyttä.

Codex Cloudin secret- ja julkaisuasetukset voivat vaatia käyttäjän omat klikkaukset; tekoäly kertoo ne yksi vaihe kerrallaan. Käytä [virallista Cloud-ohjetta](https://learn.chatgpt.com/docs/environments/cloud-environments) ja sen nykyisiä asetuksia. Tavalliset chatit tarvitsevat saman julkaistun ympäristön; asetukset eivät automaattisesti siirry kaikkiin ChatGPT-keskusteluihin.

## Kustannukset ja käyttöoikeudet

Yrityksen ylläpitäjän kannattaa luoda palvelut keskitetysti ja pitää kollegan osuus osoitteen/salasanan syöttämisenä sekä Cloudin henkilökohtaisen tunnisteen lisäämisenä. Palvelu on eristetty käyttäjäkohtaisesti, mutta Railway-workspacen ylläpitäjillä voi olla pääsy sen salaisiin asetuksiin. Kerro tämä käyttäjälle ennen salasanan tallennusta. Tämä ei ole päästä päähän salattu salasanasäilö suhteessa hostingin ylläpitäjään.

Kun käyttäjä poistuu yrityksestä tai yhteys suljetaan, poista hänen palvelunsa, Cloud-tunnisteensa ja MCP-rekisteröintinsä. Vaihdetun sähköpostisalasanan voi päivittää oman palvelun Variables-asetuksessa. Palvelun tunnisteen vaihto vaatii vastaavan Cloud network secretin päivityksen.
