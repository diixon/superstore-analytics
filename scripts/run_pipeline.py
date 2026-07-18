from db_utils import get_connection
from load_people import load_people
from load_orders import load_orders
from load_returns import load_returns
from run_transformations import run_silver_layer,run_gold_layer
import logging

conn = get_connection()
logging.info("Got a connection successfully!")
try:
    load_people(conn)
except Exception as e:
    logging.error(f'Failed to load People: {e}')
try:
    load_orders(conn)
except Exception as e:
    logging.error(f'Failed to load Orders: {e}')
try:
    load_returns(conn)
except Exception as e:
    logging.error(f'Failed to load Returns: {e}')
try:
    run_silver_layer(conn)
except Exception as e:
    logging.error(f'Failed to load silver layer: {e}')
try:
    run_gold_layer(conn)
except Exception as e:
    logging.error(f'Failed to load gold layer: {e}')
conn.close()
logging.info("Closed it.")
