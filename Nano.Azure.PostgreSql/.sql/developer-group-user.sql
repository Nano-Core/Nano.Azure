SELECT * FROM pgaadauth_create_principal('%DEVELOPER_GROUP_NAME%', false, false);

GRANT pg_read_all_data TO "%DEVELOPER_GROUP_NAME%";
GRANT pg_write_all_data TO "%DEVELOPER_GROUP_NAME%";