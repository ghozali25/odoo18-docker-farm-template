FROM python:3.12-slim-bookworm

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        git \
        build-essential \
        gcc \
        g++ \
        wkhtmltopdf \
        libpq-dev \
        libldap2-dev \
        libsasl2-dev \
        libxml2-dev \
        libxslt1-dev \
        libjpeg-dev \
        zlib1g-dev \
        libffi-dev \
        libssl-dev \
        libfreetype6-dev \
        liblcms2-dev \
        libopenjp2-7-dev \
        libtiff-dev \
        libwebp-dev \
        libharfbuzz-dev \
        libfribidi-dev \
        fonts-dejavu \
        node-less \
        npm \
        && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch 18.0 https://github.com/odoo/odoo.git /opt/odoo

WORKDIR /opt/odoo

RUN python -m pip install --no-cache-dir --upgrade \
        pip \
        setuptools \
        wheel

RUN pip install --no-cache-dir -r requirements.txt

# --- Library tambahan untuk modul-modul custom ---
# izi_data:                pandas, sqlparse, xlsxwriter, requests
# upgrade_analysis:        odoorpc, openupgradelib
# sql_export_excel:        openpyxl
# auto_database_backup:    paramiko, boto3, dropbox, pyncclient, nextcloud-api-wrapper
# izi_tokopedia:           pycryptodomex
# izi_data_lib_*:          mysql-connector-python, gspread, oauth2client
# izi_data_lib_mssql:      pymssql
RUN pip install --no-cache-dir \
        pandas \
        "sqlparse>=0.4.2" \
        xlsxwriter \
        requests \
        odoorpc \
        openupgradelib \
        openpyxl \
        paramiko \
        boto3 \
        dropbox \
        pyncclient \
        nextcloud-api-wrapper \
        pycryptodomex \
        mysql-connector-python \
        gspread \
        oauth2client \
        pymssql

# face_recognition (opsional — dlib berat di-compile, aktifkan bila perlu):
# RUN pip install --no-cache-dir face_recognition

RUN npm install -g rtlcss

RUN mkdir -p \
        /var/lib/odoo \
        /mnt/extra-addons \
        /mnt/custom-addons \
        /etc/odoo

RUN useradd \
        --system \
        --home /var/lib/odoo \
        --shell /bin/bash \
        odoo

RUN chown -R odoo:odoo \
        /var/lib/odoo \
        /opt/odoo \
        /mnt/extra-addons \
        /mnt/custom-addons

COPY config/odoo.conf /etc/odoo/odoo.conf

RUN chown odoo:odoo /etc/odoo/odoo.conf

USER odoo

EXPOSE 8069 8072

CMD ["python3", "/opt/odoo/odoo-bin", "-c", "/etc/odoo/odoo.conf"]
