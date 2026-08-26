# FERRO — Publicació a Internet

App de rutines de gimnàs (una sola pàgina HTML) amb:
- **Hosting gratuït**: GitHub Pages
- **Login individual (Google)**: Supabase (pla gratuït)
- **Dades al núvol**: Supabase (una taula per usuari)

---

## 1. Crear el projecte Supabase (gratuït)

1. Ves a https://supabase.com i fes clic a **Start your project** (registra't amb GitHub o email).
2. Crea un projecte nou: dóna-li un nom (ex. `ferro`), tria una contrasenya de base de dades i una regió propera.
3. Espera uns segons fins que el projecte estiga llest.

## 2. Crear la taula de dades

1. Al teu projecte Supabase: **SQL Editor** → **New query**.
2. Pega el contingut del fitxer **`supabase.sql`** d'aquest repositori.
3. Fes clic a **Run**.
4. Verifica a **Table Editor** que aparega la taula `user_data`.

## 3. Activar el login amb Google

### 3a. Google Cloud Console (crea l'OAuth)
1. Ves a https://console.cloud.google.com/apis/credentials → **+ Create credentials** → **OAuth client ID**.
   - Si et demana configurar la pantalla de consentiment, fes-ho primer (consent screen: External, afegeix el teu email com a test user).
2. Tipus: **Web application**.
3. En **Authorized redirect URIs** afegeix: `https://<REFERÈNCIA-DEL-TEU-PROJECTE>.supabase.co/auth/v1/callback`
   - (La referència la veuràs a Supabase, a Settings → General → Reference, ex. `abcdefghijklmnopqrst`)
4. Crea'l i copia el **Client ID** i el **Client secret**.

### 3b. Supabase (activa el provider)
1. Supabase → **Authentication** → **Providers** → **Google** → activa'l.
2. Pega el **Client ID** i **Client secret** de l'apartat anterior. **Save**.

## 4. Configurar les claus de l'app

1. Edita el fitxer **`supabase-config.js`**:
   - `url`: Supabase → Settings → API → **Project URL**.
   - `anonKey`: la mateixa pantalla → **anon public** key.
2. Guarda'l.

## 5. Pujar l'app a GitHub (GitHub Pages)

1. Crea un repositori nou a GitHub (públic o privat — **privat** si no vols que ningú més veja el codi; GitHub Pages funciona igual).
2. Puja **tots** aquests fitxers al repositori (són necessaris per a l'app i per a poder instal·lar-la com a PWA):
   - `index.html`
   - `supabase-config.js`
   - `manifest.json`
   - `sw.js`
   - `icon-192.png`
   - `icon-512.png`
   - `icon-maskable-512.png`
   - `apple-touch-icon.png`
   - `imatges/` (la carpeta sencera)
   - `supabase.sql`
   - `README.md`
   (si estàs des de terminal:
   ```
   git init
   git add index.html supabase-config.js manifest.json sw.js icon-192.png icon-512.png icon-maskable-512.png apple-touch-icon.png imatges supabase.sql README.md
   git commit -m "FERRO amb login i núvol"
   git branch -M main
   git remote add origin https://github.com/EL-TEU-USUARI/EL-REPO.git
   git push -u origin main
   ```
   )

   > **Important**: si no hi ha `manifest.json`, `sw.js` i les icones al servidor, el navegador **no podrà instal·lar l'app** (el botó «Instal·lar» et dirà que no es pot). Tots aquests fitxers s'han de pujar junts.
3. Activa GitHub Pages: repositori → **Settings** → **Pages** → *Deploy from a branch* → `main` / root → **Save**.
4. Espera 1–2 minuts. L'app estarà a: `https://EL-TEU-USUARI.github.io/EL-REPO/`

## 6. Configurar Supabase amb l'adreça de l'app

1. Supabase → **Authentication** → **URL Configuration**:
   - **Site URL**: l'adreça de l'app (ex. `https://EL-TEU-USUARI.github.io/EL-REPO/`).
   - **Redirect URLs**: afegeix també la mateixa adreça.
2. (Opcional) Si canvies l'adreça, torna a **3a** i actualitza la *Authorized redirect URI* de Google.

## 7. Prova-ho

1. Obre l'app. A dalt a la dreta veuràs el botó **👤** al costat de l'engranatge.
2. Clic → es connecta amb el compte de Google.
3. El botó **👤 desapareix** i, dins de **⚙️ Ajustos**, ara apareix la secció **Compte** amb el teu email i el botó **Tanca sessió**.
4. Les dades (exercicis, rutines, historial, ajustos, tema) es desen automàticament al núvol cada vegada que canvien.
5. Entra des d'un altre dispositiu amb el mateix compte i veuràs les mateixes dades.

---

## Com funciona la sincronització

- L'app continua treballant amb `localStorage` (funciona fins i tot sense connexió).
- Amb sessió iniciada, cada canvi es **puja** automàticament a la taula `user_data`.
- En iniciar sessió: si hi ha dades al núvol, **el núvol passa a l'aparell**; si encara no n'hi ha, es **pugen les dades locals**.
- Quan no hi ha sessió, l'app funciona normal però no sincronitza.

## Nota de privacitat

La clau anònima de Supabase és pública per disseny (es posa al navegador). El que **protegeix** les dades és el Row Level Security del SQL: cada usuari només pot llegir/esborrar les seues pròpies files.