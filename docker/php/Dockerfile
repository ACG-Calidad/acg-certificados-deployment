FROM php:8.4-apache

# Metadatos
LABEL maintainer="Oliver Castelblanco <oliver@acgcalidad.co>"
LABEL description="PHP 8.4 + Apache para ACG Certificados"

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    # Herramientas básicas
    git \
    curl \
    zip \
    unzip \
    vim \
    nano \
    # Librerías para extensiones PHP
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    libicu-dev \
    # Imagick y GhostScript para conversión PDF a PNG
    libmagickwand-dev \
    ghostscript \
    # MariaDB client
    default-mysql-client \
    # Limpiar caché
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configurar extensión GD (para generación de imágenes/PDFs)
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd

# Instalar extensiones PHP requeridas
RUN docker-php-ext-install \
    pdo \
    pdo_mysql \
    mysqli \
    mbstring \
    zip \
    exif \
    pcntl \
    bcmath \
    intl \
    opcache \
    soap

# Instalar Imagick via PECL
RUN pecl install imagick \
    && docker-php-ext-enable imagick

# Configurar ImageMagick para permitir lectura de PDFs
RUN sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/' /etc/ImageMagick-6/policy.xml || true

# Instalar Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Configurar Apache
# Habilitar mod_rewrite para URLs amigables
RUN a2enmod rewrite headers expires

# Habilitar configuración de certificados (el archivo se monta via docker-compose)
# Creamos un script de inicio que habilita la conf si existe
RUN echo '#!/bin/bash\n\
if [ -f /etc/apache2/conf-available/certificados.conf ]; then\n\
    a2enconf certificados\n\
fi\n\
exec apache2-foreground' > /usr/local/bin/start-apache.sh \
    && chmod +x /usr/local/bin/start-apache.sh

# Configurar DocumentRoot
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Crear estructura de directorios necesaria
RUN mkdir -p /var/www/html/api \
    /var/www/html/public \
    /var/www/html/storage/pdfs \
    /var/www/html/storage/logs \
    /var/www/html/storage/temp

# Crear .htaccess para el API
RUN echo 'RewriteEngine On\n\
RewriteCond %{REQUEST_FILENAME} !-f\n\
RewriteCond %{REQUEST_FILENAME} !-d\n\
RewriteRule ^(.*)$ $1.php [L]\n\
\n\
# CORS Headers para desarrollo\n\
Header set Access-Control-Allow-Origin "*"\n\
Header set Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"\n\
Header set Access-Control-Allow-Headers "Content-Type, Authorization"' > /var/www/html/api/.htaccess

# Configurar permisos
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 777 /var/www/html/storage

# Exponer puerto 80
EXPOSE 80

# Configurar timezone
ENV TZ=America/Bogota
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Comando por defecto (Apache debe ejecutarse como root para bind al puerto 80)
# Usa el script que habilita certificados.conf si existe
CMD ["/usr/local/bin/start-apache.sh"]
