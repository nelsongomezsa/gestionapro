#!/bin/zsh
# =====================================================================
# Usuario de MariaDB de mínimo privilegio para la API: solo SELECT, INSERT, UPDATE y DELETE
# sobre una base (sin DROP, ALTER, CREATE, GRANT, FILE ni acceso a otras bases).
#
#   api/sql/crear_usuario_api.sh [base] [usuario]
#   (por defecto: gestion_alquileres_pro y gestionap_api)
#
# Pide la contraseña nueva sin mostrarla y la pasa a MariaDB por la entrada estándar (no queda en el
# historial ni en la lista de procesos). Después, arranca la API con:
#   export DB_USER=gestionap_api DB_PASS=...   (o en el gestor de secretos del servidor)
# =====================================================================
set -euo pipefail
base=${1:-gestion_alquileres_pro}
usuario=${2:-gestionap_api}
mysql=${MYSQL:-/Applications/XAMPP/xamppfiles/bin/mysql}
[[ $base =~ ^[A-Za-z0-9_]+$ && $usuario =~ ^[A-Za-z0-9_]+$ ]] || { echo "Base o usuario no válidos"; exit 1; }

read -s "clave?Contraseña para $usuario (mínimo 16 caracteres): "; echo
read -s "repite?Repítela: "; echo
[[ $clave == $repite ]] || { echo "No coinciden"; exit 1; }
(( ${#clave} >= 16 )) || { echo "Demasiado corta"; exit 1; }
clave_sql=${clave//\\/\\\\}; clave_sql=${clave_sql//\'/\'\'}

# Usuario administrador de MariaDB con el que se ejecuta (por defecto root de XAMPP).
acceso=(-u "${MYSQL_ADMIN:-root}")
[[ -n ${MYSQL_ADMIN_PASSWORD:-} ]] && acceso+=(-p"$MYSQL_ADMIN_PASSWORD")
"$mysql" "${acceso[@]}" <<SQL
CREATE USER IF NOT EXISTS '$usuario'@'localhost' IDENTIFIED BY '$clave_sql';
ALTER USER '$usuario'@'localhost' IDENTIFIED BY '$clave_sql';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM '$usuario'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`$base\`.* TO '$usuario'@'localhost';
FLUSH PRIVILEGES;
SHOW GRANTS FOR '$usuario'@'localhost';
SQL
unset clave repite clave_sql
echo "Listo. Arranca la API con DB_USER=$usuario y DB_PASS (variables de entorno)."
