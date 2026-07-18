import pyodbc
import logging

logging.basicConfig(
    filename='pipeline.log',
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)

def get_connection():
    Connection_str = (
    "Driver={ODBC Driver 18 for SQL Server};"
    "Server=localhost;"
    "Database=SuperStoreProject;"
    "Trusted_Connection=yes;"
    "TrustServerCertificate=yes;")
    
    Connection = pyodbc.connect(Connection_str)
    return Connection