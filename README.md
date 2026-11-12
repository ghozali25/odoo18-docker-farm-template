# Odoo 18 Docker Template — Farm

Template deploy Odoo 18 khusus **pertanian (farm)**, turunan dari
`odoo18-docker-template`. Dipakai untuk instance farm terpisah dari database
produksi keuangan — 94 modul pertanian hasil port odoo-farm ke Odoo 18 tinggal
di sini, bukan di database `masterdata`.

Perbedaan dari template umum:

- Container `odoo18-farm` + `odoo18-farm-db` (bukan `odoo18` / `odoo18-db`)
- Port host **8076 → 8069** dan **8077 → 8072** (longpolling)
- Database memakai image kustom (`Dockerfile.db`, bukan `postgres:16` polos)
  karena modul `farm_ai_agent` butuh ekstensi PostgreSQL **pgvector** —
  image `postgres:16` standar tidak menyertakannya, dan tanpa itu install
  modul gagal (`extension "vector" is not available`)

Sudah termasuk di image Odoo (dari `Dockerfile`, sama seperti template umum):

- Dependency resmi Odoo 18 dari `requirements.txt`
- `pandas`, `sqlparse`, `xlsxwriter`, `requests`, `odoorpc`,
  `openupgradelib`, `openpyxl`, `paramiko`, `boto3`, `dropbox`,
  `pyncclient`, `nextcloud-api-wrapper`, `pycryptodomex`,
  `mysql-connector-python`, `gspread`, `oauth2client`, `pymssql`

## Cara pakai

```bash
git clone https://github.com/ghozali25/odoo18-docker-farm-template.git odoo18-farm
cd odoo18-farm
cp .env.example .env
# edit .env  -> isi POSTGRES_PASSWORD (acak, mis. openssl rand -hex 16)
# edit config/odoo.conf -> samakan db_password dengan .env,
#                          ganti admin_passwd
mkdir -p data/postgres data/odoo addons custom_addons
docker compose up -d --build
```

Bila folder di atas dibuat memakai `sudo`, samakan pemiliknya dengan user
Odoo di container (kalau tidak, Odoo error `Permission denied` di
`/var/lib/odoo/sessions`):

```bash
docker compose exec -u 0 odoo chown -R odoo:odoo /var/lib/odoo /mnt/extra-addons /mnt/custom-addons
docker compose restart odoo
```

Odoo bisa dibuka di `http://<ip-server>:8076`, Database Manager di
`http://<ip-server>:8076/web/database/manager` (selama `list_db = True`).

Folder penting (semua di host, aman dari `docker compose up -d` berulang):

| Folder host        | Isi                                   |
|--------------------|---------------------------------------|
| `data/postgres/`   | File database PostgreSQL              |
| `data/odoo/`       | Filestore & attachment Odoo           |
| `addons/`          | Addons tambahan (extra)               |
| `custom_addons/`   | Modul farm (94 modul)                 |

## Pasang modul farm

Modul pertanian: [ghozali25/odoo-farm-house](https://github.com/ghozali25/odoo-farm-house)
(94 modul, port odoo-farm ke Odoo 18, AGPL-3). Salin folder-folder modul ke
`custom_addons/`, lalu install semuanya dalam satu perintah — wajib pakai
`-c` (config) dan `--no-http` (server container sedang jalan):

```bash
MODS=$(ls custom_addons | tr "\n" "," | sed "s/,$//")
docker exec -u odoo odoo18-farm python3 /opt/odoo/odoo-bin \
  -c /etc/odoo/odoo.conf \
  --addons-path=/opt/odoo/odoo/addons,/opt/odoo/addons,/mnt/extra-addons,/mnt/custom-addons \
  -d farm -i "$MODS" --stop-after-init --no-http
docker restart odoo18-farm
```

Catatan: buat database **tanpa** `--without-demo=all` bila ingin data demo;
perintah install di atas tidak memakai flag itu, jadi demo data ikut
ter-install bila database dibuat dengan demo data.

## Sesudah database jadi

1. **Matikan `list_db`** di `config/odoo.conf` (`list_db = False`) lalu
   `docker restart odoo18-farm` — supaya Database Manager tidak bisa
   dibuka publik.
2. **Isi API key LLM** di konfigurasi LLM database farm
   (`farm_ai_llm_integration`): `api_base_url` sudah default ke endpoint
   OpenAI-compatible, lalu tekan **Test API Call**.
3. **Jangan recreate container database tanpa image ini** — `Dockerfile.db`
   yang menjamin pgvector tetap ada. `docker compose up -d --build db`
   me-recreate container db saja; data di `./data/postgres` tetap utuh.

## Opsi: data di /mnt/storage

Bila server punya mount storage besar (mis. `/mnt/storage`), clone langsung
di sana:

```bash
cd /mnt/storage
sudo git clone https://github.com/ghozali25/odoo18-docker-farm-template.git odoo18-farm
cd odoo18-farm
```

Sisa langkahnya sama seperti di atas; semua folder `data/`, `addons/`,
`custom_addons/` otomatis berada di `/mnt/storage/odoo18-farm/`.

## nginx (opsional, pola yang dipakai live)

```nginx
server {
    listen 443 ssl;
    server_name farm.hiddenlab.me;
    client_max_body_size 100M;
    location / {
        proxy_pass http://127.0.0.1:8076;
    }
    location /websocket {
        proxy_pass http://127.0.0.1:8077;
    }
    location /longpolling {
        proxy_pass http://127.0.0.1:8077;
    }
}
```
