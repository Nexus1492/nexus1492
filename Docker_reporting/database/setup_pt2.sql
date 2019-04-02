UPDATE mysql.user SET plugin = 'mysql_native_password' WHERE user = 'root';
UPDATE mysql.user SET authentication_string=PASSWORD('pw') WHERE User='root';