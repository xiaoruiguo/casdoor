# PostgreSQL Connection Information

## Server Information
- **Host**: nomad1
- **IP Address**: 192.168.36.211
- **OS**: Ubuntu 24.04 LTS

## Database Configuration
- **PostgreSQL Version**: 18.4
- **Database Name**: casdoor
- **Username**: casdoor
- **Password**: casdoor123
- **Port**: 5432

## Connection String
```
postgresql://casdoor:casdoor123@192.168.36.211:5432/casdoor
```

## Configuration Notes
- Remote access enabled (listening on all IPs)
- Auto-start on boot configured
- pg_hba.conf configured to allow casdoor user remote connections

## Service Status
```bash
sudo systemctl status postgresql
```

## Common Commands
```bash
# Connect to database
sudo -u postgres psql -d casdoor

# View service status
sudo systemctl status postgresql

# Restart service
sudo systemctl restart postgresql

# View logs
sudo tail -f /var/log/postgresql/postgresql-18-main.log
```

## Production Notes
- Change default password before production use
- Configure firewall rules to restrict access
- Consider using environment variables instead of hardcoding credentials
