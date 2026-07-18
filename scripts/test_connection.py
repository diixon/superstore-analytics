import pyodbc

Connection_str =(
    "Driver={ODBC Driver 18 for SQL Server};"
    "Server=localhost;"
    "Database=SuperStoreProject;"
    "Trusted_Connection=yes;"
    "TrustServerCertificate=yes;")

Connection = pyodbc.connect(Connection_str)
print("Connected successfully!")

Connection.close()
print("Connection closed.")